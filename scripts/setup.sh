#!/bin/bash

set -euo pipefail

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

##########################################
# DIRECTORY AND MOUNTING STRUCTURE
# /var/www/                       <-- Persistent Disk (PD) mount point (MIRROR_DISK_MOUNT_PATH)
# ├── mirror/                     <-- AOSP mirror data served by Apache container; first vol mount for container (MIRROR_PATH_INSIDE_DISK)
# └── .internal/
#     └── scripts/                <-- Internal scripts, second vol mount for container (MIRROR_SCRIPT_PATH_INSIDE_DISK)
#         └── mirror-aosp.sh      <-- Executable mirror script
##########################################

MIRROR_DISK_DEVICE="/dev/disk/by-id/google-aosp-mirror-disk" # */google-<disk-name-in-tf>/*
MIRROR_DISK_MOUNT_PATH="/var/www"
MIRROR_PATH_INSIDE_DISK="/var/www/mirror"
MIRROR_SCRIPT_PATH_INSIDE_DISK="$MIRROR_DISK_MOUNT_PATH/.internal/scripts"
REPO_CLONE_PATH="/opt/git-server-configs"
GH_REPO="${gh_repo}"
DOCKER_DIR_PATH="$REPO_CLONE_PATH/docker"
GIT_SERVER_ADDRESS="${lb_static_ip}"
GIT_SERVER_USERNAME="root"
GIT_SERVER_CONTAINER_NAME="sdv-mirror-git-server"
# secrets to fetch from GCP
GH_REPO_PAT=""
GIT_SERVER_PASSWORD=""

# Extract this file's name, create log file and log everything to it
current_script_name="$(basename "$0")"
log_file="/var/log/$current_script_name.log"
exec > "$log_file" 2>&1

##########################################
# INSTALL NECESSARY PACKAGES
##########################################
echo "[INFO] Updating system packages..."
sudo apt update

echo "[INFO] Installing prerequisite packages..."
apt install -y apt-transport-https ca-certificates curl software-properties-common

echo "[INFO] Adding Docker official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "[INFO] Adding Docker APT repository..."
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[INFO] Updating package index again..."
sudo apt update

echo "[INFO] Installing Docker Engine..."
sudo apt install -y docker-ce docker-ce-cli containerd.io

echo "[INFO] Verifying Docker installation..."
sudo docker --version

echo "[INFO] Installing Docker Compose plugin..."
sudo apt install -y docker-compose-plugin

# Install gcloud if not present
if ! command -v gcloud &> /dev/null; then
  echo "[INFO] Installing gcloud via apt..."
  # Add the Cloud SDK distribution URI as a package source
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
    | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  # Import the Google Cloud public key
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  # Update and install the Cloud SDK
  sudo apt-get update && sudo apt-get install -y google-cloud-sdk
  # Initialize gcloud
  gcloud init
fi

##########################################
# MOUNT PERSISTENT DISK
##########################################
echo "Setting up persistent disk mount..."
# Wait for disk to appear
DISK_DISCOVERY_WAIT_TIME=5 # seconds
MAX_DISK_DISCOVERY_RETRY=60  # Wait up to 5 minutes (60 * 5s)
DISK_DISCOVERY_RETRY=0
while true; do
  if [ -b "$MIRROR_DISK_DEVICE" ]; then
    echo "[INFO] Persistent disk found: $MIRROR_DISK_DEVICE"
    break
  fi
  DISK_DISCOVERY_RETRY=$((DISK_DISCOVERY_RETRY + 1))
  if [ $DISK_DISCOVERY_RETRY -ge $MAX_DISK_DISCOVERY_RETRY ]; then
    echo "[ERROR] Timed out waiting for disk to be available."
    echo "[ERROR] Disk $MIRROR_DISK_DEVICE not found after $MAX_DISK_DISCOVERY_RETRY attempts. Exiting."
    exit 1
  fi
  echo "[INFO] Waiting for disk device $MIRROR_DISK_DEVICE... ($DISK_DISCOVERY_RETRY/$MAX_DISK_DISCOVERY_RETRY)"
  sleep $DISK_DISCOVERY_WAIT_TIME
done

# Format the disk only if it's not already formatted
if ! blkid "$MIRROR_DISK_DEVICE" &>/dev/null; then
  echo "[INFO] Formatting disk $MIRROR_DISK_DEVICE with ext4 filesystem..."
  mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0 "$MIRROR_DISK_DEVICE"
else
  echo "[INFO] Disk $MIRROR_DISK_DEVICE already formatted."
fi

echo "[INFO] Ensuring mount point exists at $MIRROR_DISK_MOUNT_PATH..."
mkdir -p "$MIRROR_DISK_MOUNT_PATH"

# Mount the disk if not already mounted
if ! mountpoint -q "$MIRROR_DISK_MOUNT_PATH"; then
  echo "[INFO] Mounting disk at $MIRROR_DISK_MOUNT_PATH..."
  mount -o discard,defaults "$MIRROR_DISK_DEVICE" "$MIRROR_DISK_MOUNT_PATH"
else
  echo "[INFO] Disk already mounted at $MIRROR_DISK_MOUNT_PATH"
fi

# Get UUID of the disk
UUID=$(blkid -s UUID -o value "$MIRROR_DISK_DEVICE")
FSTAB_ENTRY="UUID=$UUID  $MIRROR_DISK_MOUNT_PATH  ext4  discard,defaults,nofail  0  2"
# Add to /etc/fstab for auto-mount on reboot
if grep -q "$UUID" /etc/fstab; then
  if ! grep -qF "$FSTAB_ENTRY" /etc/fstab; then
    echo "[INFO] Updating existing /etc/fstab entry for UUID=$UUID..."
    sudo sed -i "\|UUID=$UUID|c\\$FSTAB_ENTRY" /etc/fstab
  else
    echo "[INFO] Correct /etc/fstab entry already exists."
  fi
else
  echo "[INFO] Adding new entry to /etc/fstab..."
  echo "$FSTAB_ENTRY" >> /etc/fstab
fi

# Create necessary directories
echo "[INFO] Creating necessary directories..."
mkdir -p $MIRROR_PATH_INSIDE_DISK

##########################################
# GET SECRETS AND CLONE REPO
##########################################
GH_REPO_PAT=$(gcloud secrets versions access latest --secret=GH_REPO_PAT)
GIT_SERVER_PASSWORD=$(gcloud secrets versions access latest --secret=GIT_SERVER_PASSWORD)

# Clone AOSP Mirror Git server repo if not already exists
if [ ! -d "$REPO_CLONE_PATH/.git" ]; then
  echo "[INFO] Cloning AOSP Mirror Git server repo to access scripts..."
  git clone "https://$GH_REPO_PAT@$GH_REPO" "$REPO_CLONE_PATH"
else
  echo "[INFO] Repo already cloned. Pulling latest changes..."
  git -C "$REPO_CLONE_PATH" pull
fi

##########################################
# CONFIGURE GIT SERVER
##########################################
# Set ServerName dynamically in apache config
APACHE_SERVER_NAME_FILE_PATH="$REPO_CLONE_PATH/docker/apache-config/apache-server-name.conf"
echo "[INFO] Using host IP as ServerName: $GIT_SERVER_ADDRESS"
sed -i "s|^ServerName .*|ServerName $GIT_SERVER_ADDRESS|" $APACHE_SERVER_NAME_FILE_PATH

# Create .env file for the git server container
echo "[INFO] Writing .env file..."
cat <<EOF > "$DOCKER_DIR_PATH/.env"
USERNAME=$GIT_SERVER_USERNAME
PASSWORD=$GIT_SERVER_PASSWORD
CONTAINER_NAME=$GIT_SERVER_CONTAINER_NAME
HOST_MIRROR_MOUNT_PATH=$MIRROR_PATH_INSIDE_DISK
HOST_MIRROR_SCRIPT_MOUNT_PATH=$MIRROR_SCRIPT_PATH_INSIDE_DISK
EOF
# note that we mount two separate directories from container onto host- for mirror, and for mirror script
chmod 600 "$DOCKER_DIR_PATH/.env"

##########################################
# START DOCKER COMPOSE GIT SERVER STACK
##########################################
echo "[INFO] Starting docker-compose stack..."
cd "$REPO_CLONE_PATH/docker"
sudo docker compose up --build -d

# Wait for container healthy status
MAX_CONTAINER_DISCOVERY_RETRY=120  # Wait up to 10 minutes (60 * 5s)
CONTAINER_DISCOVERY_RETRY=0
while true; do
  STATUS=$(docker inspect -f '{{.State.Health.Status}}' $GIT_SERVER_CONTAINER_NAME 2>/dev/null || echo "notfound")
  if [ "$STATUS" = "healthy" ]; then
    echo "[INFO] Container '$GIT_SERVER_CONTAINER_NAME' is healthy!"
    break
  elif [ "$STATUS" = "unhealthy" ]; then
    echo "[ERROR] Container '$GIT_SERVER_CONTAINER_NAME' became unhealthy!"
    exit 1
  fi
  CONTAINER_DISCOVERY_RETRY=$((CONTAINER_DISCOVERY_RETRY + 1))
  if [ $CONTAINER_DISCOVERY_RETRY -ge $MAX_CONTAINER_DISCOVERY_RETRY ]; then
    echo "[ERROR] Timed out waiting for container '$GIT_SERVER_CONTAINER_NAME' to become healthy."
    exit 1
  fi
  if [ "$STATUS" = "notfound" ]; then
    echo "[INFO] Container '$GIT_SERVER_CONTAINER_NAME' not found yet, waiting... ($CONTAINER_DISCOVERY_RETRY/$MAX_CONTAINER_DISCOVERY_RETRY)"
  else
    echo "[INFO] Waiting for container '$GIT_SERVER_CONTAINER_NAME' healthy status... ($CONTAINER_DISCOVERY_RETRY/$MAX_CONTAINER_DISCOVERY_RETRY)"
  fi
  sleep 5
done

##########################################
# START AOSP MIRROR SCRIPT IN CONTAINER
##########################################
# Copy AOSP mirror script to PD making it accessible to container
mkdir -p $MIRROR_SCRIPT_PATH_INSIDE_DISK
echo "[INFO] Copying AOSP Mirror shell script to directory '$MIRROR_SCRIPT_PATH_INSIDE_DISK' inside PD..."
cp -u $REPO_CLONE_PATH/scripts/mirror-aosp.sh $MIRROR_SCRIPT_PATH_INSIDE_DISK

echo "[INFO] Running AOSP mirror script inside container..."
CONTAINER_MIRROR_SCRIPT_MOUNT_PATH="/opt/internal/scripts"
# note that the host's (or PD's) path: MIRROR_SCRIPT_PATH_INSIDE_DISK maps the container's CONTAINER_MIRROR_SCRIPT_MOUNT_PATH
# and to execute a script inside the container, we have to use the container's path CONTAINER_MIRROR_SCRIPT_MOUNT_PATH
docker exec -d "$GIT_SERVER_CONTAINER_NAME" bash -c "$CONTAINER_MIRROR_SCRIPT_MOUNT_PATH/mirror-aosp.sh > $CONTAINER_MIRROR_SCRIPT_MOUNT_PATH/mirror-aosp.log 2>&1 &"
echo "[INFO] Mirror script triggered."

echo "[DONE] Mirror startup Completed!"

