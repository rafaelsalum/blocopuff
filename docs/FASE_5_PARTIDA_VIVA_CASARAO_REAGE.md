# Fase 5 — Partida Viva: o Casarão reage

**Entrega:** transformar objetos do Casarão em armadilhas acionadas por disparo, que premiam quem joga de longe e deixam cada partida mais imprevisível e engraçada.  
**Dependência:** core da partida estável (Fases 1 a 4) e persistência protegida (`ProfileGuard`).

---

## Resultado esperado

Durante a partida, o jogador passa a:
- olhar para o cenário e procurar algo em que atirar;
- ter um motivo para jogar de longe (hoje quase todo confronto é de perto);
- evitar ficar parado encostado na parede ou em cima de um tapete;
- rir das armadilhas, mesmo quando é a vítima;
- viver um Caos Final que mexe com os dois andares.

Cada andar tem uma personalidade fácil de ler:
- **Andar de cima — o clima:** janelas que trazem vento, pombos e chuva.
- **Andar de baixo — a casa:** tapetes, lustres e lareira.

---

## Princípios

1. **Recompensa a distância.** O efeito completo só acontece com disparo de longe. De perto, a armadilha só trinca ou treme.
2. **Sempre avisa antes.** Toda armadilha tem um aviso visual e sonoro antes do efeito, então quem está perto tem chance de reagir e a jogada exige habilidade.
3. **Empurra, não machuca.** Sem HP e sem dano. O efeito é empurrão, queda de blocos, escorregão ou espirro, como o resto do jogo.
4. **No andar de baixo, cria o perigo, não elimina.** Sair da arena pelo andar de baixo elimina (Segunda Chance), então lá as armadilhas preparam a situação, por exemplo um buraco no chão ou um escorregão em direção a ele, mas nunca jogam alguém direto para fora.
5. **Não vira spam.** Cada objeto tem tempo para voltar a funcionar e limite de usos por rodada.
6. **Leitura rápida.** Uma criança precisa entender, sem texto, que o objeto pode ser acionado: ele brilha de leve quando está pronto e fica apagado quando está recarregando.
7. **Servidor decide, cliente desenha.** Acerto, empurrão, queda de blocos e crédito são do servidor. Vidro, cortinas, vento, fuligem e pombos são efeitos do cliente, como os disparos.

---

## Escopo

### 5.1 Base das armadilhas

Sistema comum, reutilizado por todas as armadilhas:
- **objeto acionável:** tag `CasaraoTrap` com atributos de tipo, estado (`Ready`, `Warning`, `Active`, `Recharging`, `Spent`) e andar;
- **acerto:** o raycast do disparo, que já é do servidor, passa a reconhecer a peça-alvo da armadilha. A franja do tapete, a corrente do lustre, o vidro da janela e a boca da lareira são essas peças;
- **distância mínima:** medida do atirador até o alvo no momento do disparo. Abaixo dela, só o efeito leve (trinca ou tremida, sem consequência);
- **aviso:** o estado `Warning` dura um tempo por armadilha e é replicado para todos os clientes desenharem o aviso;
- **efeito:** aplicado pelo servidor ao fim do aviso, com o mesmo empurrão dos disparos (`Knockback`), que já respeita a proteção da Segunda Chance;
- **atirador imune:** quem acionou nunca é afetado pela própria armadilha;
- **crédito:** a vítima fica marcada com quem acionou, e uma queda dentro de `Knockback.CreditWindow` conta como derrubada desse jogador, igual a um disparo direto;
- **recarga e limite:** tempo de recarga e número máximo de usos por rodada para cada armadilha. Tudo é restaurado no início da rodada;
- **efeitos no cliente:** um controlador desenha o aviso e o efeito a partir dos atributos e de um evento único por acionamento;
- **configuração:** tudo em `config/TrapConfig` (compartilhado).

### 5.2 Janela Ventania (andar de cima)

- **Onde:** as janelas que já existem nas três paredes externas do andar de cima. O vidro passa a ser o alvo.
- **Aviso (0,7 s):** o vidro trinca com um estalo, as cortinas incham e um rastro de vento aparece no chão em frente à janela.
- **Efeito:**
  - o vidro estoura em confete de vidro;
  - uma rajada entra num cone para dentro da arena e empurra quem estiver nele. O empurrão é forte perto da janela e fraco no fim do cone, sempre para longe da janela;
  - os blocos logo abaixo da janela (a faixa encostada na parede) tremem e caem depois do aviso de queda dos blocos.
- **Depois:** a janela fica aberta, com as cortinas balançando, até ser pregada com tábuas. Então volta a ficar pronta.

### 5.3 Tapete Puxado (andar de baixo)

- **Onde:** dois tapetes grandes no térreo, cada um com uma franja numa das pontas (o alvo).
- **Aviso (0,8 s):** o tapete ondula da franja para o outro lado, com som de pano esticando.
- **Efeito:** o tapete é puxado para o lado da franja e todos em cima escorregam nessa direção. O escorregão é um empurrão rasteiro, sem pulo.
- **Depois:** o tapete fica embolado junto da franja e volta a se esticar sozinho.
- **Leitura de jogo:** o perigo depende de haver buraco no caminho. O atirador precisa ler a posição da vítima.

### 5.4 Lustre Despencando (andar de baixo)

- **Onde:** dois lustres pendurados no teto do térreo, que é o piso do andar de cima.
- **Aviso (1,0 s):** o lustre balança, faíscas saem da corrente e um círculo de sombra aparece no chão onde ele vai cair.
- **Efeito:**
  - o lustre cai e empurra todos dentro do círculo para fora dele;
  - os blocos no centro do círculo racham e caem logo em seguida (com o aviso de queda dos blocos), abrindo um buraco.
- **Uma vez por rodada:** o lustre caído fica no chão como entulho decorativo, sem colisão.
- **Os dois andares interagem:** se os blocos do andar de cima que seguram o lustre forem destruídos, ele também cai (com o mesmo aviso). O crédito vai para quem destruiu o último bloco.

### 5.5 Lareira de Fuligem (andar de baixo)

- **Onde:** uma lareira numa parede externa do térreo. A boca da lareira é o alvo.
- **Aviso (0,6 s):** a lareira tosse brasas e começa a sair fumaça.
- **Efeito:**
  - uma nuvem de fuligem se espalha em frente à lareira por alguns segundos;
  - quem entra na nuvem leva um "ATCHIM!", com um espirro que dá um pulinho para trás (empurrão leve para longe do centro da nuvem), no máximo uma vez a cada 1,5 s por jogador;
  - a tela de quem está dentro fica levemente embaçada, sem piscar, por 1,5 s;
  - o rosto do personagem fica sujo de fuligem até o fim da rodada, só como piada visual.
- É a armadilha mais leve: serve para desequilibrar uma briga perto da parede.

### 5.6 Variações das janelas: Pombos e Chuva

As janelas sorteiam uma variação por rodada. A Ventania é a mais comum. A cortina tem uma cor por variação, então dá para ver de longe qual janela faz o quê.
- **Pombos:** um bando entra pela janela e atravessa a arena numa faixa reta. Quem está na faixa leva esbarrões leves, que são empurrões pequenos e repetidos.
- **Chuva:** a chuva entra pela janela e deixa o chão em frente a ela escorregadio por alguns segundos. Andar ali dá pouca tração, então é difícil frear e mudar de direção.

### 5.7 Caos Final: Tempestade

Soma-se ao Caos Final de hoje, em que blocos piscam em vermelho e caem:
- **anúncio:** "⛈️ A TEMPESTADE CHEGOU!", com trovão e o céu escurecendo pelas janelas;
- **em cima:** as janelas que ainda estiverem prontas estouram sozinhas, uma por vez, cada uma com o aviso normal e a variação da rodada. Esses acionamentos não dão crédito a ninguém;
- **embaixo:** as luzes piscam suavemente, sem flash forte, e os lustres que ainda estiverem pendurados caem em sequência, com o aviso normal;
- os tapetes e a lareira continuam acionáveis pelos jogadores.

**Andamento:** entregue (out/2026). O anúncio do Caos Final virou "⛈️ A TEMPESTADE CHEGOU!" ("Sem Segunda Chance · blocos vermelhos, janelas e lustres vão cair"). No servidor, `TrapService.storm` pega as janelas e os lustres prontos no começo do Caos, em ordem sorteada, e aciona cada um com o aviso normal e sem crédito. As janelas saem a cada 2,5 s a partir de 2 s; os lustres a cada 5 s a partir de 4 s. Num Caos curto, os intervalos encolhem para tudo caber antes dos últimos 3 s (`StormSchedule`, com testes no Lune). Uma armadilha que um jogador acionar nesse meio tempo sai da fila. No cliente (`StormController`):
- o céu escurece e fica azulado em 3 s (ColorCorrection);
- chove baixinho em volta do prédio;
- um trovão abre a Tempestade e outros soam a cada 6 a 10 s, com um clarão leve, sem flash forte;
- as luzes do térreo oscilam devagar entre 60% e 100% do brilho.

Tudo volta ao normal quando o Caos acaba. No Studio, num Caos de 20 s: 5 janelas e o único lustre ainda pendurado (o outro já tinha sido derrubado por um bot) caíram sem crédito, e escurecimento, chuva, trovão, luzes e anúncio funcionaram. A telemetria de quantas armadilhas a Tempestade aciona entrou na 5.8 (`StormTraps`).

### 5.8 Momentos Puff, conquistas, telemetria e ajuste

- **Momentos Puff:** "VIDRAÇA! 💨", "PUXOU O TAPETE! 🧶", "LUSTRE! 💡" e "ATCHIM! 🤧", quando uma armadilha derruba alguém.
- **Conquistas e desafios:**
  - Vidraceiro: quebrar 5 janelas de longe;
  - Puxa-Tapete: derrubar alguém com o tapete;
  - Lustre na Cabeça: derrubar 2 jogadores com o mesmo lustre;
  - desafios diários com armadilhas.
- **Telemetria:** acionamentos por tipo, distância do disparo, vítimas, derrubadas causadas, tempo até a primeira armadilha e quantas armadilhas são acionadas na Tempestade.
- **Ajuste:** números finais definidos no playtest (ver a tabela abaixo).

**Andamento:** entregue para as armadilhas (out/2026). Cada armadilha agora carrega a sua origem (`{kind, id}`) até o empurrão: `TrapBlocks`, janelas, tapetes, lustres e lareira passam a origem para o `KnockbackService`, que guarda junto com o último golpe (`getRecentHit`). Quando alguém é eliminado, o `RoundService` vê se o golpe que valeu veio de uma armadilha e chama `TrapMoments.knockout`. As regras puras ficam em `data/TrapMomentRules` (15 testes no Lune). Bots acionam e derrubam, mas só jogadores ganham alguma coisa.
- **Momentos Puff:** quem acionou a armadilha que derrubou alguém (humano ou bot) ganha o momento do tipo dela: "VIDRAÇA! 💨", "PUXOU O TAPETE! 🧶", "LUSTRE! 💡" ou "ATCHIM! 🤧", com subtítulo para quem fez e para quem vê.
- **Conquistas secretas** (`SecretCatalog`):
  - **Vidraceiro:** 5 janelas acionadas de longe na mesma partida;
  - **Puxa-Tapete:** derrubar alguém com o tapete;
  - **Lustre na Cabeça:** 2 derrubados pelo mesmo lustre na mesma partida.
- **Desafios diários** (`DailyConfig`):
  - "Acione 3 armadilhas de longe" (fácil, 2 tickets);
  - "Derrube alguém com uma armadilha" (difícil, 4 tickets).

  Eles usam duas estatísticas novas do perfil, `trapsTriggered` e `trapKnockouts`, com teto por rodada no `ProfileSchema` (80 e o máximo de jogadores menos 1). Derrubar bot não conta para o desafio, como nas derrubadas comuns.
- **Telemetria** (além de `TrapTriggered` com a distância, `TrapAffected` e `TrapSupportLost`, que já existiam):
  - `TrapFirst`: segundos de rodada até cada jogador acionar a primeira armadilha;
  - `TrapKnockout`: derrubada causada, com tipo e armadilha;
  - `StormTraps`: quantas janelas e lustres a Tempestade acionou, para quem estava vivo quando ela chegou. Vai no fim da Tempestade ou, se a rodada acabar antes, no fim da rodada.

No Studio, numa Arena com 3 bots, tiro de 32 studs na janela North:24: saiu `TrapTriggered` e `TrapFirst` (12 s), mesmo com um bot tendo acionado outra janela antes, e `StormTraps` no fim da rodada (5 janelas e 2 lustres), sem erros no console. Os dois casos foram corrigidos nesse teste: o `TrapFirst` era um por rodada e se perdia quando um bot acionava antes, e o `StormTraps` de uma rodada que acabou antes da Tempestade saía na rodada seguinte. A derrubada por armadilha (momento, conquistas e `TrapKnockout`) foi verificada pelos testes das regras e pela leitura do caminho, mas não ao vivo, porque montar uma eliminação por armadilha no Studio depende de posicionar a vítima na hora certa.

Fica para depois: os Momentos Puff, as conquistas e a telemetria do Casarão Vivo (5C), e o ajuste fino dos números no playtest.

### Fase 5C — Casarão Vivo (lobby)

Junto com as armadilhas da partida, a Fase 5 ganha uma frente no lobby: explorar, descobrir e colecionar no Casarão enquanto se espera a partida. O escopo está em `docs/FASE_5C_CASARAO_VIVO.md`. Ordem sugerida: 5.7, depois 5C.1 a 5C.4, e por último a 5.8, que passa a cobrir também os Momentos Puff, as conquistas e a telemetria do Casarão Vivo.

---

## Números iniciais

Valores de partida para o playtest. Todos ficam em `config/TrapConfig`.

| Armadilha | Distância mínima | Aviso | Área | Empurrão (perto → longe) | Recarga | Usos por rodada |
|---|---|---|---|---|---|---|
| Janela Ventania | 25 studs | 0,7 s | cone de 30 studs, 50° | 1,2× → 0,4× o disparo | 25 s | 3 por janela |
| Pombos | 25 studs | 0,7 s | faixa de 6 × 40 studs | 0,3× por esbarrão (até 3) | 25 s | 3 por janela |
| Chuva | 25 studs | 0,7 s | 12 × 12 studs | tração baixa por 5 s | 25 s | 3 por janela |
| Tapete Puxado | 20 studs | 0,8 s | o tapete | escorregão de cerca de 14 studs (0,45 s) | 20 s | 4 por tapete |
| Lustre Despencando | 20 studs | 1,0 s | círculo de 7 studs | 1,0× para fora + buraco | — | 1 por lustre |
| Lareira de Fuligem | 15 studs | 0,6 s | nuvem de 10 studs por 4 s | 0,35× por espirro | 18 s | 4 |

Referência: o disparo empurra hoje 62 de velocidade na horizontal e 26 na vertical (`GameConfig.Knockback`). Os blocos medem 6 × 1 × 6 e os andares ficam 28 studs um do outro.

---

## Arquitetura técnica

- **Servidor:**
  - `TrapService` registra as armadilhas montadas com o cenário, recebe os acertos do `ProjectileService` (`setSurfaceHitHandler`), controla os estados e as recargas e aplica os efeitos;
  - o empurrão e o crédito usam o mesmo caminho dos disparos;
  - a queda de blocos usa o mesmo caminho do Caos Final, com aviso.
- **Cenário:**
  - `BuildingDecor` e `BuildingService` montam as peças-alvo com a tag `CasaraoTrap`;
  - os tapetes, os lustres do térreo e a lareira entram no andar de baixo;
  - as janelas já existem e só ganham o alvo.
- **Cliente:**
  - `TrapVisualController` desenha o aviso, o efeito e o estado (pronta, recarregando) a partir dos atributos;
  - pooling dos efeitos e nível de detalhe por distância, como no `PuffShotRenderer`.
- **Rede:** um atributo de estado por armadilha e um evento por acionamento (tipo, alvo, atirador, instante). Nada é enviado a cada quadro.
- **Segurança:** o cliente nunca aciona armadilha diretamente. Só o disparo validado pelo servidor aciona. A distância é medida no servidor.

---

## Critérios de aceite

- [ ] Cada armadilha só dispara o efeito completo com tiro a partir da distância mínima.
- [ ] Todas avisam antes, de forma visível de qualquer ponto da arena.
- [ ] O atirador nunca é afetado pela própria armadilha.
- [ ] Quedas causadas por armadilha contam como derrubada de quem acionou.
- [ ] Nenhuma armadilha do andar de baixo joga alguém direto para fora da arena.
- [ ] Recarga e limite por rodada funcionam e são restaurados a cada rodada.
- [ ] A proteção da Segunda Chance vale contra armadilhas.
- [x] A Tempestade aciona janelas e lustres em sequência legível, sem crédito.
- [ ] Sem flash forte nem controles invertidos.
- [ ] Desempenho mobile estável com várias armadilhas ao mesmo tempo.

---

## Testes manuais prioritários

1. Acertar cada armadilha de perto e de longe.
2. Vítima reagindo durante o aviso (consegue escapar?).
3. Atirador dentro da área da própria armadilha.
4. Derrubada por armadilha aparecendo no resultado e no perfil.
5. Duas armadilhas ao mesmo tempo no mesmo jogador.
6. Lustre caindo porque os blocos de cima foram destruídos.
7. Tapete puxado com buraco no caminho e sem buraco.
8. Jogador com proteção da Segunda Chance dentro da área.
9. Tempestade com armadilhas já usadas e com armadilhas prontas.
10. Rodada seguinte: tudo restaurado.
11. Celular: dá para mirar na franja, na corrente e na janela.
12. Servidor cheio com todas as armadilhas acionadas no Caos Final.

---

## Perguntas do playtest

- os jogadores percebem sozinhos que dá para atirar nos objetos?
- jogar de longe ficou mais interessante?
- a vítima acha justo (deu para ver o aviso)?
- alguma armadilha é forte demais ou ignorada?
- a Tempestade deixa o final mais emocionante ou confuso?
- as crianças riem do espirro e do tapete?

---

## Gate para Fase 6

Avançar quando as armadilhas deixarem a partida mais divertida, sem frustração e sem prejudicar a leitura do combate, com desempenho estável no celular.
