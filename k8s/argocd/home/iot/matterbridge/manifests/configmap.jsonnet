local g = import '../globals.libsonnet';
local v = import '../values.libsonnet';
local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.34/main.libsonnet';

local cm = k.core.v1.configMap;

cm.new('matterbridge-config')
+ cm.metadata.withNamespace(g.namespace)
+ cm.metadata.withLabels(g.labels)
+ cm.withData({
  // __HA_TOKEN__ is replaced by the write-config initContainer via sed + secret env var
  'matterbridge-hass.config.json.tpl': std.manifestJsonEx({
    name: 'matterbridge-hass',
    type: 'DynamicPlatform',
    host: v.haWsUrl,
    token: '__HA_TOKEN__',
    reconnectTimeout: 60,
    reconnectRetries: 10,
    whiteList: [
      'basement_escalier',
      'bedroom',
      'bedroom_bathroom_dimmer',
      'bedroom_left_dimmer',
      'dressing',
      'entree',
      'escalier',
      'kitchen',
      'piano',
      'poutre_dimmer',
      'table',
      'terrace',
    ],
    blackList: [],
    entityBlackList: [],
    deviceEntityBlackList: {},
    unregisterOnShutdown: false,
  }, '  '),
})
