#!/bin/bash

# Get the list of YAML files in the current directory except for files beginning with "docker-"
yaml_files=$(ls *.yml *.yaml | grep -v '^docker-')

# Apply or delete the YAML files using kubectl
for file in $yaml_files; do
    if [[ $1 == "apply" ]]; then
        kubectl apply -f $file
    elif [[ $1 == "delete" ]]; then
        kubectl delete -f $file
    else
        echo "Usage: $0 (apply|delete)"
        exit 1
    fi
done
