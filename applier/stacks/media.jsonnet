{
  _config:: {
    domain: error 'Must define domain',
    namespace: 'media',
  },


  nzbget: (import 'apps/nzbget/main.libsonnet') + {
    _config+:: {
      external_domain: 'nzbget.' + $._config.domain,
      namespace: $._config.namespace,
      config: (importstr 'media/nzbget.conf') % $._config.usenet, // FIXME: Lets generate the config from jsonnet
      storage_class: $._config.storage_class,
      media_path: $._config.media_path,
    },
  },

  sonarr: (import 'apps/sonarr/main.jsonnet').new({
    namespace: $._config.namespace,
    host: 'sonarr.' + $._config.domain,
    storage_class: $._config.storage_class,
    media_path: $._config.media_path,
  }),
}
