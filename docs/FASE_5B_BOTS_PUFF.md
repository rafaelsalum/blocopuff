# Fase 5B — Bots Puff: nunca jogar sozinho

**Entrega:** completar as partidas com bots (RoboPuffs) quando faltarem jogadores, para que quem chega no jogo vazio comece a jogar em segundos, sem transformar os bots em fonte de tickets e XP fáceis.
**Dependência:** Fase 5 (armadilhas) estável. Deve ficar pronta **antes** de qualquer divulgação paga ou com criadores de conteúdo.

---

## Problema

Hoje a partida só começa com `GameConfig.MinimumPlayers = 2` no mirante, e quem fica sozinho só recebe o aviso `Lonely` depois de 60 s (`QueueConfig.LonelyHintSeconds`). No lançamento, com poucos jogadores online, quem chega por anúncio ou vídeo cai num servidor vazio, espera e sai. Isso derruba a retenção e o tempo de sessão, as métricas que decidem se o Roblox recomenda o jogo.

---

## Resultado esperado

- Quem entra sozinho está jogando em até ~20 s depois de chegar ao mirante.
- Uma partida com 1 ou 2 humanos parece cheia e divertida (4 combatentes).
- O jogador sabe que são bots e não se sente enganado.
- Jogar com humanos continua **mais recompensador** do que jogar com bots.
- Quando chegam humanos suficientes, os bots somem sozinhos.

---

## Princípios

1. **Bot completa, não substitui.** Só entra para chegar no tamanho mínimo divertido. Com humanos suficientes, não há bots.
2. **Bot é visível como bot.** O visual é próprio de RoboPuff (sem avatar de jogador), com a etiqueta 🤖 no nome, no placar e no resultado. O público é infantil: não fingir que é gente.
3. **Mesmas regras do jogo.** O bot cai, usa a Segunda Chance, é empurrado, sofre armadilha e pode vencer. Não trapaceia e não enxerga nada que o jogador não veja.
4. **Bot completa a partida, mas não dá recompensa.** Jogar com bots rende menos que jogar com humanos, e nunca conta para ranking nem para as estatísticas que desbloqueiam Puffs.
5. **Primeira vitória é sagrada.** Nas primeiras partidas da vida do jogador, os bots jogam no modo fácil, para que uma criança consiga a primeira vitória cedo.
6. **Servidor decide.** O bot é um NPC do servidor (rede do servidor). O cliente só desenha.

---

## Recompensas com bots (decisão de design)

Para o jogador, ganhar um pouco é bom: a primeira vitória e um progresso visível seguram o novato. **Ganhar o mesmo que contra humanos é ruim:**
- **Economia:** a vitória rende 3 tickets e a Puff Machine custa 5. Farmar bots daria um Puff a cada duas partidas e esvaziaria a Puffdex e a monetização da Fase 6.
- **Ranking:** os rankings globais de vitórias e derrubadas viram "quem farmou mais bot".
- **Social:** se bot vale o mesmo, ninguém tem motivo para chamar amigos. A partida com humanos tem que ser a melhor.

Regras (todas em `config/BotConfig`, ajustáveis pelo playtest):

| Item | Partida só com humanos | Partida com bots |
|---|---|---|
| Multiplicador de XP (`ParticipantMultipliers`) | por nº de participantes | calculado só com **humanos**, com piso de `BotMatchMultiplier = 0.8` |
| XP por derrubada de bot | — | metade (`BotKnockoutXpFactor = 0.5`) |
| Estatística `knockouts` (perfil, ranking, Puffdex, desafio "Derrube 3") | conta | **só derrubadas de humanos** |
| Estatísticas `wins` / `top3` (perfil, ranking, Puffdex) | conta | **só com ≥ 2 humanos na partida** |
| Tickets da rodada (participação, torcida, vitória) sem outro humano | sim | até `SoloBotTicketsPerDay = 6` por dia (subir de nível fica de fora) |
| Ticket de top 3 | sim | só com ≥ 2 humanos |
| Desafio diário "Vença uma partida" | conta | conta (já tem limite diário) |
| Conquistas secretas | conta | conta só para o humano, e nunca para um bot vencedor |
| Primeiras `BeginnerMatches = 3` partidas | — | recompensa cheia + bots no modo fácil |

Uma estatística nova no perfil, `botWins`, guarda as vitórias contra bots para mostrar ao jogador ("Vitórias contra RoboPuffs"), sem misturar com `wins`. O limite diário fica em dois campos opcionais do perfil (`botTicketDay`, `botTickets`), lidos com valor padrão e por isso sem nova versão do formato. O `ProfileGuard` já preserva estatísticas desconhecidas, então um servidor antigo não apaga `botWins` durante a atualização.

---

## Escopo

### 5B.1 Identidade de combatente (refatoração, sem mudança visível)

Hoje tudo é indexado por `Player` (`RoundService`, `KnockbackService`, `RoundStatsService`, `EliminationService`, `RoundResultBuilder`, `ProjectileService`).
- Novo tipo `Combatant` em `shared/types`: `id` (UserId para humano; **negativo** para bot, nunca 0, porque `ResultsView` trata `0` como "sem vencedor"), `name`, `kind` (`Player` | `Bot`), `player: Player?`, `getCharacter()`.
- Novo módulo `CombatantRegistry` no servidor: lista os combatentes ativos da rodada, resolve `id → Combatant`, `Model → Combatant` e `getRoot()`.
- O estado da rodada (`IsRoundParticipant`, `IsEliminated`, `RoundKnockouts`...) passa a ser gravado no `Player` **ou** no `Model` do bot, pelo registro. `StateAttributeNames` não muda.
- `RoundService`: `participants`, `eliminationPositions`, `eliminationTimes`, `usedSecondChance` e `respawnGraceUntil` passam a ser indexados por `Combatant`.
- `KnockbackService` (`lastHits`, `protectedUntil`, `getRecentAttacker`), `RoundStatsService`, `EliminationService` e `RoundResultBuilder` aceitam `Combatant`.
- Os pontos que só servem para humano recebem só a lista de humanos: `PlayerDataService.roundStarted/applyRound`, `TelemetryService`, `PuffMomentService`, `SecretAchievementService`, `MatchAudience`, `remote:FireClient`.
- **Critério:** com zero bots, o jogo se comporta exatamente como antes.

### 5B.2 Corpo do RoboPuff e preenchimento da fila

- **Corpo:** rig R15 com o visual de Puff (cores/acessórios da `PuffCatalog`), `Humanoid` com `DisplayName = "🤖 RoboPuff <nome>"`, etiqueta acima da cabeça, atributo `BotId`. `SetNetworkOwner(nil)` em todas as partes. Puffador montado no modelo (só visual).
- **Nomes:** lista curta e divertida em `BotConfig` ("Biscoito", "Pipoca", "Trovão"...), sem nomes de usuários reais.
- **Quando entram (`BotFillService`):**
  - no mirante com `1 ≤ humanos < BotFill.TargetCombatants (4)`, depois de `BotFill.WaitSeconds = 12` s sem chegar ninguém, os bots "correm" para o mirante e completam até 4;
  - se chega um humano, ele ocupa a vaga de um bot (o bot sai do mirante);
  - o máximo é `BotFill.MaxBots = 3`; nunca há bots com `humanos ≥ 4`;
  - o aviso `Lonely` é substituído por "RoboPuffs chegando!" e continua sugerindo chamar um amigo.
- **Seleção:** `PartySelection` só lida com humanos. Os bots ocupam as vagas que sobraram depois da seleção.
- **Fim da rodada:** os bots são destruídos no `returnToLobby` e recriados se a próxima rodada precisar.
- **Painel do mirante:** `QueueVisuals` mostra o ícone de RoboPuff no lugar do avatar (`rbxthumb` com id negativo quebra).

### 5B.3 O bot sofre o jogo como qualquer um

- **Acerto:** `ProjectileService.notifyHit` resolve a vítima pelo `CombatantRegistry` (hoje usa `GetPlayerFromCharacter` e o bot vira parede).
- **Empurrão:** para bot, o `KnockbackService` aplica no servidor o mesmo `LinearVelocity` que o `KnockbackController` aplica no cliente (mesmos `computeVelocity`, `Duration`, `Slide`). Vale também para Barão, Toca e armadilhas.
- **Queda e eliminação:** o `EliminationService` monitora o HRP de cada combatente. A Segunda Chance teleporta o bot no servidor.
- **Armadilhas e construção:** trocar as varreduras `Players:GetPlayers()` por `CombatantRegistry.all()` em `WindowTrap`, `RugTrap` e `BuildModeService` (não construir em cima de bot).
- **Barão, Tocas e cofre:** ficam só para jogadores nesta fase, porque os bots não entram nos corredores secretos nem no cofre (ver 5B.4).
- **Espectador:** o `SpectatorController` lista também os modelos com `BotId` vivos. Com 1 humano eliminado, ele assiste os bots até o fim (e ganha o ticket de espectador).
- **Resultado:** `ResultsView` mostra o ícone de RoboPuff e a etiqueta 🤖 para id negativo.

### 5B.4 Cérebro do RoboPuff

Laço no servidor a cada `BotBrain.TickSeconds = 0.2`, no máximo 3 bots.
- **Andar:** escolhe um bloco inteiro de destino (API nova no `ArenaService`: `isBlockIntact(cell)` e `neighbors(cell)`) e vai até ele com `Humanoid:MoveTo`. Antes de cada passo, confere se o bloco à frente existe e pula buracos de 1 bloco.
- **Fugir:** evita os blocos com aviso de queda (Caos Final, janela), a área de aviso das armadilhas e o Barão quando ele está acordado.
- **Atirar:** escolhe um alvo visível (raycast) entre os combatentes próximos, espera um tempo de reação e erra a mira por um ângulo que depende do nível. Prefere atirar no chão embaixo do alvo, como uma criança faria. Usa o cooldown do Puffador × `BotBrain.FireCooldownFactor` (mais lento que o humano).
- **Disparo:** novo `PuffadorService.fireAsBot(bot, origin, direction)`, que chama `ProjectileService.spawn` com o dono `Combatant`. O `ArenaService.tryDestroyBlock` aceita dono bot. O `PuffShotRenderer` ignora o modelo do próprio bot pelo `BotId`.
- **Armadilhas:** a partir do nível Normal, atira de vez em quando numa armadilha pronta se houver alguém na área.
- **Fora do escopo:** cofre, passagens secretas e construção, que ficam para depois do playtest.
- **Níveis (`BotConfig.Levels`):**
  - **Facinho:** reação 0,9 s, erro de 14°, anda devagar e às vezes fica parado;
  - **Normal:** reação 0,5 s, erro de 8°;
  - **Esperto:** reação 0,3 s, erro de 4°, desvia de avisos.
- **Escolha do nível:** nas primeiras `BeginnerMatches` partidas, todos Facinho. Depois, pelo nível do jogador humano de maior XP: até o nível 5, Facinho/Normal; depois, Normal/Esperto. Sempre misturado, para a partida não ficar uniforme.

### 5B.5 Recompensas e anti-farm

- `XpCalculator.compute` recebe `humanCount`, `botCount` e `botKnockouts`, e aplica a tabela de recompensas acima.
- `commitProfiles` filtra o delta do perfil: `knockouts` só de humanos; `wins` e `top3` só com ≥ 2 humanos; `botWins` + contador diário de vitórias com bots no perfil (`ProfileSchema`, campos opcionais).
- `PlayerDataService`: numa partida sem outro humano, os tickets da rodada respeitam `SoloBotTicketsPerDay`.
- `DailyRules`: o desafio "Derrube 3 jogadores" usa só derrubadas de humanos.
- `LeaderboardService` e Puffdex não mudam: leem as estatísticas já filtradas.

### 5B.6 Telemetria

- `RoundStarted` e `RoundFinished` ganham o contexto `Bots{n}` e `Humans{n}`, para separar a retenção e a taxa de vitória das partidas com bots.
- Eventos novos: `BotFillStarted` (tempo esperando sozinho), `BotReplacedByHuman`, `BotMatchFinished` (posição do humano).
- Nenhum `LogCustomEvent` é chamado com bot.

---

## Testes automatizados (Lune)

Módulos puros, com testes antes da implementação:
- `BotFillRules`: quantos bots para N humanos, saída quando chega humano, limite máximo.
- `BotRewardRules`: multiplicador, XP por derrubada de bot, filtro de estatísticas, limite diário de tickets.
- `BotLevelRules`: escolha de nível por partidas jogadas e nível do jogador.
- `RoundResultBuilder` com ids negativos (vencedor bot, empate entre humano e bot).

---

## Critérios de aceite

- [ ] Com zero bots, nada muda no comportamento nem no perfil (5B.1).
- [ ] Um jogador sozinho no mirante começa a partida em até ~20 s.
- [ ] Os bots saem quando chega gente, sem ficar bot com 4 ou mais humanos.
- [ ] Os bots são claramente bots em todos os lugares (nome, placar, resultado, painel).
- [ ] O bot é empurrado, cai, usa a Segunda Chance e sofre armadilhas.
- [ ] O tiro do bot quebra blocos, empurra e dá crédito de derrubada.
- [ ] Derrubar bot não conta para ranking, Puffdex nem para o desafio "Derrube 3 jogadores".
- [ ] Vitória sem outro humano não conta em `wins`, e os tickets dessas partidas respeitam o limite diário.
- [ ] O novato vence pelo menos uma das 3 primeiras partidas na maioria dos testes.
- [ ] O espectador consegue assistir os bots.
- [ ] Servidor estável com 3 bots + Caos Final + armadilhas, inclusive em celular.

---

## Testes manuais prioritários

1. Entrar sozinho e cronometrar até a partida começar.
2. Segundo humano chegando durante a contagem com bots.
3. Bot vencendo: resultado, placar e conquistas (ninguém ganha "Por um Fio").
4. Empate entre humano e bot.
5. Bot sendo empurrado para fora, usando a Segunda Chance e caindo de novo.
6. Bot em cima do tapete puxado e na frente da janela.
7. Construção (BuildMode) perto de um bot.
8. Humano eliminado assistindo os bots.
9. Várias partidas só com bots no mesmo dia: os tickets param em 6 (fora os de subir de nível).
10. Perfil e ranking depois de 5 partidas com bots.

---

## Perguntas do playtest

- as crianças percebem que são bots? Se importam?
- o modo Facinho é fácil demais (sem graça) ou ainda desafia?
- quem jogou com bots volta e chama amigos?
- os bots parecem "burros" de um jeito engraçado ou frustrante?
- a recompensa menor com bots é percebida como injusta?

---

## Gate para a divulgação

Avançar para anúncios e criadores quando a retenção D1 das partidas com bots estiver perto da retenção das partidas só com humanos e nenhum jogador ficar esperando mais de 30 s no mirante.
