# Graph Report - blocopuff  (2026-08-17)

## Corpus Check
- 34 files · ~19,057 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 246 nodes · 444 edges · 20 communities
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 63 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b1c43333`
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

## God Nodes (most connected - your core abstractions)
1. `beginRound()` - 12 edges
2. `refreshSpectator()` - 11 edges
3. `runEnding()` - 11 edges
4. `UiTheme.addCorner()` - 10 edges
5. `setAttribute()` - 10 edges
6. `BlocoPuff!` - 10 edges
7. `AnnouncementView.new()` - 9 edges
8. `RoundHudView.new()` - 9 edges
9. `PuffadorController.start()` - 8 edges
10. `SpectatorView.new()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `beginRound()` --calls--> `EliminationService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/EliminationService.luau
- `playLocalShotFeedback()` --calls--> `CombatCameraController.addRecoil()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/controllers/CombatCameraController.luau
- `PuffadorController.start()` --calls--> `CrosshairView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/CrosshairView.luau
- `PuffadorController.start()` --calls--> `FireButtonView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/FireButtonView.luau
- `SpectatorController.start()` --calls--> `SpectatorView.new()`  [INFERRED]
  src/client/controllers/SpectatorController.luau → src/client/ui/SpectatorView.luau

## Import Cycles
- None detected.

## Communities (20 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.12
Nodes (31): ArenaService.endRound(), ArenaService.restoreAllBlocks(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer(), disconnectParticipantDeathHandlers() (+23 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.15
Nodes (23): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+15 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.15
Nodes (16): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), computeSpawnCFrames(), createArenaVisuals(), createCollapseEffect() (+8 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.15
Nodes (25): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), onRenderStep(), updateCharacterFacing(), clearToolEquipped(), connectRemotes() (+17 more)

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
Nodes (22): AnnouncementView.new(), getToneColor(), CombatHudView.new(), createLabel(), createPanelRoot(), addCorner(), createHitLine(), CrosshairView.new() (+14 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.08
Nodes (21): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+13 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.50
Nodes (7): createCloud(), createCloudPart(), destroyOwned(), isOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

## Knowledge Gaps
- **18 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `runEnding()` connect `RoundService.luau` to `PuffadorService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Why does `PuffadorController.start()` connect `PuffadorController.luau` to `UiTheme.addCorner`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `SpectatorView.new()` connect `UiTheme.addCorner` to `SpectatorController.luau`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `runEnding()` (e.g. with `ArenaService.endRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`runEnding()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AnnouncementView.new()` and `CombatHudView.new()`) actually correct?**
  _`UiTheme.addCorner()` has 8 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._