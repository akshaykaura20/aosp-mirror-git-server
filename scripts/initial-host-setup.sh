#!/bin/bash

set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Updating system packages..."
sudo apt update

echo "Installing prerequisite packages..."
apt install -y apt-transport-https ca-certificates curl software-properties-common

echo "Adding Docker official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "Adding Docker APT repository..."
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Updating package index again..."
sudo apt update

echo "Installing Docker Engine..."
sudo apt install -y docker-ce docker-ce-cli containerd.io

echo "Verifying Docker installation..."
sudo docker --version

echo "Installing Docker Compose plugin..."
sudo apt install -y docker-compose-plugin

echo "Creating necessary directories..."
mkdir -p /var/www/{mirror,setup-scripts}
