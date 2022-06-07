local kp =
  (import "kube-prometheus/main.libsonnet") +
  (import "kube-prometheus/addons/anti-affinity.libsonnet") +
  (import "kube-prometheus/addons/managed-cluster.libsonnet") +
  (import "kube-prometheus/addons/all-namespaces.libsonnet") +
  (import "kube-prometheus/addons/strip-limits.libsonnet") +
  {
    values+:: {
      common+: {
        namespace: "monitoring",
      },
      alertmanager+:: {
        name: "main",
        replicas: 2,
      },
      grafana+:: {
        config: { // http://docs.grafana.org/installation/configuration/
          sections: {
            "auth.anonymous": {
              enabled: true,
              org_role: "Editor"
            },
          },
        },
        datasources+: [
          {
            name: "Loki",
            type: "loki",
            access: "proxy",
            url: "http://loki-release-1.monitoring.svc:3100",
            jsonData: {
              maxLines: 5000
            }
          },
          {
            access: "proxy",
            editable: false,
            name: "prometheus",
            orgId: 1,
            type: "prometheus",
            url: "http://prometheus-k8s.monitoring.svc:9090",
            version: 1
          }
        ]
      },
      blackboxExporter+:: {
        resources: {
          requests: { cpu: '10m', memory: '20Mi' },
        },
      },
    },
    prometheus+:: {
      prometheus+: {
        spec+: {
          externalUrl: "https://prometheus.kbhbilleder.deranged.dk",
          ruleSelector: { },
          ruleNamespaceSelector: { },
          retention: "168h",
          storage: {  // https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#storagespec
            volumeClaimTemplate: {  // https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.11/#persistentvolumeclaim-v1-core (defines variable named 'spec' of type 'PersistentVolumeClaimSpec')
              apiVersion: 'v1',
              kind: 'PersistentVolumeClaim',
              spec: {
                accessModes: ['ReadWriteOnce'],
                resources: { requests: { storage: '10Gi' } },
              },
            },
          },
        },
      },
    },
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          externalUrl: "https://alertmanager.kbhbilleder.deranged.dk",
        },
      },
    },
    ingress+:: {
      "alertmanager-main": {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: "alertmanager-main",
          namespace: $.values.common.namespace,
          annotations: {
            "nginx.ingress.kubernetes.io/auth-url": "https://oauth2-proxy.eu-1.deranged.dk/oauth2/auth",
            "nginx.ingress.kubernetes.io/auth-signin": "https://oauth2-proxy.eu-1.deranged.dk/oauth2/start?rd=$escaped_request_uri",
            "kubernetes.io/ingress.class": "nginx",
            "cert-manager.io/cluster-issuer": "letsencrypt",
          },
        },
        spec: {
          rules: [{
            host: "alertmanager.kbhbilleder.deranged.dk",
            http: {
              paths: [{
                path: "/",
                pathType: "Prefix",
                backend: {
                  service: {
                    name: $.alertmanager.service.metadata.name,
                    port: {
                      name: "web",
                    },
                  },
                },
              }],
            },
          }],
          tls: [{
            hosts: ["alertmanager.kbhbilleder.deranged.dk"],
            secretName: "alertmanager.kbhbilleder.deranged.dk-tls",
          }],
        },
      },
      grafana: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: "grafana",
          namespace: $.values.common.namespace,
          annotations: {
            "nginx.ingress.kubernetes.io/auth-url": "https://oauth2-proxy.eu-1.deranged.dk/oauth2/auth",
            "nginx.ingress.kubernetes.io/auth-signin": "https://oauth2-proxy.eu-1.deranged.dk/oauth2/start?rd=$escaped_request_uri",
            "kubernetes.io/ingress.class": "nginx",
            "cert-manager.io/cluster-issuer": "letsencrypt",
          },
        },
        spec: {
          rules: [{
            host: "grafana.kbhbilleder.deranged.dk",
            http: {
              paths: [{
                path: "/",
                pathType: "Prefix",
                backend: {
                  service: {
                    name: $.grafana.service.metadata.name,
                    port: {
                      name: "http",
                    },
                  },
                },
              }],
            },
          }],
          tls: [{
            hosts: ["grafana.kbhbilleder.deranged.dk"],
            secretName: "grafana.kbhbilleder.deranged.dk-tls",
          }],
        },
      },
      "prometheus-k8s": {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: "prometheus-k8s",
          namespace: $.values.common.namespace,
          annotations: {
            "nginx.ingress.kubernetes.io/auth-url": "https://oauth2-proxy.eu-1.deranged.dk/oauth2/auth",
            "nginx.ingress.kubernetes.io/auth-signin": "https://oauth2-proxy.eu-1.deranged.dk/oauth2/start?rd=$escaped_request_uri",
            "kubernetes.io/ingress.class": "nginx",
            "cert-manager.io/cluster-issuer": "letsencrypt",
          },
        },
        spec: {
          rules: [{
            host: "prometheus.kbhbilleder.deranged.dk",
            http: {
              paths: [{
                path: "/",
                pathType: "Prefix",
                backend: {
                  service: {
                    name: $.prometheus.service.metadata.name,
                    port: {
                      name: "web",
                    },
                  },
                },
              }],
            },
          }],
          tls: [{
            hosts: ["prometheus.kbhbilleder.deranged.dk"],
            secretName: "prometheus.kbhbilleder.deranged.dk-tls",
          }],
        },
      },
    },
  } + {
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          configSecret: "alertmanager-secret-config"
        },
      },
    },
  };

{ ["setup/0namespace-" + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{
  ["setup/prometheus-operator-" + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != "serviceMonitor" && name != "prometheusRule"), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ "prometheus-operator-serviceMonitor": kp.prometheusOperator.serviceMonitor } +
{ "prometheus-operator-prometheusRule": kp.prometheusOperator.prometheusRule } +
{ "kube-prometheus-prometheusRule": kp.kubePrometheus.prometheusRule } +
{ ["alertmanager-" + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ["blackbox-exporter-" + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ["grafana-" + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ["kube-state-metrics-" + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ["kubernetes-" + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ["node-exporter-" + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ["prometheus-" + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ["prometheus-adapter-" + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ["ingress-" + name]: kp.ingress[name] for name in std.objectFields(kp.ingress) }
