#!/bin/bash

set -euo pipefail

echo "Waiting for VM to boot and complete startup scripts..."
MAX_SERVER_DISCOVERY_RETRY=20  # Wait up to 10 minutes (20 * 30s)
SERVER_DISCOVERY_RETRY=0
SLEEP_TIME=30
while true; do
    if curl --fail -v http://${MIRROR_LB_IP}/healthcheck; then
        echo "Server is healthy!"
        exit 0
    fi
    SERVER_DISCOVERY_RETRY=$((SERVER_DISCOVERY_RETRY + 1))
    if [ $SERVER_DISCOVERY_RETRY -ge $MAX_SERVER_DISCOVERY_RETRY ]; then
        echo "[ERROR] Timed out waiting for Server to become healthy."
        exit 1
    fi
    echo "Attempt $SERVER_DISCOVERY_RETRY: Server Not healthy yet, retrying in ${SLEEP_TIME}s..."
    sleep $SLEEP_TIME
done