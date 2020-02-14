local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
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

local prometheus_node_selector = {
  'kubernetes.io/hostname': 'openwrt'
};

local prometheus = (
  (import 'prometheus/main.libsonnet') +
  {
    _config+:: {
      namespace: 'monitoring',
      config_files+: {
        'recording.rules.yaml': std.manifestYamlDoc(kubernetes_mixins.prometheusRules),
        'alerting.rules.yaml': std.manifestYamlDoc(kubernetes_mixins.prometheusAlerts),
      },
    }
  }
).prometheus;

local grafana = (
  (import 'grafana/grafana.libsonnet') +
  kubernetes_mixins +
  {
    _config+:: {
      namespace: 'monitoring',
      versions+:: {
        grafana: '6.6.0'
      },
      prometheus+:: {
        serviceName: 'prometheus',
      },
      grafana+:: {
        dashboards: $.grafanaDashboards,
        container: {
          requests: { memory: '80Mi' },
          limits: { memory: '80Mi' },
        },
        config: {
          sections: {
            'auth.anonymous': {
              enabled: true
            }
          },
        },
      },
    },
  }
).grafana;

k.core.v1.list.new(
  [
    namespace.new('monitoring'),
    prometheus.deployment +
      deployment.mixin.spec.template.spec.withNodeSelector(prometheus_node_selector),
    prometheus.service,
    prometheus.config_map,
    prometheus.serviceAccount,
    prometheus.clusterRole,
    prometheus.clusterRoleBinding,
    ingress.new() +
    ingress.mixin.metadata.withName('prometheus') +
    ingress.mixin.metadata.withNamespace('monitoring') +
    ingress.mixin.spec.withRules([
      ingressRule.new() +
      ingressRule.withHost('prometheus.d.42o.de') +
      ingressRule.mixin.http.withPaths([
        httpIngressPath.new() +
        httpIngressPath.withPath('/') +
        httpIngressPath.mixin.backend.withServiceName('prometheus') +
        httpIngressPath.mixin.backend.withServicePort(9090),
      ]),
    ]),
  ] +
  grafana.dashboardDefinitions +
  [
    grafana.dashboardSources,
    grafana.dashboardDatasources,
    grafana.deployment,
    grafana.serviceAccount,
    grafana.config,
    grafana.service +
    service.mixin.spec.withPorts(servicePort.newNamed('http', 3000, 'http')) +
    service.mixin.spec.withType('ClusterIP'),
    ingress.new() +
    ingress.mixin.metadata.withName('grafana') +
    ingress.mixin.metadata.withNamespace('monitoring') +
    ingress.mixin.spec.withRules([
      ingressRule.new() +
      ingressRule.withHost('grafana.d.42o.de') +
      ingressRule.mixin.http.withPaths([
        httpIngressPath.new() +
        httpIngressPath.withPath('/') +
        httpIngressPath.mixin.backend.withServiceName('grafana') +
        httpIngressPath.mixin.backend.withServicePort(3000),
      ]),
    ]),
  ]
)
