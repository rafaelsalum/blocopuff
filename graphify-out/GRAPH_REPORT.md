# Graph Report - blocopuff  (2026-08-17)

## Corpus Check
- 32 files · ~16,838 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 228 nodes · 403 edges · 19 communities
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 60 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `fbb2f58b`
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
- AnnouncementView.new
- BlocoPuff!
- CrosshairView.new

## God Nodes (most connected - your core abstractions)
1. `beginRound()` - 12 edges
2. `refreshSpectator()` - 11 edges
3. `runEnding()` - 11 edges
4. `setAttribute()` - 10 edges
5. `BlocoPuff!` - 10 edges
6. `AnnouncementView.new()` - 9 edges
7. `RoundHudView.new()` - 9 edges
8. `UiTheme.addCorner()` - 9 edges
9. `SpectatorView.new()` - 8 edges
10. `RoundService.stop()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `playLocalShotFeedback()` --calls--> `CombatCameraController.addRecoil()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/controllers/CombatCameraController.luau
- `PuffadorController.start()` --calls--> `CrosshairView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/CrosshairView.luau
- `PuffadorController.start()` --calls--> `FireButtonView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/FireButtonView.luau
- `SpectatorController.start()` --calls--> `SpectatorView.new()`  [INFERRED]
  src/client/controllers/SpectatorController.luau → src/client/ui/SpectatorView.luau
- `AnnouncementView.new()` --calls--> `UiTheme.addTextConstraint()`  [INFERRED]
  src/client/ui/AnnouncementView.luau → src/client/ui/UiTheme.luau

## Import Cycles
- None detected.

## Communities (19 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.11
Nodes (34): ArenaService.beginRound(), ArenaService.endRound(), ArenaService.restoreAllBlocks(), EliminationService.beginRound(), LobbyService.getReturnCFrame(), PuffadorService.beginRound(), beginRound(), clearRoundParticipants() (+26 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.15
Nodes (22): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+14 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.16
Nodes (13): ArenaService.create(), ArenaService.destroy(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), computeSpawnCFrames(), destroyOwnedChild(), getArenaColors(), isOwned() (+5 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.17
Nodes (20): CombatCameraController.addRecoil(), CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), onRenderStep(), updateCharacterFacing(), clearToolEquipped(), connectRemotes() (+12 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.27
Nodes (12): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId(), ReplicatedStateService.setRoundState() (+4 more)

### Community 7 - "EliminationService.luau"
Cohesion: 0.33
Nodes (9): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop(), isOwned() (+1 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.46
Nodes (6): assignLobbySpawn(), createPart(), destroyOwnedChild(), isOwned(), LobbyService.create(), LobbyService.destroy()

### Community 9 - "AnnouncementView.new"
Cohesion: 0.16
Nodes (19): AnnouncementView.new(), getToneColor(), CombatHudView.new(), createLabel(), createPanelRoot(), FireButtonView.new(), HudView.new(), ResponsiveScale.attach() (+11 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.08
Nodes (21): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+13 more)

### Community 18 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

## Knowledge Gaps
- **18 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `runEnding()` connect `RoundService.luau` to `PuffadorService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Why does `PuffadorController.start()` connect `PuffadorController.luau` to `AnnouncementView.new`, `CrosshairView.new`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **Why does `FireButtonView.new()` connect `AnnouncementView.new` to `PuffadorController.luau`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `runEnding()` (e.g. with `ArenaService.endRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`runEnding()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RoundService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._