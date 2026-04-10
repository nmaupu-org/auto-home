local v = import 'values.libsonnet';

local sl = {
  'app.kubernetes.io/name': 'matterbridge',
};
local l = {
  'app.kubernetes.io/version': std.strReplace(std.substr(v.image.tag, 0, 63), ':', '-'),
};

{
  selectorLabels: sl,
  labels: sl + l,
  namespace: 'matterbridge',
  matterPort: v.matterbridge.port,
  frontendPort: v.matterbridge.frontendPort,
}
