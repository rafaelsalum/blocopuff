# Graph Report - blocopuff  (2026-10-04)

## Corpus Check
- 232 files · ~1,147,601 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1787 nodes · 3341 edges · 145 communities (131 shown, 14 thin omitted)
- Extraction: 78% EXTRACTED · 22% INFERRED · 0% AMBIGUOUS · INFERRED: 725 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `855bd42a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PuffShotRenderer.luau
- RoundService.luau
- DailyRules.luau
- SpectatorController.luau
- CombatantRegistry.getRoot
- PuffadorController.luau
- ReplicatedStateService.luau
- BlocoPuff — Game Design Document
- LobbyService.luau
- UiTheme.addCorner
- Estado atual
- WorldVisualService.luau
- AdminService.luau
- ProfileSchema.luau
- BlockCollapseController.luau
- BuildingDecor.createPart
- MusicController.luau
- BaraoService.luau
- Escopo
- VaultService.luau
- ProfileController.luau
- PuffadorModel.luau
- RewardRules.rollMachine
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
- CharacterImpulse.luau
- Part
- ProfileGuard.luau
- ArenaService.luau
- LocaleCore.luau
- v002/source/build_model.py
- LeaderboardService.luau
- BotBody.luau
- PuffMomentController.luau
- HudController.luau
- NotificationManager.notify
- celebrate
- VaultController.luau
- grant
- PuffMachineController.start
- BlocoPuff!
- Instruções para agentes
- TelemetryService.luau
- OnboardingRules.luau
- MatchQueueController.luau
- MatchQueueService.luau
- SecretPassageController.luau
- Barão v002
- BaraoVisualController.luau
- EliminationService.luau
- Recuperação de perfil
- PartyService.luau
- inspect_model.py
- render_preview.py
- ReactionController.luau
- Escopo
- ProgressionController.luau
- RoundStatsService.luau
- BotFillService.luau
- 5. Arena
- WindowTrapFx.new
- Fase 5C — Casarão Vivo: explorar, descobrir, colecionar
- Lang.t
- Fase 5B — Bots Puff: nunca jogar sozinho
- PuffadorService.luau
- TelemetryService.lobbyEvent
- CombatantRegistry.luau
- TelemetryController.luau
- ReferralService.luau
- PhotoModeService.luau
- PlayerDataService.luau
- onRequestBuild
- PuffMomentService.luau
- AdminController.luau
- LevelCurve.luau
- CorridorTelemetryService.luau
- BuildTargeting.luau
- TrapService.luau
- ReactionService.luau
- pull
- 25. Lobby
- DashService.luau

## God Nodes (most connected - your core abstractions)
1. `Estado atual` - 44 edges
2. `Lang.t()` - 39 edges
3. `BlocoPuff — Game Design Document` - 36 edges
4. `BuildingDecor.createPart()` - 30 edges
5. `UiTheme.addCorner()` - 28 edges
6. `PuffdexView.new()` - 27 edges
7. `beginRound()` - 26 edges
8. `TelemetryService.lobbyEvent()` - 21 edges
9. `ResultsView.new()` - 20 edges
10. `UiTheme.addTextOutline()` - 20 edges

## Surprising Connections (you probably didn't know these)
- `PuffdexView.new()` --calls--> `date()`  [INFERRED]
  src/client/ui/PuffdexView.luau → tools/profile-recovery/recovery.luau
- `fullFloor()` --calls--> `BotGrid.key()`  [INFERRED]
  tests/BotGrid.spec.luau → src/server/data/BotGrid.luau
- `openStation()` --calls--> `PuffMachineController.show()`  [INFERRED]
  src/client/controllers/LobbyStationsController.luau → src/client/controllers/PuffMachineController.luau
- `ProgressionController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/ProgressionController.luau → src/client/notifications/NotificationManager.luau
- `PuffMomentController.start()` --calls--> `NotificationManager.init()`  [INFERRED]
  src/client/controllers/PuffMomentController.luau → src/client/notifications/NotificationManager.luau

## Import Cycles
- None detected.

## Communities (145 total, 14 thin omitted)

### Community 0 - "PuffShotRenderer.luau"
Cohesion: 0.10
Nodes (36): isVector3(), onFired(), onMessage(), PuffShotController.predict(), PuffShotController.start(), takePending(), acquireVisual(), buildBurst() (+28 more)

### Community 1 - "RoundService.luau"
Cohesion: 0.12
Nodes (27): CombatantRegistry.playersOf(), EliminationService.beginRound(), FinalChaosService.begin(), FinalChaosService.getDuration(), FinalChaosService.isRunning(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers() (+19 more)

### Community 2 - "DailyRules.luau"
Cohesion: 0.20
Nodes (13): DailyRules.applyRound(), DailyRules.assign(), DailyRules.claimDaily(), DailyRules.dayIndex(), DailyRules.ensureToday(), DailyRules.nextResetAt(), DailyRules.readChallenges(), DailyRules.readDaily() (+5 more)

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
Cohesion: 0.10
Nodes (20): 10. Tocas Seguras, 12. Segunda Chance e eliminação, 13. Espectador, 15. Momentos Puff, 18. Prestígio, 21. Coleções e Barão, 22. Puff Machine, 24. Conquistas secretas (+12 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.23
Nodes (12): assignActiveSpawn(), destroyOwnedChild(), getActiveSpawn(), getHorizontalDistance(), getLivingRoot(), getLobbySlots(), getOccupiedPositions(), isOwned() (+4 more)

### Community 9 - "UiTheme.addCorner"
Cohesion: 0.06
Nodes (76): createBlocker(), OrientationController.start(), report(), request(), AdminPanelView.new(), constrainText(), createSection(), createTextBox() (+68 more)

### Community 17 - "Estado atual"
Cohesion: 0.05
Nodes (44): Alertas, Momentos Puff e telemetria dos segredos (Fase 2, entrega 2.4), Armadilhas do Casarão e Janela Ventania (Fase 5, entregas 5.1 e 5.2), Artes da loja, Barão e Tocas Seguras (Fase 2, entrega 2.2), Barão maior, animado e com túnel entre os corredores (Fase 4, ajuste pós-4.5), Bots RoboPuff (Fase 5B), Comandos de teste da partida (painel admin), Controles e mira (Fase 1, entrega 1.5) (+36 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "ProfileSchema.luau"
Cohesion: 0.22
Nodes (14): DailyRules.emptyDaily(), cleanLarge(), cleanNumber(), ProfileSchema.clampDelta(), ProfileSchema.default(), ProfileSchema.emptyStats(), ProfileSchema.fromStored(), ProfileSchema.storedSession() (+6 more)

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
Nodes (44): buildLights(), buildLockers(), buildPaneling(), buildPedestal(), buildShell(), buildVaultDisk(), decor(), SecretRoomBuilder.build() (+36 more)

### Community 31 - "ProfileController.luau"
Cohesion: 0.21
Nodes (9): LeaderboardController.start(), isChallengeId(), parse(), parseAward(), parseChallenges(), parseDaily(), parseDailyReward(), ProfileController.start() (+1 more)

### Community 32 - "PuffadorModel.luau"
Cohesion: 0.50
Nodes (6): addPart(), buildBody(), buildGrip(), buildMuzzle(), buildTank(), tube()

### Community 33 - "RewardRules.rollMachine"
Cohesion: 0.70
Nodes (4): isEpicOrBetter(), RewardRules.rollMachine(), RewardRules.ticketsForRound(), rollRarity()

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
Cohesion: 0.14
Nodes (29): computeVelocity(), deliver(), isActiveParticipant(), KnockbackService.beginRound(), KnockbackService.endRound(), KnockbackService.markAttacker(), KnockbackService.slide(), KnockbackService.start() (+21 more)

### Community 54 - "CharacterImpulse.luau"
Cohesion: 0.13
Nodes (24): aliveCharacter(), DashController.dash(), DashController.start(), dashDirection(), applyKnockback(), applySlide(), getRoot(), isFiniteVector() (+16 more)

### Community 56 - "Part"
Cohesion: 0.31
Nodes (4): make_parts(), Part, Deterministic, editable Barão mesh source. Uses existing NumPy and Pillow only., uv()

### Community 57 - "ProfileGuard.luau"
Cohesion: 0.36
Nodes (7): isTable(), mergePuffs(), mergeStats(), number(), numberOr(), profile(), puff()

### Community 58 - "ArenaService.luau"
Cohesion: 0.05
Nodes (63): isWet(), refreshRain(), SlipperyController.start(), step(), watch(), ArenaService.addDestroyedListener(), ArenaService.beginRound(), ArenaService.collapseBlock() (+55 more)

### Community 59 - "LocaleCore.luau"
Cohesion: 0.14
Nodes (19): localizeProperty(), watch(), WorldTextLocalizer.start(), compiled(), Lang.current(), Lang.forPlayer(), Lang.languageOf(), Lang.localize() (+11 more)

### Community 60 - "v002/source/build_model.py"
Cohesion: 0.15
Nodes (15): parts(), Barão v002: shaped ears, fitted jersey, expressive muzzle and continuous paws., rotation_z(), export_glb(), tangents(), normalize(), Part, Small surface builders for the editable Barão model (Y up, forward -Z). (+7 more)

### Community 61 - "LeaderboardService.luau"
Cohesion: 0.28
Nodes (9): emptyBoards(), flushAll(), flushUser(), handleFailure(), LeaderboardService.start(), publish(), readBoard(), refresh() (+1 more)

### Community 62 - "BotBody.luau"
Cohesion: 0.52
Nodes (6): addAntenna(), animate(), BotBody.build(), describe(), dress(), giveServerPhysics()

### Community 63 - "PuffMomentController.luau"
Cohesion: 0.67
Nodes (3): describe(), onMoment(), PuffMomentController.start()

### Community 67 - "HudController.luau"
Cohesion: 0.20
Nodes (13): clearAnnouncement(), connectAttribute(), formatMinutesSeconds(), getPersonalScoreSummary(), HudController.start(), render(), renderActive(), renderCountdown() (+5 more)

### Community 68 - "NotificationManager.notify"
Cohesion: 0.23
Nodes (14): BaraoController.start(), onFeedback(), seconds(), finishCurrent(), insertSorted(), maxWait(), NotificationManager.clear(), NotificationManager.init() (+6 more)

### Community 69 - "celebrate"
Cohesion: 0.25
Nodes (8): celebrate(), ChallengesController.show(), ChallengesController.start(), challengeTickets(), challengeTitle(), LobbyStationsController.start(), openStation(), PuffdexController.show()

### Community 72 - "VaultController.luau"
Cohesion: 0.40
Nodes (3): banner(), playAlarm(), playSound()

### Community 74 - "grant"
Cohesion: 0.23
Nodes (11): parseSecrets(), createLobbyPuff(), grant(), SecretAchievementService.baraoEvent(), SecretAchievementService.beginRound(), SecretAchievementService.corridorEntered(), SecretAchievementService.passageRevealed(), SecretAchievementService.roundFinished() (+3 more)

### Community 75 - "PuffMachineController.start"
Cohesion: 0.21
Nodes (8): celebrate(), PuffdexController.markNew(), PuffdexController.start(), send(), parseReveal(), PuffMachineController.show(), PuffMachineController.start(), send()

### Community 78 - "BlocoPuff!"
Cohesion: 0.17
Nodes (12): Atualização futura, BlocoPuff!, Build local, Configuração do PATH por shell, Estrutura, Grafo de conhecimento (graphify), Instalação inicial no macOS, Plugin do Rojo no Roblox Studio (+4 more)

### Community 79 - "Instruções para agentes"
Cohesion: 0.18
Nodes (8): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify

### Community 80 - "TelemetryService.luau"
Cohesion: 0.21
Nodes (17): elapsed(), getCounters(), getDevice(), getFloor(), getZone(), log(), logTickets(), sampleFloors() (+9 more)

### Community 81 - "OnboardingRules.luau"
Cohesion: 0.17
Nodes (9): bitOf(), OnboardingRules.has(), OnboardingRules.initial(), OnboardingRules.mark(), OnboardingRules.stepsFromProfile(), mark(), OnboardingService.start(), onProfile() (+1 more)

### Community 82 - "MatchQueueController.luau"
Cohesion: 0.44
Nodes (7): banner(), connectTrampoline(), MatchQueueController.start(), onMessage(), playSound(), watchCountdown(), watchQueue()

### Community 83 - "MatchQueueService.luau"
Cohesion: 0.20
Nodes (18): isCompeting(), livingRoot(), MatchQueueService.count(), MatchQueueService.queuedPlayers(), MatchQueueService.refresh(), MatchQueueService.setBotCount(), MatchQueueService.setCountdown(), MatchQueueService.setOpen() (+10 more)

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
Cohesion: 0.43
Nodes (7): ArenaService.getModel(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop(), isOwned()

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

### Community 102 - "ProgressionController.luau"
Cohesion: 0.67
Nodes (3): announce(), playLevelUp(), ProgressionController.start()

### Community 103 - "RoundStatsService.luau"
Cohesion: 0.20
Nodes (16): participantMultiplier(), XpCalculator.compute(), commitProfiles(), isBeginner(), recordComeback(), add(), empty(), RoundStatsService.baraoEscape() (+8 more)

### Community 104 - "BotFillService.luau"
Cohesion: 0.08
Nodes (33): BaraoTensionController.start(), startTension(), stopTension(), thump(), watch(), BotFillRules.adjustment(), BotFillRules.canFill(), BotFillRules.desiredBots() (+25 more)

### Community 106 - "WindowTrapFx.new"
Cohesion: 0.14
Nodes (22): getEffectsFolder(), step(), track(), TrapVisualController.start(), untrack(), ChandelierTrapFx.new(), vectorAttribute(), FireplaceTrapFx.new() (+14 more)

### Community 107 - "Fase 5C — Casarão Vivo: explorar, descobrir, colecionar"
Cohesion: 0.11
Nodes (17): 5C.1 Ficha da Partida, portas e cômodos novos, 5C.2 Relíquias e o Álbum do Casarão, 5C.3 Mistérios do Barão, 5C.4 Vida e eventos no Casarão, Arquitetura técnica, Critérios de aceite, Escopo, Fase 5C — Casarão Vivo: explorar, descobrir, colecionar (+9 more)

### Community 108 - "Lang.t"
Cohesion: 0.08
Nodes (51): banner(), canInvite(), InviteController.invite(), onReward(), readCount(), report(), addLamp(), buildBaraoDoor() (+43 more)

### Community 109 - "Fase 5B — Bots Puff: nunca jogar sozinho"
Cohesion: 0.11
Nodes (17): 5B.1 Identidade de combatente (refatoração, sem mudança visível), 5B.2 Corpo do RoboPuff e preenchimento da fila, 5B.3 O bot sofre o jogo como qualquer um, 5B.4 Cérebro do RoboPuff, 5B.5 Recompensas e anti-farm, 5B.6 Telemetria, Critérios de aceite, Escopo (+9 more)

### Community 112 - "PuffadorService.luau"
Cohesion: 0.06
Nodes (47): MatchQueueService.isBoardingOpen(), MatchQueueService.isInZone(), MatchQueueService.setWarmupLine(), broadcast(), isOwned(), notifyHit(), ProjectileService.clearAll(), ProjectileService.clearFor() (+39 more)

### Community 113 - "TelemetryService.lobbyEvent"
Cohesion: 0.18
Nodes (14): parseNewPuffs(), parsePuffs(), grantPuffs(), equip(), onRequest(), throttled(), onClientReport(), TelemetryService.lobbyEvent() (+6 more)

### Community 116 - "CombatantRegistry.luau"
Cohesion: 0.13
Nodes (25): ArenaService.getSafeRespawnCFrame(), attributeHolder(), CombatantRegistry.all(), CombatantRegistry.forPlayer(), CombatantRegistry.forPlayers(), CombatantRegistry.fromCharacter(), CombatantRegistry.getAttribute(), CombatantRegistry.getBots() (+17 more)

### Community 121 - "ReferralService.luau"
Cohesion: 0.20
Nodes (16): ProfileSchema.withTickets(), ReferralRules.addPending(), ReferralRules.canRecordInviter(), ReferralRules.inviterGrant(), ReferralRules.readPending(), claimPending(), creditInviter(), grantInviter() (+8 more)

### Community 123 - "PhotoModeService.luau"
Cohesion: 0.24
Nodes (16): applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot(), getScene() (+8 more)

### Community 124 - "PlayerDataService.luau"
Cohesion: 0.19
Nodes (10): DataStoreErrors.isStudioAccessDenied(), ProfileSchema.toStored(), isNewerFormat(), nonEmpty(), normalize(), now(), rebuild(), reportGuard() (+2 more)

### Community 125 - "onRequestBuild"
Cohesion: 0.36
Nodes (6): findTarget(), getRoot(), isFiniteVector3(), isOccupied(), onRequestBuild(), playBuildSound()

### Community 127 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 129 - "LevelCurve.luau"
Cohesion: 0.60
Nodes (5): LevelCurve.levelForXp(), LevelCurve.maxXp(), LevelCurve.progress(), LevelCurve.totalXpForLevel(), LevelCurve.xpForNextLevel()

### Community 131 - "BuildTargeting.luau"
Cohesion: 0.80
Nodes (4): BuildTargeting.cellAt(), BuildTargeting.cellCenter(), BuildTargeting.findTarget(), gridOrigin()

### Community 132 - "TrapService.luau"
Cohesion: 0.10
Nodes (35): CombatantRegistry.isPresent(), blockAt(), buildChandelier(), cellKey(), ChandelierTrap.build(), ChandelierTrap.clear(), ChandelierTrap.dependentOn(), ChandelierTrap.restore() (+27 more)

### Community 141 - "ReactionService.luau"
Cohesion: 0.52
Nodes (6): isCompeting(), isMatchActive(), isWatching(), onRequest(), ReactionService.start(), throttled()

### Community 142 - "pull"
Cohesion: 0.60
Nodes (5): isCompeting(), onRequest(), PuffMachineService.start(), pull(), readRequestId()

### Community 145 - "DashService.luau"
Cohesion: 0.50
Nodes (3): DashService.forgetBot(), isAlive(), onDash()

## Knowledge Gaps
- **255 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+250 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Lang.t()` connect `Lang.t` to `celebrate`, `ProgressionController.luau`, `UiTheme.addCorner`, `WindowTrapFx.new`, `PuffMachineController.start`, `PuffadorService.luau`, `BuildingDecor.createPart`, `LocaleCore.luau`, `VaultService.luau`?**
  _High betweenness centrality (0.155) - this node is a cross-community bridge._
- **Why does `TelemetryService.lobbyEvent()` connect `TelemetryService.lobbyEvent` to `DailyRules.luau`, `BotFillService.luau`, `grant`, `Lang.t`, `ReactionService.luau`, `pull`, `TelemetryService.luau`, `DashService.luau`, `PuffadorService.luau`, `MatchQueueService.luau`, `PlayerDataService.luau`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Why does `PuffCatalog.get()` connect `TelemetryService.lobbyEvent` to `PuffShotRenderer.luau`, `UiTheme.addCorner`, `PuffMachineController.start`, `PuffadorService.luau`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Are the 37 inferred relationships involving `Lang.t()` (e.g. with `celebrate()` and `InviteController.invite()`) actually correct?**
  _`Lang.t()` has 37 INFERRED edges - model-reasoned connections that need verification._
- **Are the 19 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 19 INFERRED edges - model-reasoned connections that need verification._
- **Are the 25 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminPanelView.new()` and `createSection()`) actually correct?**
  _`UiTheme.addCorner()` has 25 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _255 weakly-connected nodes found - possible documentation gaps or missing edges._