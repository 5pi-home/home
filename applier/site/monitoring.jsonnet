local K = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local ServicePort = K.core.v1.service.mixin.spec.portsType;

local domain = 'd.42o.de';

local Monitoring = (import 'monitoring/main.libsonnet') + {
  _config+:: {
    prometheus+: {
      host: 'prometheus.' + domain,
      node_selector: {
        'kubernetes.io/hostname': 'openwrt'
      },
    },
    grafana+: {
      host: 'grafana.' + domain,
    },
  }
};

Monitoring.all
