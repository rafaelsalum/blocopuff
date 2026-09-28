--!strict

-- Curva de nível determinística: o nível sai só do XP total (dentro do
-- prestígio atual). Servidor e cliente usam as mesmas contas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)

export type LevelProgress = {
	level: number,
	-- XP dentro do nível atual e quanto falta no total para o próximo.
	current: number,
	needed: number,
	isMax: boolean,
}

local LevelCurve = {}

-- XP para ir de `level` a `level + 1`.
function LevelCurve.xpForNextLevel(level: number): number
	return ProgressionConfig.LevelBaseXp + (ProgressionConfig.LevelGrowthXp * (math.max(1, level) - 1))
end

-- XP total acumulado para chegar ao início de `level`.
function LevelCurve.totalXpForLevel(level: number): number
	local target = math.clamp(math.floor(level), 1, ProgressionConfig.MaxLevel)
	local total = 0
	for current = 1, target - 1 do
		total += LevelCurve.xpForNextLevel(current)
	end
	return total
end

-- XP máximo que conta no prestígio atual (início do nível máximo).
function LevelCurve.maxXp(): number
	return LevelCurve.totalXpForLevel(ProgressionConfig.MaxLevel)
end

function LevelCurve.progress(totalXp: number): LevelProgress
	local xp = math.max(0, math.floor(totalXp))
	local level = 1
	local remaining = xp
	while level < ProgressionConfig.MaxLevel do
		local needed = LevelCurve.xpForNextLevel(level)
		if remaining < needed then
			return { level = level, current = remaining, needed = needed, isMax = false }
		end
		remaining -= needed
		level += 1
	end
	return { level = ProgressionConfig.MaxLevel, current = 0, needed = 0, isMax = true }
end

function LevelCurve.levelForXp(totalXp: number): number
	return LevelCurve.progress(totalXp).level
end

return table.freeze(LevelCurve)
