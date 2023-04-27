#!/bin/bash

# while true; do
#   date=$(date '+%Y-%m-%d %H:%M:%S')
#   meminfo=$(free -m | awk 'NR==2{printf "%.2fGB used, %.2fGB free (%.2f%% used)\n", $3/1024, $4/1024, $3*100/($3+$4)}')
#   echo "$date $meminfo"
#   sleep 60
# done
#=================
# echo "Timestamp    | RAM used   | RAM free   | RAM used % | Top 5 Memory-Consuming Processes"
# echo "--------------------------------------------------------------------------------"

# while true; do
#   date=$(date '+%Y-%m-%d %H:%M:%S')
#   meminfo=$(free -m | awk 'NR==2{printf "%.2fGB      | %.2fGB    | %.2f%%       |", $3/1024, $4/1024, $3*100/($3+$4)}')
#   top_processes=$(ps -eo pid,rss,comm --sort=-rss | awk '{if (NR<=6 && NR>1) printf "%s:%.2fGB\n",$3,$2/(1024*1024)}')
#   echo "$date | $meminfo | $top_processes"
#   sleep 60
# done

#=======================

sleep_time=30



while true; do
    echo "Timestamp          | RAM used    | RAM free   | RAM used % "
    echo "-----------------------------------------------------------"
    date=$(date '+%Y-%m-%d %H:%M:%S')

    # Get total memory usage
    meminfo=$(free -m | awk 'NR==2{printf "%.2f", $2/1024}')

    total_mem=$(free -m | awk 'NR==2{printf "%.2fGB      | %.2fGB    | %.2f%%", $3/1024, $4/1024, $3*100/($3+$4)}')

    # Print the total memory usage
    printf "%-14s| %s\n" "$date" "$total_mem"

    # Get top 5 memory-consuming processes
    top_processes=$(ps -eo pid,pmem,comm --sort=-pmem | awk -v meminfo="$meminfo" 'BEGIN{OFS=":"}{if(NR<=6) {memory_used=$2/100*meminfo; printf "%-12s| %-22s| %.2fGB\n",$1,$3,memory_used}}')

    # Print the top 5 memory-consuming processes
    echo " "
    echo "Process ID  | Process Name          | Memory Used"
    echo "-------------------------------------------------"
    echo "$top_processes"

    sleep $sleep_time
done


#================================

# function get_mem_usage {
#   mem_usage=$(kubectl top pods --no-headers | awk '{mem += $2} END {printf "%.2f", mem/1024}')
#   echo "${mem_usage}GB"
# }

# while true; do
#   date=$(date '+%Y-%m-%d %H:%M:%S')
#   meminfo=$(free -m | awk 'NR==2{printf "%.2fGB used, %.2fGB free (%.2f%% used)\n", $3/1024, $4/1024, $3*100/($3+$4)}')
#   pod_mem_usage=$(get_mem_usage)
#   echo "$date $meminfo $pod_mem_usage"
#   sleep 1
# done


# function get_mem_usage {
#   mem_usage=$(kubectl top pods --no-headers | awk '{mem += $2} END {printf "%.2f", mem/1024}')
#   echo "${mem_usage}GB"
# }

# echo "Timestamp    | RAM used   | RAM free   | RAM used % | Pod Memory Used"
# echo "--------------------------------------------------------------------"

# while true; do
#   date=$(date '+%Y-%m-%d %H:%M:%S')
#   meminfo=$(free -m | awk 'NR==2{printf "%.2fGB      | %.2fGB    | %.2f%%       |", $3/1024, $4/1024, $3*100/($3+$4)}')
#   pod_mem_usage=$(get_mem_usage)
#   echo "$date | $meminfo | $pod_mem_usage"
#   sleep 1
# done



# function get_top_pods_mem_usage {
#   pod_mem_usage=$(kubectl top pods --no-headers | sort -k2 -n -r | head -5 | awk '{print $1 ":" $2/1024 "GB"}')
#   echo "$pod_mem_usage"
# }

# function get_top_pods_names {
#   pod_names=$(kubectl top pods --no-headers | sort -k2 -n -r | head -5 | awk '{print $1}')
#   echo "$pod_names"
# }

# echo "Timestamp    | RAM used   | RAM free   | RAM used % | Top 5 Memory-Consuming Pods"
# echo "--------------------------------------------------------------------------------"

# while true; do
#   date=$(date '+%Y-%m-%d %H:%M:%S')
#   meminfo=$(free -m | awk 'NR==2{printf "%.2fGB      | %.2fGB    | %.2f%%       |", $3/1024, $4/1024, $3*100/($3+$4)}')
#   pod_mem_usage=$(get_top_pods_mem_usage)
#   pod_names=$(get_top_pods_names)
#   echo "$date | $meminfo | $pod_mem_usage | $pod_names"
#   sleep 1
# done
