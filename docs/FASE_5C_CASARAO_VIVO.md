# Fase 5C — Casarão Vivo: explorar, descobrir, colecionar

**Entrega:** transformar o Casarão (o lobby) num lugar para explorar enquanto se espera a partida: um Casarão maior e com portas, relíquias escondidas para colecionar, mistérios para resolver e surpresas que dão vida, sem atrapalhar a fila da partida.
**Dependência:** Fase 5 (armadilhas) e Fase 5B (bots) estáveis. Perfil protegido (`ProfileGuard`): tudo o que o jogador coleciona aqui é progresso e nunca pode sumir.

---

## Problema

Hoje o Casarão é bonito, mas passivo: o jogador nasce no Salão Principal, olha as estações (Puff Machine, Puffdex, desafios, Party, treino), vai para o mirante e espera. Não há motivo para andar pelo Casarão, nada para descobrir e nada que o jogador leve embora da espera. Quem espera sem ter o que fazer sai do jogo, e o tempo de sessão e a retenção (D1, D7) são o que faz o Roblox recomendar o jogo.

Além disso, **só está na fila quem fica no mirante**. Se o Casarão ficar interessante sem mudar isso, o jogador vai ter que escolher entre explorar e jogar, e as partidas esvaziam.

---

## Resultado esperado

O jogador passa a:
- explorar o Casarão enquanto espera, sem medo de perder a partida;
- abrir portas, entrar em cômodos novos e procurar coisas escondidas;
- colecionar relíquias que ficam salvas no perfil e completar um álbum;
- resolver mistérios simples e descobrir salas secretas;
- voltar no dia seguinte para achar a Relíquia do Dia;
- correr com os amigos atrás do Fantasminha quando ele aparece;
- mostrar aos amigos o que descobriu.

---

## Princípios

1. **Explorar nunca custa a partida.** Quem entrou na fila pode passear: a partida chama o jogador onde ele estiver (Ficha da Partida).
2. **Coleção é sagrada.** Relíquias, páginas e salas descobertas são progresso salvo no perfil, com a mesma proteção dos Puffs: nunca diminuem e nunca somem.
3. **Pista, não seta.** O jogo dá dicas (quadros, Diário do Barão, sons), não setas no chão. A graça é descobrir. A única exceção é o mapa, que mostra só os cômodos já visitados.
4. **Uma criança entende sozinha.** Quebra-cabeças curtos, visuais e sem texto longo: acertar a hora, acender velas na ordem, tocar uma melodia.
5. **Recompensa pequena e única.** Cada relíquia, página ou segredo rende uma vez. Nada no Casarão vira fonte de tickets infinita; o grosso dos tickets continua vindo das partidas.
6. **Leve no celular.** Cômodos com poucas peças, uma luz sem sombra por cômodo e animações só no cliente, como no Casarão de hoje.
7. **Servidor decide, cliente desenha.** Quem achou o quê, quem resolveu o quê e os prêmios são do servidor. Portas abrindo, sons e efeitos são do cliente.

---

## Escopo

### 5C.1 Ficha da Partida, portas e cômodos novos

- **Ficha da Partida** (a base de tudo):
  - entrar na fila continua sendo pelo mirante ou pelo botão 🏟 JOGAR, mas agora o jogador **recebe uma ficha e pode sair do mirante** sem perder o lugar;
  - a etiqueta da fila mostra "🎟 FICHA DA PARTIDA · você está na fila" e um botão para devolver a ficha (sair da fila);
  - quando a contagem começa, quem tem ficha recebe o aviso "⚔️ Sua partida começa em 15 s!" com sino, a tela pisca de leve na borda e a ficha balança no HUD;
  - no fim da contagem, quem tem ficha vai para a arena de onde estiver, como hoje vai quem está no mirante;
  - a ficha vale para a Party: basta um membro com ficha para o grupo todo;
  - a ficha é devolvida sozinha quando o jogador sai do jogo ou fica parado (AFK) por muito tempo, para a partida não esperar por quem não está jogando;
  - o mirante continua sendo o lugar de assistir à partida e de esperar com os amigos.
- **Portas de verdade:**
  - abrem com o prompt "Abrir" (ou ao encostar, configurável por porta), com rangido, e fecham sozinhas depois de alguns segundos com uma batida;
  - a animação e a colisão são do cliente de quem passa: cada um vê e atravessa a porta no seu ritmo, sem disputa entre jogadores;
  - **portas trancadas** pedem uma chave (relíquia-chave achada em outro cômodo);
  - **portas de nível** só abrem a partir de um nível ou prestígio ("🔒 Nível 10", "🔒 Prestígio ★1"): mostram o que tem do outro lado por uma fresta e viram objetivo de longo prazo.
- **Cômodos novos** (ampliação do Casarão, `MansionLayout`):
  - **Biblioteca:** estantes altas, escada de rodinhas, poltronas de leitura e um livro "errado" que abre uma passagem;
  - **Sala de Música:** piano tocável (cada tecla toca uma nota), gramofone e partituras na parede;
  - **Sótão** (subindo uma escada estreita): escuro, iluminado por uma lanterna que o jogador pega na entrada, com baús, teias e móveis cobertos por lençóis;
  - **Porão/Adega** (descendo): barris, goteiras e a entrada de um túnel fechado;
  - a **Torre do Relógio** fica para a 5C.3, junto dos mistérios.
  - Para não aumentar demais a área (celular), o Sótão e o Porão usam andares acima e abaixo do Casarão de hoje, em vez de alargar o terreno.

### 5C.2 Relíquias e o Álbum do Casarão

- **Relíquias escondidas:** 40 objetos pequenos espalhados pelo Casarão, 5 em cada um de 8 cômodos (Salão Principal, Salão da Coleção, Jardim do Barão, Ponto de Encontro, Biblioteca, Sala de Música, Sótão e Porão): bonequinhos Puff, chaves antigas, retratos em miniatura, moedas do Barão, peças de xadrez.
  - Cada relíquia brilha de leve de perto e tem um prompt "Pegar".
  - Pegar toca um som, mostra o cartão da relíquia ("📜 Relíquia encontrada: Chave de Latão · Biblioteca 3/5") e salva no perfil.
  - Quem já tem a relíquia vê o lugar dela vazio, com um contorno, para saber que já pegou.
- **Álbum do Casarão** (modal novo, botão no cartão do perfil e uma estante no Salão da Coleção):
  - página por cômodo, com as 5 relíquias (as que faltam aparecem como silhuetas com uma dica curta);
  - **completar um cômodo** dá tickets e um título ("Bibliotecário", "Rato de Sótão", "Maestro");
  - **completar o álbum** dá um **Puff exclusivo** ("Puff Explorador"), que não sai na Puff Machine (só visual, como todos os Puffs).
- **Relíquia do Dia:** uma relíquia especial aparece num lugar diferente a cada dia (sorteado de uma lista de esconderijos). Achar rende tickets e conta para uma coleção própria ("Relíquias do Dia: 7 de 30"), que dá prêmio ao completar. Combina com o retorno diário que já existe.

### 5C.3 Mistérios do Barão

- **Diário do Barão:** 10 páginas escondidas pelo Casarão contam a história do Barão e do Casarão. Cada página tem uma pista de um mistério. A última página revela onde fica o Gabinete secreto.
- **Quebra-cabeças** (cada um abre uma sala ou um baú, uma vez por jogador):
  - **Torre do Relógio:** acertar os ponteiros na hora que aparece num quadro;
  - **Velas do Salão Principal:** acender os candelabros na mesma ordem das cores dos vitrais;
  - **Piano:** tocar a melodia escrita na partitura do Sótão;
  - **Cofrinho do Porão:** o código de 3 dígitos está espalhado em três quadros.
- **Salas secretas:** a estante da Biblioteca gira e abre o **Gabinete do Barão** (só para quem achou todas as páginas); o túnel do Porão leva a uma sala com o baú do tesouro. Recompensa: tickets, título e um troféu na estante do Gabinete.
- O progresso é por jogador: cada um resolve o seu. Quem já resolveu vê a passagem aberta para ele e pode levar amigos (a passagem abre para quem está junto enquanto o dono estiver perto).

### 5C.4 Vida e eventos no Casarão

- **Barão passeando:** o Barão amigável sai da caminha de tempos em tempos e anda por um caminho entre os cômodos, sem nunca atrapalhar a passagem. Fazer carinho onde ele estiver continua igual, com uma pequena chance de presente (limitada por dia).
- **Fantasminha Puff:** a cada poucos minutos aparece num cômodo aleatório, com um risinho e um aviso discreto ("👻 Um Fantasminha apareceu na Biblioteca!"). O primeiro jogador a encostar nele ganha tickets. É um evento rápido e social: todo mundo corre. Limite por jogador por dia.
- **Ambiente:**
  - quadros com olhos que seguem quem passa;
  - lustres que balançam de leve quando uma porta bate perto;
  - o relógio da torre bate a cada poucos minutos;
  - trovão e relâmpago pelas janelas durante a Tempestade da partida (5.7), para quem está no lobby também sentir.
- **Mapa do Casarão** (modal): os cômodos aparecem conforme o jogador entra neles, com "% explorado" e onde estão os amigos da Party. Chegar a 100% dá a conquista "Explorador".
- **Obby do Sótão** (opcional, se sobrar tempo): percurso curto no telhado e no sótão, com cronômetro e ranking semanal ("mais rápido do Casarão").

---

## Números iniciais

Valores de partida para o playtest. Ficam em `config/MansionLifeConfig` (novo) e `config/QueueConfig`.

| Item | Valor inicial |
|---|---|
| Aviso da Ficha antes da partida | 15 s |
| Ficha devolvida por AFK | 3 min parado |
| Porta fecha sozinha | 4 s |
| Relíquias | 40 (8 cômodos × 5) |
| Prêmio por relíquia | 1 🎟 |
| Prêmio por cômodo completo | 5 🎟 + título |
| Álbum completo | Puff Explorador (exclusivo) + título |
| Relíquia do Dia | 2 🎟 (coleção de 30) |
| Páginas do Diário | 10 |
| Quebra-cabeça resolvido | 5 🎟 (uma vez) |
| Fantasminha | a cada 3–5 min, 2 🎟, até 5 por jogador por dia |
| Presente do Barão | 10% por carinho, até 3 por dia |

Referência da economia: a Puff Machine custa 5 🎟 e uma vitória rende 3. O Casarão inteiro rende algo como 150–200 🎟 **uma vez na vida do jogador**, mais um pouco por dia (Relíquia do Dia e Fantasminha), sem competir com as partidas.

---

## Arquitetura técnica

- **Servidor:**
  - `MatchQueueService` passa a ter a Ficha: lista de quem está na fila independente de onde está, aviso no começo da contagem e teleporte no fim. A rotação justa e a Party continuam iguais;
  - `MansionService` e `MansionLayout` ganham os cômodos novos, os andares de cima e de baixo e as portas (cada porta com tag `MansionDoor` e atributos de tipo, chave ou nível);
  - `RelicService` (novo): lista das relíquias, prompts, coleta (com conferência de distância), prêmios e Relíquia do Dia;
  - `MysteryService` (novo): páginas do Diário, quebra-cabeças e salas secretas por jogador;
  - `MansionLifeService` (novo): Barão passeando, Fantasminha e relógio;
  - perfil: novos campos (relíquias, páginas, mistérios resolvidos, cômodos visitados, relíquias do dia) sempre protegidos pelo `ProfileGuard.mergeForSave`, que só deixa crescer.
- **Cliente:**
  - `MansionDoorController`: animação, colisão local e sons das portas;
  - `RelicController` e `AlbumView` (modal, no padrão `ResponsiveScale.fit`);
  - `MansionMapView` (modal);
  - efeitos de ambiente (olhos dos quadros, lustres, relógio) só no cliente e só perto do jogador.
- **Rede:** um remote por ação (pegar relíquia, resolver mistério) com conferência no servidor; o estado do jogador (o que ele já tem) vai no perfil que já é enviado ao cliente.
- **Segurança:** o servidor confere a distância do jogador até a relíquia ou ao quebra-cabeça e limita a frequência dos pedidos. A resposta do quebra-cabeça é conferida no servidor, nunca no cliente.
- **Desempenho no celular:**
  - orçamento de peças por cômodo e uma luz sem sombra por cômodo;
  - avaliar ligar o `StreamingEnabled` com a ampliação (o Casarão e a arena ficam longe um do outro);
  - nada animado pelo servidor além do Barão e do Fantasminha.
- **Sons:** os sons embutidos do Roblox são poucos. Portas (rangido e batida), relógio, piano, risinho do fantasma e coleta usam áudios gratuitos do Creator Store, com os IDs em config, como nas armadilhas.
- **Telemetria:** `LobbyTime`, `RoomEntered`, `RelicFound`, `RoomSetCompleted`, `AlbumCompleted`, `DailyRelicFound`, `PageFound`, `PuzzleSolved`, `SecretRoomOpened`, `GhostCaught`, `QueueTicketTeleport` e `QueueTicketMissed` (partida perdida apesar da ficha).

---

## Critérios de aceite

- [ ] Quem tem a Ficha pode passear pelo Casarão inteiro e entra na partida sem perder a vez.
- [ ] Ninguém é levado para a partida sem o aviso de 15 s.
- [ ] Portas abrem e fecham com som, para cada jogador no seu ritmo, sem prender ninguém.
- [ ] Portas trancadas e de nível só abrem para quem tem a chave ou o nível.
- [ ] Relíquias, páginas, mistérios e cômodos visitados ficam salvos e nunca somem, nem com falha de salvamento.
- [ ] Cada prêmio do Casarão sai uma vez só (exceto Relíquia do Dia, Fantasminha e presente do Barão, que têm limite diário).
- [ ] O Álbum mostra o que falta com dicas, sem entregar o lugar.
- [ ] Quebra-cabeças conferidos no servidor; nenhuma resposta fica no cliente.
- [ ] Uma criança resolve cada quebra-cabeça sem ler texto longo.
- [ ] Desempenho estável no celular com o Casarão ampliado.

---

## Testes manuais prioritários

1. Entrar na fila, sair do mirante, ir para o Sótão: aviso de 15 s e teleporte para a arena.
2. Party com um membro com Ficha e os outros explorando.
3. Ficha com o jogador parado (AFK) e com o jogador saindo do jogo.
4. Duas pessoas atravessando a mesma porta ao mesmo tempo.
5. Porta trancada antes e depois de achar a chave; porta de nível com nível abaixo e acima.
6. Pegar relíquia, sair do jogo e voltar: ela continua no Álbum.
7. Pegar relíquia com o perfil ainda carregando ou com o salvamento falhando.
8. Completar um cômodo e o Álbum: prêmios uma vez só.
9. Relíquia do Dia na virada do dia.
10. Cada quebra-cabeça certo, errado e com spam de tentativas.
11. Fantasminha com vários jogadores correndo para ele.
12. Celular: subir ao Sótão, descer ao Porão e abrir o Álbum e o Mapa.

---

## Perguntas do playtest

- os jogadores saem do mirante para explorar depois de ganhar a Ficha?
- alguém perde a partida por estar explorando?
- as relíquias estão difíceis demais ou fáceis demais de achar?
- as crianças entendem os quebra-cabeças sem ajuda?
- o Fantasminha anima ou atrapalha?
- o tempo no lobby e a retenção D1 e D7 subiram?

---

## Métricas de sucesso

- tempo médio no lobby por sessão e tempo de sessão total;
- relíquias encontradas por sessão e % de jogadores com ao menos um cômodo completo;
- retenção D1 e D7 antes e depois da 5C;
- % de partidas que começam com todos os jogadores com Ficha presentes.

---

## Ordem dentro da Fase 5

As entregas da 5C são independentes das armadilhas e podem entrar entre a 5.6 e a 5.7 ou depois dela. Ordem sugerida:

1. **5.7 Tempestade** (curta, fecha a partida viva).
2. **5C.1 → 5C.2 → 5C.3 → 5C.4** (Casarão Vivo).
3. **5.8 Momentos Puff, conquistas, telemetria e ajuste**, cobrindo armadilhas e Casarão Vivo juntos, com os dados dos dois.

A decisão final da ordem fica para antes de começar a 5.7.

---

## Gate para a Fase 6

Avançar quando o lobby prender o jogador entre as partidas (tempo no lobby e retenção em alta), sem esvaziar a fila da partida e com desempenho estável no celular.
