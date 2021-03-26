local k = import 'github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet';
local app = import 'lib/app.jsonnet';

local default_config = {
  name: 'mqtt',
  namespace: 'default',
  node_selector: {},
  storage_path: '',
  avahi_path: '',
  image: 'eclipse-mosquitto:1.6.7',
};

{
  new(opts)::
    local config = default_config + opts;
    app.newApp(
      config.name,
      config.image,
      namespace=config.namespace
    ) + (
      if config.storage_path != '' then
        app.withVolumeMixin(k.core.v1.volume.fromHostPath('data', config.storage_path), '/mosquitto/data') else
        {}
    ) + (
      if config.avahi_path != '' then
        app.withVolumeMixin(k.core.v1.volume.fromHostPath('avahi-services', config.avahi_path), '/etc/avahi/services') else
        {}
    )
    + app.withVolumeMixin(k.core.v1.volume.fromConfigMap('config', $.configmap.metadata.name), '/mosquitto/config') +
    {
      container+: k.core.v1.container.withPorts([
                    k.core.v1.containerPort.new(1883),
                  ]) +
                  if config.avahi_path != '' then
                    k.core.v1.container.lifecycle.postStart.exec.withCommand([
                      '/bin/sh',
                      '-euc',
                      |||
                        cat << EOF > /etc/avahi/services/mqtt.service
                        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
                        <service-group>
                         <name replace-wildcards="yes">Mosquitto MQTT server on %h</name>
                          <service>
                           <type>_mqtt._tcp</type>
                           <port>1883</port>
                           <txt-record>info=Publish, Publish! Read all about it! mqtt.org</txt-record>
                          </service>
                        </service-group>
                      |||,
                    ]) +
                    k.core.v1.container.lifecycle.preStop.exec.withCommand(['rm', '/etc/avahi/services/mqtt.service']),
      deployment+: k.apps.v1.deployment.spec.template.spec.withNodeSelector(config.node_selector) +
                   k.apps.v1.deployment.spec.template.spec.withHostNetwork(true),
      configmap: k.core.v1.configMap.new(config.name, {
        'mosquitto.conf': |||
          log_dest stdout
          persistence %s
          persistence_location %s
        ||| % [if config.storage_path != '' then 'true' else 'false', config.storage_path],
      }),
    },
}
