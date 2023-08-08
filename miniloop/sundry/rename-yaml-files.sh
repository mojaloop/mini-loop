#!/usr/bin/env bash
# small util for renaming yaml files 

turn_off_yaml_files() {
    local directory="$1"
    local prefixes=("${@:2}")

    for file in "$directory"/*.yaml; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            for prefix in "${prefixes[@]}"; do
                if [[ "$filename" == "$prefix"* ]]; then
                    local new_name="${filename%.*}.off"
                    local new_path="$directory/$new_name"
                    mv "$file" "$new_path"
                    echo "Renamed $file to $new_path"
                    break
                fi
            done
        fi
    done
}

turn_on_yaml_files() {
    local directory="$1"
    local prefixes=("${@:2}")

    for file in "$directory"/*.off; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            for prefix in "${prefixes[@]}"; do
                if [[ "$filename" == "$prefix"* ]]; then
                    local new_name="${filename%.*}.yaml"
                    local new_path="$directory/$new_name"
                    mv "$file" "$new_path"
                    echo "Renamed $file to $new_path"
                    break
                fi
            done
        fi
    done
}


# Example usage so to turn on some yaml 

directory="/home/ubuntu/vnext/platform-shared-tools/packages/deployment/k8s/crosscut"
prefixes=( "logging" "auditing" )
turn_off_yaml_files "$directory" "${prefixes[@]}"