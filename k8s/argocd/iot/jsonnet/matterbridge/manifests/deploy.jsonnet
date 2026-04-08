local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.30/main.libsonnet';
local g = import '../globals.libsonnet';
local v = import '../values.libsonnet';

local d = k.apps.v1.deployment;
local c = k.core.v1.container;
local ic = k.core.v1.container;
local vmount = k.core.v1.volumeMount;
local vol = k.core.v1.volume;
local envVar = k.core.v1.envVar;
local envVarSource = k.core.v1.envVarSource;

// Install the plugin into /root/.matterbridge/node_modules on every start.
// npm install is idempotent - it skips reinstall if the version is already present.
local initInstallPlugin =
  ic.withName('install-plugin')
  + ic.withImage('luligu/matterbridge:latest')
  + ic.withCommand([
    'sh', '-c', |||
      set -e
      mkdir -p /data/node_modules
      cd /data
      npm install --save matterbridge-home-assistant
    |||,
  ])
  + ic.withVolumeMounts([
    vmount.withName('data') + vmount.withMountPath('/data'),
  ]);

local initWriteConfig =
  ic.withName('write-config')
  + ic.withImage('busybox:latest')
  + ic.withCommand([
    'sh', '-c', |||
      set -e
      # Write matterbridge.json only on first run (matterbridge manages it after that)
      if [ ! -f /data/matterbridge.json ]; then
        cp /config/matterbridge.json /data/matterbridge.json
      fi
      # Always rewrite plugin config so token stays up to date
      sed "s|__HA_TOKEN__|${HA_TOKEN}|g" \
        /config/matterbridge-home-assistant.json.tpl \
        > /data/matterbridge-home-assistant.json
    |||,
  ])
  + ic.withEnv([
    envVar.withName('HA_TOKEN')
    + envVar.valueFrom.secretKeyRef.withName('matterbridge-secret')
    + envVar.valueFrom.secretKeyRef.withKey('HA_TOKEN'),
  ])
  + ic.withVolumeMounts([
    vmount.withName('data') + vmount.withMountPath('/data'),
    vmount.withName('config') + vmount.withMountPath('/config') + vmount.withReadOnly(true),
  ]);

local mainContainer =
  c.withName('matterbridge')
  + c.withImage('%s:%s' % [v.image.repository, v.image.tag])
  + c.withImagePullPolicy(v.image.pullPolicy)
  + c.withArgs(['-bridge', '-frontend', std.toString(g.frontendPort)])
  + c.withEnv([
    envVar.withName('TZ') + envVar.withValue('Europe/Paris'),
  ])
  + c.withPorts([
    { containerPort: g.matterPort, protocol: 'UDP', name: 'matter' },
    { containerPort: g.frontendPort, protocol: 'TCP', name: 'frontend' },
  ])
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
+ d.spec.template.spec.withHostNetwork(true)
+ d.spec.template.spec.withDnsPolicy('ClusterFirstWithHostNet')
+ d.spec.template.spec.withInitContainers([initInstallPlugin, initWriteConfig])
+ d.spec.template.spec.withVolumes([
  vol.fromPersistentVolumeClaim('data', 'matterbridge-data'),
  vol.fromConfigMap('config', 'matterbridge-config'),
])
