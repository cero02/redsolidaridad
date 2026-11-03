--!strict
-- Mini marco de tests para Lune: test(nombre, fn), expectEqual y finish().

local TestUtil = {}

local failures: { string } = {}
local passed = 0
local suiteName = "?"

function TestUtil.suite(name: string)
	suiteName = name
	failures = {}
	passed = 0
end

function TestUtil.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		table.insert(failures, `  ✗ {name}: {err}`)
	end
end

function TestUtil.expectEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "valor"}: se esperaba {tostring(expected)}, llegó {tostring(actual)}`, 2)
	end
end

function TestUtil.expectError(fn: () -> (), contains: string?)
	local ok, err = pcall(fn)
	if ok then
		error("se esperaba un error", 2)
	end
	if contains and not string.find(tostring(err), contains, 1, true) then
		error(`el error no contiene "{contains}": {err}`, 2)
	end
end

function TestUtil.finish()
	if #failures > 0 then
		error(`{suiteName}: {#failures} fallos\n{table.concat(failures, "\n")}`, 0)
	end
	print(`ok  {suiteName} ({passed} tests)`)
end

return TestUtil
