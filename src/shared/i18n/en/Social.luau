--!strict

-- Inglês dos textos de Perfil, Progressão, Ranking, Desafios e Social.

return table.freeze({
	-- DailyConfig: títulos dos desafios (exibidos com Lang.t no controller)
	["Jogue 3 partidas"] = "Play 3 matches",
	["Derrube 60 blocos"] = "Destroy 60 blocks",
	["Derrube 3 jogadores"] = "Knock out 3 players",
	["Fique no Top 3 em 2 partidas"] = "Place in Top 3 in 2 matches",
	["Fuja do Barão"] = "Escape the Baron",
	["Descubra uma passagem secreta"] = "Discover a secret passage",
	["Vença uma partida"] = "Win a match",
	["Abra o cofre do Barão"] = "Open the Baron's Vault",
	["Reconstrua 3 blocos"] = "Rebuild 3 blocks",
	["Dê a Volta por Cima"] = "Pull off a Comeback",

	-- SecretCatalog: nomes, descrições e hints das conquistas secretas
	["Passagem Oculta"] = "Hidden Passage",
	["Atravessou uma passagem antes de ela ser revelada"] = "Crossed a passage before it was revealed",
	["Nem toda parede é parede…"] = "Not every wall is a wall...",

	["Pula-Barão"] = "Baron Hopper",
	["Pulou o Barão 3 vezes na mesma partida"] = "Jumped over the Baron 3 times in one match",
	["O Barão odeia gente saltitante…"] = "The Baron hates bouncy folks...",

	["Por um Fio"] = "By a Thread",
	["Venceu com quase nada de arena de pé"] = "Won with barely any arena left standing",
	["Vencer quando quase não sobra chão…"] = "Winning when there's almost no floor left...",

	["Mestre dos Quadros"] = "Painting Master",
	["Revelou as passagens dos dois andares na mesma partida"] = "Revealed passages on both floors in one match",
	["Todos os quadros guardam algo…"] = "All paintings hide something...",

	["Puff Perdido"] = "Lost Puff",
	["Achou o Puff escondido no lobby"] = "Found the Puff hidden in the lobby",
	["Algo brilha num canto do lobby…"] = "Something sparkles in a lobby corner...",

	-- ReferralConfig: mensagem de convite com recompensa
	["Vem derrubar blocos comigo no Bloco Puff!"] = "Come destroy blocks with me in BlocoPuff!",

	-- ProgressionController: notificação de subida de nível
	["NÍVEL %d!"] = "LEVEL %d!",
	["Você subiu de nível no BlocoPuff"] = "You leveled up in BlocoPuff",

	-- PartyController: avisos de Party
	["Convite enviado para %s."] = "Invite sent to %s.",
	["%s recusou o convite."] = "%s declined the invite.",
	["Esse convite expirou."] = "That invite expired.",
	["A Party está cheia (máximo %d)."] = "Party is full (max %d).",
	["%s já está na sua Party."] = "%s is already in your Party.",
	["Esse jogador não está mais no servidor."] = "That player is no longer on the server.",
	["Espere um pouquinho para chamar de novo."] = "Wait a bit before inviting again.",
	["Espere a partida acabar para mexer na Party."] = "Wait for the match to end to manage your Party.",
	["%s entrou na Party!"] = "%s joined the Party!",
	["%s saiu da Party."] = "%s left the Party.",
	["%s foi removido da Party."] = "%s was removed from the Party.",
	["Você foi removido da Party."] = "You were removed from the Party.",
	["A Party acabou (ficou só você)."] = "Party ended (just you left).",
	["A partida lotou para a sua Party: vocês entram juntos na próxima!"] = "The match is full for your Party: you'll join together next time!",

	-- ChallengesController: notificações de desafios e secrets
	["RETORNO DIÁRIO · DIA %d"] = "DAILY RETURN · DAY %d",
	["+%d 🎟 para a Puff Machine"] = "+%d 🎟 for the Puff Machine",
	["DESAFIO CONCLUÍDO!"] = "CHALLENGE COMPLETE!",
	["%s · +%d 🎟"] = "%s · +%d 🎟",
	["CONQUISTA SECRETA!"] = "SECRET ACHIEVEMENT!",

	-- LeaderboardView: carregamento e atualização do ranking
	["Carregando ranking…"] = "Loading leaderboard...",
	["Atualizado agora"] = "Updated now",
	["Atualizado há %d min"] = "Updated %d min ago",
	["🏆 RANKING GLOBAL"] = "🏆 GLOBAL LEADERBOARD",

	-- ChallengesView: temporizador e títulos
	["Novos desafios chegando…"] = "New challenges coming...",
	["Novos desafios em %dh %02dmin"] = "New challenges in %dh %02dmin",
	["Novos desafios em %d min"] = "New challenges in %d min",
	["📋 DESAFIOS"] = "📋 CHALLENGES",
	["HOJE"] = "TODAY",
	["Dia %d\n🎟 %d"] = "Day %d\n🎟 %d",
	["Perdeu um dia? Tudo bem: a sequência continua."] = "Missed a day? No worries: your streak continues.",
	["CONQUISTAS SECRETAS"] = "SECRET ACHIEVEMENTS",

	-- PartyView: título e descrição
	["👥 PARTY"] = "👥 PARTY",
	["PARTY"] = "PARTY",
	["Até %d jogadores. Vocês entram juntos nas partidas."] = "Up to %d players. You enter matches together.",

	-- PartyInviteView: botões e mensagem de convite
	["ENTRAR"] = "JOIN",
	["AGORA NÃO"] = "NOT NOW",
	["%s te chamou para a Party!"] = "%s called you to join the Party!",

	-- ProfileCardView: botões e rótulos de estatísticas
	["PERFIL"] = "PROFILE",
	["FECHAR"] = "CLOSE",
	["NÍVEL %d%s"] = "LEVEL %d%s",
	["Partidas"] = "Matches",
	["Vitórias"] = "Wins",
	["Top 3"] = "Top 3",
	["Derrubadas"] = "Knockouts",
	["Blocos destruídos"] = "Blocks Destroyed",
	["Cofres conquistados"] = "Vaults Conquered",
	["Fugas do Barão"] = "Baron Escapes",
	["Passagens descobertas"] = "Passages Found",
	["Voltas por Cima"] = "Comebacks",
	["Vitórias contra RoboPuffs"] = "Bot Wins",

	-- InviteController: notificações de convite com recompensa
	["CONVITE INDISPONÍVEL"] = "INVITE UNAVAILABLE",
	["Sua conta não pode enviar convites agora."] = "Your account can't send invites right now.",
	["CONVIDE E GANHE"] = "INVITE & EARN",
	["por amigo novo que jogar uma partida"] = "per new friend who plays a match",
	["%d 🎟️ por amigo novo que jogar uma partida"] = "%d 🎟️ per new friend who plays a match",
	["+%d 🎟️ BOAS-VINDAS!"] = "+%d 🎟️ WELCOME!",
	["Prêmio por chegar a convite de um amigo"] = "Reward for joining a friend's invite",
	["+%d 🎟️ CONVITE!"] = "+%d 🎟️ INVITE!",
	["Um amigo seu jogou a primeira partida"] = "One of your friends played their first match",
	["%d amigos seus jogaram a primeira partida"] = "%d of your friends played their first match",

	-- ProfileCardView: interface do cartão de perfil
	["NÍVEL %d%s"] = "LEVEL %d%s",
	["NÍVEL MÁXIMO"] = "MAX LEVEL",
	["Progresso desta sessão não está sendo salvo"] = "Progress this session is not being saved",

	-- LeaderboardView: interface do ranking
	["Ranking indisponível no momento"] = "Leaderboard unavailable right now",
	["Ninguém aqui ainda. Seja o primeiro!"] = "No one here yet. Be the first!",
	["  ·  Temporadas: em breve"] = "  ·  Seasons: coming soon",

	-- ChallengesView: interface dos desafios
	["RETORNO DIÁRIO"] = "DAILY RETURN",
	["Sequência: %d %s  ·  recorde %d"] = "Streak: %d %s  ·  record %d",
	["CONQUISTAS SECRETAS  %d/%d"] = "SECRET ACHIEVEMENTS  %d/%d",

	-- PartyView: interface da Party
	["SUA PARTY"] = "YOUR PARTY",
	["CHAMAR"] = "INVITE",
	["SAIR DA PARTY"] = "LEAVE PARTY",
	["CHAMAR AMIGOS PARA O JOGO"] = "INVITE FRIENDS TO PLAY",
	["Na partida cada um joga por si: a Party só garante que vocês entrem juntos."] = "In a match everyone plays for themselves: Party only guarantees you enter together.",
	["Você ainda não está numa Party. Chame alguém ao lado!"] = "You're not in a Party yet. Invite someone on the side!",
	["SUA PARTY  %d/%d"] = "YOUR PARTY  %d/%d",
	[" (você)"] = " (you)",
	["REMOVER"] = "REMOVE",
	["Ninguém para chamar agora. Chame amigos para o jogo!"] = "No one to invite right now. Invite friends to play!",
	["Convites de amigos não estão disponíveis agora."] = "Friend invites are not available right now.",

	-- LeaderboardTypes: categorias de ranking
	["VITÓRIAS"] = "WINS",
	["DERRUBADAS"] = "KNOCKOUTS",
	["BLOCOS DESTRUÍDOS"] = "BLOCKS DESTROYED",
	["COFRES CONQUISTADOS"] = "VAULTS CONQUERED",

	-- PuffdexController: notificação de novo Puff
	["NOVO PUFF!"] = "NEW PUFF!",
	["%s · veja no Puffdex"] = "%s · check it out in Puffdex",

	-- HallOfFameService: placas do Hall da Fama
	["Seja o primeiro!"] = "Be the first!",
	["Ranking indisponível"] = "Leaderboard unavailable",
	["👑 LENDA DO BLOCOPUFF"] = "👑 BLOCPUFF LEGEND",
	["Ranking da temporada: em breve"] = "Seasonal ranking: coming soon",
	["Ainda sem lenda"] = "No legend yet",
	["Vença partidas para entrar aqui"] = "Win matches to get here",
	["%s vitórias"] = "%s wins",
	["dia"] = "day",
	["dias"] = "days",
})
