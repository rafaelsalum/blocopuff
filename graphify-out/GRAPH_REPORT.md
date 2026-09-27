# Graph Report - blocopuff  (2026-09-27)

## Corpus Check
- 64 files · ~57,046 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 642 nodes · 1115 edges · 55 communities (47 shown, 8 thin omitted)
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 173 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `06b94aec`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- RoundService.luau
- PuffadorService.luau
- ArenaService.luau
- SpectatorController.luau
- HudController.luau
- PuffadorController.luau
- ReplicatedStateService.luau
- BlocoPuff — Game Design Document
- LobbyService.luau
- UiTheme.addCorner
- BlocoPuff!
- WorldVisualService.luau
- AdminService.luau
- AdminController.luau
- BlockCollapseController.luau
- BuildingDecor.createPart
- MusicController.luau
- PhotoModeService.luau
- Escopo
- VaultService.luau
- BuildingService.luau
- PuffadorModel.luau
- VaultController.luau
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

## God Nodes (most connected - your core abstractions)
1. `BlocoPuff — Game Design Document` - 36 edges
2. `BuildingDecor.createPart()` - 18 edges
3. `UiTheme.addCorner()` - 15 edges
4. `AdminPanelView.new()` - 14 edges
5. `beginRound()` - 14 edges
6. `runEnding()` - 14 edges
7. `RoundHudView.new()` - 13 edges
8. `UiTheme.stylePanel()` - 13 edges
9. `Escopo` - 12 edges
10. `Escopo` - 12 edges

## Surprising Connections (you probably didn't know these)
- `trySecondChance()` --calls--> `ArenaService.getSafeRespawnCFrame()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/ArenaService.luau
- `beginRound()` --calls--> `EliminationService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/EliminationService.luau
- `KnockbackService.start()` --calls--> `ProjectileService.setCharacterHitHandler()`  [INFERRED]
  src/server/services/KnockbackService.luau → src/server/services/ProjectileService.luau
- `onHeartbeat()` --calls--> `PuffadorService.hasSuper()`  [INFERRED]
  src/server/services/VaultService.luau → src/server/services/PuffadorService.luau
- `AdminController.start()` --calls--> `AdminBroadcastView.new()`  [INFERRED]
  src/client/controllers/AdminController.luau → src/client/ui/AdminBroadcastView.luau

## Import Cycles
- None detected.

## Communities (55 total, 8 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.08
Nodes (49): ArenaService.endRound(), ArenaService.restoreAllBlocks(), FinalChaosService.begin(), FinalChaosService.getDuration(), FinalChaosService.isRunning(), FinalChaosService.stop(), pickRandom(), computeVelocity() (+41 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.19
Nodes (13): buildPuffadorTool(), consumeSuperCharge(), grantToolToPlayer(), isFiniteNumber(), isFiniteVector3(), isOwned(), PuffadorService.endRound(), PuffadorService.hasSuper() (+5 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.08
Nodes (32): ArenaService.beginRound(), ArenaService.collapseBlock(), ArenaService.create(), ArenaService.destroy(), ArenaService.getBlocks(), ArenaService.getIntactBlocks(), ArenaService.getNeighborBlock(), ArenaService.getPlayerSpawnCFrames() (+24 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.32
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.12
Nodes (31): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+23 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.26
Nodes (13): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setFinalChaos(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId() (+5 more)

### Community 7 - "BlocoPuff — Game Design Document"
Cohesion: 0.09
Nodes (22): 10. Tocas Seguras, 12. Segunda Chance e eliminação, 13. Espectador, 15. Momentos Puff, 18. Prestígio, 21. Coleções e Barão, 22. Puff Machine, 24. Conquistas secretas (+14 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.21
Nodes (19): assignActiveSpawn(), createSpawn(), destroyOwnedChild(), getActiveSpawn(), getGallerySlots(), getHorizontalDistance(), getLivingRoot(), getOccupiedPositions() (+11 more)

### Community 9 - "UiTheme.addCorner"
Cohesion: 0.10
Nodes (39): AdminBroadcastView.new(), AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), CombatHudView.new() (+31 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.07
Nodes (27): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+19 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 22 - "BlockCollapseController.luau"
Cohesion: 0.35
Nodes (9): BlockCollapseController.start(), clearWarning(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), showWarning(), unwatchBlock() (+1 more)

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.17
Nodes (25): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+17 more)

### Community 28 - "PhotoModeService.luau"
Cohesion: 0.27
Nodes (15): applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot(), getScene() (+7 more)

### Community 29 - "Escopo"
Cohesion: 0.10
Nodes (20): 10. Espectador social, 11. Trading — preparação, não ativação, 1. Puffdex, 2. Primeira coleção, 3. Equipamento cosmético, 4. Puff Machine, 5. Desafios, 6. Retorno diário (+12 more)

### Community 30 - "VaultService.luau"
Cohesion: 0.12
Nodes (37): ProjectileService.setCharacterHitHandler(), SecretRoomBuilder.getFrame(), SecretRoomBuilder.getPedestalTop(), attachToPanel(), createAlarm(), createGlow(), createPanel(), createPrompt() (+29 more)

### Community 31 - "BuildingService.luau"
Cohesion: 0.31
Nodes (5): along(), createBox(), createSolid(), destroyOwnedChild(), isOwned()

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

## Knowledge Gaps
- **157 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+152 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `BuildingDecor.createPart()` connect `BuildingDecor.createPart` to `VaultService.luau`, `BuildingService.luau`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `runEnding()` connect `RoundService.luau` to `PuffadorService.luau`, `EliminationService.luau`, `VaultService.luau`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `buildVaultDisk()`) actually correct?**
  _`BuildingDecor.createPart()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addCorner()` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `AdminPanelView.new()` (e.g. with `UiKit.createButton()` and `UiKit.createWordmark()`) actually correct?**
  _`AdminPanelView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _157 weakly-connected nodes found - possible documentation gaps or missing edges._