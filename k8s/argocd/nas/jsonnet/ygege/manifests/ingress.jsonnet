local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.30/main.libsonnet';

local g = import 'globals.libsonnet';
local v = import 'values.libsonnet';

local net = k.networking.v1;

net.ingress.new("ygege")
+ net.ingress.metadata.withAnnotations({
  "cert-manager.io/cluster-issuer": v.ingress.certManager.certificateIssuer,
} + v.ingress.extraAnnotations)
+ net.ingress.metadata.withLabels(g.labels)
+ net.ingress.spec.withRules([
    net.ingressRule.withHost(v.ingress.host)
    + net.ingressRule.http.withPaths([
        net.httpIngressPath.withPath("/")
        + net.httpIngressPath.withPathType("Prefix")
        + net.httpIngressPath.backend.service.withName("ygege")
        + net.httpIngressPath.backend.service.port.withNumber(g.containerPort)
    ])
])
+ net.ingress.spec.withTls(
  net.ingressTLS.withHosts([v.ingress.host])
  + net.ingressTLS.withSecretName("ygege-cert")
)
