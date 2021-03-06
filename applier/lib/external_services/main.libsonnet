local K = import 'ksonnet.beta.4/k.libsonnet';
local Service = K.core.v1.service;
local Endpoints = K.core.v1.endpoints;
local EndpointSubset = Endpoints.subsetsType;
local ServicePort = K.core.v1.service.mixin.spec.portsType;
local ContainerPort = K.core.v1.container.portsType;

{
  _config+:: {
    annotations+: {
    },
  },
  service(name, ips, ports):
    local addresses = [
      { ip: ip }
      for ip in ips
    ];

    local subset = EndpointSubset.new() +
                   EndpointSubset.withAddresses(addresses);

    {
      service: Service.new(name, {}, ports) +
               Service.mixin.metadata.withAnnotations($._config.annotations),

      endpoints: Endpoints.new() +
                 Endpoints.withSubsets(subset),
    },
}
