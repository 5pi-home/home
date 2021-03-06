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
    name: 'nzbget',
    namespace: 'media',
    version: 'v21.0-r2302-0',
    port: 6789,
    image_repo: 'fish/nzbget',
    external_domain: 'home.example.com',
    downloads_dir: '/hdd/nzbget',
    media_dir: '/hdd/media',
    uid: 1000,
    node_selector: {},
    config: '',
    ingress_max_body_size: '500m',
  },

  local image = $._config.image_repo + ':' + $._config.version,
  local mainContainer = Container.new($._config.name, image) +
                        Container.withArgs(['-s', '--configfile=/etc/nzbget/nzbget.conf']),
  local podLabels = { app: $._config.name },

  deployment:
    Deployment.new($._config.name, 1, [mainContainer], podLabels) +
    Deployment.mixin.metadata.withNamespace($._config.namespace) +
    Deployment.mixin.metadata.withLabels(podLabels) +
    Deployment.mixin.spec.selector.withMatchLabels(podLabels) +
    Deployment.mixin.spec.template.spec.withNodeSelector($._config.node_selector) +
    Deployment.mixin.spec.template.spec.securityContext.withRunAsUser($._config.uid) +
    util.configMapVolumeMount($.configmap, '/etc/nzbget') +
    util.hostVolumeMount('downloads', $._config.downloads_dir, '/nzbget/downloads') +
    util.hostVolumeMount('media', $._config.media_dir, '/media'),


  configmap: ConfigMap.new($._config.name, { 'nzbget.conf': $._config.config }) +
             ConfigMap.mixin.metadata.withNamespace($._config.namespace),

  service: Service.new($._config.name, { app: $._config.name }, { port: $._config.port }) +
           Service.mixin.metadata.withNamespace($._config.namespace),

  ingress:
    Ingress.new() +
    Ingress.mixin.metadata.withName($._config.name) +
    Ingress.mixin.metadata.withNamespace($._config.namespace) +
    Ingress.mixin.metadata.withAnnotations({
      'nginx.ingress.kubernetes.io/proxy-body-size': $._config.ingress_max_body_size,
    }) +
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
      $.configmap,
      $.deployment,
      $.service,
      $.ingress,
    ]
  ),
}
