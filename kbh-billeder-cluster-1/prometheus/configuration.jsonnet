local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local secret = k.core.v1.secret;
local pvc = k.core.v1.persistentVolumeClaim;
local ingress = k.extensions.v1beta1.ingress;
local ingressTls = ingress.mixin.spec.tlsType;
local ingressRule = ingress.mixin.spec.rulesType;
local httpIngressPath = ingressRule.mixin.http.pathsType;

local removeCpuLimit(container) = (
  container {
    resources+: {
      limits: {
        memory: container.resources.limits.memory,
      }
    }
  }
);

local addNamespaceToRule(groups) = (
  std.map(function(group)
    if (group.name == 'kubernetes-resources') then
      local rules = std.map(function(rule)
        if (rule.alert == 'CPUThrottlingHigh') then
          rule { expr: "sum(increase(container_cpu_cfs_throttled_periods_total{container!='', namespace!='kube-system'}[5m])) by (container, pod, namespace) / sum(increase(container_cpu_cfs_periods_total{}[5m])) by (container, pod, namespace) > ( 25 / 100 )" }
        else
          rule
      , group.rules);
      group { rules: rules }
    else
      group
  , groups)
);

local kp = (
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
  (import 'kube-prometheus/kube-prometheus-anti-affinity.libsonnet') +
  (import 'kube-prometheus/kube-prometheus-managed-cluster.libsonnet') +
  (import 'kube-prometheus/kube-prometheus-all-namespaces.libsonnet') +
  {
    _config+:: {
      namespace: 'monitoring',
      alertmanager+:: {
        name: 'main',
        replicas: 2,
        configSecret: 'alertmanager-secret-config'
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
        datasources+: [{
          name: "Loki",
          type: "loki",
          access: "proxy",
          url: "http://loki-release-1-headless:3100",
          jsonData: {
            maxLines: 5000
          }
        }]
      },
    },
    prometheus+:: {
      prometheus+: {
        spec+: {
          externalUrl: 'https://prometheus.kbhbilleder.deranged.dk',
          ruleSelector: { },
          ruleNamespaceSelector: { },
          retention: "168h",
          storage: {  // https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#storagespec
            volumeClaimTemplate:  // (same link as above where the 'pvc' variable is defined)
              pvc.new() +
              pvc.mixin.spec.withAccessModes('ReadWriteOnce') +
              pvc.mixin.spec.resources.withRequests({ storage: '10Gi' }),
          },
        },
      },
      rules+: {
        spec+: {
          groups: addNamespaceToRule(super.groups)
        }
      }
    },
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          externalUrl: 'https://alertmanager.kbhbilleder.deranged.dk',
        },
      },
    },
    ingress+:: {
      'alertmanager-main':
        ingress.new() +
        ingress.mixin.metadata.withName('alertmanager-main') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
          'nginx.ingress.kubernetes.io/auth-type': 'basic',
          'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
          'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
          'kubernetes.io/ingress.class': 'nginx',
          'cert-manager.io/cluster-issuer': 'letsencrypt',
        }) +
        ingress.mixin.spec.withRules(
          ingressRule.new() +
          ingressRule.withHost('alertmanager.kbhbilleder.deranged.dk') +
          ingressRule.mixin.http.withPaths(
            httpIngressPath.new() +
            httpIngressPath.mixin.backend.withServiceName('alertmanager-main') +
            httpIngressPath.mixin.backend.withServicePort('web')
          ),
        ) +
        ingress.mixin.spec.withTls(
          ingressTls.new() +
          ingressTls.withSecretName('alertmanager.kbhbilleder.deranged.dk-tls') +
          ingressTls.withHosts(['alertmanager.kbhbilleder.deranged.dk']),
        ),
      grafana:
        ingress.new() +
        ingress.mixin.metadata.withName('grafana') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
          'nginx.ingress.kubernetes.io/auth-type': 'basic',
          'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
          'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
          'kubernetes.io/ingress.class': 'nginx',
          'cert-manager.io/cluster-issuer': 'letsencrypt',
        }) +
        ingress.mixin.spec.withRules(
          ingressRule.new() +
          ingressRule.withHost('grafana.kbhbilleder.deranged.dk') +
          ingressRule.mixin.http.withPaths(
            httpIngressPath.new() +
            httpIngressPath.mixin.backend.withServiceName('grafana') +
            httpIngressPath.mixin.backend.withServicePort('http')
          ),
        ) +
        ingress.mixin.spec.withTls(
          ingressTls.new() +
          ingressTls.withSecretName('grafana.kbhbilleder.deranged.dk-tls') +
          ingressTls.withHosts(['grafana.kbhbilleder.deranged.dk']),
        ),
      'prometheus-k8s':
        ingress.new() +
        ingress.mixin.metadata.withName('prometheus-k8s') +
        ingress.mixin.metadata.withNamespace($._config.namespace) +
        ingress.mixin.metadata.withAnnotations({
          'nginx.ingress.kubernetes.io/auth-type': 'basic',
          'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
          'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required',
          'kubernetes.io/ingress.class': 'nginx',
          'cert-manager.io/cluster-issuer': 'letsencrypt',
        }) +
        ingress.mixin.spec.withRules(
          ingressRule.new() +
          ingressRule.withHost('prometheus.kbhbilleder.deranged.dk') +
          ingressRule.mixin.http.withPaths(
            httpIngressPath.new() +
            httpIngressPath.mixin.backend.withServiceName('prometheus-k8s') +
            httpIngressPath.mixin.backend.withServicePort('web')
          ),
        ) +
        ingress.mixin.spec.withTls(
          ingressTls.new() +
          ingressTls.withSecretName('prometheus.kbhbilleder.deranged.dk-tls') +
          ingressTls.withHosts(['prometheus.kbhbilleder.deranged.dk']),
        ),
    },
  } + {
    nodeExporter+:: {
      daemonset+: {
        spec+: {
          template+: {
            spec+: {
              containers: std.map(removeCpuLimit, super.containers),
            },
          },
        },
      },
    },
  } + {
    kubeStateMetrics+:: {
      deployment+: {
        spec+: {
          template+: {
            spec+: {
              containers: std.map(removeCpuLimit, super.containers),
            },
          },
        },
      }
    }
  }
);

{ ['setup/0namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor'), std.objectFields(kp.prometheusOperator))
} +

// serviceMonitor is separated so that it can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['ingress-' + name]: kp.ingress[name] for name in std.objectFields(kp.ingress) }
