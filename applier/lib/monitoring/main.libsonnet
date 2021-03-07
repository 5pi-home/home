local k = import 'ksonnet.beta.4/k.libsonnet';
local configMap = k.core.v1.configMap;
local namespace = k.core.v1.namespace;
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;
local ingress = k.extensions.v1beta1.ingress;
local ingressRule = ingress.mixin.spec.rulesType;
local httpIngressPath = ingressRule.mixin.http.pathsType;
local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerPort = container.portsType;
local containerVolumeMount = container.volumeMountsType;
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local kubernetes_mixins = import 'kubernetes-mixins.libsonnet';
local node_mixins = import 'node-mixins.libsonnet';

{
  _config+:: {
    namespace: 'monitoring',
    prometheus+:: {
      node_selector: {},
    },
  },
  prometheus+: (
    (import 'prometheus/main.libsonnet') +
    {
      _config+:: $._config.prometheus + {
        namespace: $._config.namespace,
      },
      config_files+: {
        'kubernetes.recording.rules.yaml': std.manifestYamlDoc(kubernetes_mixins.prometheusRules),
        'kubernetes.alerting.rules.yaml': std.manifestYamlDoc(kubernetes_mixins.prometheusAlerts),

        'node.recording.rules.yaml': std.manifestYamlDoc(node_mixins.prometheusRules),
        'node.alerting.rules.yaml': std.manifestYamlDoc(node_mixins.prometheusAlerts),
      },
    }
  ),

  blackbox_exporter: (
    (import 'blackbox_exporter/main.libsonnet') +
    {
      _config+:: {
        namespace: $._config.namespace,
      },
    }
  ).blackbox_exporter,

  node_exporter: (
    (import 'node_exporter/main.libsonnet') +
    {
      _config+:: {
        namespace: $._config.namespace,
      },
    }
  ).node_exporter,

  grafana:
    local grafana = (
      (import 'grafana/grafana.libsonnet') +
      kubernetes_mixins +
      node_mixins
    );
    (
      grafana
      {
        _config+:: {
          namespace: 'monitoring',
          versions+:: {
            grafana: '6.6.0',
          },
          prometheus+:: {
            serviceName: 'prometheus',
          },
          grafana+:: {
            dashboards: grafana.grafanaDashboards,
            container: {
              requests: { memory: '80Mi' },
              limits: { memory: '80Mi' },
            },
            config: {
              sections: {
                'auth.anonymous': {
                  enabled: true,
                },
              },
            },
          },
        },
      }
    ).grafana,

  all: k.core.v1.list.new(
    [
      namespace.new($._config.namespace),
      $.prometheus.deployment +
      deployment.mixin.spec.template.spec.withNodeSelector($._config.prometheus.node_selector),
      $.prometheus.service,
      $.prometheus.config_map,
      $.prometheus.serviceAccount,
      $.prometheus.clusterRole,
      $.prometheus.clusterRoleBinding,
      $.prometheus.ingress,
      $.prometheus.pvc,

      $.blackbox_exporter.deployment,
      $.blackbox_exporter.service,
      $.blackbox_exporter.config_map,

      $.node_exporter.daemonset,
    ] +
    $.grafana.dashboardDefinitions +
    [
      $.grafana.dashboardSources,
      $.grafana.dashboardDatasources,
      $.grafana.deployment,
      $.grafana.serviceAccount,
      $.grafana.config,
      $.grafana.service +
      service.mixin.spec.withPorts(servicePort.newNamed('http', 3000, 'http')) +
      service.mixin.spec.withType('ClusterIP'),
      ingress.new() +
      ingress.mixin.metadata.withName('grafana') +
      ingress.mixin.metadata.withNamespace($._config.namespace) +
      ingress.mixin.spec.withRules([
        ingressRule.new() +
        ingressRule.withHost($._config.grafana.external_domain) +
        ingressRule.mixin.http.withPaths([
          httpIngressPath.new() +
          httpIngressPath.withPath('/') +
          httpIngressPath.mixin.backend.withServiceName('grafana') +
          httpIngressPath.mixin.backend.withServicePort(3000),
        ]),
      ]),
    ]
  ),
}
