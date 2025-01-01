#!/bin/bash

# Function to check for errors and exit the script
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# # Function to install necessary tools using microdnf
# install_dependencies() {
#     microdnf update -y || error_exit "Failed to update microdnf"
#     microdnf install -y python3 gnupg curl git || error_exit "Failed to install dependencies"
#     echo "Installed python3, gnupg, curl and git."
# }

# # Function to download and install the repo tool with signature verification
# install_repo_tool() {
#     REPO=$(mktemp /tmp/repo.XXXXXXXXX) || error_exit "Failed to create temp file for repo"
#     curl -o ${REPO} https://storage.googleapis.com/git-repo-downloads/repo || error_exit "Failed to download repo tool"
#     for server in hkps://keys.openpgp.org hkps://keyserver.ubuntu.com hkps://pgp.mit.edu; do 
#         gpg --keyserver $server --recv-key 8BB9AD793E8E6153AF0F9A4416530D5E920F5C65 && echo "Success with $server" && break; 
#     done || error_exit "Failed to receive GPG key"
#     curl -s https://storage.googleapis.com/git-repo-downloads/repo.asc | gpg --verify - ${REPO} || error_exit "Failed to verify repo tool"
#     install -m 755 ${REPO} /usr/bin/repo || error_exit "Failed to install repo tool"
#     echo "Installed repo tool."
# }

# # Function to configure git, mainly for as fast repo sync as possible
# configure_git() {
#     git config --global http.postBuffer 524288000
#     git config --global user.name "root"
#     git config --global user.email "root@email.com"
#     git config --global color.ui true
#     echo "Configured git."
# }

set_working_directory() {
    mkdir -p mirror
    cd mirror || error_exit "Failed to change directory to /var/www/"
    echo "Set working directory to /var/www/"
}

# Function to initialize a new repo on local with mirror manifest
initialise_new_repo() {
    echo "Downloading and initializing new repo with manifest..."
    repo init -u https://android.googlesource.com/mirror/manifest --mirror || error_exit "Failed to initialize repo with manifest"

    echo "Removing unnecessary refs..."
    repo forall -c "git for-each-ref --format '%(refname)' refs/changes/ | xargs -n1 git update-ref -d" || error_exit "Failed to remove unnecessary refs"
}

# Function to perform repo sync with Google's source
sync_mirror() {
    start_time=$(date +%s)

    echo "Starting repo sync... at $start_time"
    repo sync -j$(nproc) || error_exit "Failed to perform repo sync" # Adjust -j flag for parallel downloads

    end_time=$(date +%s)
    sync_time=$((end_time - start_time))
    echo "Full repo sync completed in $((sync_time / 3600))h $(((sync_time % 3600) / 60))m $((sync_time % 60))s"

    local status=${1:-updated}
    echo "Sync complete. Local AOSP mirror $status."

    echo "Performing garbage collection..."
    repo forall -c "git gc --aggressive --prune=all" || error_exit "Failed to perform garbage collection"
}

# install_dependencies
# install_repo_tool
# configure_git
set_working_directory

# Check if .repo directory exists
if [[ ! -d ".repo" ]]; then
    echo ".repo folder NOT found."
    initialise_new_repo
    sync_mirror "created"
else
    echo ".repo folder found. Reusing existing repo. Updating mirror..."
    sync_mirror
fi