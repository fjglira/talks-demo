# This is insted to be used as guide torun and record the IstioDay session demo

# 1. Create kind cluster
kind create cluster --name istioday
# For me on MAC using podman: KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name istioday

# 2. Install Sail Operator
# Question: from where we should install the operator? Using the last release 0.1.0 or the master branch? For me should be from master building the image from the source code
# Even maybe we should not record How we installed? but I think we should install from the source code, building before and pushing the image to the kind registry
kubectl create ns sail-operator
helm template chart chart --include-crds --values chart/values.yaml --set image='$(IMAGE)' --namespace $(NAMESPACE) | kubectl apply --server-side=true -f -
#or
make deploy

# 3. In place update strategy
kubectl create namespace istio-system

cat <<EOF | kubectl apply -f-
apiVersion: sailoperator.io/v1alpha1
kind: Istio
metadata:
  name: default
spec:
  namespace: istio-system
  updateStrategy:
    type: InPlace
  version: v1.23.2
EOF

# This will need to be the verifications commands and watchers to show to the audience the status of the update
kubectl get pods -n sail-operator

## Watch the Istio resource status
kubectl get istio -n istio-system -w

## Show the istio resource created
kubectl get istio -n istio-system


kubectl create namespace bookinfo
kubectl label namespace bookinfo istio-injection=enabled
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/bookinfo/platform/kube/bookinfo.yaml

## Check the  app pods
kubectl get pods -n bookinfo -w

## Check the proxy version
istioctl proxy-status

## Update the istio version
kubectl patch istio default -n istio-system --type='merge' -p '{"spec":{"version":"latest"}}'

## Restart the workloads
kubectl rollout restart deployment -n bookinfo
kubectl get pods -n bookinfo -w

## Check new proxy version
istioctl proxy-status

# 4. Revision based update strategy




