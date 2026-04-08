local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.30/main.libsonnet';
local g = import '../globals.libsonnet';
local v = import '../values.libsonnet';

local cm = k.core.v1.configMap;

cm.new('matterbridge-config')
+ cm.metadata.withNamespace(g.namespace)
+ cm.metadata.withLabels(g.labels)
+ cm.withData({
  'matterbridge.json': std.manifestJsonEx({
    bridge: {
      name: 'Matterbridge',
      port: g.matterPort,
      passcode: v.matterbridge.passcode,
      discriminator: v.matterbridge.discriminator,
    },
    plugins: [
      {
        name: 'matterbridge-home-assistant',
        enabled: true,
        requiresAccessToken: false,
      },
    ],
  }, '  '),
  // Template: __HA_TOKEN__ is replaced by initContainer using sed + secret env var
  'matterbridge-home-assistant.json.tpl': std.manifestJsonEx({
    host: v.haUrl,
    token: '__HA_TOKEN__',
    whiteList: [],
    blackList: [],
    entityBlackList: [],
    deviceBlackList: [],
    configBlackList: [],
    unregisterOnShutdown: false,
  }, '  '),
})
