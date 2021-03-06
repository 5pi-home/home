local k = import 'ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local containerVolumeMount = container.volumeMountsType;
local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;

{
  _config+:: {
    image_repo: 'jimmidyson/configmap-reload',
    version: '0.3.0',
  },
  volume_webhook(volume_name, webhook_url):
    local image = $._config.image_repo + ':v' + $._config.version;
    local volume_mount = containerVolumeMount.new(volume_name, '/volume');

    container.new('reloader', image) +
    container.withArgs([
      '-volume-dir',
      '/volume',
      '-webhook-url',
      webhook_url,
    ]) +
    container.withVolumeMounts([volume_mount]),
}
