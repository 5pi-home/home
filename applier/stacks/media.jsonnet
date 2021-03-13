{
  _config:: {
    domain: error 'Must define domain',
    timezone: error 'Must define timezone',
    namespace: 'media',
    plex_env: [],
  },

  plex: (import 'apps/plex/main.jsonnet').new({
    host: 'plex.' + $._config.domain,
    namespace: 'default',  // FIXME: Too lazy to move PVC right now.. $._config.namespace,
    storage_class: $._config.storage_class,
    media_path: $._config.media_path,
    env: $._config.plex_env + [
      { name: 'TZ', value: $._config.timezone },
      { name: 'HOSTNAME', value: 'plex' },
    ],
  }),

  nzbget: (import 'apps/nzbget/main.libsonnet') + {
    _config+:: {
      external_domain: 'nzbget.' + $._config.domain,
      namespace: $._config.namespace,
      config: (importstr 'media/nzbget.conf') % $._config.usenet,  // FIXME: Lets generate the config from jsonnet
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

  radarr: (import 'apps/radarr/main.jsonnet').new({
    namespace: $._config.namespace,
    host: 'radarr.' + $._config.domain,
    storage_class: $._config.storage_class,
    media_path: $._config.media_path,
  }),
}
