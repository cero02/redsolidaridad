--!strict
-- Límite de peticiones por clave (cubo de fichas / token bucket).
-- Módulo puro: el reloj se puede inyectar para los tests.

export type RateLimiter = {
	-- Devuelve true si la petición se permite (y gasta una ficha).
	consume: (self: RateLimiter, key: any) -> boolean,
	-- Olvida una clave (p. ej. cuando el jugador sale).
	remove: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, updatedAt: number }

local RateLimiter = {}

-- capacity: ráfaga máxima permitida. perSecond: fichas que se recuperan por segundo.
function RateLimiter.new(capacity: number, perSecond: number, clock: (() -> number)?): RateLimiter
	assert(capacity >= 1, "capacity debe ser >= 1")
	assert(perSecond > 0, "perSecond debe ser > 0")
	local now = clock or os.clock
	local buckets: { [any]: Bucket } = {}

	local limiter = {} :: RateLimiter

	function limiter.consume(_self: RateLimiter, key: any): boolean
		local t = now()
		local bucket = buckets[key]
		if bucket == nil then
			bucket = { tokens = capacity, updatedAt = t }
			buckets[key] = bucket
		else
			local elapsed = math.max(0, t - bucket.updatedAt)
			bucket.tokens = math.min(capacity, bucket.tokens + elapsed * perSecond)
			bucket.updatedAt = t
		end

		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	function limiter.remove(_self: RateLimiter, key: any)
		buckets[key] = nil
	end

	return limiter
end

return RateLimiter
