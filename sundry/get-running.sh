#!/bin/bash

check_pods_running() {
  local app_layer="$1"
  local end_time=$((SECONDS + 180 ))  # Set the end time to 5 minutes from now

  while [ $SECONDS -lt $end_time ]; do
    local pods_not_running=$(kubectl get pods --selector="mojaloop.layer=$app_layer" | grep -v NAME | grep -v Running | wc -l)
    local containers_not_ready=$(kubectl get pods --selector="mojaloop.layer=$app_layer" --no-headers | awk '{split($2,a,"/"); if (a[1]!=a[2]) print}' | wc -l)

    if [ "$pods_not_running" -eq 0 ] && [ "$containers_not_ready" -eq 0 ]; then
      echo "All pods and containers in application layer  \"$app_layer\" are in running and ready state."
      return 0
    fi

    echo "sleep 5"
    sleep 5  # Wait for 5 seconds before the next check
  done

  echo "Not all pods and containers with selector \"$app_layer\" are in running and ready state."
  return 1
}

# Usage example: check_pods_running "mojaloop.layer=crosscut"
check_pods_running "$1"


