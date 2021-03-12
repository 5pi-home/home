{
  render(site): {
    [stack + '/' + app + '/' + manifest + '.yaml']: std.manifestYamlDoc(site[stack][app][manifest])
    for stack in std.objectFields(site)
    for app in std.objectFields(site[stack])    // stack fields are apps
    for manifest in std.objectFields(site[stack][app]) // app fields are manifests
  }
}
