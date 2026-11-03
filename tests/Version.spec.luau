--!strict
-- Test de humo: comprueba que Lune ejecuta los tests y que la versión tiene formato semver.

local Version = require("../src/shared/Version")

assert(type(Version) == "string", "Version debe ser un string")
assert(string.match(Version, "^%d+%.%d+%.%d+$") ~= nil, `Version no es semver: {Version}`)

print(`ok  Version.spec ({Version})`)
