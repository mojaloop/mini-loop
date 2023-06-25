#!/bin/bash

# Get the list of YAML files in the current directory except for files beginning with "docker-"
yaml_non_dataresource_files=$(ls *.yaml | grep -v '^docker-' | grep -v "\-data\-" )
yaml_dataresource_files=$(ls *.yaml | grep -v '^docker-' | grep -i "\-data\-" )

if [[ $1 == "apply" ]]; then
    for file in $yaml_dataresource_files; do
        kubectl apply -f $file
    done
    for file in $yaml_non_dataresource_files; do
        kubectl apply -f $file
    done
elif [[ $1 == "delete" ]]; then
    for file in $yaml_non_dataresource_files; do
        kubectl delete -f $file
    done
    for file in $yaml_dataresource_files; do
        kubectl delete -f $file
    done
else 
    echo "Usage: $0 (apply|delete)"
    exit 1
fi


# # Apply or delete the YAML files using kubectl
# for file in $yaml_files; do
#     if [[ $1 == "apply" ]]; then
#         kubectl apply -f $file
#     elif [[ $1 == "delete" ]]; then
#         kubectl delete -f $file
#     else
#         echo "Usage: $0 (apply|delete)"
#         exit 1
#     fi
# done

