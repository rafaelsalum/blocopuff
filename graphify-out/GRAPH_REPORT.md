# Graph Report - blocopuff  (2026-09-27)

## Corpus Check
- 55 files · ~47,313 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 440 nodes · 883 edges · 35 communities (33 shown, 2 thin omitted)
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 155 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `05d5bd2a`
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
- BlockCollapseController.luau
- BuildingDecor.createPart
- MusicController.luau
- PhotoModeService.luau
- CrosshairView.new
- VaultService.luau
- BuildingService.luau
- PuffadorModel.luau
- VaultController.luau

## God Nodes (most connected - your core abstractions)
1. `BuildingDecor.createPart()` - 18 edges
2. `UiTheme.addCorner()` - 15 edges
3. `AdminPanelView.new()` - 14 edges
4. `RoundHudView.new()` - 13 edges
5. `UiTheme.stylePanel()` - 13 edges
6. `beginRound()` - 13 edges
7. `runEnding()` - 12 edges
8. `refreshSpectator()` - 11 edges
9. `AnnouncementView.new()` - 11 edges
10. `UiTheme.addTextOutline()` - 11 edges

## Surprising Connections (you probably didn't know these)
- `beginRound()` --calls--> `EliminationService.beginRound()`  [INFERRED]
  src/server/services/RoundService.luau → src/server/services/EliminationService.luau
- `onHeartbeat()` --calls--> `PuffadorService.hasSuper()`  [INFERRED]
  src/server/services/VaultService.luau → src/server/services/PuffadorService.luau
- `AdminController.start()` --calls--> `AdminBroadcastView.new()`  [INFERRED]
  src/client/controllers/AdminController.luau → src/client/ui/AdminBroadcastView.luau
- `playLocalShotFeedback()` --calls--> `CombatCameraController.addRecoil()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/controllers/CombatCameraController.luau
- `PuffadorController.start()` --calls--> `ControlHintView.new()`  [INFERRED]
  src/client/controllers/PuffadorController.luau → src/client/ui/ControlHintView.luau

## Import Cycles
- None detected.

## Communities (35 total, 2 thin omitted)

### Community 0 - "RoundService.luau"
Cohesion: 0.13
Nodes (30): ArenaService.endRound(), ArenaService.restoreAllBlocks(), LobbyService.returnToLobby(), beginRound(), clearRoundParticipants(), connectParticipantDeathHandlers(), countConnectedPlayers(), dequeuePlayer() (+22 more)

### Community 1 - "PuffadorService.luau"
Cohesion: 0.12
Nodes (23): createImpactEffect(), isOwned(), notifyCharacterHit(), ProjectileService.clearAll(), ProjectileService.clearForPlayer(), ProjectileService.start(), ProjectileService.stop(), removeProjectileAt() (+15 more)

### Community 2 - "ArenaService.luau"
Cohesion: 0.15
Nodes (16): ArenaService.beginRound(), ArenaService.create(), ArenaService.destroy(), ArenaService.getNeighborBlock(), ArenaService.getPlayerSpawnCFrames(), ArenaService.tryDestroyBlock(), createArenaVisuals(), destroyOwnedChild() (+8 more)

### Community 3 - "SpectatorController.luau"
Cohesion: 0.32
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
Cohesion: 0.21
Nodes (19): assignActiveSpawn(), createSpawn(), destroyOwnedChild(), getActiveSpawn(), getGallerySlots(), getHorizontalDistance(), getLivingRoot(), getOccupiedPositions() (+11 more)

### Community 9 - "UiTheme.addCorner"
Cohesion: 0.10
Nodes (39): AdminBroadcastView.new(), AdminPanelView.new(), constrainText(), createSection(), createTextBox(), AnnouncementView.new(), getToneColor(), CombatHudView.new() (+31 more)

### Community 17 - "BlocoPuff!"
Cohesion: 0.07
Nodes (26): Arquitetura, Escopo e compatibilidade, graphify, Instruções para agentes, Linguagem e comunicação, Segurança e dependências, Validação e entrega, graphify (+18 more)

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

### Community 25 - "BuildingDecor.createPart"
Cohesion: 0.17
Nodes (25): addPointLight(), BuildingDecor.createChandelier(), BuildingDecor.createPart(), BuildingDecor.createPlant(), BuildingDecor.createSideTable(), BuildingDecor.createSofa(), BuildingDecor.decorateStory(), BuildingDecor.wallCFrame() (+17 more)

### Community 28 - "PhotoModeService.luau"
Cohesion: 0.24
Nodes (16): ArenaService.getBlocks(), applyPose(), attachPuffador(), blockCenter(), buildDescription(), createDebris(), createPart(), createShot() (+8 more)

### Community 29 - "CrosshairView.new"
Cohesion: 1.00
Nodes (3): addCorner(), createHitLine(), CrosshairView.new()

### Community 30 - "VaultService.luau"
Cohesion: 0.12
Nodes (37): ProjectileService.setCharacterHitHandler(), SecretRoomBuilder.getFrame(), SecretRoomBuilder.getPedestalTop(), attachToPanel(), createAlarm(), createGlow(), createPanel(), createPrompt() (+29 more)

### Community 31 - "BuildingService.luau"
Cohesion: 0.31
Nodes (5): along(), createBox(), createSolid(), destroyOwnedChild(), isOwned()

### Community 32 - "PuffadorModel.luau"
Cohesion: 0.50
Nodes (6): addPart(), buildBody(), buildGrip(), buildMuzzle(), buildTank(), tube()

## Knowledge Gaps
- **22 isolated node(s):** `Linguagem e comunicação`, `Arquitetura`, `Segurança e dependências`, `Escopo e compatibilidade`, `Validação e entrega` (+17 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `BuildingDecor.createPart()` connect `BuildingDecor.createPart` to `VaultService.luau`, `BuildingService.luau`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **Why does `runEnding()` connect `RoundService.luau` to `PuffadorService.luau`, `VaultService.luau`, `EliminationService.luau`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `BuildingDecor.createPart()` (e.g. with `createSolid()` and `buildVaultDisk()`) actually correct?**
  _`BuildingDecor.createPart()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `UiTheme.addCorner()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.addCorner()` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `AdminPanelView.new()` (e.g. with `UiKit.createButton()` and `UiKit.createWordmark()`) actually correct?**
  _`AdminPanelView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `RoundHudView.new()` (e.g. with `HudView.new()` and `UiKit.createWordmark()`) actually correct?**
  _`RoundHudView.new()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `UiTheme.stylePanel()` (e.g. with `AdminBroadcastView.new()` and `AdminPanelView.new()`) actually correct?**
  _`UiTheme.stylePanel()` has 9 INFERRED edges - model-reasoned connections that need verification._