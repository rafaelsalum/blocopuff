# Graph Report - blocopuff  (2026-10-03)

## Corpus Check
- 211 files · ~1,123,725 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1633 nodes · 2827 edges · 139 communities (127 shown, 12 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 434 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3ffd6716`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PuffShotRenderer.luau
- ProjectileService.luau
- EliminationService.luau
- SpectatorController.luau
- PhotoModeService.luau
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
- PlayerDataService.luau
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
- TocaService.luau
- CharacterImpulse.luau
- Part
- ProfileGuard.luau
- WindowTrap.luau
- BotBrainService.luau
- v002/source/build_model.py
- ProfileController.luau
- BotBody.luau
- HudController.luau
- NotificationManager.notify
- ChallengesController.luau
- VaultController.luau
- AdminController.luau
- openStation
- BlocoPuff!
- Instruções para agentes
- TelemetryService.luau
- OnboardingRules.luau
- MatchQueueController.luau
- ArenaService.luau
- SecretPassageController.luau
- Barão v002
- BaraoVisualController.luau
- CombatantRegistry.luau
- Recuperação de perfil
- PartyService.luau
- inspect_model.py
- render_preview.py
- ReactionController.luau
- Fase 5 — Partida Viva: o Casarão reage
- LobbyStationsService.luau
- RoundStatsService.luau
- RoundService.luau
- 5. Arena
- RugTrapFx.new
- KnockbackService.luau
- RoundResultBuilder.build
- Fase 5B — Bots Puff: nunca jogar sozinho
- FinalChaosService.luau
- InviteController.luau
- CorridorBuilder.luau
- ProfileSchema.luau
- TelemetryController.luau
- ReferralService.luau
- BotFillRules.luau
- LevelCurve.luau
- MatchQueueService.luau
- DailyRules.luau
- grant
- ReferralRules.luau
- ReactionService.luau
- onRequest
- PuffMomentService.luau
- onRequestBuild
- TelemetryService.lobbyEvent
- DashService.luau
- BuildTargeting.luau

## God Nodes (most connected - your core abstractions)
1. `Estado atual` - 39 edges
2. `BlocoPuff — Game Design Document` - 36 edges
3. `BuildingDecor.createPart()` - 28 edges
4. `PuffdexView.new()` - 26 edges
5. `UiTheme.addCorner()` - 21 edges
6. `TelemetryService.lobbyEvent()` - 20 edges
7. `PuffMachineView.new()` - 16 edges
8. `UiTheme.addTextOutline()` - 16 edges
9. `UiTheme.createLabel()` - 16 edges
10. `ResponsiveScale.attach()` - 15 edges

## Surprising Connections (you probably didn't know these)
- `PuffdexView.new()` --calls--> `date()`  [INFERRED]
  src/client/ui/PuffdexView.luau → tools/profile-recovery/recovery.luau
- `fullFloor()` --calls--> `BotGrid.key()`  [INFERRED]
  tests/BotGrid.spec.luau → src/server/data/BotGrid.luau
- `destroyBot()` --calls--> `DashService.forgetBot()`  [INFERRED]
  src/server/services/BotFillService.luau → src/server/services/DashService.luau
- `onRequestBuild()` --calls--> `PuffadorService.isHoldingPuffador()`  [INFERRED]
  src/server/services/BuildModeService.luau → src/server/services/PuffadorService.luau
- `openStation()` --calls--> `ChallengesController.show()`  [INFERRED]
  src/client/controllers/LobbyStationsController.luau → src/client/controllers/ChallengesController.luau

## Import Cycles
- None detected.

## Communities (139 total, 12 thin omitted)

### Community 0 - "PuffShotRenderer.luau"
Cohesion: 0.10
Nodes (36): isVector3(), onFired(), onMessage(), PuffShotController.predict(), PuffShotController.start(), takePending(), acquireVisual(), buildBurst() (+28 more)

### Community 1 - "ProjectileService.luau"
Cohesion: 0.35
Nodes (10): broadcast(), isOwned(), notifyHit(), ProjectileService.clearAll(), ProjectileService.clearFor(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop() (+2 more)

### Community 2 - "EliminationService.luau"
Cohesion: 0.36
Nodes (7): ArenaService.getModel(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop(), isOwned()

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (14): connectContainerAttribute(), cycleTarget(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute(), readNumberAttribute() (+6 more)

### Community 4 - "PhotoModeService.luau"
Cohesion: 0.11
Nodes (28): BotGrid.cellOf(), BotGrid.center(), BotGrid.chooseGoal(), BotGrid.isInside(), BotGrid.isPathClear(), BotGrid.key(), BotGrid.safety(), ArenaService.getBlocks() (+20 more)

### Community 5 - "PuffadorController.luau"
Cohesion: 0.11
Nodes (35): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+27 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.26
Nodes (13): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setFinalChaos(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId() (+5 more)

### Community 7 - "BlocoPuff — Game Design Document"
Cohesion: 0.09
Nodes (21): 10. Tocas Seguras, 12. Segunda Chance e eliminação, 13. Espectador, 15. Momentos Puff, 18. Prestígio, 21. Coleções e Barão, 22. Puff Machine, 24. Conquistas secretas (+13 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.23
Nodes (12): assignActiveSpawn(), destroyOwnedChild(), getActiveSpawn(), getHorizontalDistance(), getLivingRoot(), getLobbySlots(), getOccupiedPositions(), isOwned() (+4 more)

### Community 9 - "PuffdexView.new"
Cohesion: 0.06
Nodes (57): AnnouncementView.new(), getToneColor(), BannerView.new(), createBanner(), getToneColor(), BuildToggleView.new(), CombatHudView.new(), createLabel() (+49 more)

### Community 17 - "Estado atual"
Cohesion: 0.05
Nodes (39): Alertas, Momentos Puff e telemetria dos segredos (Fase 2, entrega 2.4), Armadilhas do Casarão e Janela Ventania (Fase 5, entregas 5.1 e 5.2), Artes da loja, Barão e Tocas Seguras (Fase 2, entrega 2.2), Barão maior, animado e com túnel entre os corredores (Fase 4, ajuste pós-4.5), Bots RoboPuff (Fase 5B), Comandos de teste da partida (painel admin), Controles e mira (Fase 1, entrega 1.5) (+31 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "LeaderboardService.luau"
Cohesion: 0.23
Nodes (10): DataStoreErrors.isStudioAccessDenied(), emptyBoards(), flushAll(), flushUser(), handleFailure(), LeaderboardService.start(), publish(), readBoard() (+2 more)

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.06
Nodes (65): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+57 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.16
Nodes (24): approach(), bark(), beginChase(), emit(), endChase(), getRoot(), goToSleep(), isActiveParticipant() (+16 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.09
Nodes (37): buildPuffadorTool(), consumeSuperCharge(), grantToolToPlayer(), isFiniteNumber(), isFiniteVector3(), isOwned(), PuffadorService.consumeBuildCharge(), PuffadorService.endRound() (+29 more)

### Community 31 - "PlayerDataService.luau"
Cohesion: 0.21
Nodes (11): ProfileSchema.toStored(), addTickets(), isNewerFormat(), normalize(), now(), progressChallenges(), rebuild(), refreshDay() (+3 more)

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

### Community 53 - "TocaService.luau"
Cohesion: 0.29
Nodes (16): claim(), eject(), emit(), getRoot(), isActiveParticipant(), occupiedToca(), paint(), release() (+8 more)

### Community 54 - "CharacterImpulse.luau"
Cohesion: 0.11
Nodes (26): aliveCharacter(), DashController.dash(), DashController.start(), dashDirection(), applyKnockback(), applySlide(), getRoot(), isFiniteVector() (+18 more)

### Community 56 - "Part"
Cohesion: 0.31
Nodes (4): make_parts(), Part, Deterministic, editable Barão mesh source. Uses existing NumPy and Pillow only., uv()

### Community 57 - "ProfileGuard.luau"
Cohesion: 0.36
Nodes (7): isTable(), mergePuffs(), mergeStats(), number(), numberOr(), profile(), puff()

### Community 58 - "WindowTrap.luau"
Cohesion: 0.27
Nodes (14): boards(), dropBlocks(), frameOf(), gustAt(), isStandingOn(), looseBlocks(), pushPlayers(), setBoarded() (+6 more)

### Community 59 - "BotBrainService.luau"
Cohesion: 0.25
Nodes (15): activeCombatants(), aimPoint(), aliveRoot(), BotBrainService.beginRound(), BotBrainService.endRound(), canSee(), dashPathSafe(), humanInfo() (+7 more)

### Community 60 - "v002/source/build_model.py"
Cohesion: 0.15
Nodes (15): parts(), Barão v002: shaped ears, fitted jersey, expressive muzzle and continuous paws., rotation_z(), export_glb(), tangents(), normalize(), Part, Small surface builders for the editable Barão model (Y up, forward -Z). (+7 more)

### Community 61 - "ProfileController.luau"
Cohesion: 0.08
Nodes (26): asNumber(), LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward() (+18 more)

### Community 62 - "BotBody.luau"
Cohesion: 0.52
Nodes (6): addAntenna(), animate(), BotBody.build(), describe(), dress(), giveServerPhysics()

### Community 67 - "HudController.luau"
Cohesion: 0.24
Nodes (5): clearAnnouncement(), renderCountdown(), renderLobbyDuringMatch(), renderQueue(), renderWaiting()

### Community 68 - "NotificationManager.notify"
Cohesion: 0.21
Nodes (15): BaraoController.start(), onFeedback(), seconds(), showAnnouncement(), finishCurrent(), insertSorted(), maxWait(), NotificationManager.clear() (+7 more)

### Community 69 - "ChallengesController.luau"
Cohesion: 0.43
Nodes (5): celebrate(), ChallengesController.show(), ChallengesController.start(), challengeTickets(), challengeTitle()

### Community 72 - "VaultController.luau"
Cohesion: 0.40
Nodes (3): banner(), playAlarm(), playSound()

### Community 74 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 75 - "openStation"
Cohesion: 0.17
Nodes (11): LobbyStationsController.start(), openStation(), celebrate(), PuffdexController.markNew(), PuffdexController.show(), PuffdexController.start(), send(), parseReveal() (+3 more)

### Community 78 - "BlocoPuff!"
Cohesion: 0.17
Nodes (12): Atualização futura, BlocoPuff!, Build local, Configuração do PATH por shell, Estrutura, Grafo de conhecimento (graphify), Instalação inicial no macOS, Plugin do Rojo no Roblox Studio (+4 more)

### Community 79 - "Instruções para agentes"
Cohesion: 0.18
Nodes (8): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify

### Community 80 - "TelemetryService.luau"
Cohesion: 0.19
Nodes (18): closeVisit(), elapsed(), getCounters(), getDevice(), getFloor(), getZone(), log(), logTickets() (+10 more)

### Community 81 - "OnboardingRules.luau"
Cohesion: 0.17
Nodes (9): bitOf(), OnboardingRules.has(), OnboardingRules.initial(), OnboardingRules.mark(), OnboardingRules.stepsFromProfile(), mark(), OnboardingService.start(), onProfile() (+1 more)

### Community 82 - "MatchQueueController.luau"
Cohesion: 0.44
Nodes (7): banner(), connectTrampoline(), MatchQueueController.start(), onMessage(), playSound(), watchCountdown(), watchQueue()

### Community 83 - "ArenaService.luau"
Cohesion: 0.17
Nodes (17): ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getNeighborBlock(), ArenaService.getSafeRespawnCFrame(), ArenaService.tryDestroyBlock() (+9 more)

### Community 84 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 86 - "Barão v002"
Cohesion: 0.12
Nodes (13): Modelos 3D do Barão, Revisões, Arquivos, Barão v001, Conferência da ficha, Etapa no Studio, Reprodução e validação, Barão v002 (+5 more)

### Community 89 - "BaraoVisualController.luau"
Cohesion: 0.12
Nodes (25): addArena(), addFriendly(), cameraPosition(), celebratePet(), characterRoot(), chaseLook(), compose(), counter() (+17 more)

### Community 90 - "CombatantRegistry.luau"
Cohesion: 0.17
Nodes (15): attributeHolder(), CombatantRegistry.all(), CombatantRegistry.forPlayer(), CombatantRegistry.forPlayers(), CombatantRegistry.fromCharacter(), CombatantRegistry.getAttribute(), CombatantRegistry.getBots(), CombatantRegistry.getCharacter() (+7 more)

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
Cohesion: 0.16
Nodes (25): createSolid(), destroyOwnedChild(), doorHole(), getDoorHoles(), getPassageGaps(), getPassageHoles(), isOwned(), buildChallengeBoard() (+17 more)

### Community 103 - "RoundStatsService.luau"
Cohesion: 0.20
Nodes (13): participantMultiplier(), XpCalculator.compute(), add(), empty(), RoundStatsService.baraoEscape(), RoundStatsService.blockBuilt(), RoundStatsService.botKnockout(), RoundStatsService.comeback() (+5 more)

### Community 104 - "RoundService.luau"
Cohesion: 0.05
Nodes (63): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch(), AdminPanelView.new(), constrainText(), createSection() (+55 more)

### Community 106 - "RugTrapFx.new"
Cohesion: 0.24
Nodes (11): getEffectsFolder(), step(), track(), TrapVisualController.start(), untrack(), RugTrapFx.new(), TrapFxUtil.newAnchor(), TrapFxUtil.newEmitter() (+3 more)

### Community 107 - "KnockbackService.luau"
Cohesion: 0.08
Nodes (41): computeVelocity(), deliver(), isActiveParticipant(), KnockbackService.endRound(), KnockbackService.isActiveParticipant(), KnockbackService.markAttacker(), KnockbackService.push(), KnockbackService.slide() (+33 more)

### Community 108 - "RoundResultBuilder.build"
Cohesion: 0.83
Nodes (3): pickHighlight(), resolveTies(), RoundResultBuilder.build()

### Community 109 - "Fase 5B — Bots Puff: nunca jogar sozinho"
Cohesion: 0.11
Nodes (17): 5B.1 Identidade de combatente (refatoração, sem mudança visível), 5B.2 Corpo do RoboPuff e preenchimento da fila, 5B.3 O bot sofre o jogo como qualquer um, 5B.4 Cérebro do RoboPuff, 5B.5 Recompensas e anti-farm, 5B.6 Telemetria, Critérios de aceite, Escopo (+9 more)

### Community 112 - "FinalChaosService.luau"
Cohesion: 0.25
Nodes (4): ArenaService.getIntactBlocks(), ArenaService.setCollapseWarning(), pickRandom(), runWaves()

### Community 113 - "InviteController.luau"
Cohesion: 0.43
Nodes (6): banner(), canInvite(), InviteController.invite(), onReward(), readCount(), report()

### Community 116 - "CorridorBuilder.luau"
Cohesion: 0.51
Nodes (9): addLamp(), buildBaraoDoor(), buildOuterWall(), buildTerritory(), buildToca(), CorridorBuilder.build(), decor(), solid() (+1 more)

### Community 118 - "ProfileSchema.luau"
Cohesion: 0.24
Nodes (13): cleanLarge(), cleanNumber(), ProfileSchema.clampDelta(), ProfileSchema.default(), ProfileSchema.emptyStats(), ProfileSchema.fromStored(), ProfileSchema.storedSession(), readAppliedRounds() (+5 more)

### Community 121 - "ReferralService.luau"
Cohesion: 0.19
Nodes (15): announce(), playLevelUp(), ProgressionController.start(), ProfileSchema.withTickets(), claimPending(), creditInviter(), grantInviter(), onProfile() (+7 more)

### Community 123 - "BotFillRules.luau"
Cohesion: 0.47
Nodes (3): BotFillRules.adjustment(), BotFillRules.canFill(), BotFillRules.desiredBots()

### Community 124 - "LevelCurve.luau"
Cohesion: 0.60
Nodes (5): LevelCurve.levelForXp(), LevelCurve.maxXp(), LevelCurve.progress(), LevelCurve.totalXpForLevel(), LevelCurve.xpForNextLevel()

### Community 125 - "MatchQueueService.luau"
Cohesion: 0.08
Nodes (43): isCompeting(), livingRoot(), MatchQueueService.isBoardingOpen(), MatchQueueService.isInZone(), MatchQueueService.refresh(), MatchQueueService.setBotCount(), MatchQueueService.setCountdown(), MatchQueueService.setWarmupLine() (+35 more)

### Community 126 - "DailyRules.luau"
Cohesion: 0.21
Nodes (7): DailyRules.assign(), DailyRules.dayIndex(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readDaily(), readCount(), shifted()

### Community 127 - "grant"
Cohesion: 0.39
Nodes (7): createLobbyPuff(), grant(), SecretAchievementService.baraoEvent(), SecretAchievementService.corridorEntered(), SecretAchievementService.passageRevealed(), SecretAchievementService.roundFinished(), SecretAchievementService.start()

### Community 129 - "ReactionService.luau"
Cohesion: 0.52
Nodes (6): isCompeting(), isMatchActive(), isWatching(), onRequest(), ReactionService.start(), throttled()

### Community 130 - "onRequest"
Cohesion: 0.60
Nodes (5): isCompeting(), onRequest(), PuffMachineService.start(), pull(), readRequestId()

### Community 131 - "PuffMomentService.luau"
Cohesion: 0.24
Nodes (4): MatchAudience.fire(), MatchAudience.isInMatch(), MatchAudience.players(), PuffMomentService.record()

### Community 132 - "onRequestBuild"
Cohesion: 0.36
Nodes (6): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound()

### Community 133 - "TelemetryService.lobbyEvent"
Cohesion: 0.31
Nodes (7): grantPuffs(), reportGuard(), equip(), onRequest(), throttled(), onClientReport(), TelemetryService.lobbyEvent()

### Community 134 - "DashService.luau"
Cohesion: 0.50
Nodes (3): DashService.forgetBot(), isAlive(), onDash()

### Community 135 - "BuildTargeting.luau"
Cohesion: 0.80
Nodes (4): BuildTargeting.cellAt(), BuildTargeting.cellCenter(), BuildTargeting.findTarget(), gridOrigin()

## Knowledge Gaps
- **233 isolated node(s):** `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)`, `Pré-requisitos`, `Instalação inicial no macOS` (+228 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TelemetryService.lobbyEvent()` connect `TelemetryService.lobbyEvent` to `ReactionService.luau`, `onRequest`, `LobbyStationsService.luau`, `DashService.luau`, `RoundService.luau`, `TelemetryService.luau`, `grant`, `MatchQueueService.luau`, `PlayerDataService.luau`?**
  _High betweenness centrality (0.176) - this node is a cross-community bridge._
- **Why does `PuffCatalog.get()` connect `ProfileController.luau` to `PuffShotRenderer.luau`, `ProjectileService.luau`, `TelemetryService.lobbyEvent`, `PuffdexView.new`, `openStation`?**
  _High betweenness centrality (0.133) - this node is a cross-community bridge._
- **Why does `ProjectileService.spawn()` connect `ProjectileService.luau` to `CombatantRegistry.luau`, `ProfileController.luau`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **Are the 17 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `PuffdexView.new()` (e.g. with `PuffdexController.start()` and `PuffCardFx.decorate()`) actually correct?**
  _`PuffdexView.new()` has 22 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AnnouncementView.new()` and `createBanner()`) actually correct?**
  _`UiTheme.addCorner()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)` to the rest of the system?**
  _233 weakly-connected nodes found - possible documentation gaps or missing edges._