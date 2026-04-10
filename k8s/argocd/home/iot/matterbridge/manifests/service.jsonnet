local g = import '../globals.libsonnet';
local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.34/main.libsonnet';

local svc = k.core.v1.service;

svc.newWithoutSelector('matterbridge')
+ svc.metadata.withNamespace(g.namespace)
+ svc.metadata.withLabels(g.labels)
+ svc.spec.withPorts([
  { port: g.frontendPort, protocol: 'TCP', targetPort: g.frontendPort, name: 'frontend' },
])
+ svc.spec.withSelector(g.selectorLabels)
