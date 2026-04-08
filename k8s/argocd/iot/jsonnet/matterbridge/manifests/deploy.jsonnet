local g = import '../globals.libsonnet';
local v = import '../values.libsonnet';
local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.34/main.libsonnet';
local cm = import 'configmap.jsonnet';

local d = k.apps.v1.deployment;
local c = k.core.v1.container;
local vmount = k.core.v1.volumeMount;
local vol = k.core.v1.volume;
local envVar = k.core.v1.envVar;

// Write the HA plugin config file (with token injection)
local initWriteConfig =
  c.withName('write-config')
  + c.withImage('busybox:latest')
  + c.withCommand(['sh', '-c', |||
    set -e
    sed "s|__HA_TOKEN__|${HA_TOKEN}|g" \
      /config/matterbridge-hass.config.json.tpl \
      > /data/matterbridge-hass.config.json
  |||])
  + c.withEnv([
    envVar.withName('HA_TOKEN')
    + envVar.valueFrom.secretKeyRef.withName('matterbridge-secret')
    + envVar.valueFrom.secretKeyRef.withKey('HA_TOKEN'),
  ])
  + c.withVolumeMounts([
    vmount.withName('data') + vmount.withMountPath('/data'),
    vmount.withName('config') + vmount.withMountPath('/config') + vmount.withReadOnly(true),
  ]);

// Register the plugin with matterbridge using the known global npm path
// (idempotent: -add is a no-op if already registered)
local initRegisterPlugin =
  c.withName('register-plugin')
  + c.withImage('%s:%s' % [v.image.repository, v.image.tag])
  + c.withCommand(['sh', '-c', |||
    matterbridge -add /usr/local/lib/node_modules/matterbridge-hass
  |||])
  + c.withVolumeMounts([
    vmount.withName('data') + vmount.withMountPath('/root/.matterbridge'),
  ]);

local mainContainer =
  c.withName('matterbridge')
  + c.withImage('%s:%s' % [v.image.repository, v.image.tag])
  + c.withImagePullPolicy(v.image.pullPolicy)
  + c.withCommand(['/matterbridge/entrypoint.latest.sh'])
  + c.withArgs(['node', '/usr/local/bin/matterbridge', '-docker', '-mdnsinterface', v.matterbridge.mdnsInterface])
  + c.withEnv([
    envVar.withName('TZ') + envVar.withValue('Europe/Paris'),
  ])
  // No ports declared: hostNetwork: true already exposes all ports on the host
  + c.withVolumeMounts([
    vmount.withName('data') + vmount.withMountPath('/root/.matterbridge'),
  ])
  + c.resources.withRequests({ memory: '128Mi', cpu: '50m' })
  + c.resources.withLimits({ memory: '256Mi' });

d.new('matterbridge', replicas=1, containers=[mainContainer])
+ d.metadata.withNamespace(g.namespace)
+ d.metadata.withLabels(g.labels)
+ d.spec.selector.withMatchLabels(g.selectorLabels)
+ d.spec.template.metadata.withLabels(g.labels)
+ d.spec.template.metadata.withAnnotations({
  'checksum/config': std.md5(std.toString(cm.data)),
})
// Recreate strategy: kill old pod before starting new one (required with hostNetwork to avoid port conflicts)
+ { spec+: { strategy: { type: 'Recreate' } } }
+ d.spec.template.spec.withHostNetwork(true)
+ d.spec.template.spec.withDnsPolicy('ClusterFirstWithHostNet')
+ d.spec.template.spec.withInitContainers([initWriteConfig, initRegisterPlugin])
+ d.spec.template.spec.withVolumes([
  vol.fromPersistentVolumeClaim('data', 'matterbridge-data'),
  vol.fromConfigMap('config', 'matterbridge-config'),
])
