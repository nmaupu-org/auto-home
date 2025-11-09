local v = import 'values.libsonnet';

{
  labels: {
    'app.kubernetes.io/name': 'ygege',
    'app.kubernetes.io/version': std.strReplace(std.substr(v.image.tag, 0, 63), ":", "-"),
  },
  containerPort: 8715,
}
