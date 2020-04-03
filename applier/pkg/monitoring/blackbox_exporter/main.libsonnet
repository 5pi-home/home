local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;

local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;
local configMap = k.core.v1.configMap;

{
  _config+:: {
    name: 'blackbox-exporter',
    namespace: 'monitoring',
    version: '0.16.0',
    port: 9115,
    uid: 1000,
    image_repo: 'prom/blackbox-exporter',
    config: std.manifestYamlDoc(import 'config.libsonnet'),
  },
  blackbox_exporter+: {
    local configv = volume.withName("config") + volume.mixin.configMap.withName($._config.name),
    local configvm = containerVolumeMount.new("config", "/blackbox-exporter/config.yaml"),
    local image = $._config.image_repo + ':v' + $._config.version,
    local c = container.new($._config.name, image) +
      container.withVolumeMounts([configvm]),
    local podLabels = { app: $._config.name },

    deployment:
      deployment.new($._config.name, 1, c, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.template.spec.withVolumes([configv]),

    service: service.new($._config.name, { app: $._config.name }, { port: $._config.port }) +
      service.mixin.metadata.withNamespace($._config.namespace),

    config_map: configMap.new($._config.name, { 'config.yaml': $._config.config}) +
      configMap.mixin.metadata.withNamespace($._config.namespace),
  }
}
