local k = import 'github.com/jsonnet-libs/k8s-libsonnet/1.30/main.libsonnet';

local g = import 'globals.libsonnet';
local v = import 'values.libsonnet';

local d = k.apps.v1.deployment;
local c = k.core.v1.container;
local vmount = k.core.v1.volumeMount;
local vol = k.core.v1.volume;

local vmountConfig =
  vmount.withName('config')
  + vmount.withMountPath('/app/config.json')
  + vmount.withSubPath('config.json')
  + vmount.withReadOnly(true);
local vmountSessions =
  vmount.withName('sessions')
  + vmount.withMountPath('/app/sessions');

local getTagSeparator(tm='tag') =
  if tm == 'tag' then
    ':'
  else if tm == 'digest' then
    '@'
  else
    error 'tm must be either "digest" or "tag"';

local mainContainer =
  c.withName('main')
  + c.withImage('%s%s%s' % [v.image.repository, getTagSeparator(v.image.tagMode), v.image.tag])
  + c.withImagePullPolicy(v.image.pullPolicy)
  + c.withPorts({
    containerPort: g.containerPort
  })
  + c.withVolumeMounts([
    vmountConfig,
    vmountSessions,
  ])
  + ( c.livenessProbe.httpGet.withPath("/health")
    + c.livenessProbe.httpGet.withPort(g.containerPort)
    + c.livenessProbe.withInitialDelaySeconds(v.container.livenessProbe.initialDelaySeconds)
    + c.livenessProbe.withPeriodSeconds(v.container.livenessProbe.periodSeconds)
    + c.livenessProbe.withTimeoutSeconds(v.container.livenessProbe.timeoutSeconds)
    + c.livenessProbe.withFailureThreshold(v.container.livenessProbe.failureThreshold))
  + ( c.readinessProbe.httpGet.withPath("/health")
    + c.readinessProbe.httpGet.withPort(g.containerPort)
    + c.readinessProbe.withInitialDelaySeconds(v.container.readinessProbe.initialDelaySeconds)
    + c.readinessProbe.withPeriodSeconds(v.container.readinessProbe.periodSeconds)
    + c.readinessProbe.withTimeoutSeconds(v.container.readinessProbe.timeoutSeconds)
    + c.readinessProbe.withFailureThreshold(v.container.readinessProbe.failureThreshold))
  + ( c.startupProbe.httpGet.withPath("/health")
    + c.startupProbe.httpGet.withPort(g.containerPort)
    + c.startupProbe.withInitialDelaySeconds(v.container.startupProbe.initialDelaySeconds)
    + c.startupProbe.withPeriodSeconds(v.container.startupProbe.periodSeconds)
    + c.startupProbe.withTimeoutSeconds(v.container.startupProbe.timeoutSeconds)
    + c.startupProbe.withFailureThreshold(v.container.startupProbe.failureThreshold))
  + c.resources.withLimits({
    cpu: v.container.resources.limits.cpu,
    memory: v.container.resources.limits.memory,
  })
  + c.resources.withRequests({
    cpu: v.container.resources.requests.cpu,
    memory: v.container.resources.requests.memory,
  });

d.new(
  'ygege',
  replicas=1,
  containers=[
    mainContainer,
  ],
)
+ d.metadata.withLabels(g.labels)
+ d.spec.selector.withMatchLabels(g.selectorLabels)
+ d.spec.template.metadata.withLabels(g.labels)
+ d.spec.template.spec.withVolumes([
  vol.fromPersistentVolumeClaim('sessions', 'ygege-sessions'),
  vol.fromSecret('config', 'ygege-secret')
])
