#!/bin/bash

# Define the minimum required free space in GB
MIN_FREE_SPACE=59

# Get the current free space on the root filesystem in GB
free_space=$(df -BG / | awk '{print $4}' | tail -n 1 | sed 's/G//')

# Compare the free space to the minimum required free space
if [[  $free_space -gt $MIN_FREE_SPACE ]] ; then
  echo "Root filesystem has at least ${MIN_FREE_SPACE}GB free space"
else
  echo "Root filesystem has less than ${MIN_FREE_SPACE}GB free space"
fi

# Get the total amount of installed RAM in GB
total_ram=$(free -g | awk '/^Mem:/{print $2}')

# Check if the total RAM is less than 4GB
if [ $total_ram -lt 4 ]; then
  echo "Your system has less than 4GB of RAM."
else
  echo "Your system has at least 4GB of RAM."
fi

# Set the minimum amount of RAM in GB
min_ram=32

# Get the total amount of installed RAM in GB
total_ram=$(free -g | awk '/^Mem:/{print $2}')

# Check if the total RAM is less than the minimum amount
if [ $total_ram -lt $min_ram ]; then
  echo "Your system has less than $min_ram GB of RAM."
else
  echo "Your system has at least $min_ram GB of RAM."
fi
