# Graph Report - blocopuff  (2026-10-04)

## Corpus Check
- 221 files · ~1,136,709 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1716 nodes · 3170 edges · 134 communities (123 shown, 11 thin omitted)
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 657 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5616785a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PuffShotRenderer.luau
- RoundService.luau
- CharacterImpulse.luau
- SpectatorController.luau
- CombatantRegistry.getRoot
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
- KnockbackService.luau
- PuffEffects.luau
- Part
- ProfileGuard.luau
- ProfileSchema.luau
- LobbyStationsService.luau
- v002/source/build_model.py
- pull
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
- EliminationService.luau
- Recuperação de perfil
- PartyService.luau
- inspect_model.py
- render_preview.py
- ReactionController.luau
- Fase 5 — Partida Viva: o Casarão reage
- ProgressionController.luau
- RoundStatsService.luau
- BotFillService.luau
- 5. Arena
- WindowTrapFx.new
- PhotoModeService.luau
- TrapService.luau
- Fase 5B — Bots Puff: nunca jogar sozinho
- onRequestBuild
- InviteController.luau
- CombatantRegistry.luau
- ProfileController.luau
- TelemetryController.luau
- ReferralService.luau
- FinalChaosService.luau
- ReactionService.luau
- BuildTargeting.luau
- DailyRules.luau
- PlayerDataService.luau
- WindowTrap.luau
- PuffadorService.luau
- LevelCurve.luau
- RoundResultBuilder.build

## God Nodes (most connected - your core abstractions)
1. `Estado atual` - 43 edges
2. `BlocoPuff — Game Design Document` - 36 edges
3. `BuildingDecor.createPart()` - 30 edges
4. `PuffdexView.new()` - 26 edges
5. `beginRound()` - 26 edges
6. `UiTheme.addCorner()` - 25 edges
7. `TelemetryService.lobbyEvent()` - 20 edges
8. `UiTheme.createLabel()` - 19 edges
9. `UiTheme.addTextOutline()` - 18 edges
10. `UiTheme.stylePanel()` - 17 edges

## Surprising Connections (you probably didn't know these)
- `PuffdexView.new()` --calls--> `date()`  [INFERRED]
  src/client/ui/PuffdexView.luau → tools/profile-recovery/recovery.luau
- `fullFloor()` --calls--> `BotGrid.key()`  [INFERRED]
  tests/BotGrid.spec.luau → src/server/data/BotGrid.luau
- `openStation()` --calls--> `ChallengesController.show()`  [INFERRED]
  src/client/controllers/LobbyStationsController.luau → src/client/controllers/ChallengesController.luau
- `showAnnouncement()` --calls--> `NotificationManager.notify()`  [INFERRED]
  src/client/controllers/HudController.luau → src/client/notifications/NotificationManager.luau
- `ProgressionController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/ProgressionController.luau → src/client/notifications/NotificationManager.luau

## Import Cycles
- None detected.

## Communities (134 total, 11 thin omitted)

### Community 0 - "PuffShotRenderer.luau"
Cohesion: 0.15
Nodes (24): isVector3(), onFired(), onMessage(), PuffShotController.predict(), PuffShotController.start(), takePending(), buildBurst(), cameraPosition() (+16 more)

### Community 1 - "RoundService.luau"
Cohesion: 0.15
Nodes (24): EliminationService.beginRound(), MatchQueueService.setCountdown(), MatchQueueService.setOpen(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countQueued(), dequeuePlayer() (+16 more)

### Community 2 - "CharacterImpulse.luau"
Cohesion: 0.12
Nodes (25): aliveCharacter(), DashController.dash(), DashController.start(), dashDirection(), applyKnockback(), applySlide(), getRoot(), isFiniteVector() (+17 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (14): connectContainerAttribute(), cycleTarget(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute(), readNumberAttribute() (+6 more)

### Community 4 - "CombatantRegistry.getRoot"
Cohesion: 0.09
Nodes (43): BotGrid.cellOf(), BotGrid.center(), BotGrid.chooseGoal(), BotGrid.isInside(), BotGrid.isPathClear(), BotGrid.key(), BotGrid.safety(), ArenaService.getBlocks() (+35 more)

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
Nodes (68): createBlocker(), OrientationController.start(), report(), request(), AdminPanelView.new(), constrainText(), createSection(), createTextBox() (+60 more)

### Community 17 - "Estado atual"
Cohesion: 0.05
Nodes (43): Alertas, Momentos Puff e telemetria dos segredos (Fase 2, entrega 2.4), Armadilhas do Casarão e Janela Ventania (Fase 5, entregas 5.1 e 5.2), Artes da loja, Barão e Tocas Seguras (Fase 2, entrega 2.2), Barão maior, animado e com túnel entre os corredores (Fase 4, ajuste pós-4.5), Bots RoboPuff (Fase 5B), Comandos de teste da partida (painel admin), Controles e mira (Fase 1, entrega 1.5) (+35 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "LeaderboardService.luau"
Cohesion: 0.21
Nodes (11): DataStoreErrors.isStudioAccessDenied(), emptyBoards(), flushAll(), flushUser(), handleFailure(), LeaderboardService.start(), publish(), readBoard() (+3 more)

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.07
Nodes (56): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+48 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.16
Nodes (24): approach(), bark(), beginChase(), emit(), endChase(), getRoot(), goToSleep(), isActiveParticipant() (+16 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.09
Nodes (44): buildLights(), buildLockers(), buildPaneling(), buildPedestal(), buildShell(), buildVaultDisk(), decor(), SecretRoomBuilder.build() (+36 more)

### Community 31 - "TelemetryService.lobbyEvent"
Cohesion: 0.21
Nodes (12): parseNewPuffs(), grantPuffs(), equip(), onRequest(), throttled(), TelemetryService.lobbyEvent(), PuffCatalog.all(), PuffCatalog.get() (+4 more)

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
Cohesion: 0.40
Nodes (5): 14. UX, câmera e controles, Alertas, Impulso, Mira, Puffador do Cofre

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
Cohesion: 0.12
Nodes (31): computeVelocity(), deliver(), isActiveParticipant(), KnockbackService.beginRound(), KnockbackService.endRound(), KnockbackService.forget(), KnockbackService.getRecentAttacker(), KnockbackService.markAttacker() (+23 more)

### Community 54 - "PuffEffects.luau"
Cohesion: 0.23
Nodes (12): acquireVisual(), buildVisual(), colorFor(), fade(), layer(), PuffEffects.attach(), PuffEffects.info(), PuffEffects.motionOffset() (+4 more)

### Community 56 - "Part"
Cohesion: 0.31
Nodes (4): make_parts(), Part, Deterministic, editable Barão mesh source. Uses existing NumPy and Pillow only., uv()

### Community 57 - "ProfileGuard.luau"
Cohesion: 0.36
Nodes (7): isTable(), mergePuffs(), mergeStats(), number(), numberOr(), profile(), puff()

### Community 58 - "ProfileSchema.luau"
Cohesion: 0.22
Nodes (14): DailyRules.emptyDaily(), cleanLarge(), cleanNumber(), ProfileSchema.clampDelta(), ProfileSchema.default(), ProfileSchema.emptyStats(), ProfileSchema.fromStored(), ProfileSchema.storedSession() (+6 more)

### Community 59 - "LobbyStationsService.luau"
Cohesion: 0.50
Nodes (12): buildChallengeBoard(), buildFriendlyBarao(), buildMachine(), buildPartyPost(), buildPedestal(), buildPuffdexLectern(), buildShop(), buildShowcase() (+4 more)

### Community 60 - "v002/source/build_model.py"
Cohesion: 0.15
Nodes (15): parts(), Barão v002: shaped ears, fitted jersey, expressive muzzle and continuous paws., rotation_z(), export_glb(), tangents(), normalize(), Part, Small surface builders for the editable Barão model (Y up, forward -Z). (+7 more)

### Community 61 - "pull"
Cohesion: 0.31
Nodes (9): isEpicOrBetter(), RewardRules.rollMachine(), RewardRules.ticketsForRound(), rollRarity(), isCompeting(), onRequest(), PuffMachineService.start(), pull() (+1 more)

### Community 62 - "BotBody.luau"
Cohesion: 0.52
Nodes (6): addAntenna(), animate(), BotBody.build(), describe(), dress(), giveServerPhysics()

### Community 67 - "HudController.luau"
Cohesion: 0.22
Nodes (6): clearAnnouncement(), renderCountdown(), renderLobbyDuringMatch(), renderQueue(), renderWaiting(), showAnnouncement()

### Community 68 - "NotificationManager.notify"
Cohesion: 0.23
Nodes (14): BaraoController.start(), onFeedback(), seconds(), finishCurrent(), insertSorted(), maxWait(), NotificationManager.clear(), NotificationManager.init() (+6 more)

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
Cohesion: 0.08
Nodes (26): closeVisit(), DashService.forgetBot(), isAlive(), onDash(), MatchAudience.fire(), MatchAudience.isInMatch(), MatchAudience.players(), PuffMomentService.beginRound() (+18 more)

### Community 81 - "OnboardingRules.luau"
Cohesion: 0.17
Nodes (9): bitOf(), OnboardingRules.has(), OnboardingRules.initial(), OnboardingRules.mark(), OnboardingRules.stepsFromProfile(), mark(), OnboardingService.start(), onProfile() (+1 more)

### Community 82 - "MatchQueueController.luau"
Cohesion: 0.44
Nodes (7): banner(), connectTrampoline(), MatchQueueController.start(), onMessage(), playSound(), watchCountdown(), watchQueue()

### Community 83 - "ArenaService.luau"
Cohesion: 0.11
Nodes (31): ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getIntactBlocks(), ArenaService.getNeighborBlock(), ArenaService.getPlayerSpawnCFrames() (+23 more)

### Community 84 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 86 - "Barão v002"
Cohesion: 0.12
Nodes (13): Modelos 3D do Barão, Revisões, Arquivos, Barão v001, Conferência da ficha, Etapa no Studio, Reprodução e validação, Barão v002 (+5 more)

### Community 89 - "BaraoVisualController.luau"
Cohesion: 0.12
Nodes (25): addArena(), addFriendly(), cameraPosition(), celebratePet(), characterRoot(), chaseLook(), compose(), counter() (+17 more)

### Community 90 - "EliminationService.luau"
Cohesion: 0.36
Nodes (8): ArenaService.getModel(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop(), isOwned(), monitorLoop()

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

### Community 102 - "ProgressionController.luau"
Cohesion: 0.67
Nodes (3): announce(), playLevelUp(), ProgressionController.start()

### Community 103 - "RoundStatsService.luau"
Cohesion: 0.20
Nodes (16): participantMultiplier(), XpCalculator.compute(), commitProfiles(), isBeginner(), recordComeback(), add(), empty(), RoundStatsService.baraoEscape() (+8 more)

### Community 104 - "BotFillService.luau"
Cohesion: 0.06
Nodes (57): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch(), BotFillRules.adjustment(), BotFillRules.canFill(), BotFillRules.desiredBots() (+49 more)

### Community 106 - "WindowTrapFx.new"
Cohesion: 0.14
Nodes (21): getEffectsFolder(), step(), track(), TrapVisualController.start(), untrack(), ChandelierTrapFx.new(), vectorAttribute(), FireplaceTrapFx.new() (+13 more)

### Community 107 - "PhotoModeService.luau"
Cohesion: 0.24
Nodes (16): applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot(), getScene() (+8 more)

### Community 108 - "TrapService.luau"
Cohesion: 0.08
Nodes (42): ArenaService.addDestroyedListener(), ProjectileService.setSurfaceHitHandler(), collectPaintings(), createCover(), createGlow(), hideAll(), isActiveParticipant(), onSurfaceHit() (+34 more)

### Community 109 - "Fase 5B — Bots Puff: nunca jogar sozinho"
Cohesion: 0.11
Nodes (17): 5B.1 Identidade de combatente (refatoração, sem mudança visível), 5B.2 Corpo do RoboPuff e preenchimento da fila, 5B.3 O bot sofre o jogo como qualquer um, 5B.4 Cérebro do RoboPuff, 5B.5 Recompensas e anti-farm, 5B.6 Telemetria, Critérios de aceite, Escopo (+9 more)

### Community 112 - "onRequestBuild"
Cohesion: 0.31
Nodes (7): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound(), PuffadorService.isHoldingPuffador()

### Community 113 - "InviteController.luau"
Cohesion: 0.43
Nodes (6): banner(), canInvite(), InviteController.invite(), onReward(), readCount(), report()

### Community 116 - "CombatantRegistry.luau"
Cohesion: 0.23
Nodes (18): attributeHolder(), CombatantRegistry.all(), CombatantRegistry.forPlayer(), CombatantRegistry.forPlayers(), CombatantRegistry.fromCharacter(), CombatantRegistry.getAttribute(), CombatantRegistry.getBots(), CombatantRegistry.getCharacter() (+10 more)

### Community 118 - "ProfileController.luau"
Cohesion: 0.10
Nodes (23): asNumber(), LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward() (+15 more)

### Community 121 - "ReferralService.luau"
Cohesion: 0.16
Nodes (16): ReferralRules.addPending(), ReferralRules.canRecordInviter(), ReferralRules.inviterGrant(), ReferralRules.readPending(), claimPending(), creditInviter(), grantInviter(), onClientReport() (+8 more)

### Community 123 - "FinalChaosService.luau"
Cohesion: 0.18
Nodes (11): CombatantRegistry.playersOf(), FinalChaosService.begin(), FinalChaosService.getDuration(), FinalChaosService.isRunning(), pickRandom(), evaluateActiveParticipants(), participantPlayers(), publishResult() (+3 more)

### Community 124 - "ReactionService.luau"
Cohesion: 0.52
Nodes (6): isCompeting(), isMatchActive(), isWatching(), onRequest(), ReactionService.start(), throttled()

### Community 125 - "BuildTargeting.luau"
Cohesion: 0.80
Nodes (4): BuildTargeting.cellAt(), BuildTargeting.cellCenter(), BuildTargeting.findTarget(), gridOrigin()

### Community 126 - "DailyRules.luau"
Cohesion: 0.18
Nodes (15): DailyRules.applyRound(), DailyRules.assign(), DailyRules.claimDaily(), DailyRules.dayIndex(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readChallenges(), DailyRules.readDaily() (+7 more)

### Community 127 - "PlayerDataService.luau"
Cohesion: 0.26
Nodes (8): ProfileSchema.toStored(), isNewerFormat(), normalize(), now(), rebuild(), reportGuard(), tryLoad(), writeBackup()

### Community 128 - "WindowTrap.luau"
Cohesion: 0.06
Nodes (49): isWet(), refreshRain(), SlipperyController.start(), step(), watch(), KnockbackService.push(), ChandelierTrap.trigger(), buildModel() (+41 more)

### Community 132 - "PuffadorService.luau"
Cohesion: 0.08
Nodes (36): MatchQueueService.isBoardingOpen(), MatchQueueService.isInZone(), MatchQueueService.setWarmupLine(), buildPuffadorTool(), consumeSuperCharge(), grantToolToPlayer(), isFiniteNumber(), isFiniteVector3() (+28 more)

### Community 142 - "LevelCurve.luau"
Cohesion: 0.60
Nodes (5): LevelCurve.levelForXp(), LevelCurve.maxXp(), LevelCurve.progress(), LevelCurve.totalXpForLevel(), LevelCurve.xpForNextLevel()

### Community 148 - "RoundResultBuilder.build"
Cohesion: 0.83
Nodes (3): pickHighlight(), resolveTies(), RoundResultBuilder.build()

## Knowledge Gaps
- **238 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+233 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PuffCatalog.get()` connect `TelemetryService.lobbyEvent` to `PuffShotRenderer.luau`, `PuffdexView.new`, `openStation`, `ArenaService.luau`, `ProfileController.luau`?**
  _High betweenness centrality (0.132) - this node is a cross-community bridge._
- **Why does `TelemetryService.lobbyEvent()` connect `TelemetryService.lobbyEvent` to `PuffadorService.luau`, `BotFillService.luau`, `TelemetryService.luau`, `ProfileController.luau`, `ReferralService.luau`, `LobbyStationsService.luau`, `ReactionService.luau`, `pull`, `DailyRules.luau`, `PlayerDataService.luau`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **Why does `ProjectileService.spawn()` connect `ArenaService.luau` to `CombatantRegistry.luau`, `TelemetryService.lobbyEvent`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **Are the 19 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `PuffdexView.new()` (e.g. with `PuffdexController.start()` and `PuffCardFx.decorate()`) actually correct?**
  _`PuffdexView.new()` has 22 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `BotBrainService.beginRound()`) actually correct?**
  _`beginRound()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _238 weakly-connected nodes found - possible documentation gaps or missing edges._