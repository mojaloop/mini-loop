#!/usr/bin/env python3
import os
import argparse

# Parse the command line arguments
parser = argparse.ArgumentParser(description='Replace environment variables in a docker-compose.yaml file with values from a .env file')
parser.add_argument('docker_compose_file', type=str, help='the path to the docker-compose.yaml file')
parser.add_argument('--env_file', type=str, default='.env', help='the path to the .env file (default: .env)')
args = parser.parse_args()

# Load the values from the .env file into a dictionary
with open(args.env_file, 'r') as f:
    env_vars = dict(line.strip().split('=', 1) for line in f if line.strip() and not line.startswith('#'))

# Read the contents of the docker-compose.yaml file
with open(args.docker_compose_file, 'r') as f:
    docker_compose_data = f.read()

# Replace all variables of format ${value} with values from the .env file
for key, value in env_vars.items():
    docker_compose_data = docker_compose_data.replace('${' + key + '}', value)

# Write the modified contents back to the docker-compose.yaml file
with open(args.docker_compose_file, 'w') as f:
    f.write(docker_compose_data)