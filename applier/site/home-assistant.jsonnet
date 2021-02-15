local util = import 'util.libsonnet';

local domain = 'd.42o.de';

local HomeAssistant = (import 'home_assistant/main.libsonnet') + {
  _config+:: {
    external_domain: 'home.' + domain,
    node_selector: {
      'kubernetes.io/hostname': 'rpi-living'
    },
  }
};

util.toList(HomeAssistant)
