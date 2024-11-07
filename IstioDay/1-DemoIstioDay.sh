#!/bin/bash

# Demo Script on each step we will add a sleep time to have time to quickly explain the steps

# 1. Show Sail Operator is Installed
echo "Sail Operator is Installed"
kubectl get pods -n sail-operator
sleep 5

# 2. Create istio-system namespace
echo "Create istio-system namespace"
kubectl create namespace istio-system
echo "Created istio-system namespace"
sleep 5

# 3. Create the Istio resource
echo "Create the Istio resource"
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

# 4. Wait until the istiod pod is running and print get pod
echo "Wait until the istiod pod is running"
sleep 5
kubectl wait --for=condition=Ready pod -l app=istiod -n istio-system --timeout=300s
kubectl get pods -n istio-system
sleep 5

# 5. Create the app ns and the deploy the app
echo "Create the app ns and the deploy the app"
kubectl create namespace bookinfo
kubectl label namespace bookinfo istio.io/rev=default-v1-23-2
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml
sleep 2

# 6. Check the  app pods
echo "Wait the app pods to be ready"
kubectl wait --for=condition=Ready pod -l app=details -n bookinfo --timeout=300s
kubectl get pods -n bookinfo
sleep 5

# 7. Check the proxy version
echo "Check the proxy version"
istioctl proxy-status
sleep 5

# 8. Update the istio version in the Istio resource
echo "Update the istio version to latest"
kubectl patch istio default -n istio-system --type='merge' -p '{"spec":{"version":"latest"}}'
sleep 5

# 9. Wait until new istiod pod is running and print get pod
echo "Wait until the new istiod pod is running"
kubectl wait --for=condition=Ready pod -l app=istiod -n istio-system --timeout=300s
kubectl get pods -n istio-system
sleep 5

# 10. Update the app namespace with the new revision
echo "Update the app namespace with the new revision"
kubectl label namespace bookinfo istio.io/rev=default-latest --overwrite
sleep 5

# 11. Update the app deployment to use the new revision
echo "Update the app deployment to use the new revision"
kubectl rollout restart deployment -n bookinfo
sleep 10






