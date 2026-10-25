# Fase 5I — Assassinato no Casarão jogável de verdade

## Objetivo

1. Facada de perto confiável (alcance, detecção, recarga e latência), sem piorar o arremesso.
2. Trocar os móveis de blocos simples por modelos de verdade, com cara de Hogwarts.
3. Mais passagens secretas na Ala do Assassinato.
4. Trocar as "cabines" de cor sólida por peças temáticas.
5. Trocar as moedas por um coletável com o tema do Casarão.

## 1. Facada

| Ajuste | Antes | Agora |
|---|---|---|
| Alcance (`StabRange`) | 6 | 7.5 |
| Cone à frente (`StabConeDegrees`) | 70° | 100° |
| Colado (`StabCloseRange`) | — | até 3.5 studs pega quem está do lado (cosseno ≥ -0.3) |
| Alvo | posição atual | posição atual e as dos últimos instantes (`MurderStabHistory`), voltando o ping + 0.1 s, no máximo 0.4 s (`MurderRules.stabRewind`) |
| Origem do golpe | posição do servidor | a que o cliente manda (`FireServer("Stab", mira, posição)`), se estiver a até 4 studs da do servidor (`StabOriginTolerance`, `MurderRules.originTrusted`) e sem parede entre as duas |
| Mira | frente do corpo agora | frente do corpo agora ou em algum instante do rebobinado (`MurderStabHistory.fronts`) |
| Parede no meio | raio pegava cortinas e panos | `RespectCanCollide`, e o raio é testado na altura do peito e na da cabeça (mesa baixa não salva ninguém) |

**Por que a origem do cliente.** No Studio, com o Assassino correndo atrás de um bot, o servidor via o atacante 1 a 2 studs atrás e virado para o lado antigo. Por isso golpes a 3–7 studs na tela chegavam como 6–8 studs "pelas costas". A tolerância de 4 studs cobre quem corre a 16 studs/s com até 0.25 s de atraso. Um cliente alterado não ganha mais do que isso. O arremesso não mudou.

**Teste no Studio.** Perseguindo bots como Assassino: depois do ajuste, o golpe a 6.6 studs eliminou (antes errava a 7.0 e a 2.8). Antes do último ajuste, os golpes a 4.9 e 3.7 também já pegavam.

## 2. Móveis da Creator Store

Todos ficam em `src/shared/assets/MurderModels.rbxm` (17 modelos). Foram inspecionados no Studio e salvos sem nenhum script, Tool, Accessory ou assento. Cada um tem a frente em -Z, o pivô no centro da base e o tamanho original no atributo `BaseSize`. Quem usa é o `MurderAssets` (`clone`, `tint`). Se o arquivo faltar, voltam as peças simples.

| Modelo | Asset | Autor |
|---|---|---|
| StoneFireplace | 85884773967694 | GlitchyNeighbor |
| DiningChair | 3619488285 | RottanMamma |
| KnightArmor | 127219913 | wickywave14 (a espada, que vinha como Tool, virou Model) |
| Cauldron | 14450962342 | CrownReborn |
| TallBookshelf | 9016968483 | Dachrivv |
| ChesterfieldSofa | 10026927662 | leutxiz |
| FourPosterBed | 63855458 | EllaLovesTy (recolorida; peças Blanket, Canopy, Mattress e Frame) |
| Bookshelf | 141047988 (metade) | Quenty |
| LongTable, RoundTable, Chest, BarrelRack, Counter, GothicChair, Bench, SideTable, Vase | 2129051912 (Medieval Furniture Kit) | detonador665 |

**Rejeitados por trazerem scripts:** 96810813701422, 97289605090254, 138434375112413, 101784640556449, 73302246488343, 7250531137, 82010639908615, 96917923600255, 96625083691323, 91643017418046.
**Rejeitados por outros motivos:** 11377510804 (simples demais) e 8387231190 (guarda-roupa limpo, mas pesado demais).

Peças feitas à mão no tema (`MurderMansionPieces`): guarda-roupa com portas abertas e cortina de veludo, harpa e tabuleiro de xadrez.

O `MurderMansionProps` agora mobilia os 12 cômodos com esses modelos. Cada um tem um bloqueador invisível, para ninguém atravessar.

## 3. Passagens secretas

Antes havia uma passagem; agora são três (`MurderMansionPlan.passages`, com `level` e `side`):

- Biblioteca → Cozinha (térreo, norte)
- Quarto do Barão → Quarto de Hóspedes (andar de cima, norte)
- Salão de Baile → Sala de Estar (térreo, sul)

O builder abre as paredes nos dois lados. Os bots navegam pelos nós de cada passagem. `MurderMansionPlan.footprint` inclui os corredores.

## 4. "Cabines"

- As `ArcadeCabinets` coloridas da Sala de Jogos viraram uma armadura de cavaleiro e uma estante alta.
- As estantes de cobertura de cor sólida (`MansionWingDecor.bookshelf`) viraram a estante de livros do modelo, em escala 0.55, com bloqueador. A peça antiga só aparece como reserva.

## 5. Cartas do Barão

As moedas viraram **Cartas do Barão** (`BaronLetterModel`): envelope de pergaminho em pé, dobras da aba, selo de cera vermelha com respingos e um brilho dourado discreto. No cliente, cada carta flutua e gira (`BaronLetterFloat`, pela tag `BaronLetter`). Pegar uma toca um som de papel (`Sounds.LetterPickup`). O HUD mostra `✉️ n/m`. Por dentro, o código continua chamando de "coins" (atributo `MysteryCoins`, tickets).

## Correções que apareceram no caminho

- A cerca invisível da Ala cortava o corredor da passagem que já existia. Agora ela segue o `footprint`.
- A grama do terreno atravessava o piso do térreo. Agora o terreno é escavado sob o `footprint` (`OutdoorService`).

## Validação

- Testes Lune: `for t in tests/*.spec.luau; do lune run $t; done` (32 arquivos, todos passam).
- `python3 -m json.tool default.project.json`.
- `rojo build default.project.json -o <scratchpad>/BlocoPuff.rbxlx`.
- Studio: partidas jogadas sem erro no console. Conferidos: cartas e HUD, Sala de Jogos (estante, xadrez, cadeira gótica), Sala de Estar (guarda-roupa, sofá), cerca e escavação. A facada foi testada como descrito acima.
