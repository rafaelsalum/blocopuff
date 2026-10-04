# Sons para pesquisar na Creator Store

Hoje esses sons são provisórios (sons internos do Roblox, `rbxasset://sounds/...`, repetidos em vários lugares). Pesquise no Studio (Toolbox > Creator Store > Audio) pelo termo em inglês. Depois devolva a lista no formato `#: rbxassetid://ID`.

Dicas:
- Prefira **sound effects curtos** (até 3 s), exceto onde estiver indicado "loop".
- Use o filtro de duração.
- Prefira áudios do próprio Roblox ou com muitas avaliações. Alguns de terceiros ficam privados.
- Se não achar um, pode pular. Eu mantenho o provisório.

## 🚪 Casarão (5C.1)

| # | Uso no jogo | Termo de busca (inglês) | Onde fica |
|---|---|---|---|
| 1 | Porta abrindo, rangido | `old wooden door creak open` | `MansionConfig.Door.CreakSoundId` |
| 2 | Porta fechando, batida | `wooden door slam close` | `MansionConfig.Door.SlamSoundId` |
| 3 | Sino do chamado "sua partida começa em 15 s" | `bell ding` ou `mansion bell ring` | `MatchQueueController` (BELL_SOUND) |
| 4 | Entrou na fila / pegou a ficha | `ticket get` ou `ui success chime` | `MatchQueueController` (JOIN_SOUND) |
| 5 | Bipes do "3, 2, 1" | `countdown beep` | `MatchQueueController` (BEEP_SOUND) |

## 🪟 Janelas (armadilha)

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 6 | Vidro trincando | `glass crack` | `TrapConfig.Window.CrackSoundId` |
| 7 | Vidro estilhaçando | `glass shatter` | `TrapConfig.Window.ShatterSoundId` |
| 8 | Rajada de vento (Ventania) | `wind gust whoosh` | `TrapConfig.Window.GustSoundId` |
| 9 | Bando de pombos batendo asas | `pigeons flock wings flapping` | `TrapConfig.Window.FlapSoundId` |
| 10 | Chuva entrando pela janela (loop) | `heavy rain loop` | `TrapConfig.Window.RainSoundId` |

## 🧶 Tapete

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 11 | Tapete esticando | `cloth stretch` ou `fabric tension` | `TrapConfig.Rug.StretchSoundId` |
| 12 | Tapete puxado | `rug pull whoosh` ou `cloth whip` | `TrapConfig.Rug.PullSoundId` |

## 💡 Lustre

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 13 | Corrente rangendo antes de cair | `chain creak metal` | `TrapConfig.Chandelier.CreakSoundId` |
| 14 | Lustre caindo e quebrando | `chandelier crash glass metal` | `TrapConfig.Chandelier.CrashSoundId` |

## 🔥 Lareira de Fuligem

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 15 | Lareira tossindo fuligem | `fireplace cough puff` ou `chimney soot puff` | `TrapConfig.Fireplace.CoughSoundId` |
| 16 | Nuvem de fuligem saindo | `smoke puff poof` | `TrapConfig.Fireplace.PuffSoundId` |
| 17 | Espirro "ATCHIM!" | `cartoon sneeze` | `TrapConfig.Fireplace.SneezeSoundId` |

## 🐶 Barão

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 18 | Passos do Barão | `dog paws footsteps wood` | `GameConfig.Barao.FootstepSoundId` |
| 19 | Batida de tensão, para quem é perseguido | `heartbeat tension low` ou `suspense hit` | `GameConfig.Barao.TensionSoundId` |
| 20 | Portinhola do túnel batendo | `small wooden hatch close` | `GameConfig.Barao.DoorSoundId` |
| 21 | Sons engraçados quando ele pega alguém | `cartoon yelp` e `cartoon boing` | `GameConfig.Barao.FunnySoundIds` (pode ser mais de um) |

## 🔐 Cofre e passagens secretas

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 22 | Alarme do cofre aberto, para todos | `vault alarm` ou `treasure unlock fanfare` | `GameConfig.SecretRoom.AlertSoundId` |
| 23 | Cofre trancado, tentativa negada | `locked door rattle` | `VaultService` (SOUND_LOCKED) |
| 24 | Cofre abrindo | `vault door open heavy` | `VaultService` (SOUND_OPEN) |
| 25 | Passagem secreta revelada | `secret discovered chime` ou `magic reveal` | `SecretPassageService` / `SecretPassageController` |
| 26 | Combinação errada da passagem | `wrong buzzer soft` | `SecretPassageService` (SOUND_WRONG) |

## 🎯 Puffador, partida e aquecimento

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 27 | Disparo do Puffador | `air puff shot` ou `cartoon pop gun` | `PuffadorModel` (shotSound) |
| 28 | Acerto no bloco | `soft hit thud` | `PuffadorModel` (hitSound) |
| 29 | Impulso (dash) | `dash whoosh` | `DashFx` |
| 30 | Balão estourando no aquecimento | `balloon pop` | `WarmupService` (POP_SOUND) |
| 31 | Acerto no alvo do Treino | `target hit ding` | `TrainingService` (HIT_SOUND) |
| 32 | Bloco reconstruído (Puffador do Cofre) | `block place build` | `BuildModeService` |

## ⭐ Interface e progressão

| # | Uso | Termo de busca | Onde fica |
|---|---|---|---|
| 33 | Clique de botão | `ui click soft` | `UiKit` (CLICK_SOUND_ID) |
| 34 | Subiu de nível | `level up` | `ProgressionController` |
| 35 | Puff desbloqueado na Puffdex | `unlock reward sparkle` | `PuffdexView` |
| 36 | Cofre: chime e superdisparo | `power up charge` | `VaultController` |

Já são sons de verdade e ficam como estão: a música de fundo (`GameConfig.Music`) e o latido do Barão.

## Próximas entregas (já pode separar)

| # | Uso | Termo de busca |
|---|---|---|
| 37 | Ambiente do Casarão: relógio de pêndulo (loop) | `grandfather clock ticking loop` |
| 38 | Ambiente: lareira crepitando (loop) | `fireplace crackling loop` |
| 39 | Relíquia encontrada | `item collect sparkle` |
| 40 | Página do Diário encontrada | `paper page flip` |
| 41 | Fantasminha passando | `cute ghost whoosh` |
| 42 | Porta trancada (chave/nível) | `door locked handle rattle` |
