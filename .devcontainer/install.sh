#!/bin/bash

# Install Gum
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum

# Install kbs-client
oras pull ghcr.io/confidential-containers/staged-images/kbs-client:sample_only-c06de35b2e2ff7a26fd42d5374ecbdbee5168532-x86_64
sudo mv kbs-client /usr/local/bin/kbs-client
sudo chmod +x /usr/local/bin/kbs-client