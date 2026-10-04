--!strict

-- Inglês dos textos de partida, HUD, resultado, fila, controles e avisos
-- (chave: o texto em português do código).

return table.freeze({
	-- FILA E EMBARQUE (Queue)
	["Sua vez chega em %d rodadas"] = "Your turn comes in %d rounds",
	["Você participa da próxima rodada"] = "You play in the next round",
	["%d na fila · fique no mirante"] = "%d in queue · stay at the lookout",
	["Falta 1 jogador para começar"] = "1 player needed to start",
	["Faltam %d jogadores para começar"] = "%d players needed to start",
	["✅ VOCÊ ESTÁ NA FILA"] = "✅ YOU'RE IN THE QUEUE",
	["🏟 NA FILA  %d/%d"] = "🏟 IN QUEUE  %d/%d",
	["🏟 %d NA FILA"] = "🏟 %d IN QUEUE",
	["🏟 FILA  %d/%d"] = "🏟 QUEUE  %d/%d",
	["Vá ao mirante para jogar"] = "Go to the lookout to play",
	["Fique no mirante para jogar a próxima"] = "Stay at the lookout to play next",
	["Você entra em %d rodadas"] = "You enter in %d rounds",
	["Você está na fila da próxima"] = "You're in the next queue",
	["VOCÊ SAIU DA FILA"] = "YOU LEFT THE QUEUE",
	["Volte ao mirante quando quiser jogar"] = "Come back to the lookout when you want to play",

	-- NOTIFICAÇÕES DE FILA (Queue Notifications)
	["CHAME UM AMIGO"] = "CALL A FRIEND",
	["A partida começa com 2 no mirante. Convide pela Party!"] = "The match starts with 2 at the lookout. Invite via Party!",
	["ROBOPUFFS CHEGANDO!"] = "ROBO PUFFS ARRIVING!",
	["Eles completam a partida. Chame um amigo para jogar junto!"] = "They complete the match. Call a friend to play with!",
	["EMBARQUE ENCERRADO!"] = "BOARDING CLOSED!",
	["Portas fechadas: a partida vai começar"] = "Doors closed: the match is about to start",
	["EMBARQUE ENCERRADO"] = "BOARDING CLOSED",
	["Essa partida já vai começar. Entre na fila da próxima!"] = "This match is about to start. Join the next queue!",
	["VOCÊ ESTÁ NA FILA!"] = "YOU'RE IN THE QUEUE!",
	["Fique no mirante. Para sair, é só voltar pela porta"] = "Stay at the lookout. To leave, just go back through the door",

	-- PORTAIS E PAINÉIS DE FILA (Queue Visuals)
	["🏟 ENTRAR NA FILA"] = "🏟 JOIN THE QUEUE",
	["Entre e saia quando quiser"] = "Join and leave whenever you want",
	["🏟 FILA DA PARTIDA"] = "🏟 MATCH QUEUE",
	["🔒 Embarque encerrado · a partida vai começar!"] = "🔒 Boarding closed · the match is starting!",
	["Partida em %ds · entre agora!"] = "Match in %ds · join now!",
	["A contagem já vai começar"] = "Countdown is about to start",
	["%d / %d na fila"] = "%d / %d in queue",

	-- AQUECIMENTO (Warmup)
	["🎈 Estoure os balões enquanto espera!"] = "🎈 Pop the balloons while you wait!",

	-- RESULTADO DE RODADA (Round Results - Status)
	["Voltando ao lobby em %d s\n%s"] = "Returning to lobby in %d s\n%s",
	["Próxima rodada em %d s\n%s"] = "Next round in %d s\n%s",
	["Aguardando jogadores para a próxima rodada"] = "Waiting for players for the next round",
	["A próxima rodada está chegando"] = "The next round is coming",

	-- MENSAGENS DE TRANSIÇÃO (Round Messages)
	["Entre no mirante para jogar"] = "Enter the lookout to play",
	["Partida em andamento"] = "Match in progress",
	["Partida encerrada"] = "Match ended",
	["A partida vai começar"] = "The match is about to start",
	["%s venceu"] = "%s won",

	-- HUD EM PARTIDA (Match HUD)
	["⚔️ PARTIDA EM ANDAMENTO"] = "⚔️ MATCH IN PROGRESS",
	["Você está na fila da próxima"] = "You're in the next queue",
	["Vá ao mirante para jogar a próxima"] = "Go to the lookout to play next",
	["Você derrubou %d %s"] = "You knocked down %d %s",
	["bloco"] = "block",
	["blocos"] = "blocks",
	["derrubada"] = "knockout",
	["derrubadas"] = "knockouts",

	-- AVISOS DE ELIMINAÇÃO (Elimination Announcements)
	["VOCÊ CAIU!"] = "YOU FELL!",
	["ELIMINADO!"] = "ELIMINATED!",
	["%s · acompanhe os jogadores restantes"] = "%s · watch the remaining players",

	-- AVISOS DE CAOS FINAL (Final Chaos Announcements)
	["CAOS FINAL!"] = "FINAL CHAOS!",
	["Sem Segunda Chance · blocos vermelhos vão cair"] = "No Second Chance · red blocks will fall",

	-- AVISOS DE SEGUNDA CHANCE (Second Chance Announcements)
	["SEGUNDA CHANCE!"] = "SECOND CHANCE!",
	["Você voltou para a arena · agora é sua última vida"] = "You're back in the arena · this is your last life",

	-- ANÚNCIO DE INÍCIO DE RODADA (Round Start)
	["PREPARE-SE"] = "GET READY",
	["VALENDO!"] = "GO!",
	["Empurre os rivais e derrube os blocos embaixo deles"] = "Push rivals and destroy blocks beneath them",

	-- PAINEL DE RESULTADOS - TÍTULOS (Results Panel - Titles)
	["VITÓRIA!"] = "VICTORY!",
	["Você foi o último na arena"] = "You were the last in the arena",
	["EMPATE!"] = "DRAW!",
	["Os últimos caíram ao mesmo tempo"] = "The last ones fell at the same time",
	["%d jogadores resistiram até o fim"] = "%d players lasted to the end",
	["FIM DA RODADA"] = "END OF ROUND",
	["%s venceu a rodada"] = "%s won the round",
	["Ninguém sobrou na arena"] = "Nobody survived in the arena",
	["Rodada encerrada"] = "Round ended",

	-- PAINEL DE RESULTADOS - PESSOAL (Results Panel - Personal)
	["Você: <font color=\"#FFD166\">#%d</font> de %d  ·  %s  ·  %s"] = "You: <font color=\"#FFD166\">#%d</font> of %d  ·  %s  ·  %s",
	["Você assistiu esta rodada"] = "You watched this round",

	-- DESTAQUES (Highlights)
	["DEMOLIDOR"] = "DEMOLISHER",
	["MAIS DERRUBADAS"] = "MOST KNOCKOUTS",
	["DONO DO COFRE"] = "VAULT MASTER",
	["ESCAPOU DO BARÃO"] = "BARON ESCAPE",
	["DESCOBRIDOR"] = "DISCOVERER",
	["VOLTA POR CIMA"] = "COMEBACK",

	-- XP E NÍVEIS (XP and Levels)
	["NÍVEL %d → %d!"] = "LEVEL %d → %d!",
	["NÍVEL MÁXIMO"] = "MAX LEVEL",
	["NÍVEL %d  ·  %d/%d"] = "LEVEL %d  ·  %d/%d",
	["+%d XP  +%d 🎟"] = "+%d XP  +%d 🎟",
	["+%d XP"] = "+%d XP",
	["Dispare pelo menos um Puff para ganhar XP"] = "Fire at least one Puff to earn XP",

	-- FONTES DE XP (XP Sources)
	["Partida"] = "Match",
	["Colocação"] = "Placement",
	["Vitória"] = "Win",
	["Derrubadas"] = "Knockouts",
	["Blocos"] = "Blocks",
	["Segredos"] = "Secrets",
	["Cofre aberto"] = "Vault opened",
	["Cofre conquistado"] = "Vault conquered",
	["Volta por Cima"] = "Comeback",
	["Construções"] = "Builds",

	-- DESTAQUES - DETALHES (Highlights - Details)
	["pegou o Puffador"] = "got the Puffador",
	["abriu o cofre"] = "opened the vault",
	["fuga"] = "escape",
	["fugas"] = "escapes",
	["passagem"] = "passage",
	["passagens"] = "passages",

	-- PAINEL DE RESULTADOS - VAZIO (Results Panel - Empty)
	["Sem destaques nesta rodada"] = "No highlights this round",

	-- MOMENTOS PUFF (Puff Moments)
	["ESCAPOU DO BARÃO!"] = "ESCAPED THE BARON!",
	["Você pulou por cima dele"] = "You jumped over him",
	["Você fugiu da perseguição"] = "You escaped the chase",
	["%s pulou por cima do Barão"] = "%s jumped over the Baron",
	["%s fugiu do Barão"] = "%s escaped the Baron",
	["VOLTA POR CIMA!"] = "COMEBACK!",
	["Você venceu depois da Segunda Chance"] = "You won after Second Chance",
	["Você voltou da Segunda Chance e derrubou alguém"] = "You came back from Second Chance and knocked someone out",
	["%s venceu depois da Segunda Chance"] = "%s won after Second Chance",
	["%s voltou da Segunda Chance e derrubou alguém"] = "%s came back from Second Chance and knocked someone out",
	["Alguém"] = "Someone",

	-- MODO CONSTRUIR (Build Mode)
	["MODO CONSTRUIR"] = "BUILD MODE",
	["Mire num buraco da arena e dispare (%d restantes)"] = "Aim at a hole in the arena and fire (%d remaining)",
	["Tem alguém no lugar do bloco"] = "Someone is in the block's place",
	["Mire num buraco da arena, mais perto"] = "Aim at a hole in the arena, closer",
	["CONSTRUÇÕES ESGOTADAS"] = "BUILDS EXHAUSTED",
	["Seu Puffador do Cofre volta a só dar Puff"] = "Your Vault Puffador is back to shooting only Puffs",
	["NÃO DÁ PARA CONSTRUIR AQUI"] = "CAN'T BUILD HERE",

	-- BOTÕES (Buttons)
	["BLOCO!"] = "BUILD!",
	["CONSTRUIR"] = "BUILD",
	["CONSTRUIR %d"] = "BUILD %d",
	["PUFF"] = "PUFF",
	["PUFF!"] = "PUFF!",
	["ATIRAR"] = "SHOOT",
	["RECARREGANDO"] = "RECHARGING",
	["RECARGA"] = "RECHARGE",

	-- PAINEL DE COMBATE (Combat HUD)
	["JOGADORES"] = "PLAYERS",
	["NA RODADA"] = "IN ROUND",
	["SEUS BLOCOS"] = "YOUR BLOCKS",
	["♥ ÚLTIMA VIDA"] = "♥ LAST LIFE",

	-- FEEDBACK DE COMBO (Combo Feedback)
	["TRIPLO!"] = "TRIPLE!",
	["EM CHAMAS!"] = "ON FIRE!",
	["IMPARÁVEL!"] = "UNSTOPPABLE!",
	["LENDÁRIO!"] = "LEGENDARY!",

	-- ESPECTADOR (Spectator)
	["👁  ASSISTINDO"] = "👁  SPECTATING",
	["1 jogador restante"] = "1 player remaining",
	["%d jogadores restantes"] = "%d players remaining",
	["👥 %s"] = "👥 %s",

	-- ORIENTAÇÃO DE TELA (Screen Orientation)
	["GIRE O CELULAR"] = "ROTATE YOUR DEVICE",
	["O Bloco Puff é jogado com a tela deitada"] = "BlocoPuff is played with the screen sideways",

	-- DICAS DE CONTROLE (Control Hints)
	["SEGURE O GATILHO DIREITO (R2) PARA ATIRAR"] = "HOLD RIGHT TRIGGER (R2) TO SHOOT",
	["SEGURE O BOTÃO PUFF PARA ATIRAR"] = "HOLD PUFF BUTTON TO SHOOT",
	["SEGURE O CLIQUE PARA ATIRAR"] = "HOLD CLICK TO SHOOT",

	-- MARCOS DE PONTUAÇÃO (Score Milestones)
	["10 blocos derrubados! 🔥"] = "10 blocks destroyed! 🔥",
	["25 blocos! Você está dominando a arena"] = "25 blocks! You're dominating the arena",
	["50 blocos! Demolidor oficial 🏆"] = "50 blocks! Official Demolisher 🏆",

	-- KICK/BAN MESSAGES (Admin Service)
	["Você está banido."] = "You are banned.",
	["Você está banido do BlocoPuff."] = "You are banned from BlocoPuff.",
	["Você foi banido do BlocoPuff."] = "You were banned from BlocoPuff.",
	["Removido por um administrador do BlocoPuff."] = "Removed by a BlocoPuff administrator.",
	["Banido por um administrador do BlocoPuff."] = "Banned by a BlocoPuff administrator.",
	["Motivo: %s"] = "Reason: %s",

	-- Botão da fila no HUD
	["🏟 JOGAR"] = "🏟 PLAY",
	["♥♥ 2 VIDAS"] = "♥♥ 2 LIVES",
	["☠ SEM 2ª CHANCE"] = "☠ NO 2ND CHANCE",
})
