local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';
local app = import 'lib/app.jsonnet';

local default_config = {
  name: 'plex',
  namespace: 'default',
  host: error 'Must define host',
  media_path: error 'Must define media_path',
  image: 'plexinc/pms-docker:1.22.0.4163-d8c4875dd',
  storage_size: '5Gi',
  storage_class: 'default',
  host_network: true,
  hostname: 'plex',
};

local ports = {
  'plex-ht': { port: 3005 },
  'plex-roku': { port: 8324 },
  'dlna-tcp': { port: 32469 },
  'dlna-udp': { port: 1900, protocol: 'UDP' },
} + {
  ['gdm-' + (i + 1)]: { port: 32410 + i, protocol: 'UDP' }
  for i in [0, 1, 2, 3]
};

{
  new(opts):
    local config = default_config + opts;
    app.newWebApp(
      'plex',
      config.image,
      config.host,
      32400,
      namespace=config.namespace
    ) +
    app.withPVC(config.name, config.storage_size, '/config', config.storage_class) +
    app.withVolumeMixin(k.core.v1.volume.fromHostPath('media', config.media_path), '/data') +
    app.withVolumeMixin(k.core.v1.volume.fromEmptyDir('transcode'), '/transcode') + {
      container+:
        k.core.v1.container.withPortsMixin([
          k.core.v1.containerPort.new(ports[name].port) +
          if 'protocol' in ports[name] then k.core.v1.containerPort.withProtocol(ports[name].protocol) else {}
          for name in std.objectFields(ports)
        ]) + k.core.v1.container.withEnv(config.env),
      deployment+: k.apps.v1.deployment.spec.template.spec.withHostNetwork(config.host_network) +
                   k.apps.v1.deployment.spec.template.spec.withHostname(config.hostname) +
                   k.apps.v1.deployment.spec.strategy.withType('Recreate'),
      service+: k.core.v1.service.spec.withPortsMixin([
        k.core.v1.servicePort.newNamed(name, ports[name].port, ports[name].port) +
        if 'protocol' in ports[name] then k.core.v1.servicePort.withProtocol(ports[name].protocol) else {}
        for name in std.objectFields(ports)
      ]),
    },
}
