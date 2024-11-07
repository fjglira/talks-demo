#!/bin/bash
# Setup the Kind cluster and install Sail Operator

# 1. Create kind cluster
kind create cluster --name istioday
# For me on MAC using podman: KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name istioday

# 2. Install Sail Operator using the previously helm package
helm install sail-operator /home/fedora/Documents/sail-operator/out/sail-operator-0.2.0.tgz --namespace sail-operator --create-namespace