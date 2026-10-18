# Fase 5D — Modos do Casarão: Arena, Corrida da Torre e Mistério no Casarão

**Entrega:** transformar a partida única (Arena) numa **rotação de modos no mesmo servidor**, com dois modos novos ambientados no Casarão: a **Corrida da Torre do Relógio** (subir a rampa desviando do que cai) e o **Mistério no Casarão** (dedução social inspirada no Murder Mystery 2, sem violência).
**Dependência:** Fase 5B (bots) e Fase 5C (Casarão Vivo, Ficha da Partida) estáveis. Deve ficar pronta **antes** da Fase 6 (LiveOps e divulgação), porque muda o que o jogador vê nas primeiras sessões.

---

## Problema

Hoje toda partida é a mesma: Arena, Puffador, derrubar e não cair. É divertido, mas depois de algumas rodadas o jogador já viu tudo o que a partida oferece, e o motivo para "só mais uma" enfraquece. Os jogos mais jogados do Roblox seguram o jogador com **variedade dentro da sessão** (Epic Minigames, Fall Guys) ou com **tensão social** que muda a cada rodada (Murder Mystery 2).

O Casarão já tem tudo para isso: cômodos, salas secretas, a Torre do Relógio, o Barão como vilão e o Fantasminha. Falta usar esse cenário dentro da partida.

Ao mesmo tempo, **separar os modos em filas diferentes esvaziaria as partidas**: com servidores de até 12 jogadores, três filas viram três salas pela metade.

---

## Resultado esperado

O jogador passa a:
- jogar modos diferentes no mesmo servidor, sem escolher fila nem trocar de sala;
- saber qual é a próxima partida durante o intervalo ("Próxima: 🕰 Corrida da Torre");
- correr até o topo da Torre do Relógio desviando de barris, quadros e baús que o Barão joga;
- receber um papel secreto (Fantasma, Detetive ou Morador) e jogar uma rodada de esconde-e-descobre no Casarão;
- voltar para a Arena, o modo base, com frequência.

---

## Princípios

1. **Um servidor, uma fila, vários modos.** A Ficha da Partida, a Party, os bots e o mirante continuam iguais. Só muda o que acontece depois da contagem.
2. **A Arena é a casa.** É o modo mais frequente e o primeiro de todo jogador novo. Os modos novos são temperos, não substitutos.
3. **Sem violência, eliminação por queda ou por susto.** Ninguém se machuca: na Corrida o jogador escorrega e cai alguns degraus; no Mistério ele "desmaia de susto" e vira Fantasminha espectador.
4. **Fiel ao que funciona.** O Mistério copia as regras do MM2 que geram tensão (papel secreto, uma única arma, punição por erro, arma que cai e vira do Herói) e troca só a pele.
5. **Aviso antes de tudo.** O que cai na Corrida tem sombra no chão; o papel no Mistério aparece num cartão claro antes de a rodada começar.
6. **Uma criança entende em 5 segundos.** Cada modo tem uma frase de objetivo na tela ("Chegue ao topo primeiro!", "Descubra quem é o Fantasma!").
7. **Servidor decide, cliente desenha.** Papéis, chegada, toques, tiros e vencedores são do servidor. Sombras, sons e efeitos são do cliente.
8. **Economia igual entre modos.** Nenhum modo rende mais tickets que outro; o jogador escolhe ficar pelo que gosta, não pelo que paga mais.

---

## Escopo

### 5D.1 Rotação de modos (base de tudo)

- **Modo como peça trocável:** a rodada passa a ser conduzida por um modo, com a mesma interface para todos: preparar o mapa, posicionar os jogadores, rodar, decidir o vencedor e montar o resultado. A Arena atual vira o primeiro modo, **sem nenhuma mudança visível**.
- **Rotação** (em `config/ModeRotationConfig`):
  - sequência padrão: **Arena → Corrida → Arena → Mistério → repete**;
  - um modo só entra se as condições dele forem atendidas (ex.: Mistério pede um mínimo de humanos); senão, a rotação pula para o próximo, e a Arena sempre pode entrar;
  - o mesmo modo novo nunca se repete duas vezes seguidas;
  - as **3 primeiras partidas da vida do jogador** são sempre Arena, para ele aprender o Puffador; se houver um novato na fila, a rotação respeita isso (ele vê a Arena; os outros recebem a Arena também nessa rodada);
  - a sequência fica em config para trocar depois por evento (Fase 6) sem mexer no código.
- **Voto pela porta do mirante** (acrescentado depois da 5D.3, para o jogador escolher o que quer jogar):
  - cada uma das 3 portas do mirante leva o nome e a cor de um modo (`DoorModes`: Corrida, Arena no meio, Mistério); a fila continua uma só;
  - entrar no mirante por uma porta é votar no modo dela; o voto vale enquanto o jogador estiver na fila (com a Ficha da Partida também), continua durante a partida e na volta dela (quem volta cai direto no mirante) e muda se ele sair e entrar por outra porta; quem entra pelo botão JOGAR ou só pela Party não vota;
  - a próxima partida é o modo mais votado entre os escalados que **pode rodar** (o Mistério sem 2 humanos não conta, e vale o segundo mais votado); empate segue a ordem da rotação;
  - o voto vale mais que a regra do novato e que a de não repetir o modo novo (os jogadores escolheram); sem nenhum voto, segue a rotação, que não anda nas partidas votadas;
  - os painéis do mirante mostram os votos ao vivo e o jogador recebe um aviso "SEU VOTO"; a prévia do próximo modo é recalculada a cada segundo da contagem.
- **Anúncio do próximo modo:**
  - no intervalo, a etiqueta da fila e o HUD mostram o próximo modo com ícone e frase curta;
  - na contagem, uma tela de abertura de 3 s com o nome do modo e o objetivo em uma frase.
- **Resultado e recompensas** usam a mesma tela de resultado de hoje, com destaques próprios de cada modo.
- **Estatísticas:** `wins` e `top3` contam em qualquer modo (são vitórias de BlocoPuff). Um campo novo, `modeStats`, guarda partidas e vitórias por modo para o perfil e para conquistas, sempre protegido pelo `ProfileGuard`.

### 5D.2 Corrida da Torre do Relógio

**Objetivo:** ser o primeiro a chegar ao topo da Torre do Relógio.

- **Mapa:** uma rampa em espiral por dentro da torre (mapa próprio, longe do Casarão do lobby), com cerca de 60–90 s de subida para quem não erra. Trechos variados:
  - rampa larga no começo (todo mundo junto, muito empurra-empurra);
  - escadaria estreita no meio;
  - pontes entre engrenagens girando perto do topo;
  - **3 checkpoints** (patamares com uma bandeira do Barão).
- **O Barão no topo** joga coisas, sempre com aviso:
  - **barris** rolam rampa abaixo (sobem e descem um degrau, dá para pular);
  - **quadros e baús** caem do alto, com **sombra no chão 1 s antes**;
  - **lustres** balançam como pêndulo sobre a rampa;
  - **engrenagens** giram e mudam de lado com um "tique" de aviso;
  - a frequência aumenta conforme a rodada passa (no lugar do Caos Final).
- **Ser atingido** empurra o jogador e pode derrubá-lo da rampa; ele volta ao **último checkpoint** (não há eliminação na Corrida).
- **Puffador liberado, com força reduzida:** dá para empurrar quem está na frente, mas não arremessar longe. É aqui que a Corrida encontra o "derrube seu amigo". Não há cofre, armadilhas da Arena nem quebra de blocos.
- **Fim:** quando o 3º jogador chega ou o tempo acaba (2 min 30 s). Quem não chegou é ordenado pela altura alcançada. Pódio com 1º, 2º e 3º no topo, com o sino da torre tocando.
- **Celular primeiro:** rampas largas, saltos curtos, câmera que não fica atrás de paredes da torre e a sombra de aviso bem visível.

### 5D.3 Mistério no Casarão

> **Substituído pela Fase 5E** (`docs/FASE_5E_ASSASSINATO_NO_CASARAO.md`): no playtest em família o Fantasma, o susto e o mapa em grade não divertiram; o modo vira o Assassinato no Casarão, fiel ao MM2. O texto abaixo fica como registro do que foi entregue na 5D.3.

**Objetivo:** os Moradores sobrevivem ou capturam o Fantasma; o Fantasma assusta todo mundo.

- **Papéis secretos** (cartão na tela por 4 s no começo, só o próprio jogador vê o seu):

| Papel | Quantos | O que faz |
|---|---|---|
| 👻 **Fantasma** | 1 | Disfarçado de jogador comum. Encostar num jogador e apertar "Assustar" faz ele desmaiar. Tem o **Lençol Voador**: arremessa um lençol em linha reta que assusta quem atingir (recarga de 4 s). |
| 🔦 **Detetive** | 1 | Começa com o **Puffador do Detetive**. Um Puff no Fantasma o captura e acaba a rodada. Recarga de 2 s entre tiros. |
| 🏠 **Moradores** | o resto | Coletam moedas, observam, fogem e se escondem. Podem pegar o Puffador do chão e virar **Herói**. |

- **Regras de punição (como no MM2):**
  - se o Detetive acertar um Morador, o Morador desmaia, o Detetive fica **atordoado por 3 s e derruba o Puffador**;
  - se o Detetive desmaiar, o Puffador **cai no chão** com um brilho e um aviso ("🔦 O Puffador do Detetive caiu!");
  - qualquer Morador pode pegá-lo e virar **Herói**, com as mesmas regras do Detetive;
  - o Fantasma **não pode pegar** o Puffador.
- **Desmaiar:** quem é assustado vira um **Fantasminha espectador** (o mesmo visual do Fantasminha Puff do lobby), assiste à rodada e pode mandar reações discretas, que não revelam nada.
- **Vitória:**
  - **Moradores vencem** se o Fantasma for capturado ou se o tempo acabar (3 min) com algum Morador acordado;
  - **Fantasma vence** se assustar todos.
  - No resultado, todos os papéis são revelados.
- **Mapa: a Ala do Mistério**, uma versão escurecida do Casarão (mapa próprio, longe do lobby, construído com as mesmas peças de `MansionLayout` e `MansionWing`):
  - os cômodos que o jogador conhece (Biblioteca, Sala de Música, Sótão, Porão) com luz baixa e lanternas;
  - a estante giratória e o túnel da adega **abertos para todos** nesse modo: viram rotas de fuga e de emboscada;
  - armários e debaixo das mesas como esconderijos (o jogador fica parcialmente visível, nunca invisível);
  - portas que batem sozinhas e trovões para dar clima, sem atrapalhar a leitura.
- **Moedas do Barão:** espalhadas pela Ala, até 10 por jogador por rodada. Dão XP e tickets no fim (ver números) e dão aos Moradores um motivo para andar, não só ficar parados num canto.
- **Sem Puffador para os Moradores e o Fantasma.** Só o Detetive ou o Herói tem a ferramenta.
- **Proteção contra estragar o jogo:**
  - o chat de quem desmaiou não chega a quem ainda está acordado (e os Fantasminhas não podem marcar ninguém);
  - o Fantasma não pode assustar nos primeiros 10 s (tempo para todos se espalharem);
  - quem sair do jogo sendo Fantasma termina a rodada com vitória dos Moradores;
  - a escolha dos papéis evita repetir o mesmo Fantasma em rodadas seguidas e dá um pouco mais de chance a quem nunca foi Fantasma ou Detetive.

### 5D.4 Bots nos modos novos

- **Corrida:** RoboPuffs sobem por pontos de caminho da rampa, erram às vezes (pulam tarde um barril) e usam o Puffador com pouca frequência. Mesmas regras de recompensa da 5B.
- **Mistério:** bots só podem ser **Moradores**. Andam entre os cômodos, pegam moedas e fogem quando um jogador corre para eles. **Nunca** são Fantasma nem Detetive, porque o modo depende de blefe e leitura de gente.
- O Mistério roda com **pelo menos 2 humanos** (os bots completam até 6 como Moradores). Com só 2 o Detetive sabe que o Fantasma é o outro humano, mas o voto na porta precisa valer para quem joga em dupla; com 3+ volta a haver dúvida. Abaixo de 2, a rotação pula para a Arena.

---

## Números iniciais

Valores de partida para o playtest. Ficam em `config/ModeRotationConfig`, `config/RaceConfig` e `config/MysteryModeConfig` (novos).

| Item | Valor inicial |
|---|---|
| Sequência da rotação (sem votos) | Arena → Corrida → Arena → Mistério |
| Portas do mirante (de −Z para +Z) | Corrida · Arena · Mistério |
| Partidas iniciais só na Arena | 3 |
| Tela de abertura do modo | 3 s |
| **Corrida:** duração máxima | 2 min 30 s |
| Corrida: subida sem erros | 60–90 s |
| Corrida: checkpoints | 3 |
| Corrida: aviso da sombra | 1 s |
| Corrida: força do Puffador | 50% da Arena |
| Corrida: fim | 3º jogador chega ou o tempo acaba |
| **Mistério:** duração | 3 min |
| Mistério: humanos mínimos | 2 (bots completam até 6) |
| Mistério: proteção inicial | 10 s sem sustos |
| Mistério: recarga do Lençol Voador | 4 s |
| Mistério: recarga do Puffador do Detetive | 2 s |
| Mistério: atordoamento por erro | 3 s + Puffador cai |
| Mistério: moedas por jogador | até 10 por rodada |
| Mistério: moedas por ticket | 5 moedas = 1 🎟 (máx. 2 por rodada) |

**Tickets por modo** (mesmos valores de `RewardConfig` de hoje, para nenhum modo pagar mais):
- participação: 1 🎟 em todos os modos;
- top 3: 1 🎟 (Corrida: pódio; Mistério: Moradores acordados no fim e quem capturou);
- vitória: 1 🎟 (Corrida: 1º lugar; Mistério: Fantasma vencedor, Detetive ou Herói que capturou, e Moradores acordados quando o tempo acaba);
- moedas do Mistério substituem os tickets que a Arena dá pelo cofre, mantendo o total parecido.

---

## Arquitetura técnica

- **Servidor:**
  - `RoundService` é dividido: o ciclo (espera, contagem, ativo, resultado, intervalo) fica nele; o que é da Arena vai para um modo `ArenaMode`. Cada modo implementa `canRun(participants)`, `prepare()`, `start(participants)`, `onTick(dt)`, `isOver()`, `buildResult()` e `cleanup()`;
  - `ModeRotation` (módulo puro): escolhe o próximo modo pela sequência, pelas condições de cada um e pela regra do novato;
  - `RaceMode` (novo) + `TowerBuilder` (mapa da torre) + `RaceHazards` (barris, quadros, lustres, engrenagens, com a sombra como aviso no cliente);
  - `MysteryMode` (novo) + `MysteryWingBuilder` (Ala do Mistério reaproveitando `MansionLayout` e `MansionWing`) + `MysteryRoles` (módulo puro de sorteio de papéis);
  - os mapas dos modos ficam longe do Casarão do lobby e da Arena; são montados uma vez no início do servidor e só resetados entre rodadas (sem reconstruir tudo a cada partida);
  - `BotBrainService` ganha comportamentos por modo (subir a rampa; andar e fugir como Morador).
- **Cliente:**
  - `ModeIntroView` (tela de abertura) e o rótulo do próximo modo na fila;
  - `RoleCardView` (cartão do papel), com o papel guardado só no cliente do próprio jogador;
  - sombras de aviso da Corrida, sons e efeitos só no cliente.
- **Rede e segurança:**
  - o papel de cada jogador é enviado **só para ele** (nunca num atributo replicado para todos);
  - "Assustar" e o Lençol Voador são conferidos no servidor (distância, recarga, papel);
  - tiros do Puffador do Detetive usam a mesma conferência do `ProjectileService`;
  - a chegada ao topo da Corrida é conferida pela posição no servidor, não por um toque do cliente.
- **Desempenho no celular:** a torre e a Ala do Mistério seguem o mesmo orçamento de peças e de luz do Casarão (5C); com três mapas no servidor, avaliar o `StreamingEnabled` (já previsto na 5C).
- **Telemetria:** `ModeStarted`, `ModeFinished`, `ModeSkipped` (com o motivo), `ModeQuit` (saiu no meio, por modo), `RaceCheckpoint`, `RaceFinish` (tempo e posição), `RaceHazardHit`, `MysteryRoleAssigned`, `MysteryScare`, `MysteryMisfire` (Detetive acertou Morador), `MysteryGunPickup`, `MysteryResult` (quem venceu e como).

---

## Testes automatizados (Lune)

Módulos puros, com testes antes da implementação:
- `ModeRotation`: sequência, pulo quando falta gente, sem repetir modo novo, regra das 3 primeiras partidas, Party com novato.
- `MysteryRoles`: sempre 1 Fantasma e 1 Detetive, bots nunca recebem esses papéis, peso para quem nunca foi, sem repetir o Fantasma seguido.
- `MysteryRules`: condições de vitória, punição do Detetive, quem pode pegar o Puffador, saída do Fantasma.
- `RaceRanking`: ordem de chegada e desempate por altura.
- `RoundResultBuilder` com resultados de cada modo.

---

## Critérios de aceite

- [ ] Com a rotação desligada (só Arena), nada muda no comportamento nem no perfil (5D.1).
- [ ] O próximo modo aparece no intervalo e na abertura, para todos.
- [ ] Novatos jogam as 3 primeiras partidas na Arena.
- [ ] O Mistério nunca começa com menos de 2 humanos (fora o teste solo do Studio).
- [ ] Na Corrida, todo objeto que cai tem aviso antes, e ninguém é eliminado.
- [ ] No Mistério, nenhum jogador consegue descobrir o papel de outro pela rede ou pela interface.
- [ ] O Puffador cai quando o Detetive erra ou desmaia, e qualquer Morador pode pegá-lo.
- [ ] Bots nunca são Fantasma nem Detetive.
- [ ] Os tickets por rodada ficam parecidos entre os três modos.
- [ ] Ficha da Partida e Party funcionam igual em todos os modos.
- [ ] Desempenho estável no celular nos três mapas.

---

## Testes manuais prioritários

1. Rodar a rotação inteira (4 partidas) com 6 jogadores.
2. Rotação com 2 humanos: o Mistério é pulado.
3. Party com um novato: a Arena entra nas 3 primeiras partidas dele.
4. Corrida: ser atingido por cada obstáculo, cair e voltar ao checkpoint certo.
5. Corrida: empurrar alguém com o Puffador perto da borda.
6. Corrida: dois jogadores chegando quase juntos ao topo.
7. Mistério: Detetive acerta o Fantasma; Detetive acerta um Morador; Morador pega o Puffador e vira Herói.
8. Mistério: Fantasma sai do jogo no meio da rodada.
9. Mistério: o tempo acaba com Moradores acordados.
10. Mistério: tentar ler o papel de outro jogador (atributos, remotes, chat dos Fantasminhas).
11. Celular: subir a torre inteira e jogar uma rodada de Mistério no escuro.

---

## Perguntas do playtest

- os jogadores ficam mais tempo no servidor com a rotação do que só com a Arena?
- algum modo faz mais gente sair do jogo no meio? Qual?
- a Corrida está difícil demais ou fácil demais? Os obstáculos parecem justos?
- as crianças entendem o seu papel no Mistério sem ajuda?
- o Detetive atira em qualquer um ou fica com medo de errar? (a punição está na medida?)
- o Fantasma consegue se disfarçar ou é descoberto logo?
- desmaiar cedo no Mistério frustra? O Fantasminha espectador segura o jogador até o fim?
- quais portas recebem mais votos, e quantas partidas ainda saem da rotação (sem votos)?

---

## Métricas de sucesso

- tempo de sessão e partidas por sessão antes e depois da 5D;
- retenção D1 e D7 antes e depois da 5D;
- % de jogadores que saem no meio, por modo;
- vitórias do Fantasma × Moradores (meta inicial: perto de 40% × 60%);
- tempo médio de subida na Corrida e % que chega ao topo.

---

## Ordem das entregas

1. **5D.1 Rotação de modos**, com só a Arena (refatoração sem mudança visível).
2. **5D.2 Corrida da Torre** (mais simples, valida a rotação e reaproveita o Puffador e a física de queda).
3. **5D.4 Bots na Corrida.**
4. **5D.3 Mistério no Casarão.**
5. **5D.4 Bots no Mistério** e ajuste da rotação com os dados do playtest.

---

## Fora de escopo desta entrega

- perks do Fantasma (correr mais rápido, ficar invisível por um instante, armadilha) e itens cosméticos por papel;
- modo Assassino (todos contra todos com alvos), versão "Hardcore" e outros modos;
- rankings globais por modo.

---

## Gate para a Fase 6

Avançar quando a rotação aumentar o tempo de sessão e o número de partidas por sessão sem aumentar a saída no meio da partida, e quando os três modos rodarem estáveis no celular.
