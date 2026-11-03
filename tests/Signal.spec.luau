--!strict
local Signal = require("../src/shared/Util/Signal")
local T = require("./TestUtil")

T.suite("Signal")

T.test("Fire llama a los conectados con los argumentos", function()
	local signal = Signal.new()
	local got = 0
	signal:Connect(function(a: number, b: number)
		got = a + b
	end)
	signal:Fire(2, 3)
	T.expectEqual(got, 5)
end)

T.test("Disconnect deja de recibir", function()
	local signal = Signal.new()
	local count = 0
	local connection = signal:Connect(function()
		count += 1
	end)
	signal:Fire()
	connection:Disconnect()
	signal:Fire()
	T.expectEqual(count, 1)
	T.expectEqual(connection.Connected, false)
end)

T.test("desconectar durante Fire es seguro", function()
	local signal = Signal.new()
	local count = 0
	local first
	first = signal:Connect(function()
		first:Disconnect()
		count += 1
	end)
	signal:Connect(function()
		count += 1
	end)
	signal:Fire()
	signal:Fire()
	T.expectEqual(count, 3)
end)

T.test("DisconnectAll desconecta todo", function()
	local signal = Signal.new()
	local count = 0
	signal:Connect(function()
		count += 1
	end)
	signal:DisconnectAll()
	signal:Fire()
	T.expectEqual(count, 0)
end)

T.finish()
