local default_values = importstr 'values-default.yaml';
local values = importstr 'values.yaml';

local parsed = std.parseYaml(values);
std.mergePatch(std.parseYaml(default_values), if parsed == null then {} else parsed)
