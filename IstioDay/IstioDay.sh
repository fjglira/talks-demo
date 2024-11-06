# This is insted to be used as guide torun and record the IstioDay session demo

# 1. Create kind cluster
kind create cluster --name istioday
# For me on MAC using podman: KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name istioday

# 2. Install Sail Operator
BUILD_WITH_CONTAINER=0 make helm-package
# This will generate the helm chart in the out folder
# On terminal 1
helm install sail-operator out/sail-operator-0.2.0.tgz --namespace sail-operator --create-namespace
kubectl get pods -n sail-operator -w

# 3. Revision based update strategy
# On terminal 1
kubectl create namespace istio-system

## Watch the Istio resource status
# On terminal 2
kubectl get istio -n istio-system -w

## Watch also the revision status
# On terminal 3
kubectl get istiorevision -n istio-system -w

# On terminal 1
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

## After the watcher show the creation show the istio resource created
# On terminal 1
kubectl get istio -n istio-system

## Create the app ns and the deploy the app
# On terminal 1
kubectl create namespace bookinfo
kubectl label namespace bookinfo istio.io/rev=default-v1-23-2
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml

## Check the  app pods
# On terminal 2
kubectl get pods -n bookinfo -w

## Check the proxy version
# On terminal 1
istioctl proxy-status

## Update the istio version
# On terminal 1
kubectl patch istio default -n istio-system --type='merge' -p '{"spec":{"version":"latest"}}'

## Check How the new istio and istiorevision resources are created
# On terminal 2
kubectl get istio -n istio-system -w
# On terminal 3
kubectl get istiorevision -n istio-system -w 

# On terminal 1
kubectl get pods -n istio-system

## Confirm that proxy is not updated yet
# On terminal 1
istioctl proxy-status

## Change the label for the new revision
# On terminal 1
kubectl label namespace bookinfo istio.io/rev=default-latest --overwrite

## Restart the workloads
# On terminal 1
kubectl rollout restart deployment -n bookinfo

## Check the new proxy version
# On terminal 1
istioctl proxy-status

## Confirm that the old revision is deleted
# On terminal 1
kubectl get istiorevision -n istio-system
# On terminal 1
kubectl get pods -n istio-system

# 4. Delete everything
# On terminal 1
kind delete cluster --name istioday






