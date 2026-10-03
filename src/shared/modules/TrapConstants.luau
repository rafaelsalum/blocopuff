--!strict

-- Nomes compartilhados das armadilhas do Casarão. O servidor decide tudo e
-- publica o estado em atributos da peça-alvo (a que leva a tag); o cliente
-- só desenha a partir deles.

export type TrapState = "Ready" | "Warning" | "Recharging" | "Spent"
export type TrapKind = "Window" | "Rug" | "Chandelier"

local TrapConstants = table.freeze({
	Tag = "CasaraoTrap",

	-- Atributos da peça-alvo.
	KindAttribute = "TrapKind",
	IdAttribute = "TrapId",
	FloorAttribute = "TrapFloor",
	-- Direção horizontal da parede para dentro da arena.
	InwardAttribute = "TrapInward",
	StateAttribute = "TrapState",
	-- Instante (Workspace:GetServerTimeNow) em que o estado começou.
	StateAtAttribute = "TrapStateAt",
	-- UserId de quem acionou (0 = ninguém).
	ByAttribute = "TrapBy",
	UsesAttribute = "TrapUses",
	-- Contador de acertos de perto (só trinca): cada aumento é uma trinca.
	CracksAttribute = "TrapCracks",

	-- Nomes das peças de uma janela (dentro do mesmo Model do vidro).
	WindowGlassName = "Glass",
	WindowCurtainNames = table.freeze({ "CurtainL", "CurtainR" }),
	WindowBoardPrefix = "Board",

	-- Tapete: direção do puxão (no alvo, a franja) e, em cada pedaço do
	-- tapete, a distância até a franja ao longo do puxão.
	RugPullAttribute = "RugPull",
	RugAlongAttribute = "RugAlong",

	-- Lustre: ponto do teto onde a corrente se prende e ponto do chão onde
	-- ele cai.
	ChandelierAnchorAttribute = "ChandelierAnchor",
	ChandelierImpactAttribute = "ChandelierImpact",

	Ready = "Ready" :: TrapState,
	Warning = "Warning" :: TrapState,
	Recharging = "Recharging" :: TrapState,
	Spent = "Spent" :: TrapState,

	Window = "Window" :: TrapKind,
	Rug = "Rug" :: TrapKind,
	Chandelier = "Chandelier" :: TrapKind,
})

return TrapConstants
