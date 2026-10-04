--!strict

-- Inglês dos textos da coleção de Puffs (Puffdex, Puff Machine, estações do lobby).
-- Chave: o texto em português do código.

return table.freeze({
	-- Raridades (PuffCatalog.luau)
	["Comum"] = "Common",
	["Raro"] = "Rare",
	["Épico"] = "Epic",
	["Lendário"] = "Legendary",

	-- Nomes de Puffs (PuffCatalog.luau)
	["Puff Branco"] = "White Puff",
	["Puff Algodão Doce"] = "Cotton Candy Puff",
	["Puff Menta"] = "Mint Puff",
	["Puff Pêssego"] = "Peach Puff",
	["Puff Gelo"] = "Ice Puff",
	["Puff Elétrico"] = "Electric Puff",
	["Puff Tijolinho"] = "Brick Puff",
	["Puff Sussurro"] = "Whisper Puff",
	["Puff Brasil"] = "Brazil Puff",
	["Puff Galáxia"] = "Galaxy Puff",
	["Puff Cofre"] = "Vault Puff",
	["Puff Barão"] = "Baron Puff",
	["Puff Dourado"] = "Golden Puff",
	["Puff Fênix"] = "Phoenix Puff",
	["Puff Chiclete"] = "Gum Puff",
	["Puff Limão"] = "Lemon Puff",
	["Puff Nuvem"] = "Cloud Puff",
	["Puff Oceano"] = "Ocean Puff",
	["Puff Arco-Íris"] = "Rainbow Puff",
	["Puff Neon"] = "Neon Puff",
	["Puff Aurora"] = "Aurora Puff",
	["Puff Cometa"] = "Comet Puff",

	-- Dicas de desbloqueio (hints) (PuffCatalog.luau)
	["Todo mundo começa com ele"] = "Everyone starts with it",
	["Chegue ao nível 3"] = "Reach level 3",
	["Jogue 5 partidas"] = "Play 5 matches",
	["Derrube 150 blocos"] = "Destroy 150 blocks",
	["Chegue ao nível 10"] = "Reach level 10",
	["Derrube 15 jogadores"] = "Knock out 15 players",
	["Reconstrua 10 blocos com o Puffador do Cofre"] = "Rebuild 10 blocks with Vault Puffador",
	["Descubra 3 passagens secretas"] = "Discover 3 secret passages",
	["Fique no Top 3 em 20 partidas"] = "Top 3 in 20 matches",
	["Chegue ao nível 25"] = "Reach level 25",
	["Conquiste o prêmio do cofre 3 vezes"] = "Conquer vault reward 3 times",
	["Fuja do Barão 25 vezes"] = "Escape the Baron 25 times",
	["Vença 25 partidas"] = "Win 25 matches",
	["Dê a Volta por Cima 10 vezes"] = "Make a Comeback 10 times",
	["Sai na Puff Machine"] = "Comes from Puff Machine",

	-- Histórias (lore) (PuffCatalog.luau)
	["O primeiro sopro de todo Puffador."] = "The first breath of every Puffador.",
	["Doce, fofinho e cheio de brilho."] = "Sweet, fluffy, and full of sparkle.",
	["Refresca até o Barão."] = "Refreshes even the Baron.",
	["Cheirinho de fruta no ar."] = "Fruity scent in the air.",
	["Deixa um rastro de neve por onde passa."] = "Leaves a snow trail wherever it goes.",
	["Nunca vai em linha reta."] = "Never goes in a straight line.",
	["Nasceu da poeira do cofre."] = "Born from vault dust.",
	["Passa girando, bem de mansinho."] = "Spins gently as it passes.",
	["Cada disparo é uma festa."] = "Every shot is a party.",
	["Carrega um pedacinho do céu."] = "Carries a piece of the sky.",
	["Brilha como moeda nova."] = "Shines like a new coin.",
	["O Barão aprovou. Com muito cuidado."] = "The Baron approved. Very carefully.",
	["Só para quem vence de verdade."] = "Only for true winners.",
	["Sempre volta, mais forte."] = "Always comes back, stronger.",
	["Estoura bolhas no caminho."] = "Pops bubbles along the way.",
	["Azedinho e cheio de energia."] = "Tangy and full of energy.",
	["Leve como um travesseiro."] = "Light as a pillow.",
	["Trouxe o mar para a arena."] = "Brought the sea to the arena.",
	["Todas as cores de uma vez."] = "All colors at once.",
	["Pisca mais que letreiro."] = "Blinks more than a sign.",
	["Dança como luz no céu do polo."] = "Dances like light in the polar sky.",
	["Risca a arena de ponta a ponta."] = "Streaks across the arena end to end.",

	-- PuffdexView.luau
	["✨ PUFFDEX"] = "✨ PUFFDEX",
	["NOVO"] = "NEW",
	["EQUIPAR"] = "EQUIP",
	["BLOQUEADO"] = "LOCKED",
	["EQUIPADO"] = "EQUIPPED",
	["???"] = "???",
	["Um Puff misterioso…"] = "A mysterious Puff…",
	["Puffs só mudam o visual do disparo. Não dão vantagem."] = "Puffs only change shot visuals. No gameplay advantage.",
	["⏳ Carregando sua coleção…\nSeus Puffs estão guardados."] = "⏳ Loading your collection…\nYour Puffs are safe.",

	-- Origin labels (PuffdexView.luau)
	["Inicial"] = "Starter",
	["Nível"] = "Level",
	["Façanha"] = "Feat",

	-- PuffMachineView.luau
	["🎰 PUFF MACHINE"] = "🎰 PUFF MACHINE",
	["Gire para ganhar um Puff!"] = "Spin to get a Puff!",
	["GIRAR  ·  %d 🎟"] = "SPIN  ·  %d 🎟",
	["VER NO PUFFDEX"] = "VIEW IN PUFFDEX",
	["CHANCES"] = "ODDS",
	["Repetido devolve %d 🎟.\nTickets saem jogando: partida, Top 3, vitória e subir de nível."] = "Duplicate returns %d 🎟.\nTickets come from: match, Top 3, win, and level up.",
	["Sem compras: tickets só saem jogando. Puffs não dão vantagem."] = "No purchases: tickets come from playing. Puffs don't give advantage.",
	["GIRANDO…"] = "SPINNING…",
	["FALTAM %d 🎟"] = "NEED %d 🎟",
	["O próximo giro é Épico ou melhor!"] = "Next spin is Epic or better!",
	["Épico ou melhor garantido em até %d giros"] = "Epic or better guaranteed in up to %d spins",
	["A máquina engasgou. Tente de novo!"] = "The machine got stuck. Try again!",
	["%s · repetido, +%d 🎟"] = "%s · duplicate, +%d 🎟",
	["%s · NOVO!"] = "%s · NEW!",

	-- LobbyStationsService.luau (Puff Machine sign)
	["Tickets viram Puffs"] = "Tickets become Puffs",
	["Girar"] = "Spin",

	-- LobbyStationsService.luau (Baron sign)
	["🐶 BARÃO"] = "🐶 BARON",
	["Aqui ele é bonzinho"] = "He's nice here",
	["Fazer carinho"] = "Pet",

	-- LobbyStationsService.luau (Puffdex lectern sign)
	["Colecione Puffs jogando"] = "Collect Puffs by playing",
	["Abrir"] = "Open",

	-- LobbyStationsService.luau (Challenges board sign)
	["Novos todo dia"] = "New every day",
	["Ver"] = "View",

	-- PuffMachineView.luau (extra states)
	["Girando…"] = "Spinning…",

	-- LobbyStationsService.luau (Showcase Puff labels)
	["{icon} {name} · {rarity}"] = "{icon} {name} · {rarity}",

	-- PuffdexView.luau (Origin labels alt text)
	["Puff Machine"] = "Puff Machine",

	-- PuffdexView.luau (Warning message)
	["⚠ Esta sessão não está salvando o progresso."] = "⚠ This session is not saving progress.",

	-- PuffMachineController.luau (Error messages)
	["Tickets insuficientes. Jogue mais partidas!"] = "Not enough tickets. Play more matches!",
	["Seu progresso não está sendo salvo agora. Tente mais tarde."] = "Your progress is not being saved right now. Try again later.",
	["Carregando seu perfil…"] = "Loading your profile…",
	["A máquina funciona só no lobby."] = "The machine only works in the lobby.",
	["A máquina está vazia agora."] = "The machine is empty right now.",
	["Calma! A máquina está recarregando."] = "Hold on! The machine is reloading.",
	["A máquina ainda está ligando…"] = "The machine is still booting up…",

	-- LobbyStationsService.luau (Prompts)
	["Girar"] = "Spin",
	["Fazer carinho"] = "Pet",
	["Ver"] = "View",
	["Espiar"] = "Peek",
	["Puffdex"] = "Puffdex",
	["Desafios"] = "Challenges",
	["Loja"] = "Shop",
	["Party"] = "Party",
	["Barão"] = "Baron",

	-- LobbyStationsController.luau (Shop sign)
	["LOJA EM BREVE"] = "SHOP COMING SOON",
	["Ainda não tem nada à venda. Puffs saem jogando!"] = "Nothing for sale yet. Puffs come from playing!",

	-- Estações do lobby (loja e Party)
	["🛍 LOJA"] = "🛍 SHOP",
	["Em breve"] = "Coming soon",
	["Chame amigos para jogar juntos"] = "Invite friends to play together",

	-- Aviso de Puff novo
	["%s · %s — veja no Puffdex"] = "%s · %s — check it in the Puffdex",

	-- Efeitos do disparo (PuffEffects)
	["Sopro"] = "Puff",
	["Brilhos"] = "Sparkles",
	["Bolhas"] = "Bubbles",
	["Nuvenzinha"] = "Little Cloud",
	["Neve"] = "Snow",
	["Raio"] = "Lightning",
	["Espiral"] = "Spiral",
	["Confete"] = "Confetti",
	["Chamas"] = "Flames",
	["Arco-íris"] = "Rainbow",
	["%s · desde %s"] = "%s · since %s",
})
