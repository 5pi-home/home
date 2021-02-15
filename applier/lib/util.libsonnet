local k = import 'k.libsonnet';
{
  toList(obj)::
    k.core.v1.list.new(std.objectValues(obj)),
}
