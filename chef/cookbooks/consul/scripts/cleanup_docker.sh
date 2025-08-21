#!/bin/bash

# Stop all running containers
docker ps -q | xargs -r docker stop

# Remove all containers
docker ps -aq | xargs -r docker rm

# Remove all images
docker images -q | xargs -r docker rmi -f

echo "All Docker containers stopped, removed, and all images deleted."
