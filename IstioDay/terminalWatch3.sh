#!/bin/bash

# Script to continuinously watch the terminal specific resources: get proxy version using istioctl proxy-status continuously

for (( ; ; ))
do
  echo "Proxy Status"
  istioctl proxy-status
  sleep 5
done