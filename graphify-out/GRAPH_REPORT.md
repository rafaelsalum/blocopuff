# Graph Report - blocopuff  (2026-09-27)

## Corpus Check
- 78 files · ~72,202 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 766 nodes · 1314 edges · 62 communities (53 shown, 9 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 178 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `05f1542c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- RoundService.luau
- PuffadorService.luau
- ArenaService.luau
- SpectatorController.luau
- NotificationManager.luau
- PuffadorController.luau
- ReplicatedStateService.luau
- BlocoPuff — Game Design Document
- LobbyService.luau
- AdminPanelView.new
- Estado atual
- WorldVisualService.luau
- AdminService.luau
- ResultsView.luau
- BlockCollapseController.luau
- BuildingDecor.createPart
- MusicController.luau
- BaraoService.luau
- Escopo
- VaultService.luau
- BuildingService.luau
- PuffadorModel.luau
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
- EliminationService.luau
- KnockbackController.luau
- TelemetryService.luau
- TelemetryController.luau
- SecretPassageService.luau
- TocaService.luau
- CorridorBuilder.luau
- BaraoModel.luau

## God Nodes (most connected - your core abstractions)
1. `BlocoPuff — Game Design Document` - 36 edges
2. `BuildingDecor.createPart()` - 22 edges
3. `beginRound()` - 16 edges
4. `AdminPanelView.new()` - 14 edges
5. `RoundHudView.new()` - 13 edges
6. `UiTheme.addCorner()` - 13 edges
7. `Estado atual` - 13 edges
8. `UiTheme.stylePanel()` - 12 edges
9. `Escopo` - 12 edges
10. `Escopo` - 12 edges

## Surprising Connections (you probably didn't know these)
- `label()` --calls--> `UiTheme.createLabel()`  [INFERRED]
  src/client/ui/ResultsView.luau → src/client/ui/UiTheme.luau
- `beginRound()` --calls--> `EliminationService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/EliminationService.luau
- `KnockbackService.start()` --calls--> `ProjectileService.setCharacterHitHandler()`  [INFERRED]
  src/server/services/KnockbackService.luau → src/server/services/ProjectileService.luau
- `onHeartbeat()` --calls--> `PuffadorService.hasSuper()`  [INFERRED]
  src/server/services/VaultService.luau → src/server/services/PuffadorService.luau
- `openVault()` --calls--> `VaultProps.startAlarm()`  [INFERRED]
  src/server/services/VaultService.luau → src/server/services/VaultProps.luau

## Import Cycles
- None detected.

## Communities (62 total, 9 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.07
Nodes (47): ArenaService.getPlayerSpawnCFrames(), ArenaService.getSafeRespawnCFrame(), FinalChaosService.begin(), FinalChaosService.getDuration(), FinalChaosService.isRunning(), computeVelocity(), isActiveParticipant(), KnockbackService.beginRound() (+39 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.12
Nodes (22): createImpactEffect(), isOwned(), notifyHit(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+14 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.08
Nodes (39): ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getBlocks(), ArenaService.getIntactBlocks(), ArenaService.getNeighborBlock() (+31 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.32
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "NotificationManager.luau"
Cohesion: 0.07
Nodes (30): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers(), BaraoController.start(), onFeedback(), seconds(), clearAnnouncement() (+22 more)

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

### Community 9 - "AdminPanelView.new"
Cohesion: 0.09
Nodes (40): AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), BannerView.new(), createBanner() (+32 more)

### Community 17 - "Estado atual"
Cohesion: 0.06
Nodes (33): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+25 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "ResultsView.luau"
Cohesion: 0.50
Nodes (3): describe(), label(), plural()

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.12
Nodes (38): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+30 more)

### Community 28 - "BaraoService.luau"
Cohesion: 0.18
Nodes (18): approach(), bark(), getRoot(), goToSleep(), isActiveParticipant(), isInDoorway(), isInNiche(), laneCenter() (+10 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.17
Nodes (27): ProjectileService.setCharacterHitHandler(), VaultProps.playSound(), VaultProps.setGlow(), VaultProps.setOpen(), clearHolder(), destroyPrize(), expel(), fireAll() (+19 more)

### Community 31 - "BuildingService.luau"
Cohesion: 0.29
Nodes (7): along(), createBox(), createSolid(), destroyOwnedChild(), doorHole(), getDoorHoles(), isOwned()

### Community 32 - "PuffadorModel.luau"
Cohesion: 0.50
Nodes (6): addPart(), buildBody(), buildGrip(), buildMuzzle(), buildTank(), tube()

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

### Community 53 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.beginRound(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 54 - "KnockbackController.luau"
Cohesion: 0.52
Nodes (5): applyKnockback(), getRoot(), isFiniteVector(), onFeedback(), stopFalling()

### Community 56 - "TelemetryService.luau"
Cohesion: 0.30
Nodes (11): elapsed(), getCounters(), getDevice(), getFloor(), getZone(), log(), sampleFloors(), TelemetryService.blocksDestroyed() (+3 more)

### Community 58 - "SecretPassageService.luau"
Cohesion: 0.22
Nodes (13): ProjectileService.setSurfaceHitHandler(), collectPaintings(), hideAll(), isActiveParticipant(), onSurfaceHit(), playSound(), reveal(), SecretPassageService.beginRound() (+5 more)

### Community 59 - "TocaService.luau"
Cohesion: 0.33
Nodes (15): claim(), eject(), getRoot(), isActiveParticipant(), occupiedToca(), paint(), release(), send() (+7 more)

### Community 60 - "CorridorBuilder.luau"
Cohesion: 0.67
Nodes (6): addLamp(), buildOuterWall(), buildToca(), CorridorBuilder.build(), decor(), solid()

## Knowledge Gaps
- **163 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+158 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `beginRound()` connect `RoundService.luau` to `ArenaService.luau`, `EliminationService.luau`, `TelemetryService.luau`, `SecretPassageService.luau`, `TocaService.luau`, `VaultService.luau`?**
  _High betweenness centrality (0.223) - this node is a cross-community bridge._
- **Why does `FireButtonView.new()` connect `AdminPanelView.new` to `TocaService.luau`, `PuffadorController.luau`?**
  _High betweenness centrality (0.160) - this node is a cross-community bridge._
- **Why does `TocaService.beginRound()` connect `TocaService.luau` to `RoundService.luau`?**
  _High betweenness centrality (0.160) - this node is a cross-community bridge._
- **Are the 11 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decor()`) actually correct?**
  _`BuildingDecor.createPart()` has 11 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `AdminPanelView.new()` (e.g. with `UiKit.createButton()` and `UiKit.createWordmark()`) actually correct?**
  _`AdminPanelView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `RoundHudView.new()` (e.g. with `HudView.new()` and `UiKit.createWordmark()`) actually correct?**
  _`RoundHudView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._