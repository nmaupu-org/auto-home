local g = import '../globals.libsonnet';
local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.34/main.libsonnet';

local ing = k.networking.v1.ingress;

ing.new('matterbridge')
+ ing.metadata.withNamespace(g.namespace)
+ ing.metadata.withLabels(g.labels)
+ ing.metadata.withAnnotations({
  'cert-manager.io/cluster-issuer': 'google-dns-issuer-prod',
  'traefik.ingress.kubernetes.io/router.entrypoints': 'websecure',
  'traefik.ingress.kubernetes.io/router.tls': 'true',
})
+ ing.spec.withRules([
  {
    host: 'matterbridge.iot.home.fossar.net',
    http: {
      paths: [
        {
          path: '/',
          pathType: 'Prefix',
          backend: {
            service: {
              name: 'matterbridge',
              port: { number: g.frontendPort },
            },
          },
        },
      ],
    },
  },
])
+ ing.spec.withTls([
  {
    secretName: 'matterbridge-tls',
    hosts: ['matterbridge.iot.home.fossar.net'],
  },
])
