helm3 repo add bitnami https://charts.bitnami.com/bitnami

helm3 upgrade cert-manager-release-1 bitnami/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --install \
  --version v0.7.1 \
  -f values.yaml
