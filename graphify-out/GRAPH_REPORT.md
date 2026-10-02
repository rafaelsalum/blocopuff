# Graph Report - blocopuff  (2026-10-02)

## Corpus Check
- 176 files · ~1,095,972 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1379 nodes · 2369 edges · 112 communities (102 shown, 10 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 352 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `37a1b344`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PuffShotRenderer.luau
- PuffadorService.luau
- ArenaService.luau
- SpectatorController.luau
- SecretPassageService.luau
- PuffadorController.luau
- ReplicatedStateService.luau
- BlocoPuff — Game Design Document
- LobbyService.luau
- UiTheme.addCorner
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
- TocaService.luau
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
- PlayerDataService.luau
- KnockbackController.luau
- Part
- ProfileGuard.luau
- PhotoModeService.luau
- MatchQueueService.luau
- v002/source/build_model.py
- ProfileController.luau
- BaraoTensionController.luau
- HudController.luau
- NotificationManager.notify
- ChallengesController.luau
- VaultController.luau
- AdminController.luau
- openStation
- BlocoPuff!
- Instruções para agentes
- TelemetryService.luau
- Toolchain local
- MatchQueueController.luau
- RoundService.luau
- SecretPassageController.luau
- Barão v002
- BaraoVisualController.luau
- PuffdexView.new
- Recuperação de perfil
- PartyService.luau
- inspect_model.py
- render_preview.py
- ReactionController.luau
- Fase 5 — Partida Viva: o Casarão reage
- LobbyStationsService.luau
- RoundStatsService.luau
- ProgressionController.luau
- 5. Arena
- TrapVisualController.luau
- CorridorBuilder.luau
- RoundResultBuilder.luau
- CrosshairView.new

## God Nodes (most connected - your core abstractions)
1. `BlocoPuff — Game Design Document` - 36 edges
2. `Estado atual` - 33 edges
3. `BuildingDecor.createPart()` - 28 edges
4. `UiTheme.addCorner()` - 22 edges
5. `UiTheme.addTextOutline()` - 17 edges
6. `UiTheme.createLabel()` - 17 edges
7. `PuffMachineView.new()` - 16 edges
8. `UiTheme.stylePanel()` - 16 edges
9. `NotificationManager.notify()` - 14 edges
10. `AdminPanelView.new()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `PuffdexView.new()` --calls--> `date()`  [INFERRED]
  src/client/ui/PuffdexView.luau → tools/profile-recovery/recovery.luau
- `showAnnouncement()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/HudController.luau → src/client/notifications/NotificationManager.luau
- `SecretPassageController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/SecretPassageController.luau → src/client/notifications/NotificationManager.luau
- `banner()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/VaultController.luau → src/client/notifications/NotificationManager.luau
- `grant()` --calls--> `ProfileSchema.withTickets()`  [INFERRED]
  src/server/services/SecretAchievementService.luau → src/server/data/ProfileSchema.luau

## Import Cycles
- None detected.

## Communities (112 total, 10 thin omitted)

### Community 0 - "PuffShotRenderer.luau"
Cohesion: 0.11
Nodes (33): isVector3(), onFired(), onMessage(), PuffShotController.start(), takePending(), acquireVisual(), buildBurst(), buildVisual() (+25 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.06
Nodes (45): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound(), broadcast(), isOwned() (+37 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.07
Nodes (30): cellKey(), ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getIntactBlocks(), ArenaService.getModel() (+22 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.33
Nodes (8): getActiveParticipantList(), getHumanoid(), isActiveParticipant(), isPartyMate(), readBooleanAttribute(), readNumberAttribute(), resetCameraToOwnCharacter(), targetLabel()

### Community 4 - "SecretPassageService.luau"
Cohesion: 0.12
Nodes (25): ProjectileService.setSurfaceHitHandler(), collectPaintings(), hideAll(), isActiveParticipant(), onSurfaceHit(), playSound(), reveal(), SecretPassageService.beginRound() (+17 more)

### Community 5 - "PuffadorController.luau"
Cohesion: 0.11
Nodes (32): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+24 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.26
Nodes (13): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setFinalChaos(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId() (+5 more)

### Community 7 - "BlocoPuff — Game Design Document"
Cohesion: 0.09
Nodes (21): 10. Tocas Seguras, 12. Segunda Chance e eliminação, 13. Espectador, 15. Momentos Puff, 18. Prestígio, 21. Coleções e Barão, 22. Puff Machine, 24. Conquistas secretas (+13 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.23
Nodes (12): assignActiveSpawn(), destroyOwnedChild(), getActiveSpawn(), getHorizontalDistance(), getLivingRoot(), getLobbySlots(), getOccupiedPositions(), isOwned() (+4 more)

### Community 9 - "UiTheme.addCorner"
Cohesion: 0.07
Nodes (55): PuffadorController.start(), AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), BannerView.new() (+47 more)

### Community 17 - "Estado atual"
Cohesion: 0.06
Nodes (33): Alertas, Momentos Puff e telemetria dos segredos (Fase 2, entrega 2.4), Armadilhas do Casarão e Janela Ventania (Fase 5, entregas 5.1 e 5.2), Artes da loja, Barão e Tocas Seguras (Fase 2, entrega 2.2), Barão maior, animado e com túnel entre os corredores (Fase 4, ajuste pós-4.5), Controles e mira (Fase 1, entrega 1.5), Corredores secretos e quadros (Fase 2, entrega 2.1), Desafios, retorno diário e conquistas secretas (Fase 4, entrega 4.3) (+25 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "LeaderboardService.luau"
Cohesion: 0.25
Nodes (10): DataStoreErrors.isStudioAccessDenied(), emptyBoards(), flushAll(), flushUser(), handleFailure(), LeaderboardService.start(), publish(), readBoard() (+2 more)

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.08
Nodes (49): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+41 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.16
Nodes (24): approach(), bark(), beginChase(), emit(), endChase(), getRoot(), goToSleep(), isActiveParticipant() (+16 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.09
Nodes (44): buildLights(), buildLockers(), buildPaneling(), buildPedestal(), buildShell(), buildVaultDisk(), decor(), SecretRoomBuilder.build() (+36 more)

### Community 31 - "TocaService.luau"
Cohesion: 0.08
Nodes (42): DailyRules.assign(), DailyRules.dayIndex(), DailyRules.emptyDaily(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readChallenges(), DailyRules.readDaily(), readCount() (+34 more)

### Community 32 - "PuffadorModel.luau"
Cohesion: 0.50
Nodes (6): addPart(), buildBody(), buildGrip(), buildMuzzle(), buildTank(), tube()

### Community 33 - "HallOfFameService.luau"
Cohesion: 0.60
Nodes (4): createBoard(), createLegend(), createPlaque(), textLabel()

### Community 35 - "Escopo"
Cohesion: 0.09
Nodes (21): 10. Trading — avaliação para ativação, 11. Economia, 1. Temporadas, 2. Ranking sazonal, 3. Live Control, 4. Eventos de partida, 5. Eventos globais, 6. Eventos de calendário (+13 more)

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

### Community 53 - "PlayerDataService.luau"
Cohesion: 0.20
Nodes (10): addTickets(), grantPuffs(), isNewerFormat(), normalize(), now(), progressChallenges(), rebuild(), refreshDay() (+2 more)

### Community 54 - "KnockbackController.luau"
Cohesion: 0.52
Nodes (5): applyKnockback(), getRoot(), isFiniteVector(), onFeedback(), stopFalling()

### Community 56 - "Part"
Cohesion: 0.31
Nodes (4): make_parts(), Part, Deterministic, editable Barão mesh source. Uses existing NumPy and Pillow only., uv()

### Community 57 - "ProfileGuard.luau"
Cohesion: 0.36
Nodes (7): isTable(), mergePuffs(), mergeStats(), number(), numberOr(), profile(), puff()

### Community 58 - "PhotoModeService.luau"
Cohesion: 0.24
Nodes (16): ArenaService.getBlocks(), applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot() (+8 more)

### Community 59 - "MatchQueueService.luau"
Cohesion: 0.11
Nodes (33): isCompeting(), livingRoot(), MatchQueueService.isBoardingOpen(), MatchQueueService.isInZone(), MatchQueueService.refresh(), MatchQueueService.setCountdown(), MatchQueueService.setWarmupLine(), MatchQueueService.start() (+25 more)

### Community 60 - "v002/source/build_model.py"
Cohesion: 0.15
Nodes (15): parts(), Barão v002: shaped ears, fitted jersey, expressive muzzle and continuous paws., rotation_z(), export_glb(), tangents(), normalize(), Part, Small surface builders for the editable Barão model (Y up, forward -Z). (+7 more)

### Community 61 - "ProfileController.luau"
Cohesion: 0.05
Nodes (50): asNumber(), LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward() (+42 more)

### Community 62 - "BaraoTensionController.luau"
Cohesion: 0.53
Nodes (5): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch()

### Community 67 - "HudController.luau"
Cohesion: 0.22
Nodes (6): clearAnnouncement(), renderCountdown(), renderLobbyDuringMatch(), renderQueue(), renderWaiting(), showAnnouncement()

### Community 68 - "NotificationManager.notify"
Cohesion: 0.23
Nodes (14): BaraoController.start(), onFeedback(), seconds(), finishCurrent(), insertSorted(), maxWait(), NotificationManager.clear(), NotificationManager.init() (+6 more)

### Community 69 - "ChallengesController.luau"
Cohesion: 0.53
Nodes (4): celebrate(), ChallengesController.start(), challengeTickets(), challengeTitle()

### Community 72 - "VaultController.luau"
Cohesion: 0.40
Nodes (3): banner(), playAlarm(), playSound()

### Community 74 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 75 - "openStation"
Cohesion: 0.17
Nodes (11): ChallengesController.show(), LobbyStationsController.start(), openStation(), PuffdexController.markNew(), PuffdexController.show(), PuffdexController.start(), send(), parseReveal() (+3 more)

### Community 78 - "BlocoPuff!"
Cohesion: 0.25
Nodes (8): BlocoPuff!, Build local, Estrutura, Grafo de conhecimento (graphify), Plugin do Rojo no Roblox Studio, Pré-requisitos, Sincronização com o Roblox Studio, Stack

### Community 79 - "Instruções para agentes"
Cohesion: 0.18
Nodes (8): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify

### Community 80 - "TelemetryService.luau"
Cohesion: 0.10
Nodes (18): closeVisit(), MatchAudience.fire(), MatchAudience.isInMatch(), MatchAudience.players(), PuffMomentService.record(), elapsed(), getCounters(), getDevice() (+10 more)

### Community 81 - "Toolchain local"
Cohesion: 0.50
Nodes (4): Atualização futura, Configuração do PATH por shell, Instalação inicial no macOS, Toolchain local

### Community 82 - "MatchQueueController.luau"
Cohesion: 0.44
Nodes (7): banner(), connectTrampoline(), MatchQueueController.start(), onMessage(), playSound(), watchCountdown(), watchQueue()

### Community 83 - "RoundService.luau"
Cohesion: 0.06
Nodes (54): computeVelocity(), isActiveParticipant(), KnockbackService.beginRound(), KnockbackService.endRound(), KnockbackService.forget(), KnockbackService.getRecentAttacker(), KnockbackService.isActiveParticipant(), KnockbackService.markAttacker() (+46 more)

### Community 84 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 86 - "Barão v002"
Cohesion: 0.12
Nodes (13): Modelos 3D do Barão, Revisões, Arquivos, Barão v001, Conferência da ficha, Etapa no Studio, Reprodução e validação, Barão v002 (+5 more)

### Community 89 - "BaraoVisualController.luau"
Cohesion: 0.11
Nodes (27): addArena(), addFriendly(), cameraPosition(), celebratePet(), characterRoot(), chaseLook(), compose(), counter() (+19 more)

### Community 90 - "PuffdexView.new"
Cohesion: 0.33
Nodes (7): createOrb(), formatDate(), paintOrb(), PuffdexView.new(), combine(), date(), newer()

### Community 92 - "Recuperação de perfil"
Cohesion: 0.40
Nodes (4): Antes de começar, Recuperação de perfil, Restaurar, Ver o perfil (não muda nada)

### Community 93 - "PartyService.luau"
Cohesion: 0.47
Nodes (3): broadcast(), sendState(), stateOf()

### Community 95 - "render_preview.py"
Cohesion: 0.29
Nodes (6): Read the exported GLB, check delivery constraints and render its actual geometry, basis_for(), raster(), Offline previews of exported mesh data with shadow maps and PBR texture inputs., Renderer, unit()

### Community 101 - "Fase 5 — Partida Viva: o Casarão reage"
Cohesion: 0.11
Nodes (18): 5.1 Base das armadilhas, 5.2 Janela Ventania (andar de cima), 5.3 Tapete Puxado (andar de baixo), 5.4 Lustre Despencando (andar de baixo), 5.5 Lareira de Fuligem (andar de baixo), 5.6 Variações das janelas: Pombos e Chuva, 5.7 Caos Final: Tempestade, 5.8 Momentos Puff, conquistas, telemetria e ajuste (+10 more)

### Community 102 - "LobbyStationsService.luau"
Cohesion: 0.50
Nodes (12): buildChallengeBoard(), buildFriendlyBarao(), buildMachine(), buildPartyPost(), buildPedestal(), buildPuffdexLectern(), buildShop(), buildShowcase() (+4 more)

### Community 103 - "RoundStatsService.luau"
Cohesion: 0.21
Nodes (12): participantMultiplier(), XpCalculator.compute(), add(), empty(), RoundStatsService.baraoEscape(), RoundStatsService.blockBuilt(), RoundStatsService.comeback(), RoundStatsService.get() (+4 more)

### Community 104 - "ProgressionController.luau"
Cohesion: 0.50
Nodes (4): announce(), playLevelUp(), ProgressionController.start(), onProfile()

### Community 106 - "TrapVisualController.luau"
Cohesion: 0.31
Nodes (8): getEffectsFolder(), step(), track(), TrapVisualController.start(), untrack(), newEmitter(), newSound(), WindowTrapFx.new()

### Community 107 - "CorridorBuilder.luau"
Cohesion: 0.51
Nodes (9): addLamp(), buildBaraoDoor(), buildOuterWall(), buildTerritory(), buildToca(), CorridorBuilder.build(), decor(), solid() (+1 more)

### Community 108 - "RoundResultBuilder.luau"
Cohesion: 0.70
Nodes (4): pickHighlight(), readCount(), resolveTies(), RoundResultBuilder.build()

### Community 109 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

## Knowledge Gaps
- **212 isolated node(s):** `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)`, `Pré-requisitos`, `Instalação inicial no macOS` (+207 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TelemetryService.lobbyEvent()` connect `ProfileController.luau` to `TelemetryService.luau`, `PuffadorService.luau`, `MatchQueueService.luau`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Why does `grant()` connect `ProfileController.luau` to `TocaService.luau`?**
  _High betweenness centrality (0.092) - this node is a cross-community bridge._
- **Why does `PuffCatalog.get()` connect `ProfileController.luau` to `PuffShotRenderer.luau`, `UiTheme.addCorner`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Are the 17 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminPanelView.new()` and `createSection()`) actually correct?**
  _`UiTheme.addCorner()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Are the 16 inferred relationships involving `UiTheme.addTextOutline()` (e.g. with `AdminPanelView.new()` and `createSection()`) actually correct?**
  _`UiTheme.addTextOutline()` has 16 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)` to the rest of the system?**
  _212 weakly-connected nodes found - possible documentation gaps or missing edges._