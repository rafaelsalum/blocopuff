# Graph Report - blocopuff  (2026-09-28)

## Corpus Check
- 132 files · ~120,256 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1056 nodes · 1856 edges · 102 communities (93 shown, 9 thin omitted)
- Extraction: 81% EXTRACTED · 19% INFERRED · 0% AMBIGUOUS · INFERRED: 351 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4ac14252`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ProfileController.luau
- PuffadorService.luau
- ArenaService.luau
- SpectatorController.luau
- TelemetryService.lobbyEvent
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
- KnockbackService.luau
- ProgressionController.luau
- RoundService.luau
- EliminationService.luau
- openStation
- NotificationManager.notify
- beginRound
- trySecondChance
- NotificationManager.init
- ChallengesController.luau
- PuffdexController.luau
- VaultController.luau
- onRequest
- RoundResultBuilder.build
- ProfileSchema.luau
- LevelCurve.luau
- PlayerDataService.luau
- AdminController.luau
- SecretPassageController.luau
- PartyService.luau
- RewardRules.rollMachine
- onRequest
- runActive
- ReactionController.luau
- XpCalculator.compute

## God Nodes (most connected - your core abstractions)
1. `BlocoPuff — Game Design Document` - 36 edges
2. `Estado atual` - 23 edges
3. `PuffdexView.new()` - 22 edges
4. `UiTheme.addCorner()` - 22 edges
5. `BuildingDecor.createPart()` - 22 edges
6. `UiTheme.addTextOutline()` - 18 edges
7. `beginRound()` - 18 edges
8. `UiTheme.stylePanel()` - 17 edges
9. `UiTheme.createLabel()` - 17 edges
10. `PuffMachineView.new()` - 16 edges

## Surprising Connections (you probably didn't know these)
- `showAnnouncement()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/HudController.luau → src/client/notifications/NotificationManager.luau
- `PuffMachineController.start()` --calls--> `PuffdexController.markNew()`  [INFERRED]
  src/client/controllers/PuffMachineController.luau → src/client/controllers/PuffdexController.luau
- `SecretPassageController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/SecretPassageController.luau → src/client/notifications/NotificationManager.luau
- `banner()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/VaultController.luau → src/client/notifications/NotificationManager.luau
- `refreshDay()` --calls--> `DailyRules.claimDaily()`  [INFERRED]
  src/server/services/PlayerDataService.luau → src/server/data/DailyRules.luau

## Import Cycles
- None detected.

## Communities (102 total, 9 thin omitted)

### Community 0 - "ProfileController.luau"
Cohesion: 0.10
Nodes (23): asNumber(), LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward() (+15 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.08
Nodes (34): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound(), buildPuffadorTool(), consumeSuperCharge() (+26 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.09
Nodes (30): cellKey(), ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getIntactBlocks(), ArenaService.getNeighborBlock() (+22 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.33
Nodes (8): getActiveParticipantList(), getHumanoid(), isActiveParticipant(), isPartyMate(), readBooleanAttribute(), readNumberAttribute(), resetCameraToOwnCharacter(), targetLabel()

### Community 4 - "TelemetryService.lobbyEvent"
Cohesion: 0.19
Nodes (13): parseNewPuffs(), grantPuffs(), ProjectileService.spawn(), equip(), onRequest(), throttled(), TelemetryService.lobbyEvent(), PuffCatalog.all() (+5 more)

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
Cohesion: 0.19
Nodes (21): assignActiveSpawn(), createSpawn(), destroyOwnedChild(), getActiveSpawn(), getGallerySlots(), getHorizontalDistance(), getLivingRoot(), getOccupiedPositions() (+13 more)

### Community 9 - "PuffdexView.new"
Cohesion: 0.07
Nodes (58): AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), getTopY(), BannerView.new() (+50 more)

### Community 17 - "Estado atual"
Cohesion: 0.04
Nodes (43): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+35 more)

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

### Community 53 - "DailyRules.luau"
Cohesion: 0.21
Nodes (11): DailyRules.applyRound(), DailyRules.assign(), DailyRules.claimDaily(), DailyRules.dayIndex(), DailyRules.emptyDaily(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readChallenges() (+3 more)

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
Cohesion: 0.12
Nodes (16): closeVisit(), PuffMomentService.beginRound(), PuffMomentService.record(), elapsed(), getCounters(), getDevice(), getFloor(), getZone() (+8 more)

### Community 61 - "LobbyStationsService.luau"
Cohesion: 0.34
Nodes (13): BaraoModel.build(), part(), LobbyService.setReservedAreas(), buildChallengeBoard(), buildFriendlyBarao(), buildMachine(), buildShop(), buildShowcase() (+5 more)

### Community 62 - "BaraoTensionController.luau"
Cohesion: 0.53
Nodes (5): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch()

### Community 67 - "HudController.luau"
Cohesion: 0.24
Nodes (5): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting(), showAnnouncement()

### Community 68 - "KnockbackService.luau"
Cohesion: 0.24
Nodes (11): computeVelocity(), isActiveParticipant(), KnockbackService.beginRound(), KnockbackService.endRound(), KnockbackService.forget(), KnockbackService.getRecentAttacker(), KnockbackService.start(), KnockbackService.stop() (+3 more)

### Community 69 - "ProgressionController.luau"
Cohesion: 0.50
Nodes (4): announce(), playLevelUp(), ProgressionController.start(), onProfile()

### Community 72 - "RoundService.luau"
Cohesion: 0.23
Nodes (12): PartySelection.select(), countConnectedPlayers(), dequeuePlayer(), enqueuePlayer(), onPlayerAdded(), onPlayerRemoving(), publishQueuePositions(), resetParticipantAttributes() (+4 more)

### Community 74 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.beginRound(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 75 - "openStation"
Cohesion: 0.25
Nodes (8): ChallengesController.show(), LobbyStationsController.start(), openStation(), PuffdexController.show(), parseReveal(), PuffMachineController.show(), PuffMachineController.start(), send()

### Community 76 - "NotificationManager.notify"
Cohesion: 0.42
Nodes (8): finishCurrent(), insertSorted(), maxWait(), NotificationManager.clear(), NotificationManager.notify(), rank(), sameKey(), showNext()

### Community 77 - "beginRound"
Cohesion: 0.25
Nodes (8): ArenaService.getPlayerSpawnCFrames(), PuffadorService.beginRound(), beginRound(), clearRoundParticipants(), markParticipantAttributes(), teleportParticipantsToArena(), RoundStatsService.beginRound(), SecretAchievementService.beginRound()

### Community 78 - "trySecondChance"
Cohesion: 0.29
Nodes (8): FinalChaosService.isRunning(), KnockbackService.protect(), connectParticipantDeathHandlers(), eliminateParticipant(), getHumanoidRootPart(), moveCharacterTo(), onParticipantDied(), trySecondChance()

### Community 79 - "NotificationManager.init"
Cohesion: 0.33
Nodes (6): BaraoController.start(), onFeedback(), seconds(), NotificationManager.init(), toAnnouncementTone(), toBannerTone()

### Community 80 - "ChallengesController.luau"
Cohesion: 0.53
Nodes (4): celebrate(), ChallengesController.start(), challengeTickets(), challengeTitle()

### Community 81 - "PuffdexController.luau"
Cohesion: 0.40
Nodes (4): celebrate(), PuffdexController.markNew(), PuffdexController.start(), send()

### Community 82 - "VaultController.luau"
Cohesion: 0.40
Nodes (3): banner(), playAlarm(), playSound()

### Community 83 - "onRequest"
Cohesion: 0.60
Nodes (5): isCompeting(), onRequest(), PuffMachineService.start(), pull(), readRequestId()

### Community 84 - "RoundResultBuilder.build"
Cohesion: 0.70
Nodes (4): pickHighlight(), readCount(), resolveTies(), RoundResultBuilder.build()

### Community 86 - "ProfileSchema.luau"
Cohesion: 0.29
Nodes (11): cleanNumber(), ProfileSchema.clampDelta(), ProfileSchema.default(), ProfileSchema.emptyStats(), ProfileSchema.fromStored(), ProfileSchema.storedSession(), readAppliedRounds(), readSecrets() (+3 more)

### Community 89 - "LevelCurve.luau"
Cohesion: 0.60
Nodes (5): LevelCurve.levelForXp(), LevelCurve.maxXp(), LevelCurve.progress(), LevelCurve.totalXpForLevel(), LevelCurve.xpForNextLevel()

### Community 90 - "PlayerDataService.luau"
Cohesion: 0.39
Nodes (7): ProfileSchema.toStored(), addTickets(), now(), progressChallenges(), refreshDay(), save(), tryLoad()

### Community 91 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 92 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 93 - "PartyService.luau"
Cohesion: 0.47
Nodes (3): broadcast(), sendState(), stateOf()

### Community 94 - "RewardRules.rollMachine"
Cohesion: 0.70
Nodes (4): isEpicOrBetter(), RewardRules.rollMachine(), RewardRules.ticketsForRound(), rollRarity()

### Community 95 - "onRequest"
Cohesion: 0.70
Nodes (4): isCompeting(), onRequest(), ReactionService.start(), throttled()

### Community 96 - "runActive"
Cohesion: 0.40
Nodes (5): FinalChaosService.begin(), FinalChaosService.getDuration(), evaluateActiveParticipants(), runActive(), startFinalChaos()

### Community 101 - "XpCalculator.compute"
Cohesion: 0.67
Nodes (3): participantMultiplier(), XpCalculator.compute(), commitProfiles()

## Knowledge Gaps
- **173 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+168 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `beginRound()` connect `beginRound` to `ArenaService.luau`, `KnockbackService.luau`, `RoundService.luau`, `EliminationService.luau`, `trySecondChance`, `BuildingDecor.createPart`, `TocaService.luau`, `TelemetryService.luau`, `VaultService.luau`?**
  _High betweenness centrality (0.192) - this node is a cross-community bridge._
- **Why does `release()` connect `TocaService.luau` to `PuffdexView.new`, `PlayerDataService.luau`?**
  _High betweenness centrality (0.121) - this node is a cross-community bridge._
- **Why does `TocaService.beginRound()` connect `TocaService.luau` to `beginRound`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **Are the 18 inferred relationships involving `PuffdexView.new()` (e.g. with `PuffdexController.start()` and `ResponsiveScale.attach()`) actually correct?**
  _`PuffdexView.new()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminPanelView.new()` and `createSection()`) actually correct?**
  _`UiTheme.addCorner()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Are the 11 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 11 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _173 weakly-connected nodes found - possible documentation gaps or missing edges._