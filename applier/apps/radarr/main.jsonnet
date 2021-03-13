local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';
local app = import 'lib/app.jsonnet';

local default_config = {
  name: 'radarr',
  namespace: 'default',
  host: error 'Must define host',
  media_path: error 'Must define media_path',
  image: 'fish/radarr:0.2.0.1293-0',
  storage_size: '500Mi',
  storage_class: 'default',
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'radarr',
      config.image,
      config.host,
      7878,
      namespace=config.namespace
    ) +
    app.withPVC(config.name, config.storage_size, '/data', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/media'),
}
