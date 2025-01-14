# helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
# helm repo update

helm upgrade --cleanup-on-fail &
  --install jslabs jupyterhub/jupyterhub &
  --namespace jslabs &
  --create-namespace &
  --version=4.0.0 &
  --values config.yaml