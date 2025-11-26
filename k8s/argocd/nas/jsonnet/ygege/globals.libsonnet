local v = import 'values.libsonnet';

local sl = {
    'app.kubernetes.io/name': 'ygege',
};
local l = {
    'app.kubernetes.io/version': std.strReplace(std.substr(v.image.tag, 0, 63), ":", "-"),
};

{
  selectorLabels: sl,
  labels: sl+l,
  containerPort: 8715,
}
