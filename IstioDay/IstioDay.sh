# This is insted to be used as guide torun and record the IstioDay session demo

# 1. Create kind cluster
kind create cluster --name istioday
# For me on MAC using podman: KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name istioday

# 2. Install Sail Operator
## Install the operator using helm install
# Add the steps here to install the operator using helm
# Using the make target we will create the chart tarball and used it to install the operator

# 3. Revision based update strategy

kubectl create namespace istio-system

cat <<EOF | kubectl apply -f-
apiVersion: sailoperator.io/v1alpha1
kind: Istio
metadata:
  name: default
spec:
  namespace: istio-system
  updateStrategy:
    type: RevisionBased
    inactiveRevisionDeletionGracePeriodSeconds: 30
  version: v1.23.2
EOF

## Watch the Istio resource status
kubectl get istio -n istio-system -w

## Watch also the revision status
kubectl get istiorevision -n istio-system -w

## Show the istio resource created
kubectl get istio -n istio-system

## Create the app ns and the deploy the app
kubectl create namespace bookinfo
kubectl label namespace bookinfo istio.io/rev=default-v1-21-0

kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml

## Check the  app pods
kubectl get pods -n bookinfo -w

## Check the proxy version
istioctl proxy-status

## Update the istio version
kubectl patch istio default -n istio-system --type='merge' -p '{"spec":{"version":"latest"}}'

## Check How the new istio and istiorevision resources are created
kubectl get istio -n istio-system
kubectl get istiorevision -n istio-system
kubectl get pods -n istio-system

## Confirm that proxy is not updated yet
istioctl proxy-status

## Change the label for the new revision
kubectl label namespace bookinfo istio.io/rev=default-v1-21-2 --overwrite

## Restart the workloads
kubectl rollout restart deployment -n bookinfo

## Check the new proxy version
istioctl proxy-status

## Confirm that the old revision is deleted
kubectl get istiorevision -n istio-system
kubectl get pods -n istio-system

# 4. Delete everything
kind delete cluster --name istioday






