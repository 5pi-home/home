local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local configMap = k.core.v1.configMap;
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;
local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerPort = container.portsType;
local containerVolumeMount = container.volumeMountsType;
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local kubernetes_mixins = import 'kubernetes-mixins/mixin.libsonnet';

local grafana = (
  (import 'grafana/grafana.libsonnet') +
  kubernetes_mixins +
  {
    _config+:: {
      namespace: 'monitoring-grafana',
      grafana+:: {
        dashboards: $.grafanaDashboards,
      },
    },
  }
).grafana;

k.core.v1.list.new(
  grafana.dashboardDefinitions +
  [
    grafana.dashboardSources,
    grafana.dashboardDatasources,
    grafana.deployment,
    grafana.serviceAccount,
    grafana.service +
    service.mixin.spec.withPorts(servicePort.newNamed('http', 3000, 'http') + servicePort.withNodePort(30910)) +
    service.mixin.spec.withType('NodePort'),
  ]
)
/*
// std.manifestYamlDoc(kubernetes_mixins.prometheusAlerts)
[
  configMap.new('prometheus') +
  configMap.withData({
    'prometheus.yaml': 'oo',
    'alerts.yaml': std.manifestYamlDoc(kubernetes_mixins.prometheusAlerts),
    'rules.yaml': std.manifestYamlDoc(kubernetes_mixins.prometheusRules),
  }),
] + [
  configMap.new(name) +
  configMap.withData(kubernetes_mixins.grafanaDashboards[name])


  deployment.new('grafana', 1, c, podLabels) +
  deployment.mixin.metadata.withNamespace('monitoring') +

]
// (import "kubernetes-mixins/mixin.libsonnet").prometheusAlerts)

*/



