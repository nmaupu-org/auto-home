local g = import '../globals.libsonnet';
local v = import '../values.libsonnet';
local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.34/main.libsonnet';

local pvc = k.core.v1.persistentVolumeClaim;

pvc.new('matterbridge-data')
+ pvc.metadata.withNamespace(g.namespace)
+ pvc.metadata.withLabels(g.labels)
+ pvc.spec.withStorageClassName(v.pvc.data.storageClass)
+ pvc.spec.withAccessModes('ReadWriteOnce')
+ pvc.spec.resources.withRequests({ storage: v.pvc.data.size })
