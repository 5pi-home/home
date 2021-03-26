{
  _config+:: {
    domain: error 'Must define domain',
    node_selector: {},
    mqtt_node_selector: {},
  },
  mqtt: (import 'apps/mqtt/main.jsonnet').new({
    storage_path: '/data/mqtt',
    avahi_path: '/etc/avahi/services',
    node_selector: $._config.mqtt_node_selector,
  }),
  zwave2mqtt: (import 'apps/zwave2mqtt/main.libsonnet') + {
    _config+:: {
      external_domain: 'zwave.' + $._config.domain,
      node_selector: $._config.node_selector,
    },
  },

  home_assistant: (import 'apps/home_assistant/main.libsonnet') + {
    _config+:: {
      external_domain: 'home.' + $._config.domain,
      node_selector: $._config.node_selector,
    },
  },
}
