#!/bin/bash

#Install Kind
kind create cluster --config kind-config.yaml

#Install Operator Lifecycle Manager
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.34.0/install.sh | bash -s v0.34.0

# Install CoCo Operator
kubectl apply -f coco-operator.yaml

# Install CoCo Instance
kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/default?ref=v0.14.0

# Test Runtime
kubectl apply -f coco-demo-01.yaml

# Test Policy
kubectl apply -f coco-demo-02.yaml

# Install Trustee
kubectl create -f https://operatorhub.io/install/trustee-operator.yaml

# Install Trustee Instance
## Install KBS Config Map
kubectl create secret -n operators generic kbs-auth-public-key --from-literal=kbs.pem="$(openssl genpkey -algorithm ed25519)"
kubectl get secret
kubectl apply -f https://raw.githubusercontent.com/confidential-containers/trustee-operator/refs/tags/v0.4.0/config/samples/all-in-one/kbs-config.yaml
kubectl apply -f https://raw.githubusercontent.com/confidential-containers/trustee-operator/refs/tags/v0.4.0/config/samples/all-in-one/rvps-reference-values.yaml
kubectl apply -f https://raw.githubusercontent.com/confidential-containers/trustee-operator/refs/tags/v0.4.0/config/samples/all-in-one/kbsconfig_sample.yaml

export KBS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export KBS_PORT=$(kubectl get svc "kbs-service" -n "operators" -o jsonpath='{.spec.ports[0].nodePort}')
export KBS_PRIVATE_KEY=$()

### Generate Random Auth Key
#kubectl create secret generic my-random-secret --from-literal=random-key=$(head -c 24 /dev/random | base64)
#kubectl apply -f trustee-kbsc
#config.yaml
