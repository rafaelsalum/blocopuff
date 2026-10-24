--!strict

-- Inglês dos textos do mundo do Casarão: placas das salas, notificações do
-- Barão, Cofre, Tocas Seguras, passagens secretas e traps (chave: o texto em
-- português do código).

return table.freeze({
	-- Placas das salas do Casarão
	["✨ SALÃO DA COLEÇÃO"] = "✨ COLLECTION HALL",
	["🕰️ TORRE DO RELÓGIO"] = "🕰️ CLOCK TOWER",
	["👥 PONTO DE ENCONTRO"] = "👥 MEETING POINT",
	["🐶 JARDIM DO BARÃO"] = "🐶 BARON'S GARDEN",
	["🏠 SALÃO PRINCIPAL"] = "🏠 GRAND HALL",
	["📚 BIBLIOTECA"] = "📚 LIBRARY",
	["🪜 ESCADARIA"] = "🪜 STAIRCASE",
	["🏆 SALA DOS TROFÉUS"] = "🏆 TROPHY ROOM",
	["🔒 CHAVE DE LATÃO"] = "🔒 BRASS KEY",
	["🔒 NÍVEL 10"] = "🔒 LEVEL 10",
	["PORTA TRANCADA"] = "LOCKED DOOR",
	["Trancada · a Chave de Latão está escondida na Biblioteca"] = "Locked · the Brass Key is hidden in the Library",
	["Sala dos Troféus · abre a partir do nível 10"] = "Trophy Room · opens from level 10",
	["🗺️ MAPA DO CASARÃO"] = "🗺️ MANSION MAP",
	["Explorado: %d%% (%d/%d)"] = "Explored: %d%% (%d/%d)",
	["🟡 Você   🔵 Party"] = "🟡 You   🔵 Party",
	["Térreo"] = "Ground floor",
	["Salão Principal"] = "Grand Hall",
	["Salão da Coleção"] = "Collection Hall",
	["Jardim do Barão"] = "Baron's Garden",
	["Ponto de Encontro"] = "Meeting Point",
	["Treino"] = "Training",
	["Biblioteca"] = "Library",
	["Escadaria"] = "Staircase",
	["Sala de Música"] = "Music Room",
	["Sala dos Troféus"] = "Trophy Room",
	["Gabinete do Vovô Puff"] = "Grandpa Puff's Study",
	["Sótão"] = "Attic",
	["Porão"] = "Cellar",
	["Sala do Tesouro"] = "Treasure Room",
	["Explorador"] = "Explorer",
	["Conheceu todos os cômodos do Casarão"] = "Visited every room in the Mansion",
	["Quem conhece cada canto do Casarão?…"] = "Who knows every corner of the Mansion?…",
	["🎹 SALA DE MÚSICA"] = "🎹 MUSIC ROOM",
	["🎯 TREINO"] = "🎯 TRAINING",
	-- Placas da Ala do Assassinato (MurderMansionDecor)
	["🍷 SALA DE JANTAR"] = "🍷 DINING ROOM",
	["🍳 COZINHA"] = "🍳 KITCHEN",
	["💃 SALÃO DE BAILE"] = "💃 BALLROOM",
	["🚪 HALL DE ENTRADA"] = "🚪 ENTRANCE HALL",
	["☕ SALA DE ESTAR"] = "☕ LIVING ROOM",
	["🌙 QUARTO DO BARÃO"] = "🌙 BARON'S BEDROOM",
	["👑 CORREDOR DOS RETRATOS"] = "👑 PORTRAIT HALL",
	["🧳 QUARTO DE HÓSPEDES"] = "🧳 GUEST ROOM",
	["🎲 SALA DE JOGOS"] = "🎲 GAME ROOM",
	["🌿 ESTUFA"] = "🌿 GREENHOUSE",

	-- Passagens secretas
	["PASSAGEM SECRETA!"] = "SECRET PASSAGE!",
	["Você revelou as passagens %s"] = "You revealed the secret passages %s",
	["%s revelou as passagens %s"] = "%s revealed the secret passages %s",
	["NÃO ERA ESSE QUADRO"] = "WRONG PAINTING",
	["Algum quadro %s esconde um segredo…"] = "Some painting %s hides a secret…",
	["no andar de baixo"] = "on the lower floor",
	["no andar de cima"] = "on the upper floor",
	["na mansão"] = "in the mansion",

	-- Cofre do Barão - eventos gerais
	["O BARÃO ACORDOU!"] = "THE BARON WOKE UP!",
	["E o cofre destrancou: porta dourada no andar de baixo"] = "And the vault unlocked: golden door on the lower floor",
	["VOCÊ ABRIU O COFRE!"] = "YOU OPENED THE VAULT!",
	["Pegue o Puffador do Cofre no pedestal. O Barão ficou bravo!"] = "Get the Vault Puffador on the pedestal. The Baron is angry!",
	["COFRE ABERTO!"] = "VAULT OPEN!",
	["%s abriu o cofre. O Barão ficou bravo!"] = "%s opened the vault. The Baron is angry!",
	["COFRE CONQUISTADO!"] = "VAULT CONQUERED!",
	["Puffador do Cofre: 2 blocos por Puff. Q, Y ou 🧱 troca para Construir"] = "Vault Puffador: 2 blocks per Puff. Q, Y or 🧱 switches to Build",
	["%s pegou o Puffador do Cofre. Derrube-o!"] = "%s got the Vault Puffador. Knock them out!",
	["TRANCADA"] = "LOCKED",
	["O cofre está atrás de outra porta!"] = "The vault is behind another door!",
	["O cofre abre quando o Barão acordar…"] = "The vault opens when the Baron wakes up…",
	["SAIA DO COFRE!"] = "LEAVE THE VAULT!",
	["O Barão vai te expulsar em %d s"] = "The Baron will kick you out in %d s",
	["EXPULSO DO COFRE!"] = "EXPELLED FROM VAULT!",
	["Seu tempo no cofre acabou nesta rodada"] = "Your time in the vault ended this round",
	["PUFFADOR DO COFRE ESGOTADO"] = "VAULT PUFFADOR DEPLETED",
	["Seu Puffador voltou ao normal"] = "Your Puffador returned to normal",

	-- Tocas Seguras
	["TOCA SEGURA"] = "SAFE BURROW",
	["O Barão não te pega aqui por %d s"] = "The Baron can't get you here for %d s",
	["SAIA DA TOCA"] = "LEAVE THE BURROW",
	["A proteção acaba em %d s"] = "Protection ends in %d s",
	["TEMPO ESGOTADO NA TOCA"] = "TIME'S UP IN THE BURROW",
	["Tocas bloqueadas para você por %d s"] = "Burrows locked for you for %d s",

	-- Barão - contato e perseguição
	["AU AU!"] = "WOOF WOOF!",
	["O Barão te expulsou do corredor"] = "The Baron pushed you out of the corridor",

	-- Corredores secretos - mensagens gerais
	["Alguém"] = "Someone",

	-- Corredores do Barão
	["TÚNEL DO BARÃO"] = "BARON'S TUNNEL",
	["🐾 TERRITÓRIO DO BARÃO"] = "🐾 BARON'S TERRITORY",

	-- Casarão - placa principal
	["CASARÃO PUFF"] = "PUFF MANSION",
	["Explore as salas enquanto a partida não começa"] = "Explore the rooms while the match hasn't started",

	-- Treino
	["Passe da faixa verde e pratique a mira"] = "Cross the green line and practice your aim",

	-- Puffador do Cofre - tooltip
	["Puffador do Cofre"] = "Vault Puffador",
	["Porta misteriosa"] = "Mysterious door",
	["Pegar"] = "Grab",
	["ATCHIM!"] = "ACHOO!",
})
