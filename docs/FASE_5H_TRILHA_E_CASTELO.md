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
- **Janelas góticas de verdade.** Têm moldura, arco pontudo, mainel e peitoril, e só vão em trechos de parede cheia. Desde a 5H.2 são recortadas na parede (ver seção 3).
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
- Os lampiões em volta do Casarão desviam das torres e da escadaria (`CastleExterior.blocks`, usado no `OutdoorService`).

## 3. Fase 5H.2 — Entrada principal, valetas e janelas de verdade

### Entrada digna

- **Porta.** Fica na parede sul do Ponto de Encontro, em x ≈ 125 (`MansionConfig.FrontDoor`), longe dos alvos do Treino. Tem as mesmas folhas de porta do Casarão (`MansionDoors`) e a placa "🌲 JARDINS DO CASTELO" por dentro.
- **Escadaria.** É montada pelo `CastleEntrance` a partir da planta pura `FrontStairs` (testada em `tests/FrontStairs.spec.luau`):
  - patamar no nível do piso e degraus de 1 stud até o chão;
  - balaustradas, pilares com bola de pedra, portal com arco pontudo, placa "🏰 CASARÃO DO BARÃO", estandartes e um lampião de cada lado do pé.
- **Caminho da frente.** Um caminho de pedra iluminado (`OutdoorConfig.FrontPath`) sai do pé da escada e vai até o lago.
- **Fachada.** Ela deixa o vão da porta livre (`clear`) e não põe janela nem contraforte no portal (`reserve`).

### Valetas e parede atravessável

- **Escavação por sala.** O terreno não é mais escavado na caixa inteira do prédio da Arena, só sala por sala. Os nichos enterrados só tiram o terreno abaixo de 4 studs do chão (`Carve.top`, `TerrainShape.carveTop`).
- **Calçada de pedra.** As pontas dos corredores secretos saem do chão. Como o terreno é escavado em células de 4 studs, ficava ali um vão sem fundo encostado na parede: quem caía voltava para dentro. Agora uma calçada de pedra sólida (`BuildingAprons`, no `OutdoorService`) cobre essas faces.
- **Conferência no Studio.** Raios do céu em volta de todas as construções: 0 buracos em 23.622 pontos.
- **Embasamento.** O embasamento de pedra das fachadas agora colide. Era só enfeite, e por isso dava para atravessar a parede.

### Janelas de verdade

- **Recorte.** O `CastleWindows` recorta cada janela (CSG, `GeometryService:SubtractAsync`) na parede, no papel de parede, no lambri, nos rodapés e no revestimento de pedra.
- **Moldura e vidro.** O vão recebe vidro claro e mainel, com moldura de pedra por fora e de madeira por dentro.
- **Quando roda.** Só no fim do `init.server.luau`, em segundo plano, depois que todos os serviços montaram suas peças.
- **Peças invisíveis às consultas.** Os acabamentos têm `CanQuery` desligado. Durante o recorte, as peças do prédio e do Casarão ficam consultáveis, e depois voltam ao que eram.
- **Onde não abre.**
  - na frente de quadro, estante, placa, porta, móvel ou alvo do Treino;
  - em peça com tag ou atributo (passagens secretas, armadilhas);
  - em parede grossa demais.
- **Resultado no Studio.** Abrem 22 das 40 janelas, e de dentro se vê o céu, a floresta e o castelo.

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
- [x] 5H.2 testado no Studio:
  - sair pela porta da frente e voltar andando;
  - escadaria e portal;
  - sem valetas em volta;
  - janelas vistas de dentro e de fora;
  - console sem erros.
- [x] Testes Lune (32 specs), build do Rojo e `graphify update`.
- [ ] Testar em celular: são cerca de 1.140 peças a mais, a maioria sem colisão, mais os recortes das janelas.
- [ ] Ouvir as faixas em partidas reais e ajustar os volumes em `MusicConfig`.
