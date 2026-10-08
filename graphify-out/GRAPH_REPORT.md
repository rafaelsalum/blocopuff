# Graph Report - blocopuff  (2026-10-07)

## Corpus Check
- 266 files · ~1,226,362 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2093 nodes · 4059 edges · 167 communities (153 shown, 14 thin omitted)
- Extraction: 78% EXTRACTED · 22% INFERRED · 0% AMBIGUOUS · INFERRED: 908 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5caea4cd`
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
- AtticController.luau
- Estado atual
- WorldVisualService.luau
- AdminService.luau
- ReferralService.luau
- BlockCollapseController.luau
- BuildingDecor.createPart
- MusicController.luau
- BaraoService.luau
- Escopo
- VaultService.luau
- DailyRules.luau
- PuffadorModel.luau
- ProfileController.luau
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
- WindowTrap.luau
- TocaService.luau
- Part
- grant
- ProjectileService.luau
- MysteryController.luau
- v002/source/build_model.py
- PlayerDataService.luau
- BotBody.luau
- Lang.t
- HudController.luau
- onRequest
- MatchQueueService.luau
- MansionLayout.get
- TelemetryService.luau
- NotificationManager.notify
- BlocoPuff!
- Instruções para agentes
- FinalChaosService.luau
- OnboardingRules.luau
- MatchQueueController.luau
- ReactionService.luau
- PuffCatalog.luau
- Barão v002
- BaraoVisualController.luau
- TrapBlocks.targetRoot
- Recuperação de perfil
- PartyService.luau
- inspect_model.py
- render_preview.py
- ReactionController.luau
- Escopo
- ArenaService.luau
- RoundStatsService.luau
- BotFillService.luau
- 5. Arena
- WindowTrapFx.new
- Fase 5C — Casarão Vivo: explorar, descobrir, colecionar
- LocaleCore.luau
- Fase 5B — Bots Puff: nunca jogar sozinho
- PuffadorService.luau
- EliminationService.luau
- CombatantRegistry.luau
- TelemetryController.luau
- FireplaceTrap.luau
- UiTheme.addCorner
- PuffdexView.new
- PuffMachineController.start
- UiTheme.createLabel
- KnockbackService.luau
- Sons para pesquisar na Creator Store
- TelemetryService.lobbyEvent
- UiTheme.addStroke
- AdminController.luau
- TrapService.luau
- UiTheme.addTextConstraint
- ProfileSchema.luau
- 25. Lobby
- SecretPassageController.luau
- UiTheme.addTextOutline
- celebrate
- LeaderboardService.luau
- RelicSpots.luau
- ResultsView.new
- onRequestBuild
- stepRains
- LevelCurve.luau
- AlbumView.luau
- DashService.luau
- VaultController.luau
- OrientationController.luau
- BuildTargeting.luau
- PuffMomentController.luau
- CrosshairView.new
- RoundHudView.new
- onFeedback
- WindowGeometry.luau

## God Nodes (most connected - your core abstractions)
1. `Lang.t()` - 53 edges
2. `Estado atual` - 50 edges
3. `BlocoPuff — Game Design Document` - 36 edges
4. `BuildingDecor.createPart()` - 35 edges
5. `UiTheme.addCorner()` - 33 edges
6. `PuffdexView.new()` - 27 edges
7. `UiTheme.createLabel()` - 26 edges
8. `UiTheme.addTextOutline()` - 24 edges
9. `beginRound()` - 24 edges
10. `TelemetryService.lobbyEvent()` - 24 edges

## Surprising Connections (you probably didn't know these)
- `PuffdexView.new()` --calls--> `date()`  [INFERRED]
  src/client/ui/PuffdexView.luau → tools/profile-recovery/recovery.luau
- `fullFloor()` --calls--> `BotGrid.key()`  [INFERRED]
  tests/BotGrid.spec.luau → src/server/data/BotGrid.luau
- `BaraoController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/BaraoController.luau → src/client/notifications/NotificationManager.luau
- `PuffMomentController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/PuffMomentController.luau → src/client/notifications/NotificationManager.luau
- `SecretPassageController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/SecretPassageController.luau → src/client/notifications/NotificationManager.luau

## Import Cycles
- None detected.

## Communities (167 total, 14 thin omitted)

### Community 0 - "PuffShotRenderer.luau"
Cohesion: 0.10
Nodes (37): isVector3(), onFired(), onMessage(), PuffShotController.predict(), PuffShotController.start(), takePending(), acquireVisual(), buildBurst() (+29 more)

### Community 1 - "RoundService.luau"
Cohesion: 0.14
Nodes (23): BotFillService.count(), CombatantRegistry.playersOf(), EliminationService.beginRound(), beginRound(), clearRoundParticipants(), countQueued(), dequeuePlayer(), enqueuePlayer() (+15 more)

### Community 2 - "CharacterImpulse.luau"
Cohesion: 0.12
Nodes (25): aliveCharacter(), DashController.dash(), DashController.start(), dashDirection(), applyKnockback(), applySlide(), getRoot(), isFiniteVector() (+17 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (14): connectContainerAttribute(), cycleTarget(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute(), readNumberAttribute() (+6 more)

### Community 4 - "CombatantRegistry.getRoot"
Cohesion: 0.09
Nodes (42): BotGrid.cellOf(), BotGrid.center(), BotGrid.chooseGoal(), BotGrid.isInside(), BotGrid.isPathClear(), BotGrid.key(), BotGrid.safety(), activeCombatants() (+34 more)

### Community 5 - "PuffadorController.luau"
Cohesion: 0.12
Nodes (31): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+23 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.26
Nodes (13): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setFinalChaos(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId() (+5 more)

### Community 7 - "BlocoPuff — Game Design Document"
Cohesion: 0.10
Nodes (20): 10. Tocas Seguras, 12. Segunda Chance e eliminação, 13. Espectador, 15. Momentos Puff, 18. Prestígio, 21. Coleções e Barão, 22. Puff Machine, 24. Conquistas secretas (+12 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.23
Nodes (12): assignActiveSpawn(), destroyOwnedChild(), getActiveSpawn(), getHorizontalDistance(), getLivingRoot(), getLobbySlots(), getOccupiedPositions(), isOwned() (+4 more)

### Community 9 - "AtticController.luau"
Cohesion: 0.36
Nodes (8): addLantern(), collectCharacters(), findHand(), getEffect(), refresh(), removeLantern(), rootOf(), setDark()

### Community 17 - "Estado atual"
Cohesion: 0.04
Nodes (50): Ala leste do Casarão: Biblioteca, Sala de Música, Sótão e Porão (Fase 5C, entrega 5C.1, parte 2), Alertas, Momentos Puff e telemetria dos segredos (Fase 2, entrega 2.4), Armadilhas do Casarão e Janela Ventania (Fase 5, entregas 5.1 e 5.2), Artes da loja, Barão e Tocas Seguras (Fase 2, entrega 2.2), Barão maior, animado e com túnel entre os corredores (Fase 4, ajuste pós-4.5), Bots RoboPuff (Fase 5B), Comandos de teste da partida (painel admin) (+42 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "ReferralService.luau"
Cohesion: 0.16
Nodes (16): ReferralRules.addPending(), ReferralRules.canRecordInviter(), ReferralRules.inviterGrant(), ReferralRules.readPending(), claimPending(), creditInviter(), grantInviter(), onClientReport() (+8 more)

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.06
Nodes (79): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+71 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.16
Nodes (24): approach(), bark(), beginChase(), emit(), endChase(), getRoot(), goToSleep(), isActiveParticipant() (+16 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.06
Nodes (51): closeVisit(), MatchAudience.fire(), MatchAudience.isInMatch(), MatchAudience.players(), PuffMomentService.beginRound(), PuffMomentService.record(), buildLights(), buildLockers() (+43 more)

### Community 31 - "DailyRules.luau"
Cohesion: 0.17
Nodes (15): DailyRules.applyRound(), DailyRules.assign(), DailyRules.claimDaily(), DailyRules.dayIndex(), DailyRules.emptyDaily(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readChallenges() (+7 more)

### Community 32 - "PuffadorModel.luau"
Cohesion: 0.50
Nodes (6): addPart(), buildBody(), buildGrip(), buildMuzzle(), buildTank(), tube()

### Community 33 - "ProfileController.luau"
Cohesion: 0.20
Nodes (10): LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward(), parseRelicEvent() (+2 more)

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

### Community 53 - "WindowTrap.luau"
Cohesion: 0.19
Nodes (19): boards(), curtainColorOf(), gust(), gustAt(), looseBlocks(), pigeons(), pushPlayers(), rollVariant() (+11 more)

### Community 54 - "TocaService.luau"
Cohesion: 0.29
Nodes (16): claim(), eject(), emit(), getRoot(), isActiveParticipant(), occupiedToca(), paint(), release() (+8 more)

### Community 56 - "Part"
Cohesion: 0.31
Nodes (4): make_parts(), Part, Deterministic, editable Barão mesh source. Uses existing NumPy and Pillow only., uv()

### Community 57 - "grant"
Cohesion: 0.23
Nodes (11): parseSecrets(), createLobbyPuff(), grant(), SecretAchievementService.baraoEvent(), SecretAchievementService.beginRound(), SecretAchievementService.corridorEntered(), SecretAchievementService.passageRevealed(), SecretAchievementService.roundFinished() (+3 more)

### Community 58 - "ProjectileService.luau"
Cohesion: 0.35
Nodes (10): broadcast(), isOwned(), notifyHit(), ProjectileService.clearAll(), ProjectileService.clearFor(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop() (+2 more)

### Community 59 - "MysteryController.luau"
Cohesion: 0.06
Nodes (41): applySolved(), candleColors(), hideSolvedPrompts(), lightCandles(), mysteriesFolder(), MysteryController.start(), notify(), onProfile() (+33 more)

### Community 60 - "v002/source/build_model.py"
Cohesion: 0.15
Nodes (15): parts(), Barão v002: shaped ears, fitted jersey, expressive muzzle and continuous paws., rotation_z(), export_glb(), tangents(), normalize(), Part, Small surface builders for the editable Barão model (Y up, forward -Z). (+7 more)

### Community 61 - "PlayerDataService.luau"
Cohesion: 0.17
Nodes (10): DataStoreErrors.isStudioAccessDenied(), ProfileSchema.toStored(), isNewerFormat(), nonEmpty(), normalize(), now(), rebuild(), reportGuard() (+2 more)

### Community 62 - "BotBody.luau"
Cohesion: 0.52
Nodes (6): addAntenna(), animate(), BotBody.build(), describe(), dress(), giveServerPhysics()

### Community 63 - "Lang.t"
Cohesion: 0.06
Nodes (68): banner(), canInvite(), InviteController.invite(), onReward(), readCount(), report(), allRelics(), apply() (+60 more)

### Community 67 - "HudController.luau"
Cohesion: 0.16
Nodes (16): clearAnnouncement(), connectAttribute(), formatMinutesSeconds(), getPersonalScoreSummary(), HudController.start(), queueStatus(), render(), renderActive() (+8 more)

### Community 68 - "onRequest"
Cohesion: 0.60
Nodes (5): announceLegendary(), isCompeting(), onRequest(), PuffMachineService.start(), readRequestId()

### Community 69 - "MatchQueueService.luau"
Cohesion: 0.36
Nodes (6): dropTicket(), giveTicket(), isCompeting(), livingRoot(), updateLonely(), updateTickets()

### Community 72 - "MansionLayout.get"
Cohesion: 0.07
Nodes (59): createSolid(), destroyOwnedChild(), doorHole(), getDoorHoles(), getPassageGaps(), getPassageHoles(), isOwned(), createCeiling() (+51 more)

### Community 74 - "TelemetryService.luau"
Cohesion: 0.20
Nodes (18): pull(), elapsed(), getCounters(), getDevice(), getFloor(), getZone(), log(), logTickets() (+10 more)

### Community 75 - "NotificationManager.notify"
Cohesion: 0.24
Nodes (13): announce(), playLevelUp(), ProgressionController.start(), finishCurrent(), insertSorted(), maxWait(), NotificationManager.init(), NotificationManager.notify() (+5 more)

### Community 78 - "BlocoPuff!"
Cohesion: 0.17
Nodes (12): Atualização futura, BlocoPuff!, Build local, Configuração do PATH por shell, Estrutura, Grafo de conhecimento (graphify), Instalação inicial no macOS, Plugin do Rojo no Roblox Studio (+4 more)

### Community 79 - "Instruções para agentes"
Cohesion: 0.18
Nodes (8): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify

### Community 80 - "FinalChaosService.luau"
Cohesion: 0.21
Nodes (10): ArenaService.getIntactBlocks(), ArenaService.setCollapseWarning(), FinalChaosService.begin(), FinalChaosService.getDuration(), FinalChaosService.isRunning(), pickRandom(), runWaves(), evaluateActiveParticipants() (+2 more)

### Community 81 - "OnboardingRules.luau"
Cohesion: 0.17
Nodes (9): bitOf(), OnboardingRules.has(), OnboardingRules.initial(), OnboardingRules.mark(), OnboardingRules.stepsFromProfile(), mark(), OnboardingService.start(), onProfile() (+1 more)

### Community 82 - "MatchQueueController.luau"
Cohesion: 0.28
Nodes (10): announce(), banner(), connectTrampoline(), MatchQueueController.start(), onMessage(), playSound(), readStatus(), ringBell() (+2 more)

### Community 83 - "ReactionService.luau"
Cohesion: 0.52
Nodes (6): isCompeting(), isMatchActive(), isWatching(), onRequest(), ReactionService.start(), throttled()

### Community 84 - "PuffCatalog.luau"
Cohesion: 0.29
Nodes (7): isEpicOrBetter(), RewardRules.rollMachine(), RewardRules.ticketsForRound(), rollRarity(), PuffCatalog.machinePool(), PuffCatalog.meetsRule(), PuffCatalog.progress()

### Community 86 - "Barão v002"
Cohesion: 0.12
Nodes (13): Modelos 3D do Barão, Revisões, Arquivos, Barão v001, Conferência da ficha, Etapa no Studio, Reprodução e validação, Barão v002 (+5 more)

### Community 89 - "BaraoVisualController.luau"
Cohesion: 0.12
Nodes (25): addArena(), addFriendly(), cameraPosition(), celebratePet(), characterRoot(), chaseLook(), compose(), counter() (+17 more)

### Community 90 - "TrapBlocks.targetRoot"
Cohesion: 0.52
Nodes (6): ChandelierTrap.trigger(), TrapBlocks.drop(), TrapBlocks.intactNear(), TrapBlocks.isStandingOn(), TrapBlocks.pushAway(), TrapBlocks.targetRoot()

### Community 92 - "Recuperação de perfil"
Cohesion: 0.40
Nodes (4): Antes de começar, Recuperação de perfil, Restaurar, Ver o perfil (não muda nada)

### Community 93 - "PartyService.luau"
Cohesion: 0.47
Nodes (3): broadcast(), sendState(), stateOf()

### Community 95 - "render_preview.py"
Cohesion: 0.29
Nodes (6): Read the exported GLB, check delivery constraints and render its actual geometry, basis_for(), raster(), Offline previews of exported mesh data with shadow maps and PBR texture inputs., Renderer, unit()

### Community 101 - "Escopo"
Cohesion: 0.10
Nodes (19): 5.1 Base das armadilhas, 5.2 Janela Ventania (andar de cima), 5.3 Tapete Puxado (andar de baixo), 5.4 Lustre Despencando (andar de baixo), 5.5 Lareira de Fuligem (andar de baixo), 5.6 Variações das janelas: Pombos e Chuva, 5.7 Caos Final: Tempestade, 5.8 Momentos Puff, conquistas, telemetria e ajuste (+11 more)

### Community 102 - "ArenaService.luau"
Cohesion: 0.20
Nodes (16): ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getNeighborBlock(), ArenaService.tryDestroyBlock(), createArenaVisuals() (+8 more)

### Community 103 - "RoundStatsService.luau"
Cohesion: 0.19
Nodes (17): participantMultiplier(), XpCalculator.compute(), commitProfiles(), creditKnockout(), isBeginner(), recordComeback(), add(), empty() (+9 more)

### Community 104 - "BotFillService.luau"
Cohesion: 0.08
Nodes (32): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch(), BotFillRules.adjustment(), BotFillRules.canFill(), BotFillRules.desiredBots() (+24 more)

### Community 106 - "WindowTrapFx.new"
Cohesion: 0.10
Nodes (27): angleFor(), pose(), readLeaf(), register(), getEffectsFolder(), step(), track(), TrapVisualController.start() (+19 more)

### Community 107 - "Fase 5C — Casarão Vivo: explorar, descobrir, colecionar"
Cohesion: 0.11
Nodes (17): 5C.1 Ficha da Partida, portas e cômodos novos, 5C.2 Relíquias e o Álbum do Casarão, 5C.3 Mistérios do Barão, 5C.4 Vida e eventos no Casarão, Arquitetura técnica, Critérios de aceite, Escopo, Fase 5C — Casarão Vivo: explorar, descobrir, colecionar (+9 more)

### Community 108 - "LocaleCore.luau"
Cohesion: 0.14
Nodes (19): localizeProperty(), watch(), WorldTextLocalizer.start(), compiled(), Lang.current(), Lang.forPlayer(), Lang.languageOf(), Lang.localize() (+11 more)

### Community 109 - "Fase 5B — Bots Puff: nunca jogar sozinho"
Cohesion: 0.11
Nodes (17): 5B.1 Identidade de combatente (refatoração, sem mudança visível), 5B.2 Corpo do RoboPuff e preenchimento da fila, 5B.3 O bot sofre o jogo como qualquer um, 5B.4 Cérebro do RoboPuff, 5B.5 Recompensas e anti-farm, 5B.6 Telemetria, Critérios de aceite, Escopo (+9 more)

### Community 112 - "PuffadorService.luau"
Cohesion: 0.06
Nodes (48): ProjectileService.setSurfaceHitHandler(), buildPuffadorTool(), consumeSuperCharge(), grantToolToPlayer(), isFiniteNumber(), isFiniteVector3(), isOwned(), PuffadorService.beginRound() (+40 more)

### Community 113 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), CombatantRegistry.isBot(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 116 - "CombatantRegistry.luau"
Cohesion: 0.17
Nodes (19): ArenaService.getPlayerSpawnCFrames(), ArenaService.getSafeRespawnCFrame(), attributeHolder(), CombatantRegistry.all(), CombatantRegistry.forPlayer(), CombatantRegistry.forPlayers(), CombatantRegistry.fromCharacter(), CombatantRegistry.getAttribute() (+11 more)

### Community 121 - "FireplaceTrap.luau"
Cohesion: 0.26
Nodes (10): CombatantRegistry.isPresent(), buildModel(), FireplaceTrap.build(), FireplaceTrap.clear(), FireplaceTrap.roundReset(), FireplaceTrap.trigger(), markSneeze(), sneeze() (+2 more)

### Community 123 - "UiTheme.addCorner"
Cohesion: 0.29
Nodes (10): AdminPanelView.new(), constrainText(), createSection(), createTextBox(), createList(), createRow(), SpectatorView.new(), UiTheme.addCorner() (+2 more)

### Community 124 - "PuffdexView.new"
Cohesion: 0.19
Nodes (12): PuffCardFx.decorate(), createOrb(), formatDate(), paintOrb(), PuffdexView.new(), orbPath(), PuffPreview.new(), UiKit.pop() (+4 more)

### Community 125 - "PuffMachineController.start"
Cohesion: 0.16
Nodes (13): ChallengesController.show(), LobbyStationsController.start(), openStation(), celebrate(), PuffdexController.markNew(), PuffdexController.show(), PuffdexController.start(), send() (+5 more)

### Community 126 - "UiTheme.createLabel"
Cohesion: 0.20
Nodes (17): AlbumView.new(), label(), DiaryPageView.new(), describeAge(), formatNumber(), LeaderboardView.new(), MysteryView.new(), stepper() (+9 more)

### Community 127 - "KnockbackService.luau"
Cohesion: 0.21
Nodes (15): computeVelocity(), deliver(), isActiveParticipant(), KnockbackService.beginRound(), KnockbackService.endRound(), KnockbackService.forget(), KnockbackService.markAttacker(), KnockbackService.protect() (+7 more)

### Community 128 - "Sons para pesquisar na Creator Store"
Cohesion: 0.15
Nodes (12): 🐶 Barão, 🚪 Casarão (5C.1), 🔐 Cofre e passagens secretas, ⭐ Interface e progressão, 🪟 Janelas (armadilha), 🔥 Lareira de Fuligem, 💡 Lustre, Próximas entregas (já pode separar) (+4 more)

### Community 129 - "TelemetryService.lobbyEvent"
Cohesion: 0.33
Nodes (9): parseNewPuffs(), parsePuffs(), grantPuffs(), equip(), onRequest(), throttled(), TelemetryService.lobbyEvent(), PuffCatalog.all() (+1 more)

### Community 130 - "UiTheme.addStroke"
Cohesion: 0.24
Nodes (9): buildSlot(), paintSlot(), PuffMachineCarousel.new(), isSpecial(), PuffMachineReveal.new(), machinePuffs(), PuffMachineView.new(), UiTheme.addStroke() (+1 more)

### Community 131 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 132 - "TrapService.luau"
Cohesion: 0.08
Nodes (44): ArenaService.addDestroyedListener(), ArenaService.getBlocks(), applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart() (+36 more)

### Community 141 - "UiTheme.addTextConstraint"
Cohesion: 0.21
Nodes (7): PuffadorController.start(), ControlHintView.new(), FeedbackView.new(), findCallout(), circle(), FireButtonView.new(), UiTheme.addTextConstraint()

### Community 142 - "ProfileSchema.luau"
Cohesion: 0.23
Nodes (15): cleanLarge(), cleanNumber(), ProfileSchema.clampDelta(), ProfileSchema.default(), ProfileSchema.emptyStats(), ProfileSchema.fromStored(), ProfileSchema.storedSession(), readAppliedRounds() (+7 more)

### Community 144 - "SecretPassageController.luau"
Cohesion: 0.60
Nodes (4): floorName(), onEvent(), playChime(), SecretPassageController.start()

### Community 145 - "UiTheme.addTextOutline"
Cohesion: 0.13
Nodes (16): AnnouncementView.new(), getToneColor(), BannerView.new(), createBanner(), getToneColor(), BuildToggleView.new(), CombatHudView.new(), createLabel() (+8 more)

### Community 146 - "celebrate"
Cohesion: 0.53
Nodes (4): celebrate(), ChallengesController.start(), challengeTickets(), challengeTitle()

### Community 148 - "LeaderboardService.luau"
Cohesion: 0.28
Nodes (9): emptyBoards(), flushAll(), flushUser(), handleFailure(), LeaderboardService.start(), publish(), readBoard(), refresh() (+1 more)

### Community 150 - "RelicSpots.luau"
Cohesion: 0.05
Nodes (70): parseRelics(), rewardText(), addSparkles(), buildDaily(), buildMesh(), buildPuff(), buildPumpkin(), buildSimple() (+62 more)

### Community 151 - "ResultsView.new"
Cohesion: 0.44
Nodes (9): createChip(), createPodiumSlot(), describe(), findEntry(), highlightDetail(), label(), plural(), ResultsView.new() (+1 more)

### Community 152 - "onRequestBuild"
Cohesion: 0.31
Nodes (7): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound(), PuffadorService.isHoldingPuffador()

### Community 153 - "stepRains"
Cohesion: 0.22
Nodes (12): isWet(), refreshRain(), SlipperyController.start(), step(), watch(), KnockbackService.getRecentAttacker(), stepRains(), ensureConstraint() (+4 more)

### Community 154 - "LevelCurve.luau"
Cohesion: 0.60
Nodes (5): LevelCurve.levelForXp(), LevelCurve.maxXp(), LevelCurve.progress(), LevelCurve.totalXpForLevel(), LevelCurve.xpForNextLevel()

### Community 156 - "DashService.luau"
Cohesion: 0.50
Nodes (3): DashService.forgetBot(), isAlive(), onDash()

### Community 158 - "OrientationController.luau"
Cohesion: 0.70
Nodes (4): createBlocker(), OrientationController.start(), report(), request()

### Community 159 - "BuildTargeting.luau"
Cohesion: 0.80
Nodes (4): BuildTargeting.cellAt(), BuildTargeting.cellCenter(), BuildTargeting.findTarget(), gridOrigin()

### Community 160 - "PuffMomentController.luau"
Cohesion: 0.67
Nodes (3): describe(), onMoment(), PuffMomentController.start()

### Community 161 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

### Community 162 - "RoundHudView.new"
Cohesion: 0.83
Nodes (3): createAnimationGroup(), createTextLabel(), RoundHudView.new()

### Community 163 - "onFeedback"
Cohesion: 0.67
Nodes (3): BaraoController.start(), onFeedback(), seconds()

### Community 164 - "WindowGeometry.luau"
Cohesion: 0.83
Nodes (3): WindowGeometry.inPigeonLane(), WindowGeometry.inRain(), WindowGeometry.local3()

## Knowledge Gaps
- **272 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+267 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Lang.t()` connect `Lang.t` to `UiTheme.addStroke`, `WindowTrapFx.new`, `NotificationManager.notify`, `AlbumView.luau`, `LocaleCore.luau`, `PuffadorService.luau`, `celebrate`, `RelicSpots.luau`, `VaultService.luau`, `BuildingDecor.createPart`, `MysteryController.luau`, `PuffdexView.new`, `PuffMachineController.start`, `UiTheme.createLabel`?**
  _High betweenness centrality (0.198) - this node is a cross-community bridge._
- **Why does `TelemetryService.lobbyEvent()` connect `TelemetryService.lobbyEvent` to `onRequest`, `MatchQueueService.luau`, `BotFillService.luau`, `TelemetryService.luau`, `DailyRules.luau`, `PuffadorService.luau`, `ReactionService.luau`, `ReferralService.luau`, `RelicSpots.luau`, `grant`, `MysteryController.luau`, `DashService.luau`, `PlayerDataService.luau`, `Lang.t`?**
  _High betweenness centrality (0.098) - this node is a cross-community bridge._
- **Why does `PuffCatalog.get()` connect `TelemetryService.lobbyEvent` to `PuffShotRenderer.luau`, `UiTheme.addStroke`, `onRequest`, `PuffCatalog.luau`, `ProjectileService.luau`, `PuffdexView.new`, `PuffMachineController.start`?**
  _High betweenness centrality (0.091) - this node is a cross-community bridge._
- **Are the 51 inferred relationships involving `Lang.t()` (e.g. with `celebrate()` and `InviteController.invite()`) actually correct?**
  _`Lang.t()` has 51 INFERRED edges - model-reasoned connections that need verification._
- **Are the 24 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 24 INFERRED edges - model-reasoned connections that need verification._
- **Are the 30 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminPanelView.new()` and `createSection()`) actually correct?**
  _`UiTheme.addCorner()` has 30 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _272 weakly-connected nodes found - possible documentation gaps or missing edges._