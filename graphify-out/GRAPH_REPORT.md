# Graph Report - blocopuff  (2026-08-17)

## Corpus Check
- 34 files · ~18,619 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 245 nodes · 426 edges · 23 communities
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 47 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bc69e268`
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
- WorldVisualService.luau
- CombatCameraController.luau
- CrosshairView.new
- RoundHudView.new

## God Nodes (most connected - your core abstractions)
1. `beginRound()` - 12 edges
2. `refreshSpectator()` - 11 edges
3. `runEnding()` - 11 edges
4. `BlocoPuff!` - 10 edges
5. `setAttribute()` - 10 edges
6. `AnnouncementView.new()` - 9 edges
7. `SpectatorView.new()` - 8 edges
8. `RoundService.stop()` - 8 edges
9. `PuffadorController.start()` - 7 edges
10. `UiTheme.addCorner()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `PuffadorController.start()` --calls--> `CrosshairView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/CrosshairView.luau
- `PuffadorController.start()` --calls--> `FireButtonView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/FireButtonView.luau
- `HudView.new()` --calls--> `RoundHudView.new()`  [INFERRED]
  src/client/ui/HudView.luau → src/client/ui/RoundHudView.luau
- `beginRound()` --calls--> `ArenaService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/ArenaService.luau
- `RoundService.stop()` --calls--> `ArenaService.endRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/ArenaService.luau

## Import Cycles
- None detected.

## Communities (23 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.10
Nodes (34): ArenaService.getPlayerSpawnCFrames(), computeSpawnCFrames(), EliminationService.beginRound(), LobbyService.getReturnCFrame(), PuffadorService.beginRound(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers() (+26 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.15
Nodes (22): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+14 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.15
Nodes (16): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.restoreAllBlocks(), ArenaService.tryDestroyBlock(), createArenaVisuals(), createCollapseEffect() (+8 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.19
Nodes (20): clearToolEquipped(), connectRemotes(), findToolSound(), getAimResult(), getAimTarget(), isActiveArenaTarget(), isFiniteNumber(), isFiniteVector3() (+12 more)

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
Cohesion: 0.20
Nodes (15): AnnouncementView.new(), getToneColor(), CombatHudView.new(), createLabel(), createPanelRoot(), HudView.new(), ResponsiveScale.attach(), createButton() (+7 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.08
Nodes (21): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+13 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.50
Nodes (7): createCloud(), createCloudPart(), destroyOwned(), isOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "CombatCameraController.luau"
Cohesion: 0.39
Nodes (5): CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), onRenderStep(), updateCharacterFacing()

### Community 21 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

### Community 22 - "RoundHudView.new"
Cohesion: 0.83
Nodes (3): createAnimationGroup(), createTextLabel(), RoundHudView.new()

## Knowledge Gaps
- **18 isolated node(s):** `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)`, `Pré-requisitos`, `Instalação inicial no macOS` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `runEnding()` connect `RoundService.luau` to `PuffadorService.luau`, `ArenaService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._
- **Why does `beginRound()` connect `RoundService.luau` to `ArenaService.luau`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `runEnding()` (e.g. with `ArenaService.endRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`runEnding()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RoundService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.10384068278805121 - nodes in this community are weakly interconnected._
- **Should `BlocoPuff!` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._