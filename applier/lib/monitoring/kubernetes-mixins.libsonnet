local kubernetes = import 'kubernetes-mixin/mixin.libsonnet';

kubernetes {
  _config+:: {
    kubeSchedulerSelector: 'kubernetes_name="kube-scheduler"',
    kubeControllerManagerSelector: 'kubernetes_name="kube-controller-manager"',
  },
}
