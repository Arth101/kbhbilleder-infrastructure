helm3 repo add bitnami https://charts.bitnami.com/bitnami

helm3 upgrade loki-release-3 bitnami/grafana-loki \
  --namespace monitoring \
  --create-namespace \
  --install \
  --version 2.1.7 \
  -f values.yaml
