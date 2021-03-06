local util = import 'jsonnet-libs/ksonnet-util/util.libsonnet';
local K = import 'ksonnet.beta.4/k.libsonnet';
local Container = K.apps.v1.deployment.mixin.spec.template.spec.containersType;
local Deployment = K.apps.v1.deployment;
local Namespace = K.core.v1.namespace;

local Service = K.core.v1.service;
local ServicePort = K.core.v1.service.mixin.spec.portsType;

local Volume = K.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local ContainerVolumeMount = Container.volumeMountsType;

local Ingress = K.extensions.v1beta1.ingress;
local IngressRule = Ingress.mixin.spec.rulesType;
local HTTPIngressPath = IngressRule.mixin.http.pathsType;

{
  _config+:: {
    name: 'home-assistant',
    namespace: 'home-assistant',
    version: '2021.2.0.dev20210126',
    port: 8123,
    image_repo: 'homeassistant/home-assistant',
    external_domain: 'home.example.com',
    node_selector: {},
  },

  local volumeName = 'data',
  local volume = Volume.fromHostPath(volumeName, '/data/home-assistant'),
  local volumeMount = ContainerVolumeMount.new(volumeName, '/config'),

  local image = $._config.image_repo + ':' + $._config.version,
  local mainContainer = Container.new($._config.name, image) +
                        Container.withArgs(['python3', '-m', 'homeassistant', '--config', '/config']) +
                        Container.withVolumeMounts([volumeMount]) +  // , devVolumeMount]) +
                        Container.mixin.securityContext.withPrivileged(true) +
                        Container.mixin.livenessProbe.withInitialDelaySeconds(600) +
                        Container.mixin.livenessProbe.httpGet.withPort(8123),
  local podLabels = { app: $._config.name },

  deployment:
    Deployment.new($._config.name, 1, [mainContainer], podLabels) +
    Deployment.mixin.metadata.withNamespace($._config.namespace) +
    Deployment.mixin.metadata.withLabels(podLabels) +
    Deployment.mixin.spec.selector.withMatchLabels(podLabels) +
    Deployment.mixin.spec.template.spec.withHostNetwork(true) +
    Deployment.mixin.spec.template.spec.withNodeSelector($._config.node_selector) +
    Deployment.mixin.spec.template.spec.withVolumes([volume]),  // , devVolume]),

  service: Service.new($._config.name, { app: $._config.name }, { port: $._config.port }) +
           Service.mixin.metadata.withNamespace($._config.namespace),

  ingress:
    Ingress.new() +
    Ingress.mixin.metadata.withName($._config.name) +
    Ingress.mixin.metadata.withNamespace($._config.namespace) +
    Ingress.mixin.spec.withRules([
      IngressRule.new() +
      IngressRule.withHost($._config.external_domain) +
      IngressRule.mixin.http.withPaths([
        HTTPIngressPath.new() +
        HTTPIngressPath.withPath('/') +
        HTTPIngressPath.mixin.backend.withServiceName($._config.name) +
        HTTPIngressPath.mixin.backend.withServicePort($._config.port),
      ]),
    ]),

  withDevice(path):: {
    deployment+:
      util.hostVolumeMount('dev', path, path),
  },
}
