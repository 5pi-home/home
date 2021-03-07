local k = import 'ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;

local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;
local configMap = k.core.v1.configMap;

local ingress = k.extensions.v1beta1.ingress;
local ingressRule = ingress.mixin.spec.rulesType;
local httpIngressPath = ingressRule.mixin.http.pathsType;

local reloader = import 'reloader/main.libsonnet';

local prometheus_config = import 'config.libsonnet';

{
  _config+:: {
    name: 'prometheus',
    namespace: 'prometheus',
    version: '2.15.2',
    port: 9090,
    uid: 1000,
    image_repo: 'prom/prometheus',
    external_domain: 'prometheus.example.com',
    external_proto: 'http',
    storage_class: 'default',
  },
  prometheus_config+: prometheus_config,
  config_files+: {
    'prometheus.yaml': std.manifestYamlDoc($.prometheus_config)
  },
  local image = $._config.image_repo + ':v' + $._config.version,
  local podLabels = { app: $._config.name },
  local serviceAccountName = 'prometheus',

  pvc: k.core.v1.persistentVolumeClaim.new() +
       k.core.v1.persistentVolumeClaim.mixin.metadata.withName('prometheus') +
       k.core.v1.persistentVolumeClaim.mixin.metadata.withNamespace($._config.namespace) +
       k.core.v1.persistentVolumeClaim.mixin.spec.withAccessModes('ReadWriteOnce') +
       k.core.v1.persistentVolumeClaim.mixin.spec.resources.withRequests({storage: '5Gi'}) +
       k.core.v1.persistentVolumeClaim.mixin.spec.withStorageClassName($._config.storage_class),

  data_volume: volume.withName('data') + volume.mixin.persistentVolumeClaim.withClaimName($.pvc.metadata.name),
  config_volume: volume.withName('config') + volume.mixin.configMap.withName("prometheus"),

  container: container.new("prometheus", image) +
    container.withArgs([
      '--config.file=/etc/prometheus/prometheus.yaml',
      '--log.level=info',
      '--storage.tsdb.path=/prometheus',
      '--web.enable-lifecycle',
      '--web.enable-admin-api',
      '--web.external-url=' + $._config.external_proto + '://' + $._config.external_domain,
    ]) +
    container.withVolumeMounts([
      containerVolumeMount.new($.data_volume.name, "/prometheus"),
      containerVolumeMount.new($.config_volume.name, "/etc/prometheus")
    ]),

  serviceAccount:
    local serviceAccount = k.core.v1.serviceAccount;
    serviceAccount.new(serviceAccountName) +
    serviceAccount.mixin.metadata.withNamespace($._config.namespace),

  clusterRole:
    local clusterRole = k.rbac.v1.clusterRole;
    local policyRule = clusterRole.rulesType;

    local coreRule = policyRule.new() +
                     policyRule.withApiGroups(['']) +
                     policyRule.withResources([
                       'services',
                       'endpoints',
                       'nodes',
                       'nodes/proxy',
                       'pods',
                     ]) +
                     policyRule.withVerbs(['get', 'list', 'watch']);
    local extensionRule = policyRule.new() +
                     policyRule.withApiGroups(['extensions']) +
                     policyRule.withResources([
                       'ingresses',
                     ]) +
                     policyRule.withVerbs(['get', 'list', 'watch']);

    local nodeMetricsRule = policyRule.new() +
                            policyRule.withApiGroups(['']) +
                            policyRule.withResources(['nodes/metrics']) +
                            policyRule.withVerbs(['get']);

    local metricsRule = policyRule.new() +
                        policyRule.withNonResourceUrls('/metrics') +
                        policyRule.withVerbs(['get']);

    local rules = [coreRule, extensionRule, nodeMetricsRule, metricsRule];

    clusterRole.new() +
    clusterRole.mixin.metadata.withName('prometheus') +
    clusterRole.withRules(rules),

  clusterRoleBinding:
    local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

    clusterRoleBinding.new() +
    clusterRoleBinding.mixin.metadata.withName('prometheus') +
    clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
    clusterRoleBinding.mixin.roleRef.withName('prometheus') +
    clusterRoleBinding.mixin.roleRef.mixinInstance({ kind: 'ClusterRole' }) +
    clusterRoleBinding.withSubjects([{ kind: 'ServiceAccount', name: 'prometheus', namespace: $._config.namespace }]),


  deployment+:
    deployment.new($._config.name, 1, [ $.container, reloader.volume_webhook('config', "http://localhost:9090/-/reload")], podLabels) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.metadata.withLabels(podLabels) +
    deployment.mixin.spec.selector.withMatchLabels(podLabels) +
    deployment.mixin.spec.template.spec.securityContext.withFsGroup($._config.uid) +
    deployment.mixin.spec.template.spec.securityContext.withRunAsUser($._config.uid) +
    deployment.mixin.spec.template.spec.withServiceAccountName(serviceAccountName) +
    deployment.mixin.spec.template.spec.withVolumes([
      $.data_volume,
      $.config_volume,
   ]),

  service: service.new($._config.name, { app: $._config.name }, { port: $._config.port }) +
    service.mixin.metadata.withNamespace($._config.namespace),

  config_map: configMap.new($._config.name, $.config_files) +
    configMap.mixin.metadata.withNamespace($._config.namespace),

  ingress:
    ingress.new() +
    ingress.mixin.metadata.withName($._config.name) +
    ingress.mixin.metadata.withNamespace($._config.namespace) +
    ingress.mixin.spec.withRules([
      ingressRule.new() +
      ingressRule.withHost($._config.external_domain) +
      ingressRule.mixin.http.withPaths([
        httpIngressPath.new() +
        httpIngressPath.withPath('/') +
        httpIngressPath.mixin.backend.withServiceName($._config.name) +
        httpIngressPath.mixin.backend.withServicePort($._config.port),
      ]),
    ]),
}
