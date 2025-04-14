#!/bin/bash

# Function to check for errors and exit the script
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

set_working_directory() {
    mkdir -p /usr/local/apache2/htdocs/mirror
    cd /usr/local/apache2/htdocs/mirror || error_exit "Failed to change directory to /usr/local/apache2/htdocs/mirror"
    echo "Set working directory to /usr/local/apache2/htdocs/mirror"
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

# Flow starts here
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