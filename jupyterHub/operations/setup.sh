#!/bin/bash

helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update

helm upgrade --cleanup-on-fail \
  --install js-labs jupyterhub/jupyterhub \
  --namespace js-labs \
  --create-namespace \
  --version=4.0.0 \
  --values config.yaml