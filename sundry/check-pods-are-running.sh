#!/bin/bash

check_pods_running() {
  local layer_value="$1"
  local selector="mojaloop.layer=$layer_value"
  local restart_threshold=3  # Set the restart threshold to your desired value
  local end_time=$((SECONDS + 300))  # Set the end time to 5 minutes from now

  while [ $SECONDS -lt $end_time ]; do
    local pods_not_running=$(kubectl get pods --selector="$selector" | grep -v NAME | grep -v Running | wc -l)
    local unstable_pods=$(kubectl get pods --selector="$selector" --no-headers | awk '{if ($3!="Running") print $1}')
    local pods_restart_count=$(kubectl get pods --selector="$selector" -o json | jq -r '.items[] | select(.status.containerStatuses[].restartCount > 0) | .metadata.name')

    if [ "$pods_not_running" -eq 0 ] && [ -z "$unstable_pods" ] && [ -z "$pods_restart_count" ]; then
      echo "All pods with mojaloop.layer=$layer_value are in running and stable state (within restart threshold)."
      return 0
    fi

    sleep 5  # Wait for 5 seconds before the next check
  done

  echo "Not all pods with mojaloop.layer=$layer_value are in running and stable state (within restart threshold)."
  return 1
}

# Usage example: check_pods_running "crosscut"
check_pods_running "$1"
