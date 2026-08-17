# Graph Report - blocopuff  (2026-08-17)

## Corpus Check
- 26 files · ~13,614 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 198 nodes · 337 edges · 18 communities
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 26 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2b144cee`
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
- SpectatorView.new
- BlocoPuff!

## God Nodes (most connected - your core abstractions)
1. `refreshSpectator()` - 12 edges
2. `beginRound()` - 12 edges
3. `runEnding()` - 11 edges
4. `setAttribute()` - 10 edges
5. `BlocoPuff!` - 10 edges
6. `RoundService.stop()` - 8 edges
7. `runRoundLifecycle()` - 7 edges
8. `Instruções para agentes` - 7 edges
9. `cycleTarget()` - 6 edges
10. `SpectatorController.start()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `beginRound()` --calls--> `ArenaService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/ArenaService.luau
- `beginRound()` --calls--> `EliminationService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/EliminationService.luau
- `SpectatorController.start()` --calls--> `SpectatorView.new()`  [INFERRED]
  src/client/controllers/SpectatorController.luau → src/client/ui/SpectatorView.luau
- `teleportParticipantsToArena()` --calls--> `ArenaService.getPlayerSpawnCFrames()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/ArenaService.luau
- `updateProjectiles()` --calls--> `ArenaService.tryDestroyBlock()`  [INFERRED]
  src/server/services/ProjectileService.luau → src/server/services/ArenaService.luau

## Import Cycles
- None detected.

## Communities (18 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.12
Nodes (31): ArenaService.endRound(), ArenaService.restoreAllBlocks(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer(), disconnectParticipantDeathHandlers() (+23 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.15
Nodes (23): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.spawn(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+15 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.16
Nodes (13): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), computeSpawnCFrames(), destroyOwnedChild(), getArenaColors() (+5 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.29
Nodes (16): connectContainerAttribute(), cycleTarget(), formatActiveCount(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep() (+8 more)

### Community 4 - "HudController.luau"
Cohesion: 0.21
Nodes (9): connectAttribute(), formatMinutesSeconds(), HudController.start(), render(), applyCorner(), applyStroke(), createBadge(), createLabel() (+1 more)

### Community 5 - "PuffadorController.luau"
Cohesion: 0.22
Nodes (12): computeAimDirection(), getAimScreenPoint(), isFiniteVector3(), onToolActivated(), PuffadorController.start(), scanExistingChildren(), startCrosshairTracking(), stopCrosshairTracking() (+4 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.27
Nodes (12): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId(), ReplicatedStateService.setRoundState() (+4 more)

### Community 7 - "EliminationService.luau"
Cohesion: 0.29
Nodes (10): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.beginRound(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop() (+2 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.39
Nodes (7): assignLobbySpawn(), createPart(), destroyOwnedChild(), isOwned(), LobbyService.create(), LobbyService.destroy(), LobbyService.getReturnCFrame()

### Community 9 - "SpectatorView.new"
Cohesion: 1.00
Nodes (3): applyCorner(), createButton(), SpectatorView.new()

### Community 17 - "BlocoPuff!"
Cohesion: 0.08
Nodes (21): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+13 more)

## Knowledge Gaps
- **18 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `runEnding()` connect `RoundService.luau` to `PuffadorService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **Why does `beginRound()` connect `RoundService.luau` to `PuffadorService.luau`, `ArenaService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Why does `returnParticipantsToLobby()` connect `RoundService.luau` to `LobbyService.luau`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `beginRound()` (e.g. with `ArenaService.beginRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`beginRound()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `runEnding()` (e.g. with `ArenaService.endRound()` and `ArenaService.restoreAllBlocks()`) actually correct?**
  _`runEnding()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RoundService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.1226890756302521 - nodes in this community are weakly interconnected._