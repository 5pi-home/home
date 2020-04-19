local kubernetes = import 'kubernetes-mixin/mixin.libsonnet';

kubernetes {
  _config+:: {},
}
