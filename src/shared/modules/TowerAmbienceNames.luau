--!strict

-- Tags e atributos dos enfeites animados da Torre do Relógio (Fase 5F.2):
-- o servidor monta e marca, o cliente anima (TowerAmbienceController).
-- O portão mágico da largada (StartGateTag) é aberto ou fechado em cada
-- cliente pelo RaceStartGateController.

return table.freeze({
	CandleTag = "TowerCandle",
	BatTag = "TowerBat",
	OrbitCenter = "OrbitCenter",
	OrbitRadius = "OrbitRadius",
	OrbitSpeed = "OrbitSpeed",
	Phase = "Phase",
	StartGateTag = "RaceStartGate",
})
