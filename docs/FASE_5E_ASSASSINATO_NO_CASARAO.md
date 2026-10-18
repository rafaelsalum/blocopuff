# Fase 5E — Assassinato no Casarão

**Entrega:** trocar o Mistério no Casarão (Fantasma, susto e lençol) por um modo **fiel ao Murder Mystery 2**: um **Assassino** com faca, um **Xerife** com arma, **Inocentes** que coletam moedas e fogem, e o **Herói** que pega a arma caída. Com sorteio de papéis em tela cheia, mapa novo de dois andares e bots que andam direito.
**Dependência:** Fase 5D entregue (rotação, voto pela porta do mirante, `RoundMode`). Substitui a 5D.3 e a parte do Mistério da 5D.4. Deve ficar pronta **antes** da Fase 6.

---

## Problema

O Mistério da 5D.3 foi jogado em família e não divertiu. Os motivos:

1. **O sorteio não aparece.** O papel surge num aviso pequeno no canto. No MM2 a tela inteira gira e para no papel, e esse é o momento de maior expectativa da partida.
2. **Não há ameaça.** "Assustar encostando" não dá medo de ninguém chegar perto. No MM2 a tensão vem da faca escondida, que pode aparecer a qualquer momento, e do arremesso, que pega quem foge em linha reta.
3. **Os bots andam nas paredes.** `MysteryBots` manda o bot andar em linha reta até um ponto sorteado de outro cômodo, sem passar pelas portas.
4. **O mapa é repetitivo.** São 9 cômodos iguais numa grade, escuros, com poucos móveis, sem caminhos em círculo para fugir, cantos para se esconder nem lugares marcantes.

---

## Resultado esperado

O jogador passa a:
- ver uma **roleta em tela cheia** que para no papel dele (🔪 Assassino, 🔫 Xerife, 😇 Inocente), com o objetivo em uma frase;
- sentir a tensão de não saber quem tem a faca até ela aparecer;
- fugir por escadas, corredores e passagens de um Casarão de dois andares cheio de móveis e esconderijos;
- virar Herói ao pegar a arma do Xerife caída;
- ver, no fim, quem era quem e quem eliminou quem;
- jogar com bots Inocentes que andam pelas portas, fogem da faca e buscam a arma caída.

---

## Princípios

1. **Copiar o que funciona no MM2.** Papéis secretos, uma faca, uma arma, punição por tiro errado, arma que cai e vira do Herói, moedas para dar motivo de andar. Só a pele é do BlocoPuff.
2. **Violência de desenho animado.** Sem sangue, sem corpo no chão: quem é eliminado vira fumaça e confete e o Puff some com um "puf". Nos textos da interface, a palavra é **eliminar**, nunca "matar". A classificação de maturidade da experiência é atualizada pelo dono do jogo ao publicar (provável "violência leve", como o MM2).
3. **O Assassino é sempre humano.** O modo depende de blefe e de leitura de gente. Bots são **só Inocentes** (nunca Assassino nem Xerife).
4. **O papel é óbvio para quem o tem, e secreto para os outros.** Roleta grande, selo fixo no alto da tela, cor própria por papel. Ninguém mais recebe essa informação.
5. **Servidor decide, cliente desenha.** Papéis, golpes, arremessos, tiros, posse da arma e vencedores são do servidor. Roleta, sons e efeitos são do cliente.
6. **Funciona no celular.** Botões grandes de sacar, golpear, arremessar e atirar; o mapa respeita o orçamento de peças e de luz do Casarão.
7. **Economia igual entre modos.** O modo não rende mais tickets que a Arena e a Corrida.

---

## Escopo

### Papéis

| Papel | Quantos | O que faz |
|---|---|---|
| 🔪 **Assassino** | 1 (sempre humano) | Tem a faca. Vence se eliminar todos os outros. |
| 🔫 **Xerife** | 1 (sempre humano) | Tem a arma com 1 tiro. Vence com os Inocentes. |
| 😇 **Inocentes** | o resto (humanos e bots) | Coletam moedas, observam, fogem e se escondem. Podem pegar a arma caída. |
| 🦸 **Herói** | quem pegar a arma | Um Inocente que pegou a arma do chão; mesmas regras do Xerife. |

- **Sorteio com peso:** quem foi o papel menos vezes tem mais chance; o Assassino da partida anterior não repete quando há outra opção (as regras de `MysteryModeRules.assignRoles` continuam valendo, com os papéis renomeados).
- **Com 2 humanos:** um é o Assassino e o outro o Xerife; os bots completam como Inocentes. O Xerife sabe que o Assassino é o outro humano, mas a perseguição, os arremessos, as moedas e a arma caída continuam valendo. Com 3 ou mais humanos volta a ter dúvida.

### Sorteio e papel na tela

- **Roleta em tela cheia (3 s)**, na abertura da partida, só para o próprio jogador: os três cartões giram e param no papel, com som de impacto, cor própria (🔪 vermelho, 🔫 azul, 😇 verde) e o objetivo em uma frase:
  - Assassino: "Elimine todos sem ser pego pelo Xerife";
  - Xerife: "Descubra o Assassino e acerte-o. Errar elimina você";
  - Inocente: "Fuja, colete moedas e pegue a arma se ela cair".
- **Selo fixo no alto da tela**, grande, durante toda a partida (papel, cor e ícone).
- **Revelação no fim:** a tela de resultado mostra o papel de todos, quem eliminou quem e quem pegou a arma.

### Faca do Assassino

- **Sacar e guardar:** botão próprio (tecla e botão no celular). Guardada, a faca não aparece; sacada, todos a veem na mão do Assassino. Sacar leva 0,4 s.
- **Golpe de perto:** com a faca sacada, elimina o primeiro alvo à frente dentro do alcance.
- **Arremesso:** a faca voa em linha reta, para na primeira parede ou móvel e elimina o primeiro que atingir; volta para a mão após a recarga.
- **Proteção da largada:** sem golpes nem arremessos nos primeiros 10 s.
- **Servidor confere:** papel, faca sacada, recarga, distância, ângulo à frente e linha de visão (raio contra paredes e móveis). O cliente só pede o golpe ou a direção do arremesso.
- O arremesso reaproveita o projétil simulado no servidor do Lençol Voador (`MysterySheet`).

### Arma do Xerife e o Herói

- **Um tiro**, recarga de 3 s, mira pelo mesmo caminho do Puffador (`ProjectileService`, conferido no servidor).
- **Acertar o Assassino:** Inocentes vencem na hora.
- **Acertar um Inocente:** o Inocente é eliminado **e o Xerife também**, e a arma cai no chão (regra do MM2).
- **Xerife eliminado pelo Assassino:** a arma cai onde ele estava.
- **Arma caída:** brilho e feixe de luz visíveis de longe, aviso para todos ("🔫 A arma do Xerife caiu!"). Qualquer Inocente vivo (humano) que encostar vira Herói. O Assassino não pode pegá-la. Reaproveita a lógica de arma caída da 5D.3 (`lastGunPosition`, `canPickUp`, volta ao centro do mapa se cair num lugar inválido).

### Eliminação e espectadores

- Quem é eliminado vira fumaça e confete, sai do mapa e **assiste à partida** (câmera alternando entre os vivos).
- O chat de eliminados não chega a quem está vivo.
- Quem sair do jogo sendo Assassino encerra a partida com vitória dos Inocentes. Se o Xerife sair, a arma cai onde ele estava.

### Vitória

- **Assassino vence** se eliminar todos os outros.
- **Inocentes vencem** (com o Xerife e o Herói) se o Assassino for eliminado ou se o tempo acabar com algum Inocente vivo.

### Moedas

- Espalhadas pelos cômodos, **saco de até 10 por jogador** por partida, com aviso de "saco cheio".
- O Assassino também coleta (senão o contador de moedas o denunciaria).
- 5 moedas = 1 🎟, máximo 2 por partida (como na 5D.3).

### Mapa novo: a Ala do Assassinato

Substitui a grade de 9 cômodos iguais. Fica longe do lobby, da Arena e da Torre, montada uma vez no início do servidor e só resetada entre partidas.

- **Dois andares** de 3 x 2 cômodos (32 x 36 studs), com **portas entre todos os vizinhos**, **duas escadas** em lados opostos (Salão de Baile → Sala de Música e Sala de Estar → Estufa) e **uma passagem secreta**: um corredor escondido atrás das estantes, da Biblioteca até a Cozinha. Assim existem caminhos em círculo: quem foge sempre tem para onde ir.
- **Cômodos com identidade**, cada um com móveis próprios:
  - térreo: Biblioteca, Sala de Jantar, Cozinha, Salão de Baile, Hall de Entrada, Sala de Estar;
  - andar de cima: Quarto do Barão, Corredor dos Retratos, Quarto de Hóspedes, Sala de Música, Sala de Jogos, Estufa.
- **Esconderijos:** armários, debaixo de mesas e camas, atrás de cortinas. O jogador fica parcialmente visível, nunca invisível.
- **Luz suficiente para enxergar:** um lustre e duas arandelas por cômodo (luz verde na Estufa); a passagem secreta fica na penumbra.
- **Linhas de visão quebradas:** colunas, estantes e biombos impedem ver o mapa inteiro de um ponto.
- **Pontos de navegação** dos bots já fazem parte da planta (centro de cada cômodo, cada porta, pé e alto de cada escada com um ponto de aproximação, e a passagem secreta).
- Mesmo orçamento de peças e de luz do Casarão (5C), tudo ancorado.

### Bots Inocentes

- **Navegação por grafo:** os pontos de navegação do mapa formam um grafo (cômodos, portas, escadas); o bot calcula o caminho até o destino passando pelas portas e anda de ponto em ponto. O pathfinding do Roblox fica como reserva.
- **Destravar:** se o bot não avançar por 2 s, volta para o ponto de navegação mais próximo e recalcula.
- **Comportamento:**
  - anda entre cômodos coletando moedas;
  - **foge** de quem estiver com a faca sacada a menos de 25 studs, para o lado oposto do grafo;
  - se a arma cair, os bots **não** a pegam (só humanos viram Herói), mas olham e andam na direção dela, o que ajuda o humano a achá-la;
  - nunca blefa nem acusa ninguém.

### Porta do mirante e nomes

- A porta roxa vira **"🔪 ASSASSINATO NO CASARÃO"** ("Entre para votar · a partir de 2 jogadores").
- O id interno do modo continua `Mystery` (rotação, voto, telemetria e atributos já usam esse id); mudam os textos, os papéis e os arquivos internos do modo.
- Sai do jogo: o Fantasma, o susto, o Lençol Voador e o "Detetive com Puffador".

---

## Números iniciais

Ficam em `config/MysteryModeConfig`.

| Item | Valor inicial |
|---|---|
| Duração | 3 min |
| Humanos mínimos | 2 (bots completam até 6, só como Inocentes) |
| Roleta do papel | 3 s |
| Proteção da largada | 10 s sem golpes, arremessos nem tiros |
| Faca: tempo para sacar | 0,4 s |
| Faca: alcance do golpe | 5 studs, à frente (ângulo de 70°) |
| Faca: recarga do golpe | 1 s |
| Faca: arremesso | 90 studs/s, até 110 studs, recarga 4 s |
| Arma: tiros | 1, recarga 3 s |
| Arma: tiro em Inocente | Inocente e Xerife eliminados, arma cai |
| Arma caída: raio para pegar | 5 studs |
| Moedas: saco por jogador | 10 |
| Moedas por ticket | 5 moedas = 1 🎟 (máx. 2 por partida) |
| Bots: distância para fugir da faca | 25 studs |
| Bots: tempo para destravar | 2 s |

**Tickets** (mesmos valores de `RewardConfig`, para nenhum modo pagar mais):
- participação: 1 🎟;
- top 3: 1 🎟 (Inocentes vivos no fim, Xerife ou Herói que acertou o Assassino, Assassino vencedor);
- vitória: 1 🎟 (Assassino vencedor; Xerife ou Herói que acertou o Assassino; Inocentes vivos quando o tempo acaba);
- moedas: até 2 🎟.

---

## Arquitetura técnica

- **Servidor:**
  - `MysteryMode` continua implementando `RoundMode`; a lógica dos papéis, da faca e da arma sai do módulo atual para peças menores;
  - `MurderRules` (módulo puro, substitui `MysteryModeRules`): sorteio dos papéis, condições de vitória, punição do Xerife, quem pode pegar a arma, proteção da largada e recargas, alcance e ângulo do golpe, moedas em tickets;
  - `MurderKnife` (novo): sacar, guardar, golpe e arremesso (arremesso reaproveita o projétil de `MysterySheet`, renomeado);
  - `MurderGun` (novo): tiro, punição, arma caída e Herói (sai do `MysteryMode` atual);
  - `MurderMansionPlan` (módulo puro): a planta (cômodos, portas, escadas, passagem e pontos de navegação); `MurderMansionBuilder` (substitui `MysteryWingBuilder`) monta os dois andares e `MurderMansionProps`, os móveis e esconderijos;
  - `NavGraph` (módulo puro, novo): grafo de pontos, caminho mais curto (A*), ponto mais próximo e "lado oposto" para fugir;
  - `MysteryBots` passa a usar o `NavGraph` e o comportamento de fuga;
  - `MysteryCoins` ganha o saco com limite.
- **Cliente:**
  - `RoleRevealView` (novo): roleta em tela cheia e selo fixo do papel;
  - `MysteryModeController`: botões de sacar, golpear, arremessar e atirar (tecla, clique e toque), aviso de arma caída, música dos últimos 30 s, câmera de espectador;
  - tela de resultado com os papéis revelados.
- **Rede e segurança:**
  - o papel de cada jogador vai **só para ele** (remote dedicado), nunca num atributo replicado; o "faca sacada" é público, porque todos veem a faca;
  - golpe, arremesso e tiro são pedidos do cliente com limite de frequência e conferência completa no servidor (papel, recarga, distância, ângulo, linha de visão, vetores finitos);
  - a origem do arremesso é a posição do corpo no servidor (nunca a enviada pelo cliente), como já é no lençol;
  - handlers de acerto com `task.defer`, como no resto do `ProjectileService`.
- **Telemetria:** `MurderRoleAssigned`, `MurderKnifeEquip`, `MurderStab`, `MurderThrow`, `MurderThrowHit`, `MurderSheriffShot` (acerto, erro, Inocente), `MurderGunDropped`, `MurderHero`, `MurderResult` (quem venceu, como, duração), `MurderBotStuck`.

---

## Testes automatizados (Lune)

Escritos antes da implementação:
- `MurderRules`:
  - sempre 1 Assassino e 1 Xerife humanos, bots nunca recebem esses papéis, peso para quem foi menos vezes, sem repetir o Assassino seguido, funciona com 2 humanos;
  - vitória: Assassino eliminado, todos eliminados, tempo acabou com Inocente vivo, Assassino saiu do jogo;
  - tiro em Inocente elimina os dois e derruba a arma; Assassino não pega a arma; bot não pega a arma;
  - golpe: dentro e fora do alcance, atrás das costas, durante a proteção da largada, na recarga, com a faca guardada;
  - saco de moedas com limite e conversão em tickets.
- `NavGraph`: caminho entre cômodos passando pelas portas, caminho entre andares pelas escadas, ponto mais próximo, destino de fuga longe da ameaça, grafo desconectado não trava.
- `RoundResultBuilder` com o resultado do modo (papéis revelados).

---

## Critérios de aceite

- [ ] A roleta aparece em tela cheia para todos os jogadores na abertura e para no papel certo; o selo fica visível a partida inteira.
- [ ] Nenhum cliente recebe o papel de outro jogador antes do fim da partida.
- [ ] O Assassino só elimina com a faca sacada, dentro do alcance, à frente e sem parede no meio.
- [ ] O arremesso para na primeira parede ou móvel.
- [ ] Tiro do Xerife em Inocente elimina os dois e derruba a arma; a arma caída é vista de longe e vira do primeiro Inocente humano que encostar.
- [ ] O Assassino é sempre humano; bots são sempre Inocentes.
- [ ] Bots andam pelas portas e escadas sem atravessar nem raspar paredes; nenhum bot fica preso mais de 2 s.
- [ ] O mapa tem dois andares, duas escadas, uma passagem secreta, esconderijos e luz suficiente para enxergar.
- [ ] Com 2 humanos a partida acontece quando a porta roxa ganha o voto.
- [ ] Nenhum sangue, corpo no chão ou palavra "matar" na interface.
- [ ] Roda a 60 FPS num celular médio no mapa novo.

---

## Testes manuais prioritários

1. Partida com 2 humanos e bots: roleta, perseguição, arremesso, Xerife acertando o Assassino.
2. Xerife acertando um Inocente: os dois saem, a arma cai, outro humano vira Herói.
3. Assassino tentando golpear através de parede, de costas e durante a proteção da largada (deve falhar).
4. Bots fugindo de quem saca a faca e andando entre os andares por 3 partidas seguidas sem travar.
5. Assassino ou Xerife saindo do jogo no meio da partida.
6. Celular: botões de sacar, golpear, arremessar e atirar; FPS no mapa novo.
7. Teste solo do Studio continua possível (o jogador alterna Assassino e Xerife; um bot assume o outro papel **só no Studio**, para testar sozinho).

---

## Perguntas do playtest

- As crianças entendem o papel e o objetivo só pela roleta?
- O Assassino consegue eliminar alguém antes de ser descoberto, ou o Xerife acha rápido demais?
- O arremesso está forte demais (recarga, alcance)?
- Os Inocentes têm o que fazer (moedas, fugir, se esconder), ou ficam parados?
- O mapa tem caminhos suficientes para a fuga? Algum cômodo fica sempre vazio?
- Quantas partidas seguidas a porta roxa vence, comparada com as outras?

---

## Métricas de sucesso

- Votos na porta roxa: pelo menos tanto quanto a Corrida.
- Saída no meio da partida no Assassinato: não maior que na Arena.
- Duração média da partida: entre 1 min 30 s e 3 min (nem acaba em 20 s, nem sempre no tempo).
- Vitórias do Assassino entre 35% e 55%.
- Nenhum `MurderBotStuck` repetido no mesmo ponto do mapa.

---

## Ordem das entregas

1. **5E.1 Núcleo do Assassinato:** papéis novos, roleta e selo, faca (sacar, golpe, arremesso), arma do Xerife e Herói, eliminação em estilo desenho, revelação no fim, porta roxa renomeada. Ainda no mapa atual, para validar a diversão logo.
2. **5E.2 Mapa novo:** a Ala do Assassinato de dois andares, com os pontos de navegação.
3. **5E.3 Bots que andam direito:** `NavGraph`, destravar, fugir da faca.
4. **5E.4 Ritmo e acabamento:** saco de moedas, música dos últimos 30 s, câmera de espectador, sons da faca e da arma, ajuste dos números com o playtest.

Cada entrega é testada no Studio e tem commit próprio.

**Andamento:**
- **5E.1 entregue.** A arma do Xerife é o próprio Puffador (com 1 tiro a cada 3 s, sem empurrão) e fica sempre na mão; uma arma com cara de revólver e o "guardar a arma" ficam para a 5E.4. O XP do modo conta golpes, arremessos, moedas e pegar a arma (só sobreviver parado não conta). O voto da porta passou a durar entre partidas: quem volta da partida cai direto no mirante e continua votando no mesmo modo.
- **5E.2 entregue.** A Ala de dois andares substitui a grade de 9 cômodos. Ficou de fora o Porão: a passagem secreta vai da Biblioteca até a Cozinha (dá o mesmo atalho de fuga sem um terceiro nível). Os bots ainda andam em linha reta até um ponto sorteado (agora nos dois andares); andar pelos pontos de navegação é a 5E.3.
- **5E.3 entregue.** Os bots andam pelo grafo da planta (A* em `NavGraph`, seguido por `MysteryBotNav`): passam pelas portas, sobem e descem pelas escadas e usam a passagem secreta. Passeiam de cômodo em cômodo; fogem para um dos cômodos mais longe de quem estiver com a faca na mão a até 25 studs no mesmo andar, sem passar pelo cômodo dele; metade vai até perto da arma caída, sem pegá-la. Quando travam, pulam e refazem a rota, e desistem do destino depois de 3 travadas seguidas. No Studio, os Inocentes percorreram uns 450 studs em 40 s pelos dois andares, e um bot fugiu de 8 para 71 studs em 6 s depois que a faca foi sacada.
- **5E.4 (primeira parte) entregue.** O modo passou a ser em primeira pessoa, com a câmera travada nos olhos (sem afastar, para ninguém espiar por cima das paredes), campo de visão de 80° e sem balançar ao andar. Na tela aparecem só a mão e o item: a faca do Assassino (abaixada enquanto guardada, erguida quando à vista) ou a arma do Xerife e do Herói (com coice ao atirar). Os controles da faca ficaram assim: clique ou toque rápido golpeia; segurar e soltar arremessa para onde a mira aponta (a mão treme quando a carga enche). No celular há um botão só, no lugar e no visual do botão de tiro. Saem as teclas Q e E e os três botões. A faca não fica mais na mochila: o servidor saca ao atacar (todos a veem) e guarda 4 s depois do último ataque. A faca arremessada ficou maior, mais lenta (70 studs/s) e com rastro vermelho. Uma contagem abaixo da mira mostra quando a faca é liberada (10 s de carência no início).
- **Faca 3D e Puffador real.** A faca agora é a malha 3D gratuita "Knife model" da Creator Store (asset 3576051114, a faca clássica dos jogos de assassinato), montada por código como peça com FileMesh (`shared/modules/KnifeMesh`), sem arquivo binário. Ela é usada na mão do Assassino, no arremesso e na primeira pessoa (girada para mostrar a lateral da lâmina). A arma do Xerife e do Herói na primeira pessoa é o próprio Puffador, uma cópia em 75% das peças da ferramenta que ele segura, vista de lado.
- **Fantasmas e o Puffador caído.** Quem é eliminado deixa um fantasma no lugar até o fim da partida: uma cópia de pé do corpo e dos acessórios, translúcida e azulada, que flutua devagar, com luz fraca e o nome em cima, e que não bloqueia passagem, tiro nem faca (`MurderGhosts`). Quando o Xerife ou o Herói é eliminado, cai o próprio Puffador, girando acima do chão com o feixe azul (`MurderGunDrop`), e qualquer Inocente humano pode pegá-lo. Os bots não seguram mais o Puffador nessa partida: ele fica guardado e volta no fim. No teste solo do Studio, na rodada em que o jogador é o Assassino, um bot vira Xerife sem atirar, para dar para testar a arma caindo.

---

## Fora de escopo desta entrega

- skins de faca e de arma, efeitos de eliminação e outros cosméticos (Fase 6, monetização);
- perks do Assassino (correr mais rápido, ficar invisível por um instante, armadilha);
- outros mapas para o modo e votação de mapa;
- modo Assassino em que todos têm alvos, versão "Hardcore", ranking por modo;
- chat de voz.

---

## Gate para a Fase 6

Avançar quando a porta roxa receber votos com frequência, a saída no meio da partida não for maior que na Arena, e o modo rodar estável no celular com bots que não travam.
