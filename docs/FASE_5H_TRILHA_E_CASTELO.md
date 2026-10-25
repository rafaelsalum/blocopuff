# Fase 5H — Trilha sonora por momento e Casarão com cara de castelo

## Objetivo

1. Parar de usar a mesma música em todo lugar. A trilha muda com o ambiente e com o momento, e há efeitos de ambiente.
2. Tirar o aspecto de "caixa" do lado de fora do Casarão. Ele passa a parecer um castelo no estilo de Hogwarts.

## 1. Trilha sonora

A regra de escolha fica em `src/shared/modules/MusicMood.luau`. É pura e testada em `tests/MusicMood.spec.luau`. Quem toca as faixas é o `MusicController` (cliente). Os ids das faixas e os volumes estão em `src/shared/config/MusicConfig.luau`.

| Momento | Clima | Faixas (Creator Store) |
|---|---|---|
| Casarão de dia | `LobbyDay` | The Magic Waltz B, The Enchanted Princess B, o tema antigo |
| Casarão à noite | `LobbyNight` | Transparencies 3 (caixinha de música), The Enchanted Princess, Nursery Crime |
| Lado de fora, de dia | `OutdoorDay` + passarinhos | Butterfly Colony, Natural Planet |
| Lado de fora, à noite | `OutdoorNight` + grilos | Forest Night Flute, Transparencies 3 |
| Dentro da Torre do Relógio | `Tower` | Nursery Crime, Transparencies 3 |
| Partida na Arena | `Arena` | Silly Chase, Snappy Clappy, Playful Twist |
| Caos Final / Tempestade | `Chaos` | Making the Tough Call (B), Hell Ride |
| Corrida da Torre | `Race` | Fun Race, Forces Of Nature B |
| Assassinato no Casarão | `Mystery` | Anything Could Happen (b), Nursery Crime |
| Últimos 30 s do Assassinato | `Silent` | só a música de tensão do `MysteryFinalMusic` |
| Fim da partida | vinheta | vitória: Full of Wonder (sting); para os outros: We Good (sting) |

### Como funciona

- **Dia e noite.** Segue a hora do céu, que o `DayCycleService` mantém no horário de Brasília. A noite é a mesma faixa em que os lampiões ficam acesos (`OutdoorConfig.Lamps`).
- **Dentro ou fora.** A cada segundo o cliente lança um raio para cima, ignorando a floresta e os personagens:
  - nada em cima → lado de fora;
  - teto da `RaceTower` → Torre;
  - qualquer outro teto → dentro.
- **Revezamento.** Cada clima tem várias faixas. Quando uma termina, entra outra do mesmo clima, nunca a mesma duas vezes seguidas. As trocas de faixa e de clima são suaves (2 s).
- **Quem está no lobby** não troca de música por causa de uma partida em andamento. Só quem está jogando ouve a trilha do modo.
- **Vinheta do fim.** Toca para quem jogou a rodada. A música abaixa enquanto a vinheta toca.
- **Faixas licenciadas.** Todas são de APM Music, DistroKid ou Pro Sound Effects, liberadas para uso no Roblox, e todas carregaram no Studio. Para trocar uma faixa, basta mudar o id em `MusicConfig`.
- **Configuração.** Saiu o antigo `GameConfig.Music` (faixa única).

## 2. Casarão com cara de castelo

O código fica em `src/server/services/CastleExterior.luau`, `CastleFacade.luau` e `CastleTowers.luau`. Ele é montado no `init.server.luau`, depois da Torre do Relógio, dentro de um `pcall` (é só cenário). Nada muda por dentro.

### Fachadas

As fachadas são medidas com raios de fora para dentro, numa grade de 2 studs (`src/server/data/FacadeGrid.luau`, testada em `tests/FacadeGrid.spec.luau`). Em cada célula a grade guarda a profundidade da parede, ou 0 quando há um vão.

- **Revestimento de pedra.** Fica rente à parede, juntado em retângulos. Não tampa janela, porta, vidro nem passagem secreta.
- **Embasamento de pedra escura.** Cobre o vão entre o chão e o piso do Casarão, que fica acima do chão. Ele não é colocado onde algo passa por baixo, como o túnel do Barão.
- **Janelas góticas acesas.** Têm moldura, arco pontudo, mainel e peitoril, e só vão em trechos de parede cheia.
- **Contrafortes.** Também só em parede cheia, entre as janelas.

### Silhueta

- **Ameias** nas beiras dos telhados.
- **Telhados de ardósia de duas águas** por cima dos tetos planos: prédio da Arena, Casarão, ala leste e anexos.
- **Torres redondas.** Têm frisos, seteiras acesas, coroa com ameias e telhado cônico azul com ponta dourada, como a Torre do Relógio. Ficam nos cantos do prédio da Arena, nas junções com o Casarão, nos cantos da ala leste, nos anexos (Escritório e Sala do Tesouro do Barão, Sala de Troféus) e na entrada do Saguão da Torre.
- **Torre de menagem.** Fica no meio do telhado do Casarão, com quatro torrinhas e um pináculo alto.

### Regras de segurança

- Cada torre de canto é afastada na diagonal o bastante para não entrar em nenhuma sala. Isso foi conferido no Studio contra todos os interiores.
- Para o escritório do Barão foi feita só a torrinha do canto norte, porque a do sul entraria no túnel e no tesouro.
- O prédio da Arena tem os corredores secretos encostados por fora. A medição dele tem alcance maior, para achar a parede principal atrás dos corredores. As torres têm raio 7 para não invadir os corredores.
- Tudo é enfeite (não colide, não recebe raio nem toque), exceto o corpo das torres e o pé dos contrafortes. Quem passeia lá fora esbarra neles.
- Os lampiões em volta do Casarão desviam das torres (`CastleExterior.footprints`, usado no `OutdoorService`).

## Progresso

- [x] Trilha por clima, revezamento, ambiente de passarinhos e grilos, vinhetas do fim.
- [x] Testado no Studio:
  - **Músicas:** valsa no Casarão de dia; floresta com passarinhos de dia; flauta e grilos à noite; música da Torre; música épica no Caos Final; vinheta de vitória com a música abaixada.
- [x] Fachadas de castelo, telhados, torres e torre de menagem.
- [x] Testado no Studio:
  - **Castelo:** vistas de dia e de noite.
  - **Interiores:** nenhuma torre entra em sala.
  - **Lampiões:** fora das torres.
  - **Console:** sem erros.
- [x] Testes Lune (31 specs), build do Rojo e `graphify update`.
- [ ] Testar em celular: são cerca de 1.140 peças a mais, a maioria sem colisão.
- [ ] Ouvir as faixas em partidas reais e ajustar os volumes em `MusicConfig`.
