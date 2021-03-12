local k = import "github.com/jsonnet-libs/k8s-alpha/1.19/main.libsonnet";


local newApp(name, image, namespace="default") = {
  container: k.core.v1.container.new(name, image),
  deployment: k.apps.v1.deployment.new(name, containers=[$.container]) +
              k.apps.v1.deployment.metadata.withNamespace(namespace),
};

local newWebApp(name, image, host, containerPort, namespace="default") = newApp(name, image, namespace) + {
  _port:: containerPort,

  service: k.core.v1.service.new(name, $.deployment.spec.template.metadata.labels, k.core.v1.servicePort.new($._port, $._port)) +
           k.core.v1.service.metadata.withNamespace(namespace),

  ingress_rule: k.networking.v1.ingressRule.withHost(host) +
                k.networking.v1.ingressRule.http.withPaths([
                  k.networking.v1.httpIngressPath.withPath('/') +
                  k.networking.v1.httpIngressPath.withPathType('Prefix') +
                  k.networking.v1.httpIngressPath.backend.service.withName($.service.metadata.name) +
                  k.networking.v1.httpIngressPath.backend.service.port.withNumber($._port)
                ]),
  ingress: k.networking.v1.ingress.new(name) +
           k.networking.v1.ingress.metadata.withNamespace($.deployment.metadata.namespace) +
           k.networking.v1.ingress.spec.withRules([$.ingress_rule]),

  all:: k.core.v1.list.new([
    $.deployment,
    $.service,
    $.ingress,
  ])
};

local withVolumeMixin(volume, mountPath, readOnly=false) = {
  deployment+: k.apps.v1.deployment.spec.template.spec.withVolumesMixin(volume),
  container+: k.core.v1.container.withVolumeMountsMixin([
                k.core.v1.volumeMount.new(volume.name, mountPath, readOnly)
  ]),
};

local withPVC(name, size, mountPath, class="default") = {
  pvc: k.core.v1.persistentVolumeClaim.new($.deployment.metadata.name) +
       k.core.v1.persistentVolumeClaim.metadata.withNamespace($.deployment.metadata.namespace) +
       k.core.v1.persistentVolumeClaim.spec.withAccessModes('ReadWriteOnce') +
       k.core.v1.persistentVolumeClaim.spec.resources.withRequests({storage: size}) +
       k.core.v1.persistentVolumeClaim.spec.withStorageClassName(class),
  all+: k.core.v1.list.new([$.pvc]),
} + withVolumeMixin(k.core.v1.volume.fromPersistentVolumeClaim(name, name), mountPath);

{
  newApp:: newApp,
  newWebApp:: newWebApp,

  withVolumeMixin:: withVolumeMixin,
  withPVC:: withPVC,
}
