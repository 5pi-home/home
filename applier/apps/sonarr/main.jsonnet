local k = import "github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet";
local app = import 'app.jsonnet';


{
  _config:: {
    name: 'sonarr',
    namespace: 'default',
    host: error 'Must define host',
    media_path: error 'Must define media_path',
    image: 'fish/sonarr@sha256:66dfdb71890123758b154f922825288b272531be759d27f5ca2860a9cebdd2b8',
    storage_size: '500Mi',
    storage_class: 'default',
  },

  app: app.newWebApp(
            'sonarr',
            $._config.image,
            $._config.host,
            8989,
            namespace=$._config.namespace) +
       app.withPVC($._config.name, $._config.storage_size, '/data', $._config.storage_class) +
       app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', $._config.media_path), '/media'),

  all: $.app.all
}
