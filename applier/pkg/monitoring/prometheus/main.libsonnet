local k = import 'ksonnet-lib/ksonnet.beta.4/k.libsonnet';
local container = k.apps.v1.deployment.mixin.spec.template.spec.containersType;
local deployment = k.apps.v1.deployment;

local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;

local volume = k.apps.v1.deployment.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;
local configMap = k.core.v1.configMap;

{
  _config+:: {
    name: 'prometheus',
    namespace: 'prometheus',
    version: '2.15.2',
    port: 9090,
    uid: 1000,
    image_repo: 'prom/prometheus',
    config_files+: {
      'prometheus.yml': std.manifestYamlDoc(import 'config.libsonnet'),
    }
  },
  prometheus+: {
    local datavm = containerVolumeMount.new("data", "/prometheus"),
    local datav = volume.fromHostPath("data", "/data/prometheus"),
    local configvm = containerVolumeMount.new("config", "/etc/prometheus"),
    local configv = volume.withName("config") + volume.mixin.configMap.withName("prometheus"),
    local image = $._config.image_repo + ':v' + $._config.version,
    local c = container.new("prometheus", image) +
      container.withVolumeMounts([datavm, configvm]),
    local podLabels = { app: $._config.name },
    local serviceAccountName = 'prometheus',

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


    deployment:
      deployment.new($._config.name, 1, c, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.template.spec.securityContext.withFsGroup($._config.uid) +
      deployment.mixin.spec.template.spec.securityContext.withRunAsUser($._config.uid) +
      deployment.mixin.spec.template.spec.withServiceAccountName(serviceAccountName) +
      deployment.mixin.spec.template.spec.withVolumes([datav, configv]),

    service: service.new($._config.name, { app: $._config.name }, { port: $._config.port }) +
      service.mixin.metadata.withNamespace($._config.namespace),

    config_map: configMap.new($._config.name, $._config.config_files) +
      configMap.mixin.metadata.withNamespace($._config.namespace),
  }
}
