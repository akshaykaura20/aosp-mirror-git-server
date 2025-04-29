#!/bin/bash

set -euo pipefail

MAX_HEALTH_CHECK_RETRY=20  # Wait up to 10 minutes (20 * 30s)
HEALTH_CHECK_RETRY=0
SLEEP_TIME=30
echo "Load Balancer backend service name: $MIRROR_LB_BACKEND_SERVICE_NAME"
while true; do
    HEALTH_STATUS=$(gcloud compute backend-services get-health $MIRROR_LB_BACKEND_SERVICE_NAME --global --format='value(healthStatus.healthState)' 2>&1)

    if [[ "$HEALTH_STATUS" == "HEALTHY" ]]; then
        echo "Load Balancer backend is $HEALTH_STATUS."
        exit 0
    fi
    HEALTH_CHECK_RETRY=$((HEALTH_CHECK_RETRY + 1))
    if [ $HEALTH_CHECK_RETRY -ge $MAX_HEALTH_CHECK_RETRY ]; then
        echo "[ERROR] Timed out waiting for Load Balancer backend to become healthy."
        exit 1
    fi
    echo "[ERROR] Load Balancer backend is NOT HEALTHY. Status: $HEALTH_STATUS"
    echo "Attempt $HEALTH_CHECK_RETRY of $MAX_HEALTH_CHECK_RETRY: Retrying in ${SLEEP_TIME}s..."
    sleep $SLEEP_TIME
done