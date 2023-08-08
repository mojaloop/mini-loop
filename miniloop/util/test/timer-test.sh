#!/bin/bash

#==================
# timer() {
#   start=$1
#   stop=$2
#   elapsed=$((stop - start))

#   echo $elapsed
# }

# start=$(date +%s)

# # do some work here
# sleep 5 

# stop=$(date +%s)
# elapsed_time=$(timer $start $stop)

# echo "Elapsed time: $elapsed_time seconds"


#=============================


declare -A timer_array

timer() {
  start=$1
  stop=$2
  elapsed=$((stop - start))

  echo $elapsed
}

start=$(date +%s)

# do some work here
sleep 1

stop=$(date +%s)
elapsed_time=$(timer $start $stop)
timer_array[timer1]=$elapsed_time

start=$(date +%s)

# do some other work here
sleep 1

stop=$(date +%s)
elapsed_time=$(timer $start $stop)
timer_array[timer2]=$elapsed_time

# add more calls to the timer function and add the elapsed times to the timer_array with different keys as needed

# echo "Elapsed time for timer1: ${timer_array[timer1]} seconds"
# echo "Elapsed time for timer2: ${timer_array[timer2]} seconds"

# print out all the elapsed times in the timer_array
echo "All elapsed times:"
for key in "${!timer_array[@]}"; do
  echo "$key: ${timer_array[$key]} seconds"
done
