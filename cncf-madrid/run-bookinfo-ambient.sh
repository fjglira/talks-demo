#!/bin/bash

# Demo script for Istio Ambient mode with Bookinfo application
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to cleanup on exit
cleanup() {
    print_warning "Cleaning up background processes..."

    # Kill traffic generation if running
    if [[ -n $TRAFFIC_PID ]]; then
        kill $TRAFFIC_PID 2>/dev/null || true
    fi

    # Kill Kiali dashboard if running
    if [[ -n $KIALI_PID ]]; then
        kill $KIALI_PID 2>/dev/null || true
    fi

    # Kill any port-forward processes
    pkill -f "kubectl.*port-forward" 2>/dev/null || true

    print_success "Cleanup completed"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

echo ""
print_step "Starting Istio Ambient Mode Demo"

## Create new cluster and install Istio in ambient mode
print_step "Creating kind cluster for ambient mode"
kind create cluster --name istio-ambient

print_step "Installing Istio in ambient mode"
istioctl install --set profile=ambient --skip-confirmation

### Wait for the istio-system namespace to be ready
print_step "Waiting for Istio ambient control plane to be ready"
kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system
kubectl wait --for=condition=Ready pod -l app=ztunnel -n istio-system --timeout=180s

print_success "Istio ambient mode installed successfully"
kubectl get pods -n istio-system

### Install Bookinfo in ambient mode
print_step "Installing Bookinfo application for ambient mode"
kubectl create ns bookinfo

# Deploy Bookinfo without sidecar injection
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/bookinfo/platform/kube/bookinfo.yaml -n bookinfo

### Wait for pods to be ready
kubectl wait --for=condition=Ready pod --all -n bookinfo --timeout=300s

### Adding bookinfo namespace to ambient mesh
print_step "Adding bookinfo namespace to ambient mesh"
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient

print_success "Bookinfo namespace added to ambient mesh"
kubectl get pods -n bookinfo

### Install monitoring tools for ambient mode
print_step "Installing monitoring tools for ambient mode"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/kiali.yaml

kubectl wait --for=condition=Ready pod -l app=kiali -n istio-system --timeout=180s

### Start Kiali dashboard for ambient mode
print_step "Starting Kiali dashboard for ambient mode"
istioctl dashboard kiali --browser=true &
KIALI_PID=$!
sleep 3

print_success "Kiali dashboard is running at: http://localhost:20001"

### Check with istioctl proxy-status
print_step "Checking proxy status in ambient mode"
istioctl proxy-status

echo ""
print_success "Ambient mode setup completed!"
echo -e "${YELLOW}=== AMBIENT MODE RUNNING ===${NC}"
echo -e "Open Kiali dashboard at: ${BLUE}http://localhost:20001${NC}"
echo -e "${GREEN}Notice the difference: NO sidecar containers in the pods!${NC}"
echo ""

### Generate traffic for ambient mode
print_step "Starting traffic generation for ambient mode"
ratings_pod=$(kubectl get pod -n bookinfo -l app=ratings -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$ratings_pod" ]]; then
    print_error "Could not find ratings pod"
    exit 1
fi

print_success "Found ratings pod: $ratings_pod"

{
    while true; do
        kubectl exec -n bookinfo "$ratings_pod" -- curl -sS productpage:9080/productpage >/dev/null 2>&1
        echo -e "${GREEN}Ambient traffic sent at $(date)${NC}"
        sleep 2
    done
} &
TRAFFIC_PID=$!

print_success "Traffic generation started for ambient mode (PID: $TRAFFIC_PID)"
print_warning "Traffic is being generated every 2 seconds. Check Kiali dashboard to see the service mesh topology."

echo ""
echo -e "${YELLOW}=== AMBIENT MODE RUNNING ===${NC}"
echo -e "Open Kiali dashboard at: ${BLUE}http://localhost:20001${NC}"
echo -e "Traffic is being generated automatically."
echo -e "${GREEN}Key difference: Pods have only 1 container (no sidecar proxy)${NC}"
echo ""
read -p "Press [Enter] key to finish demo and cleanup..."

print_step "Final cleanup"
kind delete cluster --name istio-ambient

print_success "Ambient mode demo completed!"
echo -e "${BLUE}To run sidecar mode demo, execute: ${YELLOW}./run-bookinfo-sidecar.sh${NC}"