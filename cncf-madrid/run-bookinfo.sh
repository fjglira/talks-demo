#!/bin/bash

# Demo script for comparing Istio Sidecar vs Ambient modes with Bookinfo application
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

print_step "Starting Istio Sidecar Mode Demo"

## Create cluster and install Istio in sidecar mode
print_step "Creating kind cluster"
kind create cluster --name istio-demo

print_step "Installing Istio in sidecar mode"
istioctl install --skip-confirmation

### Wait for the istio-system pods to be Running
print_step "Waiting for Istio control plane to be ready"
kubectl wait --for=condition=Ready pod -l app=istiod -n istio-system --timeout=180s

### Print the istio-system pods
kubectl get pods -n istio-system
sleep 2

## Install Bookinfo in sidecar mode
print_step "Installing Bookinfo application with sidecar injection"
kubectl create ns bookinfo
kubectl label namespace bookinfo istio-injection=enabled
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/bookinfo/platform/kube/bookinfo.yaml -n bookinfo

### Wait for the Bookinfo pods are running
print_step "Waiting for Bookinfo pods to be ready"
kubectl wait --for=condition=Ready pod --all -n bookinfo --timeout=300s

### Print the services in the bookinfo ns
print_success "Bookinfo application deployed successfully"
kubectl get svc -n bookinfo
kubectl get pods -n bookinfo
sleep 2

## Install monitoring tools
print_step "Installing Prometheus and Kiali"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/kiali.yaml

### Wait for the Kiali pod to be running
print_step "Waiting for Kiali to be ready"
kubectl wait --for=condition=Ready pod -l app=kiali -n istio-system --timeout=180s
sleep 2

### Open Kiali dashboard in a separate process
print_step "Starting Kiali dashboard"
istioctl dashboard kiali --browser=false &
KIALI_PID=$!
sleep 3

print_success "Kiali dashboard is running at: http://localhost:20001"

## Generate traffic in the application
print_step "Starting traffic generation"
ratings_pod=$(kubectl get pod -n bookinfo -l app=ratings -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$ratings_pod" ]]; then
    print_error "Could not find ratings pod"
    exit 1
fi

print_success "Found ratings pod: $ratings_pod"

## Show istioctl proxy-status
print_step "Checking proxy status in sidecar mode"
istioctl proxy-status
sleep 2

# Start traffic generation in background
{
    while true; do
        kubectl exec -n bookinfo "$ratings_pod" -c ratings -- curl -sS productpage:9080/productpage >/dev/null 2>&1
        echo -e "${GREEN}Traffic sent at $(date)${NC}"
        sleep 2
    done
} &
TRAFFIC_PID=$!

print_success "Traffic generation started (PID: $TRAFFIC_PID)"
print_warning "Traffic is being generated every 2 seconds. Check Kiali dashboard to see the service mesh topology."

### Wait until the user press Enter to cleanup sidecar mode
echo ""
echo -e "${YELLOW}=== SIDECAR MODE RUNNING ===${NC}"
echo -e "Open Kiali dashboard at: ${BLUE}http://localhost:20001${NC}"
echo -e "Traffic is being generated automatically."
echo ""
read -p "Press [Enter] key to stop sidecar mode and switch to ambient mode..."

# Stop background processes
print_step "Stopping traffic generation and Kiali dashboard"
kill $TRAFFIC_PID 2>/dev/null || true
kill $KIALI_PID 2>/dev/null || true
unset TRAFFIC_PID KIALI_PID

# Clean up cluster
print_step "Cleaning up sidecar mode cluster"
kind delete cluster --name istio-demo

echo ""
print_step "Starting Istio Ambient Mode Demo"

## Create new cluster and install Istio in ambient mode
print_step "Creating new kind cluster for ambient mode"
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
istioctl dashboard kiali --browser=false &
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
echo -e "Notice the difference: ${GREEN}no sidecar containers${NC} in the pods!"
echo ""

### Generate traffic for ambient mode
print_step "Starting traffic generation for ambient mode"
ratings_pod=$(kubectl get pod -n bookinfo -l app=ratings -o jsonpath='{.items[0].metadata.name}')

{
    while true; do
        kubectl exec -n bookinfo "$ratings_pod" -- curl -sS productpage:9080/productpage >/dev/null 2>&1
        echo -e "${GREEN}Ambient traffic sent at $(date)${NC}"
        sleep 2
    done
} &
TRAFFIC_PID=$!

print_success "Traffic generation started for ambient mode"

echo ""
read -p "Press [Enter] key to finish demo and cleanup..."

print_step "Final cleanup"
kind delete cluster --name istio-ambient

print_success "Demo completed! Both sidecar and ambient modes have been demonstrated."

