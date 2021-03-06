local domain = 'd.42o.de';

local zwave2mqtt = (import 'zwave2mqtt/main.libsonnet') + {
  _config+:: {
    external_domain: 'zwave.' + domain,
    node_selector: {
      'kubernetes.io/hostname': 'rpi-living',
    },
  },
};

zwave2mqtt.all
