#!/bin/bash

# Get current timestamp
timestamp=$(date +"%Y-%m-%d %T")

# Sleep for 30 seconds
sleep_duration=3

# Declare associative array to store memory usage
declare -A mem_usage

# Get total memory
total_mem=$(free -m | awk 'NR==2{printf "%.2f", $2/1024}')

# Loop 5 times to get memory usage for top 5 processes
for i in {1..5}; do
  # Get process name and memory usage
  process=$(ps aux --sort=-%mem | awk 'NR==2{print $11}')
  mem_used=$(ps aux --sort=-%mem | awk 'NR==2{printf "%.2f", $6/1024}')
  mem_percent=$(ps aux --sort=-%mem | awk 'NR==2{printf "%.2f", $4}')
  
  # Add memory usage to associative array
  mem_usage["$process"]=$mem_used,$mem_percent
  
  # Sleep for 30 seconds
  sleep $sleep_duration
done

# Print total memory usage
echo "Total memory usage: $total_mem GB"

# Print top 5 processes and their memory usage
echo "Top 5 memory using processes:"
printf "%-30s %-20s %-20s\n" "Process" "Memory Used (GB)" "Memory Used (%)"
for process in "${!mem_usage[@]}"; do
  mem_used_gb=$(echo "${mem_usage[$process]}" | cut -d',' -f1)
  mem_used_percent=$(echo "${mem_usage[$process]}" | cut -d',' -f2)
  printf "%-30s %-20s %-20s\n" "$process" "$mem_used_gb GB" "$mem_used_percent %"
done
