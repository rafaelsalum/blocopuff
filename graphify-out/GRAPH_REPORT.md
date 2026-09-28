# Graph Report - blocopuff  (2026-09-27)

## Corpus Check
- 129 files · ~116,528 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1039 nodes · 1834 edges · 101 communities (90 shown, 11 thin omitted)
- Extraction: 80% EXTRACTED · 20% INFERRED · 0% AMBIGUOUS · INFERRED: 360 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d1935ef3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ProfileController.luau
- PuffadorService.luau
- ArenaService.luau
- SpectatorController.luau
- HudController.luau
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
- BuildingService.luau
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
- KnockbackService.luau
- KnockbackController.luau
- RoundStatsService.luau
- TelemetryController.luau
- PhotoModeService.luau
- TocaService.luau
- TelemetryService.luau
- BaraoModel.luau
- BaraoTensionController.luau
- PuffdexController.luau
- DailyRules.luau
- ProgressionController.start
- RoundService.luau
- EliminationService.luau
- NotificationManager.notify
- beginRound
- FinalChaosService.luau
- NotificationManager.init
- celebrate
- VaultController.luau
- AdminController.luau
- SecretPassageController.luau
- XpCalculator.compute
- RoundResultBuilder.build
- PlayerDataService.applyRound
- TelemetryService.lobbyEvent
- PlayerDataService.luau
- PuffCatalog.luau
- TelemetryService.event
- PartyService.luau
- LevelCurve.luau
- onRequest
- setState
- ReactionController.luau

## God Nodes (most connected - your core abstractions)
1. `BlocoPuff — Game Design Document` - 36 edges
2. `PuffdexView.new()` - 22 edges
3. `UiTheme.addCorner()` - 22 edges
4. `BuildingDecor.createPart()` - 22 edges
5. `Estado atual` - 22 edges
6. `beginRound()` - 19 edges
7. `UiTheme.addTextOutline()` - 18 edges
8. `UiTheme.stylePanel()` - 17 edges
9. `UiTheme.createLabel()` - 17 edges
10. `PlayerDataService.applyRound()` - 17 edges

## Surprising Connections (you probably didn't know these)
- `showAnnouncement()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/HudController.luau → src/client/notifications/NotificationManager.luau
- `SecretPassageController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/SecretPassageController.luau → src/client/notifications/NotificationManager.luau
- `banner()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/VaultController.luau → src/client/notifications/NotificationManager.luau
- `ProfileSchema.default()` --calls--> `DailyRules.emptyDaily()`  [INFERRED]
  src/server/data/ProfileSchema.luau → src/server/data/DailyRules.luau
- `ProfileSchema.fromStored()` --calls--> `DailyRules.readChallenges()`  [INFERRED]
  src/server/data/ProfileSchema.luau → src/server/data/DailyRules.luau

## Import Cycles
- None detected.

## Communities (101 total, 11 thin omitted)

### Community 0 - "ProfileController.luau"
Cohesion: 0.10
Nodes (22): asNumber(), LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward() (+14 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.10
Nodes (25): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound(), buildPuffadorTool(), consumeSuperCharge() (+17 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.10
Nodes (30): cellKey(), ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getIntactBlocks(), ArenaService.getNeighborBlock() (+22 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.33
Nodes (8): getActiveParticipantList(), getHumanoid(), isActiveParticipant(), isPartyMate(), readBooleanAttribute(), readNumberAttribute(), resetCameraToOwnCharacter(), targetLabel()

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (5): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting(), showAnnouncement()

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
Cohesion: 0.20
Nodes (20): assignActiveSpawn(), createSpawn(), destroyOwnedChild(), getActiveSpawn(), getGallerySlots(), getHorizontalDistance(), getLivingRoot(), getOccupiedPositions() (+12 more)

### Community 9 - "PuffdexView.new"
Cohesion: 0.07
Nodes (58): AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), getTopY(), BannerView.new() (+50 more)

### Community 17 - "Estado atual"
Cohesion: 0.04
Nodes (42): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+34 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "LeaderboardService.luau"
Cohesion: 0.22
Nodes (11): DataStoreErrors.isStudioAccessDenied(), emptyBoards(), flushAll(), flushUser(), handleFailure(), LeaderboardService.start(), readBoard(), refresh() (+3 more)

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.10
Nodes (38): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+30 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.15
Nodes (24): approach(), bark(), beginChase(), emit(), endChase(), getRoot(), goToSleep(), isActiveParticipant() (+16 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.09
Nodes (44): buildLights(), buildLockers(), buildPaneling(), buildPedestal(), buildShell(), buildVaultDisk(), decor(), SecretRoomBuilder.build() (+36 more)

### Community 31 - "BuildingService.luau"
Cohesion: 0.29
Nodes (7): along(), createBox(), createSolid(), destroyOwnedChild(), doorHole(), getDoorHoles(), isOwned()

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

### Community 53 - "KnockbackService.luau"
Cohesion: 0.24
Nodes (11): computeVelocity(), isActiveParticipant(), KnockbackService.beginRound(), KnockbackService.endRound(), KnockbackService.forget(), KnockbackService.getRecentAttacker(), KnockbackService.start(), KnockbackService.stop() (+3 more)

### Community 54 - "KnockbackController.luau"
Cohesion: 0.52
Nodes (5): applyKnockback(), getRoot(), isFiniteVector(), onFeedback(), stopFalling()

### Community 56 - "RoundStatsService.luau"
Cohesion: 0.26
Nodes (13): publishResult(), recordComeback(), add(), empty(), RoundStatsService.baraoEscape(), RoundStatsService.blockBuilt(), RoundStatsService.comeback(), RoundStatsService.endRound() (+5 more)

### Community 58 - "PhotoModeService.luau"
Cohesion: 0.24
Nodes (16): ArenaService.getBlocks(), applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot() (+8 more)

### Community 59 - "TocaService.luau"
Cohesion: 0.29
Nodes (16): claim(), eject(), emit(), getRoot(), isActiveParticipant(), occupiedToca(), paint(), release() (+8 more)

### Community 60 - "TelemetryService.luau"
Cohesion: 0.28
Nodes (12): elapsed(), getCounters(), getDevice(), getFloor(), getZone(), log(), sampleFloors(), TelemetryService.blocksDestroyed() (+4 more)

### Community 62 - "BaraoTensionController.luau"
Cohesion: 0.53
Nodes (5): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch()

### Community 67 - "PuffdexController.luau"
Cohesion: 0.23
Nodes (8): celebrate(), PuffdexController.markNew(), PuffdexController.show(), PuffdexController.start(), send(), parseReveal(), PuffMachineController.start(), send()

### Community 68 - "DailyRules.luau"
Cohesion: 0.17
Nodes (15): DailyRules.applyRound(), DailyRules.assign(), DailyRules.claimDaily(), DailyRules.dayIndex(), DailyRules.emptyDaily(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readChallenges() (+7 more)

### Community 69 - "ProgressionController.start"
Cohesion: 0.50
Nodes (4): announce(), playLevelUp(), ProgressionController.start(), onProfile()

### Community 72 - "RoundService.luau"
Cohesion: 0.17
Nodes (17): PartySelection.select(), ArenaService.getPlayerSpawnCFrames(), KnockbackService.protect(), connectParticipantDeathHandlers(), dequeuePlayer(), eliminateParticipant(), enqueuePlayer(), getHumanoidRootPart() (+9 more)

### Community 74 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.beginRound(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 75 - "NotificationManager.notify"
Cohesion: 0.42
Nodes (8): finishCurrent(), insertSorted(), maxWait(), NotificationManager.clear(), NotificationManager.notify(), rank(), sameKey(), showNext()

### Community 76 - "beginRound"
Cohesion: 0.17
Nodes (8): PuffadorService.beginRound(), PuffMomentService.beginRound(), PuffMomentService.record(), beginRound(), clearRoundParticipants(), markParticipantAttributes(), RoundStatsService.beginRound(), SecretAchievementService.beginRound()

### Community 77 - "FinalChaosService.luau"
Cohesion: 0.32
Nodes (6): FinalChaosService.begin(), FinalChaosService.getDuration(), FinalChaosService.isRunning(), evaluateActiveParticipants(), runActive(), startFinalChaos()

### Community 78 - "NotificationManager.init"
Cohesion: 0.33
Nodes (6): BaraoController.start(), onFeedback(), seconds(), NotificationManager.init(), toAnnouncementTone(), toBannerTone()

### Community 79 - "celebrate"
Cohesion: 0.53
Nodes (4): celebrate(), ChallengesController.start(), challengeTickets(), challengeTitle()

### Community 80 - "VaultController.luau"
Cohesion: 0.40
Nodes (3): banner(), playAlarm(), playSound()

### Community 81 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 82 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 84 - "RoundResultBuilder.build"
Cohesion: 0.70
Nodes (4): pickHighlight(), readCount(), resolveTies(), RoundResultBuilder.build()

### Community 86 - "PlayerDataService.applyRound"
Cohesion: 0.24
Nodes (16): cleanNumber(), ProfileSchema.addStats(), ProfileSchema.clampDelta(), ProfileSchema.default(), ProfileSchema.emptyStats(), ProfileSchema.fromStored(), ProfileSchema.storedSession(), ProfileSchema.withAppliedRound() (+8 more)

### Community 89 - "TelemetryService.lobbyEvent"
Cohesion: 0.23
Nodes (13): parseNewPuffs(), PlayerDataService.getSnapshot(), equip(), onRequest(), throttled(), isCompeting(), onRequest(), PuffMachineService.start() (+5 more)

### Community 90 - "PlayerDataService.luau"
Cohesion: 0.24
Nodes (12): ProfileSchema.toStored(), publish(), grantPuffs(), keyFor(), load(), now(), PlayerDataService.prestige(), PlayerDataService.update() (+4 more)

### Community 91 - "PuffCatalog.luau"
Cohesion: 0.23
Nodes (9): isEpicOrBetter(), RewardRules.rollMachine(), RewardRules.ticketsForRound(), rollRarity(), ProjectileService.spawn(), PuffCatalog.machinePool(), PuffCatalog.meetsRule(), PuffCatalog.progress() (+1 more)

### Community 92 - "TelemetryService.event"
Cohesion: 0.29
Nodes (3): closeVisit(), PlayerDataService.roundStarted(), TelemetryService.event()

### Community 93 - "PartyService.luau"
Cohesion: 0.47
Nodes (3): broadcast(), sendState(), stateOf()

### Community 94 - "LevelCurve.luau"
Cohesion: 0.60
Nodes (5): LevelCurve.levelForXp(), LevelCurve.maxXp(), LevelCurve.progress(), LevelCurve.totalXpForLevel(), LevelCurve.xpForNextLevel()

### Community 95 - "onRequest"
Cohesion: 0.70
Nodes (4): isCompeting(), onRequest(), ReactionService.start(), throttled()

### Community 96 - "setState"
Cohesion: 0.67
Nodes (4): countConnectedPlayers(), runCountdown(), runWaitingForPlayers(), setState()

## Knowledge Gaps
- **172 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+167 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `beginRound()` connect `beginRound` to `setState`, `ArenaService.luau`, `RoundService.luau`, `EliminationService.luau`, `TelemetryService.luau`, `KnockbackService.luau`, `BuildingDecor.createPart`, `TocaService.luau`, `TelemetryService.event`, `VaultService.luau`?**
  _High betweenness centrality (0.159) - this node is a cross-community bridge._
- **Why does `release()` connect `TocaService.luau` to `PuffdexView.new`, `PlayerDataService.luau`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Why does `FireButtonView.new()` connect `PuffdexView.new` to `TocaService.luau`, `PuffadorController.luau`?**
  _High betweenness centrality (0.097) - this node is a cross-community bridge._
- **Are the 18 inferred relationships involving `PuffdexView.new()` (e.g. with `PuffdexController.start()` and `ResponsiveScale.attach()`) actually correct?**
  _`PuffdexView.new()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminPanelView.new()` and `createSection()`) actually correct?**
  _`UiTheme.addCorner()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Are the 11 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 11 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _172 weakly-connected nodes found - possible documentation gaps or missing edges._