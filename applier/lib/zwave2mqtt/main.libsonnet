local K = import 'ksonnet.beta.4/k.libsonnet';
local util = (import 'jsonnet-libs/ksonnet-util/kausal.libsonnet').util;

local Container = K.apps.v1.deployment.mixin.spec.template.spec.containersType;
local Deployment = K.apps.v1.deployment;
local Namespace = K.core.v1.namespace;
local ConfigMap = K.core.v1.configMap;
local Service = K.core.v1.service;
local ServicePort = K.core.v1.service.mixin.spec.portsType;

local Volume = K.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local ContainerVolumeMount = Container.volumeMountsType;

local Ingress = K.extensions.v1beta1.ingress;
local IngressRule = Ingress.mixin.spec.rulesType;
local HTTPIngressPath = IngressRule.mixin.http.pathsType;

{
  _config+:: {
    name: 'zwave2mqtt',
    namespace: 'home-automation',
    version: 'latest',
    port: 8091,
    image_repo: 'robertslando/zwave2mqtt',
    external_domain: 'zwave.example.com',
    zwave_dev: '/dev/ttyACM0',
    node_selector: {},
    data_dir: '/data/zwave2mqtt',
  },

  local devVolumeName = 'dev',
  local devVolume = Volume.fromHostPath(devVolumeName, "/dev"),
  local devVolumeMount = ContainerVolumeMount.new(devVolumeName, "/dev/ttyACM-zwave") +
                         ContainerVolumeMount.withSubPath("ttyACM0"),
  local mainContainer = Container.new($._config.name, image) +
                        Container.withVolumeMounts([devVolumeMount]) +
                        Container.mixin.securityContext.withPrivileged(true),
  local image = $._config.image_repo + ':' + $._config.version,
  local podLabels = { app: $._config.name },

  deployment:
    Deployment.new($._config.name, 1, [ mainContainer ], podLabels) +
    Deployment.mixin.metadata.withNamespace($._config.namespace) +
    Deployment.mixin.metadata.withLabels(podLabels) +
    Deployment.mixin.spec.selector.withMatchLabels(podLabels) +
    Deployment.mixin.spec.template.spec.withNodeSelector($._config.node_selector) +
    Deployment.mixin.spec.template.spec.withVolumes([devVolume]) +
    util.hostVolumeMount('data', $._config.data_dir, '/usr/src/app/store'),

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
  all: K.core.v1.list.new(
    [
      Namespace.new($._config.namespace),
      $.deployment,
      $.service,
      $.ingress,
    ]
  )
}
