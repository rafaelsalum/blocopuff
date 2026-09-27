# Graph Report - blocopuff  (2026-09-27)

## Corpus Check
- 48 files · ~33,952 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 349 nodes · 685 edges · 28 communities
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 125 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `389b4cfb`
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
- `PuffadorController.start()` --calls--> `FeedbackView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/FeedbackView.luau

## Import Cycles
- None detected.

## Communities (28 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.12
Nodes (30): ArenaService.endRound(), ArenaService.restoreAllBlocks(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer(), disconnectParticipantDeathHandlers() (+22 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.14
Nodes (25): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+17 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.16
Nodes (14): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), createArenaVisuals(), destroyOwnedChild(), getFloorStyle() (+6 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.12
Nodes (31): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), getSafeShoulderOffset(), lockZoom(), onRenderStep(), restoreZoom() (+23 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.27
Nodes (12): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId(), ReplicatedStateService.setRoundState() (+4 more)

### Community 7 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.beginRound(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.29
Nodes (13): assignActiveSpawn(), createSpawn(), destroyOwnedChild(), getActiveSpawn(), getGallerySlots(), getLivingRoot(), isActiveCompetitor(), isOwned() (+5 more)

### Community 9 - "AdminPanelView.new"
Cohesion: 0.11
Nodes (35): AdminBroadcastView.new(), AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), CombatHudView.new() (+27 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.07
Nodes (24): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+16 more)

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

## Knowledge Gaps
- **20 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+15 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PuffadorController.start()` connect `PuffadorController.luau` to `AdminPanelView.new`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `SpectatorView.new()` connect `AdminPanelView.new` to `SpectatorController.luau`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Why does `RoundService.stop()` connect `RoundService.luau` to `LobbyService.luau`, `PuffadorService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createFillLights()` and `createSolid()`) actually correct?**
  _`BuildingDecor.createPart()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `AdminPanelView.new()` (e.g. with `UiKit.createButton()` and `UiKit.createWordmark()`) actually correct?**
  _`AdminPanelView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `RoundHudView.new()` (e.g. with `HudView.new()` and `UiKit.createWordmark()`) actually correct?**
  _`RoundHudView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addCorner()` has 10 INFERRED edges - model-reasoned connections that need verification._