--!strict
-- Señal mínima (conectar, disparar, desconectar) sin dependencias externas.
-- Módulo puro para poder probarlo con Lune.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local listeners: { [Connection]: (T...) -> () } = {}

	local signal = {} :: Signal<T...>

	function signal.Connect(_self: Signal<T...>, fn: (T...) -> ()): Connection
		local connection = { Connected = true } :: Connection
		function connection.Disconnect(self: Connection)
			self.Connected = false
			listeners[self] = nil
		end
		listeners[connection] = fn
		return connection
	end

	function signal.Fire(_self: Signal<T...>, ...: T...)
		-- Copia para que desconectar durante el disparo sea seguro.
		local snapshot = table.clone(listeners)
		for connection, fn in snapshot do
			if connection.Connected then
				fn(...)
			end
		end
	end

	function signal.DisconnectAll(_self: Signal<T...>)
		for connection in listeners do
			connection.Connected = false
		end
		table.clear(listeners)
	end

	return signal
end

return Signal
