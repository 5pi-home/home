local k = import 'ksonnet.beta.4/k.libsonnet';
local util = (import 'jsonnet-libs/ksonnet-util/util.libsonnet');

local Container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local Deployment = k.apps.v1.deployment;
local Namespace = k.core.v1.namespace;
local ConfigMap = k.core.v1.configMap;
local Service = k.core.v1.service;
local ServicePort = k.core.v1.service.mixin.spec.portsType;

local Volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local ContainerVolumeMount = Container.volumeMountsType;

local Ingress = k.extensions.v1beta1.ingress;
local IngressRule = Ingress.mixin.spec.rulesType;
local HTTPIngressPath = IngressRule.mixin.http.pathsType;

{
  _config+:: {
    name: 'nzbget',
    namespace: 'default',
    version: 'v21.0',
    port: 6789,
    image_repo: 'fish/nzbget',
    external_domain: error 'Must specify external_domain',
    media_path: error 'Must specify media_path',
    storage_class: 'default',
    uid: 1000,
    node_selector: {},
    config: '',
    ingress_max_body_size: '500m',
  },

  local image = $._config.image_repo + ':' + $._config.version,
  local mainContainer = Container.new($._config.name, image) +
                        Container.withArgs(['-s', '--configfile=/etc/nzbget/nzbget.conf']),
  local podLabels = { app: $._config.name },

  pvc: k.core.v1.persistentVolumeClaim.new() +
       k.core.v1.persistentVolumeClaim.mixin.metadata.withName('nzbget') +
       k.core.v1.persistentVolumeClaim.mixin.metadata.withNamespace($._config.namespace) +
       k.core.v1.persistentVolumeClaim.mixin.spec.withAccessModes('ReadWriteOnce') +
       k.core.v1.persistentVolumeClaim.mixin.spec.resources.withRequests({storage: '100Gi'}) +
       k.core.v1.persistentVolumeClaim.mixin.spec.withStorageClassName($._config.storage_class),

  deployment:
    Deployment.new($._config.name, 1, [mainContainer], podLabels) +
    Deployment.mixin.metadata.withNamespace($._config.namespace) +
    Deployment.mixin.metadata.withLabels(podLabels) +
    Deployment.mixin.spec.selector.withMatchLabels(podLabels) +
    Deployment.mixin.spec.strategy.withType('Recreate') +
    Deployment.mixin.spec.template.spec.withNodeSelector($._config.node_selector) +
    Deployment.mixin.spec.template.spec.securityContext.withRunAsUser($._config.uid) +
    util.pvcVolumeMount($.pvc.metadata.name, '/nzbget/downloads') +
    util.configMapVolumeMount($.configmap, '/etc/nzbget') +
    util.hostVolumeMount('media', $._config.media_path, '/media'),


  configmap: ConfigMap.new($._config.name + '-config', { 'nzbget.conf': $._config.config }) +
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
}
