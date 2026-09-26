# Graph Report - blocopuff  (2026-09-26)

## Corpus Check
- 44 files · ~28,731 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 321 nodes · 622 edges · 27 communities
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 98 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5ed9657e`
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
- EliminationService.luau
- LobbyService.luau
- UiTheme.addCorner
- BlocoPuff!
- WorldVisualService.luau
- AdminService.luau
- AdminController.luau
- CrosshairView.new
- BuildingDecor.luau

## God Nodes (most connected - your core abstractions)
1. `UiTheme.addCorner()` - 15 edges
2. `BuildingDecor.createPart()` - 14 edges
3. `UiTheme.addStroke()` - 13 edges
4. `beginRound()` - 12 edges
5. `refreshSpectator()` - 11 edges
6. `runEnding()` - 11 edges
7. `setAttribute()` - 10 edges
8. `BlocoPuff!` - 10 edges
9. `PuffadorController.start()` - 9 edges
10. `AdminPanelView.new()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `beginRound()` --calls--> `EliminationService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/EliminationService.luau
- `AdminController.start()` --calls--> `AdminBroadcastView.new()`  [INFERRED]
  src/client/controllers/AdminController.luau → src/client/ui/AdminBroadcastView.luau
- `playLocalShotFeedback()` --calls--> `CombatCameraController.addRecoil()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/controllers/CombatCameraController.luau
- `PuffadorController.start()` --calls--> `ControlHintView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/ControlHintView.luau
- `PuffadorController.start()` --calls--> `CrosshairView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/CrosshairView.luau

## Import Cycles
- None detected.

## Communities (27 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.12
Nodes (30): ArenaService.endRound(), ArenaService.restoreAllBlocks(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer(), disconnectParticipantDeathHandlers() (+22 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.14
Nodes (24): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+16 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.15
Nodes (15): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), createArenaVisuals(), createCollapseEffect(), destroyOwnedChild() (+7 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.15
Nodes (26): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), onRenderStep(), updateCharacterFacing(), clearToolEquipped(), connectRemotes() (+18 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.27
Nodes (12): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId(), ReplicatedStateService.setRoundState() (+4 more)

### Community 7 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.beginRound(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.29
Nodes (13): assignActiveSpawn(), createSpawn(), destroyOwnedChild(), getActiveSpawn(), getGallerySlots(), getLivingRoot(), isActiveCompetitor(), isOwned() (+5 more)

### Community 9 - "UiTheme.addCorner"
Cohesion: 0.14
Nodes (26): AdminBroadcastView.new(), AdminPanelView.new(), constrainText(), createButton(), createLabel(), createTextBox(), AnnouncementView.new(), getToneColor() (+18 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.08
Nodes (23): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+15 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.60
Nodes (5): applyInteriorLighting(), destroyOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 22 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

### Community 25 - "BuildingDecor.luau"
Cohesion: 0.17
Nodes (25): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+17 more)

## Knowledge Gaps
- **19 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+14 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PuffadorController.start()` connect `PuffadorController.luau` to `UiTheme.addCorner`, `CrosshairView.new`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `RoundService.stop()` connect `RoundService.luau` to `LobbyService.luau`, `PuffadorService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `runEnding()` connect `RoundService.luau` to `LobbyService.luau`, `PuffadorService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Are the 13 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addCorner()` has 13 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `decorateArenaWalls()`) actually correct?**
  _`BuildingDecor.createPart()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `UiTheme.addStroke()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addStroke()` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 4 INFERRED edges - model-reasoned connections that need verification._