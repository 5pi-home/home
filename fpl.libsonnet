local fplibs = {
  release: import 'github.com/5pi/jsonnet-libs/main.libsonnet',
  dev: import '../jsonnet-libs/main.libsonnet',
};
if std.extVar('fpl_local') == 'true' then fplibs.dev else fplibs.release
