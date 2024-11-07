#!/bin/bash
# Setup the Kind cluster and install Sail Operator

# 1. Create kind cluster
kind create cluster --name istioday
# For me on MAC using podman: KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name istioday

# 2. Generate the helm chart
BUILD_WITH_CONTAINER=0 make helm-package
# This will generate the helm chart in the out folder

# 3. Install the helm chart
helm install sail-operator out/sail-operator-0.2.0.tgz --namespace sail-operator --create-namespace