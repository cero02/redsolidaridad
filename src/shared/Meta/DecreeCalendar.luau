--!strict
-- Qué Decreto del César está activo en un momento dado y cuánto le queda.
-- Determinista: todos los servidores del mundo calculan el mismo decreto sin hablar entre sí.

local WEEK = 7 * 24 * 60 * 60
-- El 1 de enero de 1970 fue jueves; el primer lunes fue el 5 de enero (345 600 s).
local FIRST_MONDAY = 4 * 24 * 60 * 60

local DecreeCalendar = {}

DecreeCalendar.WEEK = WEEK

function DecreeCalendar.weekIndex(unixTime: number): number
	return math.floor((unixTime - FIRST_MONDAY) / WEEK)
end

-- Devuelve el índice (1..count) del decreto activo y los segundos que le quedan.
function DecreeCalendar.current(unixTime: number, count: number): (number, number)
	assert(count > 0, "sin decretos")
	local week = DecreeCalendar.weekIndex(unixTime)
	local index = (week % count) + 1
	local nextWeekStart = FIRST_MONDAY + (week + 1) * WEEK
	return index, nextWeekStart - unixTime
end

-- "3 d 4 h", "5 h 12 min" o "8 min": tiempo restante legible.
function DecreeCalendar.formatRemaining(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local days = total // 86400
	local hours = (total % 86400) // 3600
	local minutes = (total % 3600) // 60
	if days > 0 then
		return `{days} d {hours} h`
	elseif hours > 0 then
		return `{hours} h {minutes} min`
	end
	return `{math.max(1, minutes)} min`
end

return DecreeCalendar
