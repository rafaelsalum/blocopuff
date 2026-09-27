# Graph Report - blocopuff  (2026-09-27)

## Corpus Check
- 49 files · ~39,405 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 374 nodes · 741 edges · 30 communities (29 shown, 1 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 128 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d78526ac`
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
- AdminPanelView.new
- BlocoPuff!
- WorldVisualService.luau
- AdminService.luau
- AdminController.luau
- BlockCollapseController.luau
- BuildingDecor.luau
- MusicController.luau
- PhotoModeService.luau
- CrosshairView.new

## God Nodes (most connected - your core abstractions)
1. `BuildingDecor.createPart()` - 15 edges
2. `AdminPanelView.new()` - 14 edges
3. `RoundHudView.new()` - 13 edges
4. `UiTheme.addCorner()` - 13 edges
5. `UiTheme.stylePanel()` - 12 edges
6. `beginRound()` - 12 edges
7. `refreshSpectator()` - 11 edges
8. `AnnouncementView.new()` - 11 edges
9. `runEnding()` - 11 edges
10. `PuffadorController.start()` - 10 edges

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

## Communities (30 total, 1 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.12
Nodes (30): ArenaService.endRound(), ArenaService.restoreAllBlocks(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer(), disconnectParticipantDeathHandlers() (+22 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.14
Nodes (25): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+17 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.17
Nodes (14): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), createArenaVisuals(), destroyOwnedChild(), getFloorStyle() (+6 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.14
Nodes (28): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+20 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.27
Nodes (12): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId(), ReplicatedStateService.setRoundState() (+4 more)

### Community 7 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.beginRound(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.20
Nodes (20): assignActiveSpawn(), createSpawn(), destroyOwnedChild(), getActiveSpawn(), getGallerySlots(), getHorizontalDistance(), getLivingRoot(), getOccupiedPositions() (+12 more)

### Community 9 - "AdminPanelView.new"
Cohesion: 0.11
Nodes (35): AdminBroadcastView.new(), AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), CombatHudView.new() (+27 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.07
Nodes (25): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+17 more)

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
Cohesion: 0.33
Nodes (6): BlockCollapseController.start(), createFragment(), emitDust(), getEffectsFolder(), playCollapse(), watchBlock()

### Community 25 - "BuildingDecor.luau"
Cohesion: 0.17
Nodes (26): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+18 more)

### Community 28 - "PhotoModeService.luau"
Cohesion: 0.25
Nodes (16): ArenaService.getBlocks(), applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot() (+8 more)

### Community 29 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

## Knowledge Gaps
- **21 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+16 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ArenaService.restoreAllBlocks()` connect `RoundService.luau` to `ArenaService.luau`, `PhotoModeService.luau`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `PuffadorController.start()` connect `PuffadorController.luau` to `AdminPanelView.new`, `CrosshairView.new`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Why does `LobbyService.returnToLobby()` connect `LobbyService.luau` to `RoundService.luau`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createFillLights()` and `createSolid()`) actually correct?**
  _`BuildingDecor.createPart()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `AdminPanelView.new()` (e.g. with `UiKit.createButton()` and `UiKit.createWordmark()`) actually correct?**
  _`AdminPanelView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `RoundHudView.new()` (e.g. with `HudView.new()` and `UiKit.createWordmark()`) actually correct?**
  _`RoundHudView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addCorner()` has 10 INFERRED edges - model-reasoned connections that need verification._