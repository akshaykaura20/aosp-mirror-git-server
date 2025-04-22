#!/bin/bash

set -euo pipefail

CONTAINER_MIRROR_MOUNT_PATH="/usr/local/apache2/htdocs"
CONTAINER_MIRROR_SCRIPT_MOUNT_PATH="/opt/internal/scripts/"

# Create /healthcheck path for apache container healthchecks
echo "healthy" > "$CONTAINER_MIRROR_MOUNT_PATH/healthcheck"

# Create a user in the password file
htpasswd -bc $CONTAINER_MIRROR_MOUNT_PATH/../conf/.htpasswd "$USERNAME" "$PASSWORD"

# Provide permissions to Apache user for Git repository directory
chgrp -R www-data $CONTAINER_MIRROR_MOUNT_PATH/*
chown -R www-data:www-data $CONTAINER_MIRROR_MOUNT_PATH/*
chmod -R 775 $CONTAINER_MIRROR_MOUNT_PATH/*
# Provide permissions to Apache user for mirror related scripts
chgrp -R www-data $CONTAINER_MIRROR_SCRIPT_MOUNT_PATH/*
chown -R www-data:www-data $CONTAINER_MIRROR_SCRIPT_MOUNT_PATH/*
chmod -R 775 $CONTAINER_MIRROR_SCRIPT_MOUNT_PATH/*

# Start Apache in foreground
exec httpd-foreground