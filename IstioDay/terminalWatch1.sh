#!/bin/bash

# Script to continuinously watch the terminal specific resources: istio resources

kubectl get istio -n istio-system -w
