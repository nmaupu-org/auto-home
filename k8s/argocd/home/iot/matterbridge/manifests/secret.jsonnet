local secretSealedStr = importstr '../sealed-secret.yaml';
local secretSealed = std.parseYaml(secretSealedStr);
local g = import '../globals.libsonnet';

secretSealed {
  metadata+: {
    labels+: g.labels,
  },
}
