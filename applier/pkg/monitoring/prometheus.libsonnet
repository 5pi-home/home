local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;

local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;

local name = 'prometheus';
local namespace = 'prometheus';
local image = 'prometheus/prometheus:v2.15.2';
local port = 9090;

{
  new(): {
    local vm = containerVolumeMount.new("data", "/prometheus"),
    local v = volume.fromHostPath("data", "/data/prometheus"),

    local c = container.new(name, image) +
      container.withVolumeMounts([vm]),

    deployment: deployment.new(name, 1, c, { app: name }) +
      deployment.mixin.metadata.withNamespace(namespace) +
      deployment.mixin.spec.template.spec.withVolumes([v]),

    service: service.new(name, { app: name }, { port: port }) +
      service.mixin.metadata.withNamespace(namespace),
  }
}
