local k = import 'k.libsonnet';

local fpl = import 'fpl.libsonnet';
local cert_manager = fpl.apps.cert_manager;

{
  k8s_webhook_handler: fpl.apps.k8s_webhook_handler.new({
    host: 'k8s-webhook-handler.' + $._config.domain,
    webhook_secret: std.extVar('k8s_webhook_handler_webhook_secret'),
    github_username: '5pi-bot',
    github_token: std.extVar('k8s_webhook_handler_github_token'),
    node_selector: { 'kubernetes.io/arch': 'amd64' },
    rbac_rules: [
      k.rbac.v1.policyRule.withApiGroups('argoproj.io') +
      k.rbac.v1.policyRule.withResources('workflows') +
      k.rbac.v1.policyRule.withVerbs('create'),
    ],
  }) + {
    ingress+: k.networking.v1.ingress.metadata.withAnnotationsMixin(
      {
        'nginx.ingress.kubernetes.io/enable-global-auth': 'false',
      },
    ),
    service_account+: k.core.v1.serviceAccount.withImagePullSecrets([{ name: 'image-pull-secret' }]),
  } + cert_manager.withCertManagerTLS($._config.tls_issuer),
  deployer: {
    service_account: k.core.v1.serviceAccount.new('ci-deployer') +
                     k.core.v1.serviceAccount.metadata.withNamespace('ci') +
                     k.core.v1.serviceAccount.withImagePullSecrets([{ name: 'image-pull-secret' }]),
    admin_cluster_role_binding:
      k.rbac.v1.clusterRoleBinding.new('ci-deployer-admin') +
      k.rbac.v1.clusterRoleBinding.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      k.rbac.v1.clusterRoleBinding.roleRef.withKind('ClusterRole') +
      k.rbac.v1.clusterRoleBinding.roleRef.withName('cluster-admin') +
      k.rbac.v1.clusterRoleBinding.withSubjects([
        k.rbac.v1.subject.fromServiceAccount(self.service_account),
      ]),
  },
  volumes: {
    podman: k.core.v1.persistentVolumeClaim.new('podman') +
            k.core.v1.persistentVolumeClaim.metadata.withNamespace('ci') +
            k.core.v1.persistentVolumeClaim.spec.withAccessModes(['ReadWriteOnce']) +
            k.core.v1.persistentVolumeClaim.spec.withStorageClassName('zfs-stripe-ssd') +
            k.core.v1.persistentVolumeClaim.spec.resources.withRequests({ storage: '100Gi' }),
  },
}
