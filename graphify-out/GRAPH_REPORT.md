# Graph Report - blocopuff  (2026-09-28)

## Corpus Check
- 140 files · ~128,329 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1104 nodes · 1842 edges · 101 communities (91 shown, 10 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 271 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `16dd9b2c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ProfileController.luau
- PuffadorService.luau
- RoundService.luau
- SpectatorController.luau
- ArenaService.luau
- PuffadorController.luau
- ReplicatedStateService.luau
- BlocoPuff — Game Design Document
- LobbyService.luau
- PuffdexView.new
- Estado atual
- WorldVisualService.luau
- AdminService.luau
- LeaderboardService.luau
- BlockCollapseController.luau
- BuildingDecor.createPart
- MusicController.luau
- BaraoService.luau
- Escopo
- VaultService.luau
- ProfileSchema.luau
- PuffadorModel.luau
- HallOfFameService.luau
- Escopo
- Fase 1 — Core Gameplay & UX
- Escopo
- Escopo
- 11. Barão
- 19. Rankings
- 29. LiveOps e eventos
- 31. Telemetria
- 14. UX, câmera e controles
- 20. Puffdex
- 4. Ciclo de uma partida
- 6. Puffador
- 16. Resultado da partida
- 17. Perfil, XP e nível
- 1. Visão do jogo
- 23. Desafios e retorno diário
- 3. Estrutura de servidores e partidas
- 9. Corredores secretos
- SecretPassageService.luau
- KnockbackController.luau
- RoundStatsService.luau
- TelemetryController.luau
- PhotoModeService.luau
- TocaService.luau
- TelemetryService.luau
- LobbyStationsService.luau
- BaraoTensionController.luau
- HudController.luau
- MansionService.luau
- RoundHudView.new
- NotificationManager.notify
- RoundResultBuilder.luau
- openStation
- ChallengesController.luau
- PuffdexController.luau
- VaultController.luau
- MatchQueueService.luau
- NotificationManager.init
- AdminController.luau
- ProgressionController.luau
- AdminPanelView.luau
- SecretPassageController.luau
- onFeedback
- BaraoModel.luau
- ReactionService.luau
- PartyService.luau
- ReactionController.luau

## God Nodes (most connected - your core abstractions)
1. `BlocoPuff — Game Design Document` - 36 edges
2. `Estado atual` - 26 edges
3. `PuffdexView.new()` - 22 edges
4. `BuildingDecor.createPart()` - 21 edges
5. `UiTheme.addCorner()` - 17 edges
6. `PuffMachineView.new()` - 16 edges
7. `UiTheme.addTextOutline()` - 14 edges
8. `UiTheme.stylePanel()` - 14 edges
9. `UiTheme.createLabel()` - 14 edges
10. `NotificationManager.notify()` - 13 edges

## Surprising Connections (you probably didn't know these)
- `onMessage()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/MatchQueueController.luau → src/client/notifications/NotificationManager.luau
- `banner()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/VaultController.luau → src/client/notifications/NotificationManager.luau
- `BaraoController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/BaraoController.luau → src/client/notifications/NotificationManager.luau
- `SecretPassageController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/SecretPassageController.luau → src/client/notifications/NotificationManager.luau
- `PuffMachineController.start()` --calls--> `PuffdexController.markNew()`  [INFERRED]
  src/client/controllers/PuffMachineController.luau → src/client/controllers/PuffdexController.luau

## Import Cycles
- None detected.

## Communities (101 total, 10 thin omitted)

### Community 0 - "ProfileController.luau"
Cohesion: 0.07
Nodes (35): LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward(), parsePuffs() (+27 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.06
Nodes (44): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound(), createImpactEffect(), isOwned() (+36 more)

### Community 2 - "RoundService.luau"
Cohesion: 0.10
Nodes (28): PuffMomentService.beginRound(), PuffMomentService.record(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countQueued(), creditKnockout(), dequeuePlayer() (+20 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.33
Nodes (8): getActiveParticipantList(), getHumanoid(), isActiveParticipant(), isPartyMate(), readBooleanAttribute(), readNumberAttribute(), resetCameraToOwnCharacter(), targetLabel()

### Community 4 - "ArenaService.luau"
Cohesion: 0.07
Nodes (30): cellKey(), ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getIntactBlocks(), ArenaService.getModel() (+22 more)

### Community 5 - "PuffadorController.luau"
Cohesion: 0.11
Nodes (34): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+26 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.26
Nodes (13): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setFinalChaos(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId() (+5 more)

### Community 7 - "BlocoPuff — Game Design Document"
Cohesion: 0.09
Nodes (22): 10. Tocas Seguras, 12. Segunda Chance e eliminação, 13. Espectador, 15. Momentos Puff, 18. Prestígio, 21. Coleções e Barão, 22. Puff Machine, 24. Conquistas secretas (+14 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.23
Nodes (12): assignActiveSpawn(), destroyOwnedChild(), getActiveSpawn(), getHorizontalDistance(), getLivingRoot(), getLobbySlots(), getOccupiedPositions(), isOwned() (+4 more)

### Community 9 - "PuffdexView.new"
Cohesion: 0.08
Nodes (46): AnnouncementView.new(), getToneColor(), BannerView.new(), createBanner(), getToneColor(), BuildToggleView.new(), CombatHudView.new(), createLabel() (+38 more)

### Community 17 - "Estado atual"
Cohesion: 0.04
Nodes (46): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+38 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "LeaderboardService.luau"
Cohesion: 0.23
Nodes (11): DataStoreErrors.isStudioAccessDenied(), emptyBoards(), flushAll(), flushUser(), handleFailure(), LeaderboardService.start(), publish(), readBoard() (+3 more)

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.08
Nodes (44): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+36 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.15
Nodes (24): approach(), bark(), beginChase(), emit(), endChase(), getRoot(), goToSleep(), isActiveParticipant() (+16 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.18
Nodes (22): clearHolder(), destroyPrize(), expel(), fireAll(), fireTo(), getRoot(), isActiveParticipant(), isInsideOpenVault() (+14 more)

### Community 31 - "ProfileSchema.luau"
Cohesion: 0.05
Nodes (56): parseNewPuffs(), DailyRules.applyRound(), DailyRules.assign(), DailyRules.claimDaily(), DailyRules.dayIndex(), DailyRules.emptyDaily(), DailyRules.ensureToday(), DailyRules.nextResetAt() (+48 more)

### Community 32 - "PuffadorModel.luau"
Cohesion: 0.50
Nodes (6): addPart(), buildBody(), buildGrip(), buildMuzzle(), buildTank(), tube()

### Community 33 - "HallOfFameService.luau"
Cohesion: 0.60
Nodes (4): createBoard(), createLegend(), createPlaque(), textLabel()

### Community 35 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Trading — avaliação para ativação, 11. Economia, 1. Temporadas, 2. Ranking sazonal, 3. Live Control, 4. Eventos de partida, 5. Eventos globais, 6. Eventos de calendário (+12 more)

### Community 36 - "Fase 1 — Core Gameplay & UX"
Cohesion: 0.11
Nodes (18): 1. Estrutura da rodada, 2. Arena de dois níveis, 3. Puffador real, 4. Segunda Chance, 5. Caos Final, 6. Controles e câmera, 7. HUD e Notification Manager, 8. Pós-partida básico (+10 more)

### Community 37 - "Escopo"
Cohesion: 0.11
Nodes (17): 1. Corredores secretos, 2. Quadros reveladores, 3. Tocas Seguras, 4. Barão, 5. Cofre, 6. Puffador do Cofre, 7. Alertas e áudio, 8. Momentos Puff iniciais (+9 more)

### Community 38 - "Escopo"
Cohesion: 0.11
Nodes (17): 1. Perfil persistente, 2. XP, 3. Nível BlocoPuff, 4. Prestígio, 5. Resultado avançado, 6. Ranking global, 7. Hall da Fama, 8. Proteção de integridade (+9 more)

### Community 39 - "11. Barão"
Cohesion: 0.40
Nodes (5): 11. Barão, Gameplay, Identidade, Tensão, Variações futuras

### Community 40 - "19. Rankings"
Cohesion: 0.40
Nodes (5): 19. Rankings, Hall da Fama, Ranking da partida, Ranking sazonal, Rankings globais

### Community 41 - "29. LiveOps e eventos"
Cohesion: 0.40
Nodes (5): 29. LiveOps e eventos, Eventos administrados, Eventos de calendário, Eventos globais, Presença de criadores/admins

### Community 42 - "31. Telemetria"
Cohesion: 0.40
Nodes (5): 31. Telemetria, Barão/corredores, Core gameplay, Progressão, Social

### Community 43 - "14. UX, câmera e controles"
Cohesion: 0.50
Nodes (4): 14. UX, câmera e controles, Alertas, Mira, Puffador do Cofre

### Community 44 - "20. Puffdex"
Cohesion: 0.67
Nodes (3): 20. Puffdex, Estrutura de um Puff, Raridades iniciais

### Community 45 - "4. Ciclo de uma partida"
Cohesion: 0.67
Nodes (3): 4. Ciclo de uma partida, Caos Final, Macrofluxo

### Community 46 - "6. Puffador"
Cohesion: 0.67
Nodes (3): 6. Puffador, Evolução do protótipo existente, Puffador comum

### Community 53 - "SecretPassageService.luau"
Cohesion: 0.16
Nodes (16): MatchAudience.fire(), MatchAudience.isInMatch(), MatchAudience.players(), collectPaintings(), createCover(), createGlow(), hideAll(), isActiveParticipant() (+8 more)

### Community 54 - "KnockbackController.luau"
Cohesion: 0.52
Nodes (5): applyKnockback(), getRoot(), isFiniteVector(), onFeedback(), stopFalling()

### Community 56 - "RoundStatsService.luau"
Cohesion: 0.21
Nodes (12): participantMultiplier(), XpCalculator.compute(), add(), empty(), RoundStatsService.baraoEscape(), RoundStatsService.blockBuilt(), RoundStatsService.comeback(), RoundStatsService.get() (+4 more)

### Community 58 - "PhotoModeService.luau"
Cohesion: 0.24
Nodes (16): ArenaService.getBlocks(), applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot() (+8 more)

### Community 59 - "TocaService.luau"
Cohesion: 0.14
Nodes (23): computeVelocity(), isActiveParticipant(), KnockbackService.endRound(), KnockbackService.start(), KnockbackService.stop(), onCharacterHit(), ProjectileService.setCharacterHitHandler(), claim() (+15 more)

### Community 60 - "TelemetryService.luau"
Cohesion: 0.17
Nodes (14): closeVisit(), elapsed(), getCounters(), getDevice(), getFloor(), getZone(), log(), sampleFloors() (+6 more)

### Community 61 - "LobbyStationsService.luau"
Cohesion: 0.50
Nodes (12): buildChallengeBoard(), buildFriendlyBarao(), buildMachine(), buildPartyPost(), buildPedestal(), buildPuffdexLectern(), buildShop(), buildShowcase() (+4 more)

### Community 62 - "BaraoTensionController.luau"
Cohesion: 0.53
Nodes (5): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch()

### Community 67 - "HudController.luau"
Cohesion: 0.22
Nodes (5): clearAnnouncement(), renderCountdown(), renderLobbyDuringMatch(), renderQueue(), renderWaiting()

### Community 68 - "MansionService.luau"
Cohesion: 0.28
Nodes (14): archSize(), box(), createCeiling(), createPartitions(), createPlaque(), createRug(), createShell(), createStatue() (+6 more)

### Community 69 - "RoundHudView.new"
Cohesion: 0.47
Nodes (4): HudView.new(), createAnimationGroup(), createTextLabel(), RoundHudView.new()

### Community 72 - "NotificationManager.notify"
Cohesion: 0.42
Nodes (8): finishCurrent(), insertSorted(), maxWait(), NotificationManager.clear(), NotificationManager.notify(), rank(), sameKey(), showNext()

### Community 74 - "RoundResultBuilder.luau"
Cohesion: 0.70
Nodes (4): pickHighlight(), readCount(), resolveTies(), RoundResultBuilder.build()

### Community 75 - "openStation"
Cohesion: 0.25
Nodes (8): ChallengesController.show(), LobbyStationsController.start(), openStation(), PuffdexController.show(), parseReveal(), PuffMachineController.show(), PuffMachineController.start(), send()

### Community 78 - "ChallengesController.luau"
Cohesion: 0.53
Nodes (4): celebrate(), ChallengesController.start(), challengeTickets(), challengeTitle()

### Community 79 - "PuffdexController.luau"
Cohesion: 0.40
Nodes (4): celebrate(), PuffdexController.markNew(), PuffdexController.start(), send()

### Community 80 - "VaultController.luau"
Cohesion: 0.40
Nodes (3): banner(), playAlarm(), playSound()

### Community 81 - "MatchQueueService.luau"
Cohesion: 0.27
Nodes (9): buildMarkers(), createSign(), isCompeting(), livingRoot(), MatchQueueService.refresh(), MatchQueueService.start(), onRequest(), refresh() (+1 more)

### Community 82 - "NotificationManager.init"
Cohesion: 0.29
Nodes (5): MatchQueueController.start(), onMessage(), NotificationManager.init(), toAnnouncementTone(), toBannerTone()

### Community 83 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 84 - "ProgressionController.luau"
Cohesion: 0.50
Nodes (4): announce(), playLevelUp(), ProgressionController.start(), onProfile()

### Community 86 - "AdminPanelView.luau"
Cohesion: 0.70
Nodes (4): AdminPanelView.new(), constrainText(), createSection(), createTextBox()

### Community 89 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 90 - "onFeedback"
Cohesion: 0.67
Nodes (3): BaraoController.start(), onFeedback(), seconds()

### Community 92 - "ReactionService.luau"
Cohesion: 0.52
Nodes (6): isCompeting(), isMatchActive(), isWatching(), onRequest(), ReactionService.start(), throttled()

### Community 93 - "PartyService.luau"
Cohesion: 0.47
Nodes (3): broadcast(), sendState(), stateOf()

## Knowledge Gaps
- **176 isolated node(s):** `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)`, `Pré-requisitos`, `Instalação inicial no macOS` (+171 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PuffCatalog.get()` connect `ProfileSchema.luau` to `ProfileController.luau`, `PuffdexView.new`, `PuffdexController.luau`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `TelemetryService.lobbyEvent()` connect `ProfileSchema.luau` to `ProfileController.luau`, `PuffadorService.luau`, `TelemetryService.luau`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Why does `updateProjectiles()` connect `PuffadorService.luau` to `ArenaService.luau`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Are the 18 inferred relationships involving `PuffdexView.new()` (e.g. with `PuffdexController.start()` and `ResponsiveScale.attach()`) actually correct?**
  _`PuffdexView.new()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AnnouncementView.new()` and `createBanner()`) actually correct?**
  _`UiTheme.addCorner()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)` to the rest of the system?**
  _176 weakly-connected nodes found - possible documentation gaps or missing edges._