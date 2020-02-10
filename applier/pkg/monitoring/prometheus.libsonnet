local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;

local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;

{
  _config+:: {
    name: 'prometheus',
    namespace: 'prometheus',
    version: '2.15.2',
    port: 9090,
    image_repo: 'prometheus/prometheus',
  },
  prometheus+: {
    local vm = containerVolumeMount.new("data", "/prometheus"),
    local v = volume.fromHostPath("data", "/data/prometheus"),
    local image = $._config.image_repo + ':' + $._config.version,
    local c = container.new("prometheus", image) +
      container.withVolumeMounts([vm]),

    deployment: deployment.new($._config.name, 1, c, { app: $._config.name }) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.spec.template.spec.withVolumes([v]),

    service: service.new($._config.name, { app: $._config.name }, { port: $._config.port }) +
      service.mixin.metadata.withNamespace($._config.namespace),
  }
}
