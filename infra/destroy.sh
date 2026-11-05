#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

echo -e "\nDestroying containers, networks, images and volumes\n"

# Kill containers floci spins up by itself first (eks control plane, registries, ui)
docker ps -aq --filter "name=floci-aws" | xargs -r docker rm -f
docker compose down --remove-orphans --rmi all --volumes

# Remove volumes holding state created by floci (k3s kubernetes state, registry, etc.)
docker volume ls -q --filter "name=floci-aws" | xargs -r docker volume rm

# Remove networks created by floci (emulated VPC)
docker network ls -q --filter "name=floci-aws" | xargs -r docker network rm

if [ -d "./data" ]; then
  echo -e "\nRemoving local data\n"
  sudo rm -rf ./data
fi
