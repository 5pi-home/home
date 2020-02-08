local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';

local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;

local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;

{
  local new(namespace, name, image, port, args=[]) = {
    local c = container.new(name, image) +
      container.withArgs(args),

    deployment: deployment.new(name, 1, c, { app: name }) +
      deployment.mixin.metadata.withNamespace(namespace),

    service: service.new(name, { app: name }, { port: port }) +
      service.mixin.metadata.withNamespace(namespace)
  },

  local withVolumeHostMount(name, path, hostPath) = {
    local vm = containerVolumeMount.new(name, path),
    local v = volume.fromHostPath(name, hostPath),

    super.containers[0] = deployment.mixin.spec.template.spec.withVolumes([volume])
  },

  new:: new,
  withVolumeHostMount:: withVolumeHostMount,
}
