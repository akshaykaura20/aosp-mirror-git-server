#!/bin/bash

set -euo pipefail

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

export REPO_CLONE_PATH="/opt/git-server-configs"
GH_REPO="${gh_repo}"
GH_REPO_PAT=""
export GIT_SERVER_ADDRESS="${lb_static_ip}"

##########################################
# GET REPO PAT AND CLONE REPO
##########################################
# create repo dir
mkdir -p $REPO_CLONE_PATH
# fetch repo PAT secret from GCP
GH_REPO_PAT=$(gcloud secrets versions access latest --secret=GH_REPO_PAT)

# Clone AOSP Mirror Git server repo if not already exists
if [ ! -d "$REPO_CLONE_PATH/.git" ]; then
  echo "Cloning AOSP Mirror Git server repo to access scripts..."
  git clone "https://$GH_REPO_PAT@$GH_REPO" "$REPO_CLONE_PATH"
else
  echo "Repo already cloned. Pulling latest changes..."
  git -C "$REPO_CLONE_PATH" pull
fi

##########################################
# EXECUTE HOST SETUP AND STARTUP SCRIPT
##########################################
bash "$REPO_CLONE_PATH/scripts/setup.sh"