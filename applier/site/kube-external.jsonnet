local K = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local ServicePort = K.core.v1.service.mixin.spec.portsType;

local ExternalServices = (import 'external_services/main.libsonnet') +
  { _config+:: { annotations: { "prometheus.io/scrape": "true" } } };

local ips = [ "192.168.1.1" ];

[
  ExternalServices.service("kube-scheduler", ips, [ServicePort.new(10251)]),
  ExternalServices.service("kube-controller-manager", ips, [ServicePort.new(10252)]),
]
