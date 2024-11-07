#!/bin/bash

# Script to continuinously watch the terminal specific resources: istioresvision resources

kubectl get istiorevision -n istio-system -w