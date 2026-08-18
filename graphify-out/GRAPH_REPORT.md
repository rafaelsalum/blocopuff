# Graph Report - blocopuff  (2026-08-17)

## Corpus Check
- 41 files · ~24,368 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 287 nodes · 541 edges · 25 communities
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 86 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9263c7ff`
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

## God Nodes (most connected - your core abstractions)
1. `UiTheme.addCorner()` - 15 edges
2. `UiTheme.addStroke()` - 13 edges
3. `beginRound()` - 12 edges
4. `refreshSpectator()` - 11 edges
5. `runEnding()` - 11 edges
6. `setAttribute()` - 10 edges
7. `BlocoPuff!` - 10 edges
8. `PuffadorController.start()` - 9 edges
9. `AdminPanelView.new()` - 9 edges
10. `AnnouncementView.new()` - 9 edges

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

## Communities (25 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.13
Nodes (30): ArenaService.restoreAllBlocks(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer(), disconnectParticipantDeathHandlers(), eliminateParticipant() (+22 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.14
Nodes (24): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+16 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.14
Nodes (17): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), computeSpawnCFrames(), createArenaVisuals() (+9 more)

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
Cohesion: 0.36
Nodes (8): assignLobbySpawn(), createContainmentPart(), createPart(), destroyOwnedChild(), isOwned(), LobbyService.create(), LobbyService.destroy(), LobbyService.getReturnCFrame()

### Community 9 - "UiTheme.addCorner"
Cohesion: 0.14
Nodes (26): AdminBroadcastView.new(), AdminPanelView.new(), constrainText(), createButton(), createLabel(), createTextBox(), AnnouncementView.new(), getToneColor() (+18 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.08
Nodes (22): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+14 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.67
Nodes (5): destroyOwned(), isOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "AdminService.luau"
Cohesion: 0.22
Nodes (21): createRemotes(), deliverAnnouncement(), filterText(), getFilteredReason(), getKickMessage(), getValidatedTarget(), handleAnnouncement(), handleBan() (+13 more)

### Community 21 - "AdminController.luau"
Cohesion: 0.60
Nodes (4): AdminController.start(), buildPlayerEntries(), getRemote(), refreshPlayers()

### Community 22 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

## Knowledge Gaps
- **18 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PuffadorController.start()` connect `PuffadorController.luau` to `UiTheme.addCorner`, `CrosshairView.new`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `runEnding()` connect `RoundService.luau` to `PuffadorService.luau`, `ArenaService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `SpectatorView.new()` connect `UiTheme.addCorner` to `SpectatorController.luau`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Are the 13 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addCorner()` has 13 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `UiTheme.addStroke()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addStroke()` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `runEnding()` (e.g. with `ArenaService.endRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`runEnding()` has 4 INFERRED edges - model-reasoned connections that need verification._