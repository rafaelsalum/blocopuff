# Graph Report - blocopuff  (2026-09-28)

## Corpus Check
- 139 files · ~127,649 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1101 nodes · 1897 edges · 99 communities (90 shown, 9 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 327 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9a988b25`
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
- TelemetryService.lobbyEvent
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
- DailyRules.luau
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
- onRequest
- LevelCurve.luau
- AdminController.luau
- ProfileSchema.luau
- SecretPassageController.luau
- PlayerDataService.luau
- RewardRules.rollMachine
- onRequest
- PartyService.luau
- CrosshairView.new
- ReactionController.luau

## God Nodes (most connected - your core abstractions)
1. `BlocoPuff — Game Design Document` - 36 edges
2. `Estado atual` - 25 edges
3. `BuildingDecor.createPart()` - 23 edges
4. `PuffdexView.new()` - 22 edges
5. `UiTheme.addCorner()` - 21 edges
6. `UiTheme.addTextOutline()` - 17 edges
7. `UiTheme.createLabel()` - 17 edges
8. `PuffMachineView.new()` - 16 edges
9. `UiTheme.stylePanel()` - 16 edges
10. `NotificationManager.notify()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `banner()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/VaultController.luau → src/client/notifications/NotificationManager.luau
- `SecretPassageController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/SecretPassageController.luau → src/client/notifications/NotificationManager.luau
- `PuffMachineController.start()` --calls--> `PuffdexController.markNew()`  [INFERRED]
  src/client/controllers/PuffMachineController.luau → src/client/controllers/PuffdexController.luau
- `refreshDay()` --calls--> `DailyRules.claimDaily()`  [INFERRED]
  src/server/services/PlayerDataService.luau → src/server/data/DailyRules.luau
- `ProfileSchema.fromStored()` --calls--> `DailyRules.readChallenges()`  [INFERRED]
  src/server/data/ProfileSchema.luau → src/server/data/DailyRules.luau

## Import Cycles
- None detected.

## Communities (99 total, 9 thin omitted)

### Community 0 - "ProfileController.luau"
Cohesion: 0.09
Nodes (23): asNumber(), LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward() (+15 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.08
Nodes (34): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound(), buildPuffadorTool(), consumeSuperCharge() (+26 more)

### Community 2 - "RoundService.luau"
Cohesion: 0.09
Nodes (37): buildMarkers(), createSign(), isCompeting(), livingRoot(), MatchQueueService.count(), MatchQueueService.refresh(), MatchQueueService.setOpen(), MatchQueueService.start() (+29 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.33
Nodes (8): getActiveParticipantList(), getHumanoid(), isActiveParticipant(), isPartyMate(), readBooleanAttribute(), readNumberAttribute(), resetCameraToOwnCharacter(), targetLabel()

### Community 4 - "ArenaService.luau"
Cohesion: 0.06
Nodes (40): cellKey(), ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getIntactBlocks(), ArenaService.getModel() (+32 more)

### Community 5 - "PuffadorController.luau"
Cohesion: 0.12
Nodes (30): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+22 more)

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
Nodes (53): PuffadorController.start(), AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), BannerView.new() (+45 more)

### Community 17 - "Estado atual"
Cohesion: 0.04
Nodes (45): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+37 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "LeaderboardService.luau"
Cohesion: 0.16
Nodes (15): announce(), playLevelUp(), ProgressionController.start(), DataStoreErrors.isStudioAccessDenied(), emptyBoards(), flushAll(), flushUser(), handleFailure() (+7 more)

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.09
Nodes (41): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+33 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.15
Nodes (24): approach(), bark(), beginChase(), emit(), endChase(), getRoot(), goToSleep(), isActiveParticipant() (+16 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.09
Nodes (44): buildLights(), buildLockers(), buildPaneling(), buildPedestal(), buildShell(), buildVaultDisk(), decor(), SecretRoomBuilder.build() (+36 more)

### Community 31 - "TelemetryService.lobbyEvent"
Cohesion: 0.19
Nodes (13): parseNewPuffs(), grantPuffs(), ProjectileService.spawn(), equip(), onRequest(), throttled(), TelemetryService.lobbyEvent(), PuffCatalog.all() (+5 more)

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

### Community 53 - "DailyRules.luau"
Cohesion: 0.21
Nodes (11): DailyRules.applyRound(), DailyRules.assign(), DailyRules.claimDaily(), DailyRules.dayIndex(), DailyRules.emptyDaily(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readChallenges() (+3 more)

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
Cohesion: 0.12
Nodes (15): closeVisit(), PuffMomentService.record(), elapsed(), getCounters(), getDevice(), getFloor(), getZone(), log() (+7 more)

### Community 61 - "LobbyStationsService.luau"
Cohesion: 0.13
Nodes (28): BaraoModel.build(), part(), createSolid(), destroyOwnedChild(), doorHole(), getDoorHoles(), getPassageGaps(), getPassageHoles() (+20 more)

### Community 62 - "BaraoTensionController.luau"
Cohesion: 0.53
Nodes (5): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch()

### Community 67 - "HudController.luau"
Cohesion: 0.21
Nodes (10): clearAnnouncement(), connectAttribute(), getPersonalScoreSummary(), getQueueMessage(), HudController.start(), render(), renderCountdown(), renderEnding() (+2 more)

### Community 68 - "MansionService.luau"
Cohesion: 0.28
Nodes (14): archSize(), box(), createCeiling(), createPartitions(), createPlaque(), createRug(), createShell(), createStatue() (+6 more)

### Community 69 - "RoundHudView.new"
Cohesion: 0.47
Nodes (4): HudView.new(), createAnimationGroup(), createTextLabel(), RoundHudView.new()

### Community 72 - "NotificationManager.notify"
Cohesion: 0.16
Nodes (17): BaraoController.start(), onFeedback(), seconds(), showAnnouncement(), MatchQueueController.start(), onMessage(), finishCurrent(), insertSorted() (+9 more)

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

### Community 81 - "onRequest"
Cohesion: 0.60
Nodes (5): isCompeting(), onRequest(), PuffMachineService.start(), pull(), readRequestId()

### Community 82 - "LevelCurve.luau"
Cohesion: 0.60
Nodes (5): LevelCurve.levelForXp(), LevelCurve.maxXp(), LevelCurve.progress(), LevelCurve.totalXpForLevel(), LevelCurve.xpForNextLevel()

### Community 83 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 86 - "ProfileSchema.luau"
Cohesion: 0.29
Nodes (11): cleanNumber(), ProfileSchema.clampDelta(), ProfileSchema.default(), ProfileSchema.emptyStats(), ProfileSchema.fromStored(), ProfileSchema.storedSession(), readAppliedRounds(), readSecrets() (+3 more)

### Community 89 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 90 - "PlayerDataService.luau"
Cohesion: 0.39
Nodes (7): ProfileSchema.toStored(), addTickets(), now(), progressChallenges(), refreshDay(), save(), tryLoad()

### Community 91 - "RewardRules.rollMachine"
Cohesion: 0.70
Nodes (4): isEpicOrBetter(), RewardRules.rollMachine(), RewardRules.ticketsForRound(), rollRarity()

### Community 92 - "onRequest"
Cohesion: 0.70
Nodes (4): isCompeting(), onRequest(), ReactionService.start(), throttled()

### Community 93 - "PartyService.luau"
Cohesion: 0.47
Nodes (3): broadcast(), sendState(), stateOf()

### Community 95 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

## Knowledge Gaps
- **175 isolated node(s):** `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)`, `Pré-requisitos`, `Instalação inicial no macOS` (+170 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PuffCatalog.get()` connect `TelemetryService.lobbyEvent` to `ProfileController.luau`, `PuffdexView.new`, `PuffdexController.luau`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Why does `PuffdexView.new()` connect `PuffdexView.new` to `TelemetryService.lobbyEvent`, `PuffdexController.luau`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Why does `TelemetryService.lobbyEvent()` connect `TelemetryService.lobbyEvent` to `ProfileController.luau`, `PuffadorService.luau`, `TelemetryService.luau`, `onRequest`, `PlayerDataService.luau`, `onRequest`, `LobbyStationsService.luau`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Are the 12 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `PuffdexView.new()` (e.g. with `PuffdexController.start()` and `ResponsiveScale.attach()`) actually correct?**
  _`PuffdexView.new()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminPanelView.new()` and `createSection()`) actually correct?**
  _`UiTheme.addCorner()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)` to the rest of the system?**
  _175 weakly-connected nodes found - possible documentation gaps or missing edges._