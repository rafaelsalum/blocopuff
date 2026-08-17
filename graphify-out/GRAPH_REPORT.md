# Graph Report - blocopuff  (2026-08-17)

## Corpus Check
- 35 files · ~19,870 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 250 nodes · 419 edges · 24 communities
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 33 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6cf0754a`
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
- ProjectileService.luau
- CombatCameraController.luau
- CombatHudView.new

## God Nodes (most connected - your core abstractions)
1. `refreshSpectator()` - 11 edges
2. `BlocoPuff!` - 10 edges
3. `setAttribute()` - 10 edges
4. `beginRound()` - 9 edges
5. `runEnding()` - 8 edges
6. `AnnouncementView.new()` - 8 edges
7. `RoundHudView.new()` - 8 edges
8. `SpectatorView.new()` - 8 edges
9. `UiTheme.addCorner()` - 8 edges
10. `UiTheme.addStroke()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `beginRound()` --calls--> `PuffadorService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/PuffadorService.luau
- `PuffadorController.start()` --calls--> `ControlHintView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/ControlHintView.luau
- `runEnding()` --calls--> `PuffadorService.endRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/PuffadorService.luau
- `RoundService.stop()` --calls--> `PuffadorService.stop()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/PuffadorService.luau
- `SpectatorController.start()` --calls--> `SpectatorView.new()`  [INFERRED]
  src/client/controllers/SpectatorController.luau → src/client/ui/SpectatorView.luau

## Import Cycles
- None detected.

## Communities (24 total, 0 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.14
Nodes (28): beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer(), disconnectParticipantDeathHandlers(), eliminateParticipant(), enqueuePlayer() (+20 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.21
Nodes (15): buildPuffadorTool(), computeOrigin(), ensureRemotesContainer(), grantToolToPlayer(), incrementRoundBlocksDestroyed(), isFiniteNumber(), isFiniteVector3(), isOwned() (+7 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.14
Nodes (18): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.endRound(), ArenaService.getPlayerSpawnCFrames(), ArenaService.restoreAllBlocks(), ArenaService.tryDestroyBlock(), computeSpawnCFrames() (+10 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.31
Nodes (15): connectContainerAttribute(), cycleTarget(), getActiveParticipantList(), getHumanoid(), isActiveParticipant(), onInputBegan(), onRenderStep(), readBooleanAttribute() (+7 more)

### Community 4 - "HudController.luau"
Cohesion: 0.24
Nodes (4): clearAnnouncement(), getQueueMessage(), renderCountdown(), renderWaiting()

### Community 5 - "PuffadorController.luau"
Cohesion: 0.18
Nodes (21): clearToolEquipped(), connectRemotes(), findToolSound(), getAimResult(), getAimTarget(), getControlHintText(), isActiveArenaTarget(), isFiniteNumber() (+13 more)

### Community 6 - "ReplicatedStateService.luau"
Cohesion: 0.27
Nodes (12): isOwned(), ReplicatedStateService.clearWinner(), ReplicatedStateService.create(), ReplicatedStateService.destroy(), ReplicatedStateService.setBlockCounts(), ReplicatedStateService.setParticipantCount(), ReplicatedStateService.setRoundId(), ReplicatedStateService.setRoundState() (+4 more)

### Community 7 - "EliminationService.luau"
Cohesion: 0.29
Nodes (9): ArenaService.getModel(), checkParticipants(), createVisualZoneIfNeeded(), destroyOwnedVisual(), EliminationService.endRound(), EliminationService.start(), EliminationService.stop(), isOwned() (+1 more)

### Community 8 - "LobbyService.luau"
Cohesion: 0.36
Nodes (7): assignLobbySpawn(), createContainmentPart(), createPart(), destroyOwnedChild(), isOwned(), LobbyService.create(), LobbyService.destroy()

### Community 9 - "AnnouncementView.new"
Cohesion: 0.17
Nodes (18): AnnouncementView.new(), getToneColor(), addCorner(), createHitLine(), CrosshairView.new(), FireButtonView.new(), ResponsiveScale.attach(), createAnimationGroup() (+10 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.08
Nodes (21): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+13 more)

### Community 18 - "WorldVisualService.luau"
Cohesion: 0.50
Nodes (7): createCloud(), createCloudPart(), destroyOwned(), isOwned(), stopOwnedVisuals(), WorldVisualService.start(), WorldVisualService.stop()

### Community 20 - "ProjectileService.luau"
Cohesion: 0.36
Nodes (8): createImpactEffect(), isOwned(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt(), updateProjectiles()

### Community 21 - "CombatCameraController.luau"
Cohesion: 0.39
Nodes (5): CombatCameraController.disable(), CombatCameraController.enable(), getCharacterParts(), onRenderStep(), updateCharacterFacing()

### Community 22 - "CombatHudView.new"
Cohesion: 0.47
Nodes (4): CombatHudView.new(), createLabel(), createPanelRoot(), HudView.new()

## Knowledge Gaps
- **18 isolated node(s):** `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)`, `Pré-requisitos`, `Instalação inicial no macOS` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SpectatorView.new()` connect `AnnouncementView.new` to `SpectatorController.luau`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `SpectatorController.start()` connect `SpectatorController.luau` to `AnnouncementView.new`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `ArenaService.tryDestroyBlock()` connect `ArenaService.luau` to `ProjectileService.luau`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `Stack`, `Estrutura`, `Grafo de conhecimento (graphify)` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RoundService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.14193548387096774 - nodes in this community are weakly interconnected._
- **Should `ArenaService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.13666666666666666 - nodes in this community are weakly interconnected._
- **Should `BlocoPuff!` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._