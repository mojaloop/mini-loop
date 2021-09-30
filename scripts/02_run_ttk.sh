#!/usr/bin/env bash

printf "Running the Testing Toolkit via \"helm test ml \" \n\n"

# run the Setup collection followed by the Golden Path collection of tests 
# exit if this does not return zero
if [[ ! ` su - vagrant -c "helm test ml" ` ]] ; then
	  	printf "\"helm test ml\" failed \n"
      printf "please check prior output looking for mojaloop setup and install errors \n" 
	    exit 1
fi



# Collect logs and check all Golden Path tests passed 
okpercent=` su - vagrant -c "kubectl logs pod/ml-ml-ttk-test-validation | grep \"Passed percentage\" | cut -d \" \" -f5 | cut -d \".\" -f1 " `  
if [[ $okpercent -lt 100 ]] ; then 
  printf "*** Golden Path tests had some failures \n"
  printf "*** Percentage of tests passing is : %s \n" $okpercent
else
  printf "Golden Path Tests passed OK  \n"
fi

