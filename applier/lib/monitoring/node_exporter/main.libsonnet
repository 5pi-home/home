local k = import 'ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local DaemonSet = k.apps.v1.daemonSet;

local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;

{
  _config+:: {
    name: 'node-exporter',
    namespace: 'monitoring',
    version: '1.0.0-rc.0',
    port: 9100,
    uid: 1000,
    image_repo: 'prom/node-exporter',
  },
  node_exporter+: {
    local image = $._config.image_repo + ':v' + $._config.version,
    local c = container.new($._config.name, image),
    local podLabels = { app: $._config.name, name: $._config.name },

    daemonset:
      DaemonSet.new() +
      DaemonSet.mixin.metadata.withName($._config.name) +
      DaemonSet.mixin.metadata.withNamespace($._config.namespace) +
      DaemonSet.mixin.metadata.withLabels(podLabels) +
      DaemonSet.mixin.spec.template.metadata.withLabels(podLabels) +
      DaemonSet.mixin.spec.template.spec.withContainers(c) +
      DaemonSet.mixin.spec.template.spec.withHostPid(true) +
      DaemonSet.mixin.spec.template.spec.withHostNetwork(true) +
      DaemonSet.mixin.spec.selector.withMatchLabels(podLabels) +
      DaemonSet.mixin.spec.updateStrategy.rollingUpdate.withMaxUnavailable("100%"),

  }
}
