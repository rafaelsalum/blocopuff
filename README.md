# BlocoPuff!

BlocoPuff! é um jogo multiplayer infantil, colorido e cartunesco para 2 a 10 jogadores. Os participantes permanecem sobre uma plataforma de blocos enquanto partes dela desaparecem; vence a rodada o último jogador restante.

## Stack

- Roblox Studio
- Luau em modo estrito (`--!strict`)
- Rojo 7 para sincronização entre os arquivos locais e o Roblox Studio
- Git para controle de versão
- [graphify](https://github.com/Graphify-Labs/graphify) para o grafo de conhecimento do código (agentes de IA)

## Estrutura

```text
src/
├── client/
│   ├── controllers/  # Lê o estado replicado e trata entrada do jogador
│   └── ui/            # Constrói e atualiza a interface (HUD)
├── server/   # Scripts e serviços autoritativos do servidor
└── shared/   # Configurações, tipos e módulos compartilhados
tests/        # Testes futuros
```

O arquivo `default.project.json` mapeia essas pastas para `StarterPlayerScripts/Client`, `ServerScriptService/Server` e `ReplicatedStorage/Shared`, respectivamente.

## Grafo de conhecimento (graphify)

O projeto usa [graphify](https://github.com/Graphify-Labs/graphify) para manter um grafo de código em `graphify-out/` (nós, arestas de chamada/import, comunidades). Agentes de IA (Codex, Claude Code) consultam esse grafo — `graphify query`, `graphify path`, `graphify explain` — em vez de ler ou buscar em todos os arquivos, o que reduz bastante o consumo de tokens em tarefas de exploração. As instruções de uso ficam em [AGENTS.md](AGENTS.md) e [CLAUDE.md](CLAUDE.md).

A extração é 100% local (parsing AST via tree-sitter, com suporte a Luau), sem chamadas a LLM e sem custo:

```sh
graphify extract . --code-only   # gera/atualiza graphify-out/graph.json
graphify cluster-only . --no-label   # agrupa em comunidades e gera GRAPH_REPORT.md
```

Depois de alterar o código, atualize o grafo antes de commitar:

```sh
graphify update .
```

`graphify-out/graph.json`, `GRAPH_REPORT.md` e `manifest.json` são versionados — quem entra no projeto (humano ou agente) já começa com o grafo extraído, sem precisar rodar `graphify extract` antes de consultar. `graphify-out/cache/`, `graph.html` e os arquivos de análise/labels de comunidade (`.graphify_analysis.json`, `.graphify_labels.json*`) ficam fora do Git: são derivados de `graph.json`, mudam a cada rebuild automático do hook e regeneram em segundos, offline e sem custo com `graphify cluster-only .` (esse comando também recria `graph.html`, caso você queira abrir a visualização interativa).

A reconstrução automática a cada commit já está ativa via hooks locais do Git (`.git/hooks/post-commit` e `post-checkout`, instalados com `graphify hook install`; não versionados, cada clone precisa rodar o comando de novo). O merge do `graph.json` entre branches usa um driver de união configurado em [.gitattributes](.gitattributes) (`git config merge.graphify.*`, também local por clone).

Quem usa Claude Code também pode instalar o hook `PreToolUse` que sugere `graphify query` antes de leituras/buscas de arquivo:

```sh
graphify claude install
```

Esse comando grava `.claude/settings.json` com o caminho absoluto do executável `graphify` da própria máquina — por isso o arquivo é local (ver `.gitignore`) e precisa ser gerado por cada desenvolvedor, não compartilhado pelo Git.

## Pré-requisitos

- Git
- Roblox Studio para macOS
- Rokit 1.2.0 ou mais recente
- Rojo CLI 7.7.0, fixado pelo projeto
- Plugin do Rojo para Roblox Studio compatível com a versão principal da CLI

## Toolchain local

O projeto usa [Rokit](https://github.com/rojo-rbx/rokit) para instalar ferramentas Roblox de forma reproduzível. A versão do Rojo fica fixada no arquivo `rokit.toml`; não é necessário instalar Rojo globalmente por outro método.

### Instalação inicial no macOS

Instale o Rokit com o instalador oficial:

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

### Configuração do PATH por shell

Para Bash ou Zsh, reinicie o terminal para carregar o PATH. Se necessário na sessão atual, carregue o ambiente POSIX do Rokit:

```sh
source "$HOME/.rokit/env"
```

O arquivo `~/.rokit/env` não deve ser carregado no Fish, pois usa sintaxe POSIX. Para Fish, crie uma configuração nativa e idempotente em `~/.config/fish/conf.d/rokit.fish`:

```fish
fish_add_path --path "$HOME/.rokit/bin"
```

Depois de abrir um novo Fish, acesse a raiz do projeto e execute normalmente:

```fish
rojo serve
```

Na raiz deste repositório, confie no pacote oficial e instale a versão fixada:

```sh
rokit trust rojo-rbx/rojo
rokit install
```

Confirme a instalação:

```sh
rokit --version
rojo --version
```

A versão esperada atualmente é `Rojo 7.7.0`.

### Atualização futura

Verifique primeiro se há uma atualização disponível:

```sh
rokit update --check
```

Para atualizar somente o Rojo e registrar a nova versão em `rokit.toml`:

```sh
rokit update rojo
```

Revise a alteração do manifesto e repita o build de validação antes de compartilhar a atualização.

## Sincronização com o Roblox Studio

Na raiz do projeto, inicie o servidor de sincronização:

```sh
rojo serve
```

Abra uma experiência no Roblox Studio, selecione o plugin Rojo na barra de plugins e clique em **Connect**. Use o endereço exibido pelo comando; por padrão, o servidor local usa `localhost:34872`.

## Plugin do Rojo no Roblox Studio

Instale o [plugin oficial Rojo 7 no Creator Store](https://create.roblox.com/store/asset/13916111004). Na página, clique em **Install** e confirme que o plugin aparece na aba **Plugins** do Roblox Studio. A versão principal do plugin deve ser a mesma da CLI.

Para fazer a primeira sincronização:

1. Abra o Roblox Studio e crie ou abra um place local de desenvolvimento.
2. Na raiz deste repositório, execute `rojo serve` e mantenha o terminal aberto.
3. No Studio, abra o painel do Rojo pela aba **Plugins**.
4. Use o endereço mostrado no terminal, normalmente `localhost:34872`, e clique em **Connect**.
5. Revise e aceite a sincronização apresentada pelo plugin.

Depois da sincronização, o Explorer deve conter:

```text
ReplicatedStorage/Shared
ServerScriptService/Server
StarterPlayer/StarterPlayerScripts/Client
```

Para um teste simples, abra **View > Output** e clique em **Play**. Sem erros, devem aparecer estas mensagens:

```text
[BlocoPuff] Server initialized
[BlocoPuff] Replicated state initialized
[BlocoPuff] World visuals created
[BlocoPuff] Building created
[BlocoPuff] Lobby created
[BlocoPuff] Arena created with 450 blocks
[BlocoPuff] Puffador system started
[BlocoPuff] Elimination zone armed
[BlocoPuff] Round cycle started
[BlocoPuff] Client initialized
```

Durante o teste, o servidor também cria `Workspace/BlocoPuffWorld` com o prédio (`Building`), o lobby, a arena e `Projectiles`, além de `ReplicatedStorage/BlocoPuffState` (estado da rodada por atributos) e `ReplicatedStorage/BlocoPuffRemotes`, com `RequestPuff` para solicitar disparos e `PuffFeedback` para confirmar acertos válidos ao atirador. O cliente lê exclusivamente os atributos replicados para desenhar o HUD; a cada mudança real de estado, o servidor registra `[BlocoPuff] Round state: <Estado>`. Encerre o teste pelo botão **Stop**; os objetos gerados em runtime desaparecem ao finalizar o Play.

## Build local

Para gerar uma cópia local da experiência no formato XML:

```sh
rojo build -o BlocoPuff.rbxlx
```

Arquivos `.rbxl` e `.rbxlx` são artefatos locais e não fazem parte da fonte principal deste repositório.

## Estado atual

### Idiomas: português e inglês

Quem tem o Roblox em português vê o jogo em português; qualquer outro idioma vê inglês (`player.LocaleId`).

- **O texto em português do código é a chave.** O dicionário em inglês fica em `src/shared/i18n/en/`, uma tabela por área: `Collection`, `Match`, `Round`, `Social` e `World`. Sem tradução, o texto aparece em português.
- **Como usar** (`shared/i18n/Lang`):
  - no cliente, `Lang.t("FALTAM %d 🎟", n)`: passe o molde e os valores, nunca o texto já montado com `string.format`;
  - no servidor, para um jogador só (ex.: kick), `Lang.forPlayer(player, "...")`;
  - no servidor, nas placas, painéis e prompts do cenário, `Lang.t("...")`. O servidor escreve em português, e o `WorldTextLocalizer` do cliente traduz para quem joga em inglês, inclusive textos com números (`"Partida em 12s · entre agora!"`) e trechos separados por ` · `;
  - no cliente, para texto que chega pronto do servidor, `Lang.localize(texto)`.
- **Dados de catálogo** (nomes de Puffs, desafios, conquistas, efeitos, categorias do ranking) continuam em português no config e são traduzidos na hora de exibir.
- **Ficam em português:** o painel de admin e os avisos que o admin digita. A dica da hotbar do Puffador (`Tool.ToolTip`) também fica em português.
- **Na página do jogo**, nome e descrição em inglês ficam no Creator Hub (Localização).
- **Testes:** `lune run tests/Locale.spec`. Confere:
  - os mesmos `%d`/`%s` na tradução;
  - conflitos entre dicionários;
  - toda chamada `T("...")`, `Lang.t("...")` e `Lang.forPlayer(p, "...")` com tradução;
  - os textos dos catálogos;
  - o uso proibido de `T(string.format(...))`.

### Bots RoboPuff (Fase 5B)

Escopo em `docs/FASE_5B_BOTS_PUFF.md`. Ninguém joga sozinho: bots completam a partida quando falta gente.

- **Identidade de combatente** (`CombatantRegistry`): a rodada, o empurrão, os projéteis, a queda, as armadilhas e o resultado tratam jogador e bot do mesmo jeito (`Combatant`, com id negativo para bot). O que é só de jogador (perfil, telemetria, remotes) usa `combatant.player`. Com zero bots, o jogo se comporta como antes.
- **Chegada** (`BotFillService`, regras em `data/BotFillRules`):
  - quando há de 1 a 3 humanos no mirante, depois de 12 s (3 s no Studio) chegam bots até a partida ter 4 combatentes, no máximo 3 bots;
  - quem chega ocupa a vaga de um bot, e sem humanos na fila os bots vão embora. Nunca há partida só de bots;
  - depois de uma partida com bots, eles voltam ao mirante sem a espera por 45 s;
  - o painel do mirante mostra os bots com 🤖, e a fila recebe o aviso "RoboPuffs chegando!". O aviso de "chame um amigo" só aparece sem bots.
- **Corpo** (`bots/BotBody`): avatar R15 do servidor nas cores de Puff, com antena, nome `🤖 <nome>`, Puffador na mão e animações padrão tocadas pelo servidor. A física é do servidor.
- **O bot sofre o jogo:** o empurrão é aplicado no servidor com a mesma física do cliente (`shared/modules/CharacterImpulse`). O bot cai, usa a Segunda Chance, sofre armadilhas, pode vencer e aparece no espectador e no resultado (ícone 🤖).
- **Cérebro** (`BotBrainService`, `bots/BotArenaView`, `data/BotGrid`):
  - **Andar:** vai até blocos inteiros e seguros alcançáveis em linha reta e pula buracos de um bloco.
  - **Fugir:** nos níveis Normal e Esperto, sai de blocos piscando e da área de armadilhas em aviso.
  - **Atirar:** atira em quem está à vista, depois do tempo de reação e com erro de mira, no corpo ou no chão embaixo do alvo. Às vezes aciona uma armadilha pronta com alguém perto.
  - **Nível** (`data/BotLevelRules`): com algum novato na partida (menos de 3 partidas), todos são Fáceis; até o nível 5, Fácil e Normal; acima disso, Normal e Esperto.
  - Os números ficam em `config/BotConfig`.
- **Recompensas** (`data/BotRewardRules`):
  - **Derrubadas:** derrubar bot vale metade do XP e não conta no perfil (ranking, Puffdex, desafio "Derrube 3").
  - **Vitória e top 3:** só contam no perfil com pelo menos 2 humanos na partida. A vitória sem outro humano vira `botWins` ("Vitórias contra RoboPuffs" no perfil).
  - **Tickets sem outro humano:** os tickets da rodada (participação, torcida e vitória) somam no máximo 6 por dia. Os de subir de nível ficam de fora. O contador fica em `botTicketDay`/`botTickets` no perfil, campos opcionais que não exigem nova versão.
  - **XP:** usa o multiplicador dos humanos, com piso de 0,8.
  - **Novatos:** nas 3 primeiras partidas, XP e tickets são cheios.
- **Telemetria:** `RoundStarted`, `RoundFinished` e `RoundWon` levam o contexto `Bots{n}`. Eventos novos: `BotFillStarted` (segundos de espera) e `BotReplacedByHuman`.
- **Robustez:** se todos os humanos saem, a rodada termina na hora. Um bot cujo corpo some é eliminado. Falhas ao montar o avatar esperam 5 s antes de nova tentativa.
- **Fora do escopo por enquanto:** os bots não entram nos corredores secretos (Barão, Tocas), não abrem o cofre e não constroem.
- **Testes:** `lune run tests/BotFillRules.spec`, `tests/BotGrid.spec`, `tests/BotLevelRules.spec` e `tests/BotRewardRules.spec`.

### Impulso

- **Como usar:** tecla **F**, botão **B** do controle ou o botão » acima do pulo no celular. O botão imita o visual do pulo nativo do Roblox: círculo escuro translúcido com anel branco.
- **Efeito:** uma arrancada curta (cerca de 11 studs) para onde o jogador está andando; parado, para a frente.
- **Regras** (`shared/modules/DashRules`, valores em `config/DashConfig`):
  - Um impulso a cada 3 s. Na recarga, o botão mostra os segundos que faltam.
  - No ar, um impulso por pulo; tocar o chão devolve. No ar, a queda para no início da arrancada.
  - Não funciona durante um empurrão nem no escorregão do tapete.
  - A tecla é F porque o E é dos prompts de interação (estações do lobby e cofre).
- **Servidor** (`DashService`): o cliente faz a arrancada na hora, porque é ele quem simula o próprio personagem, e avisa o servidor. O servidor confere o intervalo e marca `LastDashAt` no jogador para todos verem a fumaça (`effects/DashFx`).
  - Impulso fora do intervalo não aparece para ninguém e conta em `DashRejected`.
  - A física do personagem continua sendo do cliente, como andar e pular.
- **Bots:** RoboPuffs Normal e Esperto usam o impulso para sair de bloco piscando ou de área de armadilha, só se todo o caminho da arrancada for chão inteiro e seguro.
- **Telemetria:** `RoundDashes` (impulsos aceitos por rodada) e `DashRejected`.
- **Testes:** `lune run tests/DashRules.spec`.

### Observabilidade (Creator Dashboard)

Além dos eventos customizados (`TelemetryService`), o jogo usa dois relatórios nativos do Creator Dashboard e separa a retenção pelo tipo da primeira partida.

- **Funil da primeira sessão** (Analytics > Funnels > Onboarding; `OnboardingService`, regras em `data/OnboardingRules`):
  - Os passos são `Joined` → `FirstShot` → `QueueEntered` → `MatchStarted` → `FirstBlockDown` → `MatchFinished` → `SecondMatch` → `ReturnedAnotherDay` (24 h depois da criação do perfil).
  - Cada passo vai uma vez na vida do jogador, só com o perfil salvo. Os passos ficam em `onboardingSteps`, um campo de bits opcional que não exige nova versão.
  - Quem já tinha partidas antes do funil existir fica de fora.
- **Economia de tickets** (Analytics > Economy): cada entrada e saída de tickets vai com o saldo final.
  - Entradas: rodada (fonte da linha), desafio, retorno diário (`TimedReward`), conquista secreta, convite e devolução de repetido.
  - Saída: giro da Puff Machine (`Shop`).
  - Com a carteira no teto, conta só o que de fato entrou.
  - Substitui os antigos eventos `TicketsEarned` e `TicketsSpent`.
- **Retenção com bots x só humanos:**
  - O perfil guarda o tipo da primeira partida em `firstMatchKind` (0 nenhuma, 1 só humanos, 2 com bots).
  - O `SessionStart` leva esse tipo no detalhe (CustomField03 = `FirstBots`, `FirstHumans` ou `FirstNone`).
  - Para comparar, filtre o evento `SessionStart` pela faixa `D1+` e quebre pelo CustomField03. A comparação vale a partir do D1.
- **Testes:** `lune run tests/OnboardingRules.spec`.

### Comandos de teste da partida (painel admin)

Seção **TESTES DA PARTIDA** no painel admin. Vale só para o servidor atual e só para admins.

- **▶ COMEÇAR JÁ:** a contagem cai para 3 s assim que houver gente na fila, e os bots chegam na hora se faltar gente. O pedido vale por 30 s.
- **🌪 CAOS FINAL:** durante a partida, pula direto para o Caos Final.
- **⏹ ENCERRAR:** termina a partida em andamento sem vencedor.
- **🤖 BOTS LIGADOS / 🚫 BOTS DESLIGADOS:** liga ou desliga os bots RoboPuff neste servidor. Ao desligar, os bots do mirante vão embora.
- **Nível dos bots:** AUTO, FÁCIL, NORMAL ou ESPERTO, a partir da próxima partida.
- Código em `services/MatchTestControls` (registrado com `AdminService.registerAction`).

### Convite com recompensa (Fase 5B)

- **Botão 💌** no cartão de perfil (`InviteController`): abre o convite do próprio Roblox. O `LaunchData` leva o UserId de quem convidou.
- **Quem chega a convite:** o servidor (`ReferralService`) lê `GetJoinData().ReferredByPlayerId`, preenchido pelo próprio Roblox. O `LaunchData` não vale, porque qualquer um monta esse link. Só fica registrado no perfil de quem nunca jogou, e nunca é trocado.
- **Prêmio do amigo:** 5 tickets ao terminar a primeira partida inteira, uma vez só.
- **Prêmio de quem convidou:** 5 tickets por amigo, uma vez por amigo, até 3 amigos por dia e 20 no total. Amigos além do limite do dia não rendem.
- **Quem convidou está em outro servidor ou fora do jogo:** o amigo entra numa lista no DataStore `BlocoPuffReferralsV1`, e um aviso pelo MessagingService chama o servidor certo. Se quem convidou estiver fora, recebe ao entrar.
- **Perfil:** campos `referredBy`, `referralPaid`, `referralFriends`, `referralDay` e `referralDayCount`. São opcionais e não exigem nova versão.
- **Configuração:** valores em `config/ReferralConfig`; regras em `data/ReferralRules`.
- **Telemetria:** `InviteSent`, `InviteUnavailable`, `ReferralJoined`, `ReferralInviteePaid`, `ReferralInviterPaid` e a entrada de tickets `Referral` na economia nativa (ver Observabilidade).
- **Testar de verdade:** só com o jogo publicado. O Roblox só preenche quem convidou em convites reais, e o Studio pode não ter acesso ao DataStore e ao MessagingService. Os banners de recompensa da página do convite são configurados no Creator Hub (Engagement > Referral Rewards), com o jogo publicado há pelo menos 1 dia.
- **Testes:** `lune run tests/ReferralRules.spec`.

### Relíquias e Álbum do Casarão (Fase 5C, entrega 5C.2)

- **Relíquias** (`RelicService`, catálogo em `config/RelicCatalog`, regras em `data/RelicRules`): 40 objetos pequenos, 5 em cada um de 8 cômodos (Salão Principal, Salão da Coleção, Jardim do Barão, Ponto de Encontro, Biblioteca, Sala de Música, Sótão e Porão).
- **Modelos** (`RelicModels`): malhas gratuitas da Creator Store, criadas na hora pelo servidor com `AssetService:CreateMeshPartAsync`. Só malha e textura entram, nunca scripts.
  - São relógio de bolso, moedas de ouro e prata, chave antiga, rei, torre e bispo de xadrez, xícara com pires, livro antigo, bússola e frasco de poção.
  - O Puff, a abóbora e a estrela da Relíquia do Dia são feitos de peças.
  - Se uma malha não carregar, entra uma versão simples de peças.
- **Esconderijos de verdade:** cada relíquia diz o móvel onde fica (sofá, vaso, mesa, estante, piano, baú, barril, adega, pedestal da vitrine, balcão da loja, cama do Barão…). O servidor (`RelicSpots`) procura em volta e embaixo dele o ponto mais escondido.
  - O ponto vencedor é o que tem mais direções tapadas e, de preferência, algo por cima.
  - Fica sempre no chão; só vai para cima de um móvel se não houver lugar no chão.
  - A decoração não aparece nos raios do Roblox, então o cálculo usa um índice próprio das peças visíveis.
- **Difícil de achar:**
  - sem luz;
  - as faíscas só acendem a 10 studs (no cliente);
  - o prompt **"Pegar"** só aparece a 7 studs (o servidor confere a distância);
  - as pistas do Álbum são charadas ("Onde o Barão sonha com ossos").
  - O servidor confere a distância, se o jogador está vivo e um intervalo mínimo.
- **Quem já pegou** vê só o contorno vazio, sem faíscas e sem prompt (só para ele, `RelicController`).
- **Recompensas:**
  - 1 🎟 por relíquia;
  - **cômodo completo:** +5 🎟 e um título (Anfitrião, Colecionador, Amigo do Barão, Detetive, Bibliotecário, Maestro, Rato de Sótão, Guardião do Porão);
  - **álbum completo:** o título Explorador do Casarão e o **Puff Explorador** (Lendário, exclusivo, não sai na Puff Machine).
- **Temporadas** (o álbum nunca acaba): páginas novas por tempo limitado, com título e tickets próprios.
  - As relíquias de uma temporada entram e saem do Casarão sozinhas nas datas dela.
  - A página fica no álbum para sempre, mesmo depois de a temporada acabar.
  - Não contam para o Puff Explorador.
  - **Temporada 1, "Noite das Abóboras"** (1º/out a 8/nov de 2026): 10 relíquias de Halloween, título Caça-Abóboras e +10 🎟.
  - Para criar outra: nova entrada em `SEASONS` no catálogo, com datas e relíquias.
- **Relíquia do Dia:** uma estrela dourada escondida junto a um de 12 móveis, sorteado por dia. Nunca é o mesmo de ontem e é igual em todos os servidores. Vale 2 🎟, uma vez por dia. Ao juntar 30, dá +20 🎟 e o título Caçador de Relíquias.
- **Álbum** (`AlbumView`, botão 📜 no cartão do perfil): abas com rolagem para as temporadas, os cômodos e a Relíquia do Dia. As que faltam aparecem como "❔" com a charada. Mostra também os títulos ganhos e o prêmio do álbum.
- **Títulos:** aparecem no Álbum e no painel PERFIL do cartão (o melhor ganho). Não são equipáveis.
- **Perfil:** campos `relics` (id e data, álbum e temporadas), `dailyRelicDay` e `dailyRelicCount`. São opcionais, sem nova versão. A guarda de gravação nunca perde relíquias e nunca diminui a contagem da Relíquia do Dia.
- **Telemetria:** `RelicFound`, `RoomSetCompleted`, `SeasonCompleted`, `AlbumCompleted`, `DailyRelicFound`, `AlbumOpened` e as entradas de tickets `Relic` e `DailyRelic`.
- **Opcional:** se a colocação das relíquias falhar, o servidor sobe mesmo assim.
- **Testes:** `lune run tests/RelicRules.spec` e `lune run tests/ProfileGuard.spec`.

### Ala leste do Casarão: Biblioteca, Sala de Música, Sótão e Porão (Fase 5C, entrega 5C.1, parte 2)

- **Ala nova** a leste do Casarão (`MansionWing`, geometria em `MansionWingLayout`, medidas em `MansionWingConfig`):
  - **Biblioteca** (norte): porta para o Salão da Coleção, estantes altas, escada de rodinhas e canto de leitura. Tem um livro vermelho "errado" (`WrongBook`), reservado para a passagem secreta da 5C.3.
  - **Hall da Escadaria** (meio): porta para o Jardim do Barão, escada que sobe ao Sótão e escada que desce ao Porão.
  - **Sala de Música** (sul): piano tocável, sofás, gramofone e partituras.
  - **Sótão** (em cima, a ala inteira): escuro, com baús, móveis cobertos por lençóis e teias.
  - **Porão** (embaixo): barris, adega, goteiras com som e a entrada fechada do túnel (`CellarTunnel`, reservada para a 5C.3).
- **Portas:** todas as portas da ala usam as mesmas portas automáticas com som da parte 1, um pouco menores que os arcos. Cada lado tem uma placa dizendo para onde a porta leva.
- **Escadas:** os degraus são de verdade e têm uma rampa invisível por cima, para subir liso no celular. Há guarda-corpos nos lados abertos e em volta dos buracos.
- **Piano** (`PianoService`): clicar ou tocar numa tecla toca a nota para todos por perto. São 13 teclas, de Dó a Dó, com os sustenidos, e a tecla afunda um pouco a cada nota. Há intervalo mínimo por tecla e por jogador.
- **Lanterna do Sótão** (`AtticController`, só no cliente): quem está no Sótão (jogadores e bots) fica com uma lanterna acesa na mão, e a sua tela escurece um pouco enquanto você está lá.
- **Ala opcional:** se a construção dela falhar, o servidor sobe mesmo assim e a parede leste do Casarão fica fechada.

### Sons

- Os sons provisórios do Roblox foram trocados por sons gratuitos da Creator Store, todos testados no Studio. A lista com os IDs está em `docs/SONS_PARA_PESQUISAR.md`.
- Sequências que montavam uma melodia com o som provisório (subir de nível, segredo, sino da ficha, alarme do cofre) viraram um único som.

### Ficha da Partida e portas do Casarão (Fase 5C, entrega 5C.1, parte 1)

- **Ficha da Partida:** quem entra no mirante ou aperta JOGAR fica na fila e pega a ficha. Com ela, dá para sair do mirante e explorar o Casarão sem perder a vaga. O JOGAR não teletransporta mais: a ficha vem ali mesmo.
- **Chamado:** faltando 15 s para a partida (`QueueConfig.TicketCallSeconds`), quem está fora do mirante ouve um sino e vê o aviso "SUA PARTIDA COMEÇA EM 15 s!". Na hora, vai para a arena de onde estiver.
- **Sair da fila:** o botão SAIR DA FILA (no lugar do JOGAR) devolve a ficha. Quem está na fila só pela Party vê o aviso de que a Party ainda segura a vaga.
- **AFK:** parado (sem andar 2 studs na horizontal) fora do mirante por 3 min (`TicketAfkSeconds`), a ficha volta, com o aviso "SUA FICHA VOLTOU".
- **Etiqueta do HUD:** mostra "🎟 FICHA 1/2" para quem está passeando, com o tempo da contagem.
- **Atributos:** `InMatchQueue` (na fila) e `QueuePlace` ("", "Mirante", "Ticket" ou "Party").
- **Seleção:** o `RoundService` escala quem tem vaga (`MatchQueueService.hasPlace`: mirante ou ficha, mais a Party). O aquecimento continua só no mirante.
- **Telemetria:** `QueueJoinButton`, `QueueLeaveButton` e `QueueTicketExpired`.
- **Portas:** portas duplas de madeira em todos os arcos das divisórias (`MansionDoors`, no servidor). Elas abrem sozinhas quando alguém chega perto, girando para o lado oposto de quem chegou, com rangido, e fecham batendo quando todos saem.
  - A animação é só no cliente (`MansionDoorController`). As folhas não têm colisão, então não seguram nem empurram ninguém.
  - Medidas, cores e sons ficam em `MansionConfig.Door`. Os sons são provisórios, do próprio Roblox.

### Variações das janelas: Pombos e Chuva (Fase 5, entrega 5.6)

- **Sorteio por rodada:** cada janela do andar de cima sorteia uma variação no começo de cada rodada. A cortina tem uma cor por variação, para dar para ver de longe qual janela faz o quê.
  - Ventania, 60%, cortina vermelha.
  - Pombos, 20%, cortina bege.
  - Chuva, 20%, cortina azul.
  - Pesos e cores ficam em `TrapConfig.Window.Variants`. A distância mínima, o aviso, a recarga e os usos são os da janela.
- **Pombos:**
  - Um bando de 9 pombos entra pela janela e atravessa uma faixa reta de 40 × 6 studs em 1,6 s.
  - Quem está no trecho da faixa onde o bando passa leva esbarrões leves: 0,3× o empurrão do disparo, até 3, um a cada 0,25 s, com crédito para quem atirou.
  - O cliente desenha o voo pelo relógio do servidor, então os esbarrões batem com a passagem do bando.
- **Chuva:**
  - O chão em frente à janela (12 × 12 studs) fica molhado e escorregadio por 5 s.
  - Com pouca tração (`RainGrip`), a velocidade só chega aos poucos à que o jogador quer andar. Fica difícil frear e mudar de direção, e quem passa por cima de um buraco cai.
  - O servidor publica até quando chove (atributo `WindowRainUntil`). Quem simula o personagem aplica o escorregão (`SlipperyGround`): o próprio cliente para o jogador (`SlipperyController`) e o servidor para os bots.
  - Empurrão, escorregão do tapete e impulso têm prioridade, e no ar nada muda.
  - Quem está na chuva fica marcado como empurrado por quem atirou, sem tirar o crédito de quem empurrou antes.
  - Aparecem chuva e poça no chão enquanto durar, inclusive para quem entra no meio.
- **Geometria compartilhada** (`WindowGeometry`): o ponto da janela no piso, a faixa dos pombos e a área da chuva, iguais no servidor e no cliente.
- **Telemetria:** `TrapTriggered`, `TrapAffected` e `TrapSupportLost` registram a variação junto (`Window.Gust`, `Window.Pigeons`, `Window.Rain`).
- **Sons provisórios**, embutidos no Roblox: o bater de asas e a chuva.

### Modais do lobby maiores e mais fáceis de tocar

- **Ranking, Puffdex, Puff Machine, Desafios e Party** agora crescem até quase a tela toda: 95% da largura e 96% da altura da área segura. O limite de escala vai de 0,5× a 1,5× (`ResponsiveScale.fit` / `ResponsiveScale.Modal`). Antes ficavam presos entre 0,55× e 1×.
- **Um só UIScale por painel** faz o ajuste à tela e a animação de abertura. Antes havia dois no mesmo painel, e eles não se somavam.
- **Painéis deitados** (o celular só joga deitado), com fontes e botões maiores:
  - O botão ✕ passou para 56×48.
  - As abas do ranking ficaram mais altas.
  - Os botões das linhas da Party ficaram com 112×36.
  - O botão Girar ficou com 52 de altura, e o Equipar com 50.
- **Ranking:** o top 10 aparece em duas colunas (1º–5º e 6º–10º).
- **Desafios:** os desafios do dia ficam à esquerda, o retorno diário (grade 4 + 3) à direita e as conquistas secretas numa faixa embaixo.
- **Party:** a lista cabe a Party cheia (4) sem rolar.
- **Perfil** (botão PERFIL do cartão):
  - As estatísticas abrem ao lado do cartão, e não mais embaixo, para caber no celular deitado.
  - As linhas e as letras ficaram maiores: 26 de altura, com texto de 16.
  - O botão PERFIL também ficou maior.
- **Tamanho no celular deitado:** o texto fica cerca de 80% maior que antes.

### Lareira de Fuligem (Fase 5, entrega 5.5)

- **Onde:** no centro da parede sul do térreo, no lugar da porta falsa (`traps/FireplaceTrap`). A parede, a posição e a largura ficam em `TrapConfig.Fireplace`. A decoração da parede deixa esse trecho livre (`StoryOptions.reserved`). Tem lareira de tijolos, consolo de madeira, chaminé até o teto, lenha e brasas acesas.
- **Alvo:** a boca da lareira, com tiro de pelo menos 15 studs. De perto, ela só solta umas brasas e um fiapo de fumaça.
- **Aviso (0,6 s):** a lareira tosse brasas e começa a sair fumaça.
- **Nuvem de fuligem:** fica 4 s em frente à lareira, com 10 studs de raio, só do lado de dentro da parede (atrás dela passa o corredor secreto).
  - Quem entra na nuvem espirra: aparece "ATCHIM!" sobre a cabeça, com um pulinho para longe do centro (0,35× o empurrão do disparo). Cada pessoa espirra no máximo uma vez a cada 1,5 s.
  - Quem espirra fica com a tela levemente embaçada por 1,5 s, sem piscar, e com o rosto sujo de fuligem até o fim da rodada.
  - Quem atirou nunca espirra, e quedas depois de um espirro contam como derrubada dele.
- **Recarga:** 18 s, com as brasas apagadas. São 4 usos por rodada.
- **Cliente:** `effects/FireplaceTrapFx` desenha as brasas, a fumaça e a nuvem. `effects/SootFx` desenha o rosto sujo, o "ATCHIM!" e a tela embaçada, a partir da tag `TrapSooty` e do atributo `TrapSneezeAt` no corpo, que o servidor limpa no começo e no fim da rodada.
- **Telemetria:** `TrapAffected` conta só quem espirrou no primeiro instante da nuvem. A contagem completa de vítimas fica para a 5.8.

### Lustre Despencando (Fase 5, entrega 5.4)

- **Onde:** dois lustres sobre o térreo (`traps/ChandelierTrap`), longe dos tapetes. Cada um fica pendurado embaixo de um bloco do andar de cima (o **bloco de apoio**), com florão no teto, corrente e o lustre uns 13 studs acima do chão, aceso. As posições ficam em `TrapConfig.Chandelier.Spots`, em células da grade.
- **Duas formas de derrubar, sempre com 1 s de aviso** (balanço, faíscas no florão e uma sombra que cresce no chão; no fim do aviso ele despenca):
  - **De baixo:** um tiro na corrente ou no lustre, de pelo menos 20 studs. A caixa de acerto é um pouco maior que o lustre, para facilitar no celular. De perto, ele só balança e tilinta.
  - **De cima:** destruir o bloco de apoio. Quem destruiu leva o crédito; se foi o desabamento do Caos Final, ninguém leva. A arena avisa quem derrubou cada bloco (`ArenaService.addDestroyedListener`), e o `TrapService` dispara a armadilha presa a ele.
- **Impacto:** empurra para fora de um círculo de 7 studs quem estava embaixo. Em seguida, os blocos do chão bem embaixo (uma cruz de 5) piscam por 0,6 s e caem, abrindo um buraco. Os cacos dourados e os pedaços do lustre afundam junto. Quem atirou nunca é atingido, e quedas contam como derrubada dele.
- **Sempre cai depois do aviso:** se o bloco de apoio cair durante o aviso de um tiro, o lustre cai mesmo que o atirador saia do jogo (sem crédito para ninguém).
- **Uma vez por rodada:** o lustre volta assim que a arena restaura os blocos (fim da rodada e modo foto, via `TrapService.refresh`).
- **Telemetria:** a derrubada pelo bloco de apoio é registrada como `TrapSupportLost`, separada do `TrapTriggered` (que guarda a distância do tiro).
- **Código comum:** `traps/TrapBlocks` reúne o que a janela e o lustre fazem com os blocos e com quem está perto: blocos que piscam e caem, crédito de quem estava em cima e empurrão de impacto.

### Tapete Puxado (Fase 5, entrega 5.3)

- **Onde:** dois tapetes no térreo (`traps/RugTrap`), um em cada metade, montados sobre os blocos e puxados para o centro, onde costuma ter buraco. Posição, tamanho e cor ficam em `TrapConfig.Rug.Rugs`, em células da grade.
- **Alvo:** a franja, numa das pontas. O tiro precisa vir de pelo menos 20 studs; mais perto, a franja e o tapete só tremem.
- **Aviso (0,8 s):** uma onda corre pelo tapete, da franja para a outra ponta.
- **Puxão:** todo mundo em cima do tapete escorrega para o lado da franja, cerca de 14 studs em 0,45 s, só na horizontal e sem pulo (quem passa por cima de um buraco cai). Quem atirou não escorrega, e quem cair num buraco no caminho conta como derrubada dele.
- **Depois:** o tapete fica embolado junto da franja, com dobras e poeira, e se estica sozinho no fim da recarga (20 s). Cada tapete tem 4 usos por rodada.
- **Nunca flutua:** o tapete é feito de um pedaço por bloco do piso. O pedaço some quando o bloco embaixo cai e volta quando ele é restaurado. A franja deixa de ser alvo se todos os blocos debaixo dela caírem.
- **Cliente** (`effects/RugTrapFx`): a onda, o puxão e o tapete embolado são desenhados só no cliente e só enquanto há movimento. Parado, nada é redesenhado.

### Armadilhas do Casarão e Janela Ventania (Fase 5, entregas 5.1 e 5.2)

Escopo em `docs/FASE_5_PARTIDA_VIVA_CASARAO_REAGE.md`.

- **Base das armadilhas** (`TrapService`): objetos do cenário com a tag `CasaraoTrap` que um disparo da partida aciona.
  - Só participantes vivos acionam, e só durante a rodada.
  - O efeito completo só sai com tiro a partir da distância mínima. Mais perto, a armadilha só trinca (estalo e rachaduras, sem consequência).
  - Sempre há aviso antes do efeito (estado `Warning`). Depois vem a recarga (`Recharging`), e sem usos a armadilha fica gasta (`Spent`) até a próxima rodada. Tudo é restaurado no início e no fim de cada rodada.
  - O empurrão passa pelo `KnockbackService.push`, com as mesmas regras do disparo: proteção da Segunda Chance e derrubada creditada a quem acionou. O atirador nunca é afetado pela própria armadilha.
  - O estado vai em atributos da peça-alvo (`TrapConstants`), e o cliente (`TrapVisualController`) só desenha.
  - Números em `config/TrapConfig`. Telemetria: `TrapTriggered` (distância do tiro) e `TrapAffected` (jogadores atingidos).
- **Janela Ventania** (`traps/WindowTrap` no servidor, `effects/WindowTrapFx` no cliente): as janelas do andar de cima viraram alvo.
  - **Pronta:** um brilho leve no vidro.
  - **Aviso (0,7 s):** rachaduras, vidro tremendo, cortinas inflando e vento rasteiro no chão, no caminho da rajada.
  - **Rajada:** confete de vidro e um vento num cone de 30 studs para dentro da arena. O empurrão vai de 1,2× o do disparo perto da janela a 0,4× no fim do cone. Os blocos encostados na parede, debaixo da janela, piscam e caem em 1 s, e quem estiver em cima cai por causa do atirador.
  - **Depois:** a janela fica aberta, com as cortinas batendo, e é pregada com tábuas no fim da recarga (25 s). Cada janela tem 3 usos por rodada, e o tiro precisa vir de pelo menos 25 studs.
  - **Sons provisórios** embutidos no Roblox: troque `CrackSoundId`, `ShatterSoundId` e `GustSoundId` em `TrapConfig` por áudios da Creator Store.

### Próximas fases

- **Fase 5 — Partida Viva: o Casarão reage** (`docs/FASE_5_PARTIDA_VIVA_CASARAO_REAGE.md`): armadilhas acionadas por disparo que premiam quem joga de longe.
  - Em cima: Janela Ventania, Pombos e Chuva.
  - Embaixo: Tapete Puxado, Lustre Despencando e Lareira de Fuligem.
  - Tempestade no Caos Final.
- **Fase 5C — Casarão Vivo: explorar, descobrir, colecionar** (`docs/FASE_5C_CASARAO_VIVO.md`): o lobby vira um lugar para explorar enquanto se espera a partida.
  - Ficha da Partida (passear sem perder a vez), portas com som e cômodos novos.
  - Relíquias escondidas e o Álbum do Casarão.
  - Mistérios do Barão e salas secretas.
  - Barão passeando, Fantasminha e mapa.
  - Ordem sugerida: 5.7 Tempestade, depois 5C.1 a 5C.4, e por último a 5.8 (Momentos Puff, conquistas e telemetria), cobrindo armadilhas e Casarão Vivo juntos.
- **Fase 6 — LiveOps, Temporadas & Monetização** (`docs/FASE_6_LIVEOPS_TEMPORADAS_MONETIZACAO.md`), que antes era a Fase 5. Inclui as skins do Puffador.

### Painel administrativo seguro

O projeto possui um painel administrativo próprio, inspirado no fluxo do AdminPanel+, mas implementado integralmente nos arquivos do Rojo. O pacote original da Toolbox não é executado nem incluído no jogo. O acesso inicial pertence somente ao User ID `4328593410`, configurado em `src/server/config/AdminConfig.luau`; qualquer administrador adicional deve ser incluído explicitamente nesse arquivo.

O botão do painel (🛡️ pequeno, na barra do topo ao lado dos botões do Roblox) aparece apenas depois que o servidor confirma a autorização. O painel cresce com a tela, até 1,6×, para facilitar o uso. Pelo painel é possível enviar avisos filtrados, expulsar jogadores do servidor atual e aplicar ou remover banimentos persistentes por User ID. Todas as solicitações passam por autenticação e validação no servidor, possuem limite de frequência e impedem ações contra contas administrativas protegidas. Avisos e banimentos são sincronizados entre servidores com `MessagingService`; os bans usam o DataStore `BlocoPuffAdminBansV1`.

Para testar persistência e sincronização no Studio, a experiência precisa estar publicada e com **Enable Studio Access to API Services** habilitado. Sem esse acesso, o restante do jogo continua funcionando e o painel informa quando uma operação persistente ou global não está disponível. O atalho `F2` abre ou fecha o painel no computador; em toque e gamepad, use o botão visível e os controles selecionáveis da interface.

O servidor gera em runtime uma primeira versão visual do mundo, com um prédio fechado e uma arena de dois pisos (450 blocos identificados). Um ciclo de partidas autoritativo (`WaitingForPlayers → Countdown → Active → Ending`) seleciona participantes, teleporta-os para posições distintas na arena e replica o estado para o cliente somente por atributos em `ReplicatedStorage/BlocoPuffState`. O cliente traduz esse estado em camadas independentes de preparação, combate, anúncios e espectador.

Quando há mais jogadores conectados do que o limite de participantes por rodada, a seleção usa uma **fila de rotação justa**: em vez de sempre escalar os primeiros jogadores conectados, quem acabou de jogar vai para o fim da fila, dando prioridade a quem ainda está esperando a vez. Jogadores que precisam esperar mais de uma rodada veem essa posição no HUD ("Você joga em N rodadas").

Após o primeiro teste em conjunto, alguns ajustes de jogabilidade: o painel do HUD ficou mais compacto e discreto durante `Active` (sem repetir a mesma mensagem de status já óbvia enquanto se joga), a contagem regressiva não mostra mais o número duas vezes na tela, e o Puffador ganhou uma mira (retículo) simples enquanto está equipado, já que sem ela não havia nenhuma referência visual de para onde o tiro ia.

Na primeira fase de polimento do combate, o Puffador passou a usar uma câmera sobre o ombro com comportamento de shift-lock e mira central em computador, toque e gamepad. O botão de disparo dedicado (`FireButtonView`) aparece em dispositivos de toque, mostra texto e progresso de recarga, enquanto o retículo possui alto contraste, animação de disparo e confirmação de acerto enviada pelo servidor. O Puffador continua **equipado automaticamente** assim que é concedido a cada participante (via `Humanoid:EquipTool`), sem exigir interação com o inventário.

Na segunda fase, a interface foi reconstruída sobre um tema visual central (`UiTheme`) e componentes responsivos. Espera e contagem regressiva usam uma apresentação própria; o aviso `PREPARE-SE` fica em um cartão compacto no canto superior direito para preservar a visão da arena. Durante `Active`, cronômetro, quantidade de jogadores e integridade da arena ocupam regiões compactas separadas. Início, eliminação e resultado aparecem em banners animados que não reiniciam a cada atualização do cronômetro. Todos os `ScreenGui` importantes respeitam `CoreUISafeInsets`, painéis usam `UIScale` por viewport e o modo compacto reorganiza o cronômetro em celulares estreitos para impedir sobreposição. O botão de toque exibe `ATIRAR` com texto responsivo e, enquanto o Puffador está equipado, a barra padrão da mochila é ocultada para não competir com os controles do combate; seu estado anterior é restaurado ao desequipar ou renascer. O espectador segue o mesmo tema, possui botões de 54 pixels e navegação por teclado, toque e gamepad.

Na terceira fase, o mundo recebeu direção de arte pastel inteiramente nativa: atmosfera, bloom, correção de cor e nuvens sem colisão são gerenciados pelo `WorldVisualService`, sem assets ou dependências externas. A arena ganhou uma moldura energética também sem colisão, que aumenta de intensidade somente durante `Active`. Ao destruir um bloco, o buraco autoritativo continua abrindo imediatamente, enquanto o cliente (`BlockCollapseController`, reagindo ao atributo `IsDestroyed`) quebra uma cópia visual em pedaços que caem girando com uma nuvem de poeira — rodar no cliente deixa a animação fluida; no reset, os blocos reaparecem com uma transição curta. A mira identifica um bloco válido com mudança de geometria, contraste e o rótulo `BLOCO`, sem depender apenas de cor. Essa prévia usa somente a tag e o atributo replicados em `ArenaConstants`: não concede ao cliente autoridade sobre impacto ou destruição e não adiciona novos eventos remotos.

Após a validação visual da terceira fase, a paleta do mundo foi amortecida, o bloom foi reduzido e a correção de cor passou a diminuir brilho e saturação. As nuvens formam uma camada baixa ao redor das plataformas, ajudando a compor o horizonte sem encobrir a arena. O lobby recebeu fundação em camadas, pilares e paredes físicas invisíveis de 18 studs acima da plataforma: a cerca baixa continua sendo o limite visual, mas um salto normal não permite mais sair da área de espera.

Na quarta fase, cada participante passou a ter uma pontuação pessoal de blocos destruídos na rodada. O atributo `RoundBlocksDestroyed` é zerado na seleção e incrementado apenas pelo servidor depois que `ArenaService.tryDestroyBlock` confirma um impacto válido; o cliente somente o apresenta em um painel compacto e nos resumos de eliminação e encerramento. A primeira vez que o Puffador é equipado em uma sessão, uma dica temporária informa o controle adequado para mouse, toque ou gamepad e desaparece no primeiro disparo ou após sete segundos. O texto não bloqueia ações, respeita a área segura da tela e não depende apenas de ícones.

Cada participante recebe, ao entrar em `Active`, o **Puffador**: uma ferramenta cartunesca construída inteiramente com instâncias nativas (sem assets externos), já equipada na mão. O jogador mira e dispara com mouse, toque, gamepad ou o botão dedicado — todos convergem para a mesma função no cliente, que calcula o ponto visado no mundo e o envia pelo `RemoteEvent RequestPuff`. Como em jogos de tiro em terceira pessoa, o acerto segue o raio da câmera: o cliente envia também a origem desse raio, que o servidor só aceita perto da cabeça e com linha livre até ela (caso contrário usa o cano). O projétil visível sai do cano e converge para o raio da mira em poucos studs, então o tiro acerta exatamente o que está sob o retículo, sem confiar no cliente para alcance, cadência ou impacto. Durante o combate o zoom da câmera fica fixo e o deslocamento de ombro encolhe perto de paredes, impedindo que a câmera atravesse o prédio. O projétil usa material neon, trilha, brilho e efeito de impacto; recuo, clarão, som e recarga são feedbacks locais imediatos.

Quando um projétil atinge diretamente um bloco válido e ativo da arena (tag `ArenaBlock`), o `ArenaService` o remove **temporariamente**: fica invisível, sem colisão e sem ser atingível por novos raycasts, permitindo que personagens caiam pelo espaço aberto. O bloco não é destruído de fato — todos os 450 são restaurados integralmente (posição, tamanho, cor, atributos e tags) antes de cada nova rodada. O Puffador continua **sem causar dano direto**: a queda usa apenas a física normal, sem impulso, sem eliminação atribuída ao disparo. As contagens `TotalBlockCount`, `RemainingBlockCount` e `DestroyedBlockCount` são replicadas em `BlocoPuffState`; durante `Active`, o HUD as apresenta como percentual de integridade, barra visual e contagem exata secundária.

Abaixo da arena existe uma **zona de eliminação** autoritativa: o servidor monitora, a cada 0,1s, a posição vertical dos participantes ativos e os elimina assim que cruzam um limite calculado a partir da própria posição da arena (não é um valor fixo do mundo, nem depende exclusivamente de `Workspace.FallenPartsDestroyHeight`, que continua existindo apenas como rede de segurança global). A eliminação registra a causa (`FellFromArena`, `CharacterDied` para outras mortes durante `Active`, ou `PlayerLeft` ao sair), revoga o Puffador, limpa os projéteis do jogador e permite o respawn normal no lobby — sem impulso, sem teleporte especial e sem crédito de eliminação atribuído a outro jogador.

### Prédio fechado com dois pisos

A ilha flutuante e o skybox foram removidos: a partida acontece dentro de um prédio fechado (`BuildingService`), com paredes, teto e poço em cores sólidas, frisos e faixas de luz por andar e iluminação de interior (`WorldVisualService`). A geometria é centralizada em `src/shared/modules/BuildingLayout.luau` e configurada em `GameConfig.Arena` (`FloorCount`, `FloorSpacing`) e `GameConfig.Building`.

O lobby é a galeria envidraçada dentro do próprio prédio, com carpete, sofás e lustres: todos nascem e aguardam ali, vendo a arena. Como o lobby tem um único `SpawnLocation`, o servidor move cada personagem, logo ao nascer (e ao voltar da partida), para a posição livre da galeria mais distante dos demais, evitando jogadores empilhados. Ao iniciar a partida, os participantes descem para o piso de cima em posições sorteadas e o mais afastadas possível umas das outras (amostragem do ponto mais distante em `BuildingLayout.getSpreadSpawnCFrames`). A arena tem dois pisos de blocos: quem está em cima atira no próprio chão ou, pelos buracos, no piso de baixo; quem está embaixo atira para cima e derruba o piso de quem está acima. Cair do piso de cima apenas leva ao andar inferior; somente cair abaixo do piso mais baixo elimina, até restar um competidor. Eliminados renascem no lobby e, ao final, os participantes restantes voltam para ele antes de os pisos serem restaurados.

O interior segue o estilo de mansão de jogos como Murder Mystery, usando somente materiais nativos: porão de tijolos no poço, papel de parede, lambri, rodapés, sancas, portas, quadros e janelas noturnas por andar (`BuildingDecor`), teto com vigas, lustres e arandelas com luz quente. O piso de cima é de taco de madeira e o de baixo de pedra fosca, sem reflexo, o que facilita enxergar os buracos. A iluminação usa `Lighting.Technology = Future` (em `default.project.json`) com base uniforme de luz ambiente; lustres e arandelas são acentos fracos e o andar de baixo recebe uma única luz de teto difusa.

### Regras do core (Fase 1, entrega 1.1)

Direção de produto em `docs/GAME_DESIGN.md`; escopo da fase em `docs/FASE_1_CORE_GAMEPLAY_UX.md`.

- Até 12 jogadores por rodada; rodada de 3:30 (60 s no Studio).
- **Empurrão:** acertar outro jogador com o Puffador o empurra (`KnockbackService`, `GameConfig.Knockback`). O servidor valida e calcula; o cliente dono do personagem aplica a velocidade (`KnockbackController`). Não há dano: elimina-se caindo.
- **Derrubadas:** quem empurrou alguém nos últimos 6 s recebe o crédito se ele cair (atributo `RoundKnockouts`).
- **Segunda Chance:** a primeira queda para fora da arena devolve o jogador a um bloco inteiro do andar de baixo, com 2,5 s de imunidade a empurrões; a segunda queda elimina. A HUD mostra "2 VIDAS" / "ÚLTIMA VIDA".
- **Caos Final:** nos últimos 30 s a Segunda Chance é desligada e, a cada 2 s, blocos aleatórios piscam em vermelho por 1,2 s e caem (3 no início, até 9 no fim). O cronômetro fica vermelho (`FinalChaosService`, `GameConfig.FinalChaos`).

### Controles e mira (Fase 1, entrega 1.5)

- **Mira:** retículo menor (anel de 18 px, ponto de 4 px, traços finos) sem a etiqueta "BLOCO". Fica verde sobre um bloco válido; o marcador de acerto é amarelo em bloco e rosa em jogador (empurrão).
- **Segurar para atirar:** o botão PUFF (toque), o clique do mouse e o gatilho direito (R2/RT) disparam continuamente enquanto estiverem segurados, respeitando a cadência (`GameConfig.Puffador.FireCooldown`, revalidada no servidor).
- **Celular:** tocar na tela para girar a câmera não dispara mais; o disparo vem só do botão PUFF. O botão fica à esquerda e um pouco acima do botão de pulo nativo do Roblox e se reposiciona conforme o tamanho da tela.
- **Controle:** R2/RT atira e o analógico direito gira a câmera (padrão do Roblox); a dica de controle mostra o comando certo para cada dispositivo.
- **Impulso:** tecla F, botão B ou o botão » acima do pulo no celular (ver a seção Impulso).
- **Tela deitada obrigatória no celular** (`OrientationController`):
  - O jogo pede `LandscapeRight`, o lado natural de tombar o celular, no `StarterGui` (`default.project.json`) e no `PlayerGui` antes de carregar o resto. Pede de novo se algo mudar a orientação.
  - Como alguns aparelhos ignoram o pedido, um aparelho de toque com a tela em pé recebe uma tela cheia "Gire o celular" que bloqueia o jogo até ser deitado.
  - O Output registra a orientação pedida e a atual (`Screen orientation`).
- **Assistência de mira:** não foi adicionada. O game design só a prevê se o playtest mostrar necessidade.

### Telemetria (Fase 1, entrega 1.4)

`TelemetryService` envia eventos customizados pelo `AnalyticsService` do Roblox; eles aparecem no Creator Dashboard, em Analytics › Custom Events. No Studio cada evento também é impresso no Output (`GameConfig.Telemetry`). Os contadores de combate são somados no servidor e enviados uma vez no fim da rodada. Todos os eventos são por jogador, e os campos customizados seguem a mesma ordem: **Field01 = dispositivo** (Mobile, Desktop, Gamepad, informado pelo `TelemetryController`), **Field02 = contexto**, **Field03 = detalhe**.

| Evento | Valor | Field02 / Field03 |
| --- | --- | --- |
| `RoundStarted` | jogadores na rodada | — |
| `Rematch` | 1 (jogou a rodada anterior e seguiu) | — |
| `FloorDrop` | segundos de rodada | zona / `F2>F1` |
| `Fell` | segundos de rodada | zona / `SecondChance` ou `Eliminated` |
| `SecondChanceUsed` | segundos de rodada | — |
| `Eliminated` | posição final | motivo / segundos |
| `FinalChaosStarted` | jogadores vivos | — |
| `LeftMidRound` | segundos de rodada | — |
| `RoundFinished` | duração em segundos | `Win`, `Draw` ou `Loss` |
| `RoundWon` | duração em segundos | — |
| `RoundShots`, `RoundPlayerHits`, `RoundBlockHits`, `RoundBlocksDestroyed` | total na rodada | — |

As zonas dividem a arena em `Center`, `NorthWest`, `NorthEast`, `SouthWest` e `SouthEast`.

### Pós-partida (Fase 1, entrega 1.3)

Ao fim de cada rodada o servidor monta o resultado (`RoundResultBuilder`) e o envia a todos pelo RemoteEvent `RoundResult`. O cliente mostra o painel `ResultsView` (`ResultsController`):

- **Título:** "VITÓRIA!" para quem venceu, "FIM DA RODADA" com o nome do vencedor, ou "EMPATE!" quando o tempo acaba com mais de um jogador vivo.
- **Sua posição:** #1 é o vencedor; quem é eliminado fica com (jogadores ainda vivos + 1). Em empate, todos os sobreviventes ficam em #1. Quedas no mesmo instante dividem a posição; se todos caem antes do fim, vence quem caiu por último (ou é empate, se caíram juntos).
- **Seus números:** blocos destruídos e derrubadas.
- **Destaques:** "MAIS BLOCOS" e "MAIS DERRUBADAS", quando alguém pontuou.
- **Classificação:** as 5 primeiras posições, com sua linha destacada. O desempate usa derrubadas e depois blocos.
- **Próxima rodada:** o rodapé mostra "Voltando ao lobby em N s", depois "Próxima rodada em N s", e se você joga a próxima ou em quantas rodadas entra. O painel fecha no botão OK, faltando 3 s para a próxima rodada ou quando ela começa.
- O encerramento passou para 12 s, para dar tempo de ler. Nada disso é salvo entre sessões nesta fase.

### Notificações (Fase 1, entrega 1.2)

Todo alerta de tela passa pelo `NotificationManager` (`src/client/notifications/`). Existem dois canais, em regiões diferentes da tela, e cada um mostra um alerta por vez, então nada se sobrepõe:

| Canal | Onde | O que mostra |
| --- | --- | --- |
| `Center` | anúncio grande no meio | rodada, eliminação, Segunda Chance, Caos Final, resultado |
| `Banner` | faixa no topo (mais baixa em telas estreitas) | cofre, avisos de administrador |

Regras de cada canal:

- **Prioridade:** `Critical` > `High` > `Normal` > `Low`. Um alerta mais importante interrompe o atual; o interrompido volta para a fila se for `High`/`Critical` e ainda tiver mais de 1 s, senão é descartado.
- **Fila:** até 4 alertas, por prioridade e ordem de chegada. Com a fila cheia, sai o menos importante.
- **Validade:** quem espera demais é descartado (Low 2 s, Normal 3 s, High 6 s, Critical 8 s), para não mostrar notícia velha.
- **Substituição:** a mesma `key` atualiza o alerta na tela ou substitui o que está na fila.
- **Categoria:** `clear(canal, categoria)` limpa só um tipo de alerta.

| Alerta | Canal | Prioridade |
| --- | --- | --- |
| Eliminado, Caos Final, vencedor | Center | Critical |
| Segunda Chance, fim sem vencedor | Center | High |
| "VALENDO!" | Center | Normal |
| Aguarde sua vez | Center | Low |
| Cofre invadido | Banner | Critical |
| Aviso de administrador, cofre destrancou, Super pego | Banner | High |

Os pop-ups de combate perto da mira ("+1", combo e marcos) seguem na `FeedbackView`, no canto direito, porque são reforços curtos que não competem com os alertas.

### Corredores secretos e quadros (Fase 2, entrega 2.1)

Escopo em `docs/FASE_2_SEGREDOS_COFRE_BARAO.md`.

- **Corredores:** do lado de fora das paredes norte e sul há um corredor escondido (`CorridorBuilder`). Ele tem um patamar no nível do andar de baixo, uma rampa e um patamar no nível do andar de cima, e serve para subir, descer ou fugir. O cofre fica só na parede oeste, separado dos corredores.
- **Entradas escondidas:** cada corredor tem uma entrada por andar. Elas sempre existem, mas começam atrás de um painel falso igual à parede, que não colide: quem conhece o lugar atravessa antes da revelação.
- **Quadros:** a cada rodada um quadro de cada andar é sorteado em segredo. Acertá-lo com o Puffador revela, para todos, as entradas daquele andar: o painel some, surge uma moldura dourada acesa e aparece a faixa "PASSAGEM SECRETA!" com o nome de quem descobriu. Revelar um andar não revela o outro. Quadros errados respondem com um som e "NÃO ERA ESSE QUADRO".
- **Código:** `SecretPassageService` (regras e painéis), `CorridorBuilder` (arquitetura), `BuildingLayout.getCorridors`, e `SecretPassageController` no cliente. Os quadros da arena são marcados com a tag `RevealPainting`.

### Barão e Tocas Seguras (Fase 2, entrega 2.2)

- **Barão:** vira-lata caramelo de camisa verde e amarela, feito de peças nativas (`BaraoModel`). Há um só por rodada. Começa dormindo no patamar de baixo de um corredor e acorda com latidos depois de `WakeDelay` segundos (20). Depois disso patrulha, persegue quem estiver no mesmo corredor e, se só houver gente no outro corredor por 4 s, reaparece lá pela ponta mais distante.
- **Contato:** não causa dano. Dá um empurrão forte para longe dele, rumo à saída daquele lado. Quem está no vão de uma entrada é jogado para dentro do prédio. Toca um som engraçado aleatório e mostra "AU AU!" para quem foi empurrado.
- **Como escapar:** a perseguição (14) é mais lenta que o jogador (16). Também dá para pular por cima dele, porque o contato só conta com os pés abaixo de `JumpClearance`.
- **Pistas:** a única pista é o áudio 3D (passos em loop e latidos em intervalos irregulares). Não há minimapa nem indicador de distância.
- **Tocas Seguras:** são duas por corredor, nichos na parede externa, uma em cada patamar. Cabe um ocupante por vez; a luz fica verde quando a Toca está livre e laranja quando está ocupada. O ocupante fica protegido do Barão, mas não do Puffador: um empurrão o tira de lá e a Toca fica livre.
- **Contra camping:** cada ocupação dura no máximo 8 s, com aviso 3 s antes do fim. Depois o jogador é empurrado para o corredor e fica 10 s sem poder usar Tocas.
- **Ajustes:** ficam em `GameConfig.Barao` e `GameConfig.Toca`. Os sons atuais são provisórios, embutidos no Roblox; troque `BarkSoundIds`, `FunnySoundIds` e `FootstepSoundId` por áudios da Creator Store (`rbxassetid://...`).
- **Código:** `BaraoService` (comportamento), `BaraoModel`, `TocaService`, `CorridorBuilder` (nichos) e `BuildingLayout.getTocas` / `isInsideToca` / `getCorridorFloorY`. No cliente, `BaraoController` mostra os avisos.

### Barão maior, animado e com túnel entre os corredores (Fase 4, ajuste pós-4.5)

- **Maior:** o Barão está 1,35× maior (`GameConfig.Barao.ModelScale`), com ~4,3 studs, quase a altura de um jogador. O alcance do empurrão (3,4) e a altura para pular por cima (2,9) acompanham. O do Jardim do Casarão está 1,15× maior, numa caminha maior.
- **Corredores mais largos:** largura de 7 para 10 studs e pé-direito de 11 para 13. As Tocas, a rampa e as entradas acompanham.
- **Desenhado e animado no cliente** (`BaraoVisualController` + `effects/BaraoAnimator`):
  - o servidor só move uma raiz invisível (com os sons) e publica o estado em atributos (`BaraoState`, `BaraoTarget`, `BaraoEnraged`, contadores `BaraoBark` e `BaraoPush`);
  - cada jogador desenha o Barão liso a 60 quadros por segundo, com cada parte girando na sua articulação (`BaraoModel` tem um "osso" por peça);
  - poses:
    - dormindo, respira com "Zzz" e espreguiça ao acordar;
    - na patrulha, trota ou fareja o chão;
    - na perseguição, galopa com as orelhas para trás e a língua de fora, olhando para quem persegue;
    - depois de empurrar, senta e abana o rabo por 1,6 s, com um "AU AU!" em balão;
  - ao latir, dá um pulinho;
  - bravo depois que abrem o cofre: olhos vermelhos e fumacinha;
  - o do Jardim dorme e, no carinho, pula e abana o rabo;
  - longe da câmera nada é animado.
- **Túnel do Barão:**
  - cada cabeceira dos corredores tem uma portinhola ("TÚNEL DO BARÃO");
  - quando só há gente no outro corredor por 2,5 s, ele corre até a portinhola mais perto, a tampa balança com um som e ele some por 2 s;
  - depois sai pela portinhola do outro corredor, na ponta longe de quem está lá, latindo;
  - desiste se alguém entra no corredor dele ou se o outro esvazia;
  - substitui o teletransporte invisível de antes.
- **Visual da capa** (`BaraoModel`):
  - cabeça grande e quadrada, focinho e bochechas claros, mancha clara na testa;
  - olhos grandes com brilho, orelhas grandes caídas, sorriso aberto com a língua de fora;
  - camisa verde com listras amarelas, mangas amarelas e a bandeira do Brasil nas costas (vista de cima, na câmera) e nos dois lados;
  - rabo peludo de ponta clara.
- **Andar natural** (`BaraoAnimator`):
  - a passada acompanha a velocidade, então as patas não patinam; a pata que vai à frente levanta do chão;
  - trote com as patas em diagonal; galope com o corpo balançando como cavalinho;
  - vira aos poucos e inclina nas curvas; a cabeça compensa o balanço;
  - orelhas e língua chacoalham com mola; o rabo abana de lado.
- **Carinho no Jardim:**
  - o aviso "Fazer carinho" fica na frente da caminha, sem tapar o Barão;
  - no carinho ele acorda, late baixinho, pula dando uma volta, solta corações 💜 e senta abanando o rabo olhando para você;
  - o cliente espera todas as peças chegarem do servidor antes de animar (antes, podia começar sem elas e não mexer nada);
  - cada animação roda protegida: um erro aparece uma vez na saída e não para as outras.
- **Modelo 3D:** o Barão usa o modelo 3D do Studio (`src/shared/assets/BaraoMesh.rbxm`, que vira `ReplicatedStorage.Shared.assets.BaraoMesh`): 12 MeshParts com textura PBR (SurfaceAppearance), a ficha técnica está em `docs/BARAO_MODELO_3D.html`.
  - `BaraoModel` gira o arquivo (ele vem de frente para +Z), centraliza no chão entre as patas, ancora as peças, liga cada uma ao seu osso e calcula as articulações pela forma de cada peça (topo das patas e das orelhas, nuca, base do rabo, raiz da língua);
  - os olhos (`Eye` e `Eye2`) seguem a cabeça; bravo, eles brilham em vermelho por um `Highlight` (a cor da peça não aparece sobre a textura);
  - se o modelo faltar ou estiver incompleto, o jogo avisa no Output e usa o Barão de blocos (`BaraoBlocks`);
  - as malhas e texturas precisam estar liberadas para a experiência (Creator Hub → item → Permissões), senão aparecem invisíveis ou cinza no jogo publicado.
- **Latido de verdade:** o latido é o áudio `rbxassetid://124017572768108` (~3 s, em `GameConfig.Barao.BarkSoundIds`), tocado inteiro e com o tom um pouco variado (`BarkPitch`). Um latido não começa enquanto o anterior toca: o Barão só faz a animação de latir.
- **Território:** placas "🐾 TERRITÓRIO DO BARÃO" e pegadas no chão de cada patamar.

### Puffador menor (Fase 4, ajuste pós-4.5)

O Puffador na mão ficou 28% menor (`HELD_SCALE = 0.72` em `PuffadorModel`) para não tapar a mira. A boca do cano, a empunhadura e o brilho do Super acompanham a escala, e o disparo sai da boca como antes. O tamanho do projétil, o alcance e o acerto não mudam. O prêmio do Cofre, que é só exposição, continua em tamanho cheio. As skins do Puffador ficaram anotadas para a Fase 6 (`docs/FASE_6_LIVEOPS_TEMPORADAS_MONETIZACAO.md`, item 8.1).

### Puffdex empolgante — Camada A (Fase 4, ajuste pós-4.5)

Cada Puff agora tem um **formato de efeito** e uma **frase de história**, além das cores (`effect` em `PuffStyle` e `lore` em `PuffDefinition`).

- **Formatos:**
  - 💨 Sopro, ✨ Brilhos, 🫧 Bolhas, ☁️ Nuvenzinha, ❄️ Neve, ⚡ Raio, 🌀 Espiral, 🎉 Confete, 🔥 Chamas e 🌈 Arco-íris;
  - são 10 formatos compartilhados pelos 22 Puffs.
- **No disparo** (`PuffEffects`):
  - partículas do formato acompanham o projétil;
  - o impacto solta uma explosão das mesmas partículas;
  - o Arco-íris pinta o rastro com o espectro inteiro;
  - Espiral e Raio desviam só o projétil visual em espiral ou zigue-zague. O acerto continua seguindo a mira, igual para todos.
- **No Salão da Coleção:** cada pedestal solta, com calma, as partículas do seu Puff, e a placa mostra o ícone do formato.
- **No Puffdex:**
  - **prévia animada** (`PuffPreview`): o Puff atravessa a janelinha em loop com o rastro e as partículas do formato. É 2D porque o ViewportFrame do Roblox não desenha partículas;
  - **cartões por raridade** (`PuffCardFx`): Raro com brilho suave na borda, Épico com borda animada e Lendário com borda dourada e reflexo holográfico;
  - **desbloqueio com comemoração:** clarão, pulo do cartão e som, com um Puff novo de cada vez ao abrir o painel;
  - o detalhe mostra a raridade, o formato e a história. Os bloqueados continuam como "?" com a dica.
- **Pronto para a Camada B:**
  - texturas próprias entram trocando os ids em `PuffEffects` (`TEXTURES`);
  - a ilustração de cada cartão entra no campo `image` do catálogo.

### Disparos desenhados no cliente (Fase 4, ajuste pós-4.5)

Os efeitos dos Puffs agora aparecem nos disparos de verdade. Antes o servidor movia uma bolinha e o Roblox só a enviava umas 20 vezes por segundo: a 220 studs/s a espiral sumia e as partículas quase não apareciam.

- **Servidor (`ProjectileService`):**
  - só decide: o raio da mira anda, acerta blocos, personagens e alvos, igual antes;
  - não cria mais peças; avisa os clientes pelo remote `PuffShots` (`Fired` na saída, `Ended` com a distância e o ponto do impacto, `Clear` no fim da rodada).
- **Cliente (`PuffShotController` + `effects/PuffShotRenderer`):**
  - desenha cada disparo a cada quadro, com o miolo, o rastro, as partículas do Puff, a espiral/zigue-zague do formato e a explosão no impacto;
  - o disparo do próprio jogador aparece na hora do clique e é ligado ao do servidor quando a confirmação chega.
- **Desempenho:**
  - peças reaproveitadas (pool por Puff), nada é criado a cada quadro, um raio por disparo por quadro;
  - detalhe pela distância da câmera: perto tem tudo e luz, no meio metade das partículas, longe só o rastro, muito longe nem desenha;
  - no máximo 14 disparos com partículas ao mesmo tempo, e metade delas no celular ou com os gráficos em 1 a 3;
  - o servidor ficou mais leve: nada de peças, rastros e partículas replicados por disparo.
- **Justiça:** o acerto continua 100% do servidor; o desenho só acompanha.

### Embarque e aquecimento no mirante (Fase 4, ajuste pós-4.5)

- **Entrar e sair são livres.** Passar pela porta coloca na fila, com o aviso "✅ Você está na fila!" e um som, e voltar pela porta tira da fila ("Você saiu da fila").
- **Embarque encerrado:**
  - nos **últimos 5 s** da contagem as portas fecham com uma barreira de luz dourada, e quem está na fila vê "🔒 EMBARQUE ENCERRADO!";
  - a barreira reabre quando os escalados descem para a arena ou quando a contagem é cancelada;
  - o botão JOGAR é recusado enquanto as portas estão fechadas;
  - quem está na fila ouve bipes no "3, 2, 1".
- **Mirante mais largo:** passou de 20 para **32 studs**, com o centro livre; só restaram dois sofás, nas pontas. O Casarão acompanha, porque tudo sai da mesma geometria.
- **Sinalização:**
  - do lado do Casarão, cada porta tem um portal verde com o letreiro **"🏟 ENTRAR NA FILA — Entre e saia quando quiser"** e uma passadeira com setas vindo do Salão Principal;
  - dentro, um painel em cada ponta mostra quantos estão na fila, o tempo ou quantos faltam, os avatares de quem está na fila e o placar do aquecimento.
- **Aquecimento no mirante** (`WarmupService`), sem prêmio:
  - quem está na fila recebe o Puffador de treino e estoura **balões-Puff** que sobem na frente do vidro;
  - dois **trampolins** nas pontas, com o impulso aplicado no cliente;
  - os balões somem quando o embarque fecha.
- **Código:**
  - `QueueVisuals` (portais, barreiras e painéis) e `WarmupService`;
  - `MatchQueueService.setCountdown` é chamado pelo `RoundService` a cada segundo da contagem;
  - novos campos em `QueueConfig`.

### Partida isolada do lobby e ajustes de tela (Fase 4, ajuste pós-4.5)

- **Quem está no lobby não vê nada da partida:**
  - os avisos da partida (cofre, passagens secretas, Momentos Puff) e o resultado final vão só para quem está nela (`MatchAudience`: escalados, inclusive os eliminados);
  - no cliente, o HUD de combate, os anúncios e o cronômetro da partida ficam só com os participantes;
  - o cronômetro da contagem só aparece para quem está na fila;
  - quem está fora vê apenas a etiqueta "⚔️ PARTIDA EM ANDAMENTO" com a situação da fila da próxima.
- **Reações:** só para quem assiste (eliminados e quem está no mirante), numa coluna na borda direita, no meio da altura, longe dos botões de pulo e de tiro.
- **Botão ADM:** foi para o canto inferior esquerdo, longe do HUD do topo e dos avisos.
- **Vitrine do Salão da Coleção sem neon:** cada Puff é uma nuvem fosca nas cores do rastro, sobre um pedestal de mármore com faixa metálica da cor da raridade.

### Fila da partida no mirante (Fase 4, ajuste pós-4.5)

A partida só puxa quem quer jogar: **o mirante (a galeria envidraçada) é a fila da partida**. Quem está passeando pelo Casarão não é escalado.

- **Entrar e sair:**
  - estar no mirante coloca na fila (`MatchQueueService`);
  - com **2 na fila** começa a contagem de **20 s**, e se sobrar menos de 2 ela para;
  - sair do mirante tira da fila.
- **Quem joga:** só quem está na fila quando a contagem acaba. A rotação justa continua, e quem está fora mantém a posição (`PartySelection` com `eligible`).
- **Party:** basta um membro no mirante para o grupo todo entrar na fila. Os demais vão direto para a arena quando a partida começa.
- **Depois da partida:** quem jogou volta para o mirante, já na fila da próxima, e quem quiser passear sai de lá. Eliminados também renascem no mirante, assistindo à arena. Quem acabou de entrar no jogo nasce no Salão Principal.
- **HUD:**
  - o cartão central "BlocoPuff / Aguardando jogadores" saiu;
  - no canto superior direito fica uma etiqueta da fila ("🏟 FILA 1/2", "🏟 NA FILA 1/2", "✅ VOCÊ ESTÁ NA FILA") com o botão **🏟 JOGAR**, que leva ao mirante;
  - na contagem, o cronômetro fica acima da etiqueta;
  - o aviso "AGUARDE SUA VEZ" só aparece para quem estava na fila.
- **No mapa:** faixa verde e placa "🏟 FILA DA PARTIDA" em cada porta do mirante, e placas "🏟 MIRANTE · JOGAR" no Salão Principal.
- **Sozinho na fila por 60 s:** aviso discreto "CHAME UM AMIGO", uma vez por espera.
- **Telemetria:** `QueueJoinButton` e `QueueLonely`.
- **Código:** `QueueConfig`, `MatchQueueService` (atributo `InMatchQueue`, remote `MatchQueue`) e, no cliente, `MatchQueueController`.

### O Casarão e alertas fora do centro (Fase 4, ajuste pós-4.5)

O lobby virou um **Casarão** de 110 × 130 studs (a galeria tinha 20 × 90), anexo a leste do prédio da arena, com pé-direito de 24 studs. Três portas largas na parede leste da galeria levam ao Salão Principal; a galeria continua sendo o mirante da arena, com o Hall da Fama acima das portas.

- **Salão Principal** (60 × 60): todos nascem e esperam aqui, em volta da estátua dourada "CASARÃO PUFF". Tem sofás e plantas, e os arcos levam às outras salas, cada um com uma placa dizendo para onde vai.
- **Salão da Coleção** (norte): vitrine com **todos os 22 Puffs** do catálogo em duas fileiras, o púlpito do **Puffdex** e a **Puff Machine**.
- **Jardim do Barão** (leste): gramado com o **Barão amigável** na caminha, a **loja "em breve"** e o Puff Perdido (conquista secreta) escondido num canto.
- **Ponto de Encontro** (ala sul, oeste): o **quadro de desafios** e o **canto da Party** (sofás e uma placa com prompt que abre a Party).
- **Treino** (ala sul, leste): faixa verde, seis alvos fixos e dois que deslizam.
- **Ninguém nasce em cima de móveis:** estátua, sofás e plantas do Salão reservam as suas áreas no `LobbyService` (`addReservedAreas`).
- **Celular:** seis lustres sem sombra (nenhuma arandela), placas com distância máxima e nada animado além dos alvos de treino.
- **Alertas fora do centro:**
  - os anúncios (`AnnouncementView`) e a faixa de avisos (`BannerView`) viraram cartões compactos na **borda esquerda**, que entram deslizando (anúncio a 42% da altura, aviso a 56%);
  - o convite de Party desceu para 72%;
  - o cartão de espera do lobby ficou menor e mais colado ao topo;
  - o centro (mira) e o topo (cronômetro) ficam livres.
- **Código:**
  - `MansionConfig` e `MansionLayout` (geometria única do Casarão), `MansionService` (construção) e `WallBuilder` (paredes com vãos, também usado pelo `BuildingService`);
  - `BuildingDecor` aceita vãos de largura e altura próprias e lustres sem sombra.

### Lobby expandido (Fase 4, entrega 4.5)

A galeria (20 × 90 studs) ganhou estações físicas. Cada uma tem um ProximityPrompt que abre a tela correspondente, e o centro e os sofás continuam livres.

- **Ponta norte:**
  - **Puff Machine** física: gabinete com cúpula de cápsulas; o prompt "Girar" abre a máquina;
  - **Barão amigável** dormindo numa caminha ("Zzz"). O prompt "Fazer carinho" faz ele pular de alegria (💜), sem nenhuma hostilidade;
  - o Puff Perdido (conquista secreta da 4.3) continua escondido atrás do caixote no canto.
- **Lado do vidro:**
  - **vitrine de Puffs** (exibição de cosméticos): um Puff de cada raridade em pedestais, com nome e raridade; o prompt abre o Puffdex;
  - **quadro de desafios**, que abre os desafios do dia;
  - **loja "em breve"**, só a banca fechada. O prompt avisa que nada é vendido por enquanto (preparação para a Fase 6).
- **Ponta sul, área de treino** (`TrainingService`): quem passa da faixa verde e não está competindo recebe um Puffador de treino e pratica a mira em quatro alvos (três fixos e um que desliza).
  - Acertar dá o mesmo retorno visual de sempre (+1 e combo).
  - Os disparos de treino só acertam alvos: não quebram bloco, não empurram ninguém e não contam estatística nem XP (`training` no `ProjectileService`, `setTraining` no `PuffadorService`).
  - Quem é escalado para a partida troca na hora pelo Puffador da partida. Ao sair da área o de treino some, e no fim da partida quem continua na área recebe o de treino de novo.
- **Ninguém nasce em cima das estações:** o `LobbyService` recebe as áreas reservadas e tira essas posições da lista de lugares da galeria.
- **Celular:** poucas peças, nenhuma luz extra, placas com distância máxima e só um alvo animado pelo servidor.
- Os atalhos do cartão de perfil continuam funcionando: as estações são um caminho a mais, físico.
- **Telemetria:** `BaraoPet`, `TrainingSession` (acertos e duração) e `SessionStart` (dias desde a criação do perfil, com a faixa D0, D1+, D7+ ou D28+, para medir D1/D7/D28, e o tipo da primeira partida no detalhe).
- **Código:** `LobbyStationsService` e `TrainingService`. No cliente, `LobbyStationsController`.

### Party e espectador social (Fase 4, entrega 4.4)

- **Party** (`PartyService`, `shared/config/SocialConfig`): grupo de até 4 jogadores do mesmo servidor, um terço da sala de 12, então sobra vaga para quem joga sozinho.
  - Chamar alguém do servidor manda um convite, que expira em 30 s. O cartão de convite aparece na lateral esquerda com ENTRAR e AGORA NÃO.
  - Quem está competindo só vê o convite ao voltar ao lobby, se ele ainda não tiver expirado.
  - O líder (👑) pode remover alguém. Se o líder sai, o próximo assume; Party de uma pessoa só acaba.
  - O botão "CHAMAR AMIGOS PARA O JOGO" abre o convite nativo do Roblox (`SocialService`).
- **Entrar junto:** a seleção de participantes (`PartySelection`) põe a Party inteira ou nenhum membro.
  - Se a Party não cabe nas vagas que sobram, ela espera na frente da fila (entra primeiro na próxima), quem vem atrás ocupa as vagas, e os membros recebem o aviso "A partida lotou para a sua Party".
  - Quem jogou vai para o fim da fila, como antes, então a Party segue junta partida após partida.
- **Na partida** cada um joga por si: a Party não dá nenhuma vantagem.
- **Espectador social:**
  - o eliminado segue primeiro alguém da própria Party (marcado com 👥) e continua trocando a câmera pelas setas, D-Pad ou botões;
  - reações com 5 emojis fixos (👏 😮 😂 🔥 💜), sem texto livre;
  - só quem não está competindo reage, e só quem não está competindo vê: nada aparece na tela de quem joga. A barra fica discreta no canto inferior direito;
  - **torcida:** o eliminado que fica assistindo até o fim da partida ganha +1 🎟 (só quem jogou a rodada de verdade, então não dá para ganhar parado no lobby).
- **Cartão de perfil:** os atalhos agora ficam numa fileira embaixo do cartão (🏆 ✨ 🎰 📋 👥), para caber em celular. O 👥 mostra o tamanho da Party.
- **Telemetria:** `PartyCreated`, `PartyInvite`, `PartyJoined`, `PartyLeft` (motivo), `PartyMatch` (Party jogando junta), `PartyReplay` (de novo na partida seguinte), `PartyDeferred` (sem vaga), `Reaction`, `SpectatorSwitch` e a entrada de tickets `Spectator` na economia nativa.
- **Código:** `PartyService`, `data/PartySelection`, `ReactionService` e `SocialConfig`. No cliente, `PartyController`, `PartyView`, `PartyInviteView`, `ReactionController`, `ReactionView` e `SpectatorController`.

### Desafios, retorno diário e conquistas secretas (Fase 4, entrega 4.3)

- **Desafios diários** (`shared/config/DailyConfig`): 3 por dia, um de cada nível (fácil, médio e difícil), sorteados de forma fixa por jogador e dia (o mesmo em qualquer servidor).
  - Todos são de gameplay: partidas, blocos, derrubadas, Top 3, Barão, passagem secreta, vitória, cofre, reconstrução e Volta por Cima. Nenhum é do tipo "fique online".
  - O progresso sai da soma da rodada calculada pelo servidor, e só conta rodada jogada de verdade (com XP).
  - Concluir dá tickets na hora (2 a 4), sem botão de resgatar.
  - O dia vira à meia-noite de Brasília (`DayOffsetHours = -3`). Se virar com o jogador online, os desafios trocam no fim da próxima rodada.
- **Retorno diário:** recompensa automática no primeiro login do dia, em ciclo de 7 dias (2, 2, 3, 3, 4, 4 e 8 🎟).
  - Sequência amigável: perder um dia não zera nada (`GraceDays = 1`). O recorde fica guardado.
- **Conquistas secretas** (`shared/config/SecretCatalog`): ficam como "???" com uma pista curta até alguém conseguir. Cada uma vale 5 🎟, uma vez só, e todas são detectadas no servidor (`SecretAchievementService`):
  - **Passagem Oculta:** atravessar uma passagem de um andar ainda não revelado;
  - **Pula-Barão:** pular o Barão 3 vezes na mesma partida;
  - **Mestre dos Quadros:** revelar as passagens dos dois andares na mesma partida;
  - **Por um Fio:** vencer com até 15% da arena de pé;
  - **Puff Perdido:** achar o Puff dourado escondido atrás de um caixote num canto da galeria.
- **Interface:** botão 📋 no cartão de perfil (com uma bolinha quando há desafio a fazer) abre o painel **DESAFIOS**.
  - Mostra os desafios de hoje com barra de progresso e o tempo até os próximos.
  - Mostra o ciclo de 7 dias com a sequência e as conquistas secretas.
  - Avisos comemoram o retorno diário, o desafio concluído e a conquista secreta.
- **Uma vez só:** no perfil, a recompensa do dia fica marcada pelo último dia recebido, os desafios guardam `done` e as conquistas ficam pelo id. Reconectar não repete nada. Numa sessão que não salva, nada é comemorado (voltaria como novo).
- **Perfil v5:** passa a guardar `daily`, `challenges`, `challengesCompleted` e `secrets`. A migração v4 → v5 é automática.
- **Arquitetura:** o `PlayerDataService` ganhou `update(player, updater, saveNow)`, uma atualização atômica genérica do perfil (o `updater` não pode pausar).
  - O equipar do Puffdex, o giro da Puff Machine e as conquistas secretas passaram a viver nos seus próprios serviços, usando essa função.
- **Telemetria:** `ChallengeAssigned`, `ChallengeCompleted`, `ChallengesOpened`, `DailyReturn` (sequência e recorde), `SecretAchievement` e as entradas de tickets `Daily`, `Challenge` e `Secret` na economia nativa.
- **Código:** `DailyConfig`, `SecretCatalog`, `data/DailyRules`, `SecretAchievementService` e `PlayerDataService`. No cliente, `ChallengesController` e `ChallengesView`.

### Tickets e Puff Machine (Fase 4, entrega 4.2)

- **Tickets** (moeda não competitiva, só para a Puff Machine): saem só jogando, calculados pelo servidor no fim da rodada (`RewardRules.ticketsForRound`).
  - 1 por partida jogada de verdade (quem ganhou XP), +1 no Top 3 e +1 na vitória.
  - +2 por nível ganho.
  - Teto de 12 por rodada. O pós-partida mostra "+XP +N 🎟".
- **Puff Machine:** botão 🎰 no cartão de perfil (lobby), com o saldo de tickets num selo.
  - Cada giro custa 5 🎟 e dá um dos 8 Puffs exclusivos da máquina: Chiclete, Limão e Nuvem (Comuns), Oceano e Arco-Íris (Raros), Neon e Aurora (Épicos) e Cometa (Lendário).
  - Os Puffs de façanha continuam só por façanha.
- **Transparente e sem estrutura predatória:**
  - chances fixas mostradas na própria máquina (Comum 60%, Raro 28%, Épico 10%, Lendário 2%), com quantos de cada raridade o jogador já tem;
  - Épico ou melhor garantido a cada 10 giros sem um, com o contador visível;
  - Puff repetido devolve 2 🎟 (e soma na quantidade do item);
  - não existe compra de tickets nem de giros.
- **Integridade:** o sorteio usa o `Random` do servidor.
  - Conferir o saldo, gastar e guardar o Puff acontecem numa única atualização do perfil (`PlayerDataService.machinePull`), sem pausa entre elas, então não há gasto duplo. O perfil é salvo logo depois.
  - Só gira com o perfil sendo salvo, só no lobby e com intervalo mínimo entre giros (`RewardConfig`).
- **Revelação (refeita):**
  - **Carrossel:** uma fita de mini cartões de Puffs (cores do rastro, olhinhos e raridade) passa atrás de uma moldura dourada. Parada, anda devagar; no giro, acelera; quando a resposta chega (mínimo de 1,8 s), freia suave e para exatamente no Puff sorteado, com um tique a cada cartão (`PuffMachineCarousel`). Os cartões de enchimento são só enfeite, sorteados no cliente pelas chances da tabela.
  - **Cápsula:** a tela escurece, a cápsula na cor da raridade treme cada vez mais forte e estoura (clarão, confete e som). Depois aparece o cartão do Puff com a prévia animada do Puffdex, o nome, a frase, "✨ NOVO!" ou "Repetido · +2 🎟", e o botão CONTINUAR (`PuffMachineReveal`).
  - **Épico e Lendário:** raios girando atrás do cartão, fundo mais escuro, tremida mais longa, mais confete e fanfarra própria.
  - **Aviso de Lendário:** quando alguém tira um Lendário **novo**, os outros jogadores do servidor veem a faixa "LENDÁRIO NA PUFF MACHINE!". No máximo um aviso a cada 30 s por jogador.
  - Resposta atrasada (depois do limite do giro) mostra o Puff direto. Fechar o painel no meio da freada termina o giro na hora.
  - O botão VER NO PUFFDEX leva direto ao Puff.
- **Perfil v4:** passa a guardar `tickets`, `ticketsEarned`, `ticketsSpent`, `machinePulls` e `machinePity`. A migração v3 → v4 é automática.
- **Telemetria:** entradas e saídas de tickets na economia nativa (inclusive a devolução de repetidos), `PuffMachineOpened`, `PuffMachinePull` (Puff, raridade, novo ou repetido) e `PuffUnlocked` com origem `Machine`.
- **Código:** `RewardConfig`, `data/RewardRules`, `PuffMachineService` e `PlayerDataService.machinePull`. No cliente, `PuffMachineController`, `PuffMachineView`, `PuffMachineCarousel` e `PuffMachineReveal`.

### Puffdex e primeira coleção (Fase 4, entrega 4.1)

Escopo em `docs/FASE_4_PUFFDEX_RECOMPENSAS_SOCIAL.md`.

- **Coleção inicial** (`shared/config/PuffCatalog`): 14 Puffs em quatro raridades, todos conquistados jogando (mais os 8 da Puff Machine, na 4.2).
  - **Comuns:** Branco (inicial), Algodão Doce (nível 3), Menta (5 partidas), Pêssego (150 blocos).
  - **Raros:** Gelo (nível 10), Elétrico (15 derrubadas), Tijolinho (10 blocos reconstruídos), Sussurro (3 passagens secretas).
  - **Épicos:** Brasil (20 Top 3), Galáxia (nível 25), Cofre (3 cofres conquistados).
  - **Lendários:** Barão (25 fugas do Barão), Dourado (25 vitórias), Fênix (10 Voltas por Cima).
  - Ids ficam salvos nos perfis: nunca renomeie nem reaproveite um id.
- **Só visual:** o Puff equipado muda o rastro, o brilho e as faíscas do impacto do disparo.
  - Tamanho, velocidade, alcance, cadência, empurrão e acerto são iguais para todos.
  - O miolo do projétil continua branco, para não atrapalhar a visibilidade.
- **Desbloqueio no servidor:** o `PlayerDataService` concede os Puffs merecidos ao carregar o perfil e depois de cada rodada.
  - Perfis antigos recebem na hora o que já tinham conquistado.
  - O inventário é indexado pelo id do Puff, então nada duplica ao reconectar e cada recompensa é dada uma vez só.
- **Perfil v3:** o perfil passa a guardar `puffs` (data, quantidade, origem e um `uid` por item) e `equippedPuff`. A migração v2 → v3 é automática.
- **Equipar:** o painel pede ao servidor pelo remote `Puffdex` (`PuffdexService`), que confere se o jogador tem o Puff.
  - O Puff equipado fica no atributo `EquippedPuff` do jogador, que todos os clientes enxergam.
  - É dali que o `PuffadorService` tira as cores de cada disparo.
- **Interface:** o botão ✨ ao lado do 🏆 no cartão de perfil (lobby) abre o **PUFFDEX**.
  - Grade com a coleção: os Puffs bloqueados aparecem como "?" com a raridade.
  - O detalhe mostra a prévia das cores, a origem, a data, a dica curta de como conseguir e o progresso (por exemplo, "7 / 15").
  - Puffs novos ganham o aviso "NOVO PUFF!" e a etiqueta NOVO.
- **Trading:** preparado, mas desligado (`PuffCatalog.TradingEnabled = false`, campo `tradable` e `uid` por item). Não existe nenhum caminho de troca.
- **Telemetria:** `PuffUnlocked` (id, raridade e origem), `PuffCollection` (progresso), `PuffEquipped` e `PuffdexOpened`.
- **Código:** `PuffCatalog`, `PuffTypes`, `data/PuffInventory`, `ProfileSchema`, `PlayerDataService` e `PuffdexService`. No cliente, `PuffdexController` e `PuffdexView`.

### Ranking global e Hall da Fama (Fase 3, entrega 3.4)

- **Categorias** (poucas de propósito): vitórias, derrubadas, blocos destruídos e cofres conquistados. Cada uma tem um OrderedDataStore (`BlocoPuffLB_v1_<categoria>`, chave = UserId).
- **Integridade:**
  - os valores vêm só do perfil calculado e salvo pelo servidor (`PlayerDataService`), e só de perfis que estão sendo salvos de verdade;
  - o cliente nunca envia números para o ranking;
  - valores acima de 10 milhões são ignorados, e empates dividem a mesma posição.
- **Atualização:**
  - **Gravação:** a cada 60 s, só das categorias que mudaram, e também quando o jogador sai ou o servidor fecha.
  - **Leitura:** o top 10 é lido a cada 2 min em segundo plano, então o lobby nunca espera o DataStore.
  - **Falhas:** se uma categoria falhar, fica a leitura anterior.
- **Hall da Fama** (`HallOfFameService`): cinco painéis no alto da parede leste da galeria, entre o topo das janelas e a sanca. Da esquerda para a direita:
  - Vitórias;
  - Derrubadas;
  - **Lenda do BlocoPuff** (1º em vitórias, com foto) e a linha "Ranking da temporada: em breve";
  - Blocos destruídos;
  - Cofres conquistados.

  Cada painel mostra o top 5. O texto é desenhado pelo servidor.
- **Painel RANKING:** botão 🏆 ao lado do cartão de perfil, com o top 10 por categoria em abas, foto, posição e valor; a sua linha fica em dourado. A aba 📅 de temporada está reservada e desativada. O painel fecha quando você entra na partida.
- **Telemetria:** `LeaderboardOpened` (com a aba) e `HallOfFameViewed` (ficou 3 s na galeria virado para os painéis; uma vez por sessão).
- **Corrigir o ranking:**
  1. Corrija primeiro o perfil (procedimento da entrega 3.1).
  2. No Data Stores Manager, ajuste ou apague a chave `<UserId>` em cada `BlocoPuffLB_v1_<categoria>`.
  3. O valor volta a ser gravado a partir do perfil na próxima vez que ele mudar.
- **Studio:** sem acesso às APIs, os painéis mostram "Ranking indisponível".
- **Código:** `LeaderboardService`, `HallOfFameService` e `LeaderboardTypes`. No cliente, `LeaderboardController` e `LeaderboardView`.

### Resultado avançado (Fase 3, entrega 3.3)

- **Pódio:** os três primeiros, com foto (headshot), nome e degraus de ouro, prata e bronze. Em empate, o texto mostra a mesma posição.
- **Sua linha:** posição, blocos e derrubadas.
- **Destaques** (até 5; o seu fica em dourado):

  | Destaque | Critério |
  |----------|----------|
  | Demolidor | Mais blocos, mínimo 5 |
  | Mais derrubadas | Mais derrubadas |
  | Dono do cofre | Pegou o Puffador do Cofre ou abriu o cofre |
  | Escapou do Barão | Mais fugas |
  | Descobridor | Mais passagens reveladas |
  | Volta por Cima | Voltou da Segunda Chance e derrubou alguém ou venceu |

  Nenhum destaque premia comportamento antijogo: não há prêmio por se esconder na Toca, ficar parado ou fugir da luta. Todos vêm de jogar de verdade.
- **XP da rodada:** o total, a barra de nível (ou "NÍVEL 4 → 5!") e cada fonte do XP. Ele chega pelo perfil logo depois do resultado, marcado com o número da rodada, e só entra no painel dessa mesma rodada.
- **Código:** `RoundResultBuilder` (destaques e contadores por jogador), `ResultTypes`, `ResultsView` e `ResultsController`.

### XP, Nível e Prestígio (Fase 3, entrega 3.2)

- **XP por rodada** (`XpCalculator`, calculado no servidor ao fim de cada rodada):

  | Fonte | XP |
  |-------|----|
  | Concluir a partida (quem disparou pelo menos um Puff) | 20 |
  | Colocação (do último ao primeiro) | 0 a 30 |
  | Vitória | 40 |
  | Derrubadas | 8 cada, até 5 |
  | Blocos destruídos | 1 a cada 2, até 20 |
  | Passagem descoberta | 10 cada |
  | Cofre aberto / conquistado | 10 / 15 |
  | Fuga do Barão | 8 cada, até 2 |
  | Volta por Cima | 15 |
  | Construções | 2 cada |

- **Contra farming:**
  - multiplicador pelo tamanho da partida: 0,6 com 2 participantes, 0,8 com 3 e 1,0 com 4 ou mais;
  - quem não disparou nada não ganha XP de participação, colocação nem vitória;
  - o XP é calculado com os mesmos números já limitados que vão para o perfil;
  - cada fonte tem limite, e há um teto de 400 XP por rodada;
  - o XP entra junto com a rodada, pela mesma chave única, então também não duplica ao reconectar.
- **Nível:** para ir do nível N ao N+1 são necessários 100 + 25 × (N − 1) XP, até o nível 50 (34.300 XP no total). O nível é sempre recalculado a partir do XP (`LevelCurve`, compartilhado entre servidor e cliente), então é determinístico. Nível não muda nada na força do jogador.
- **Prestígio:** preparado, mas desligado (`ProgressionConfig.PrestigeEnabled = false`). Quando liberado, no nível 50 o jogador soma uma estrela de prestígio (até 10) e recomeça do nível 1; é só status, sem força. Chamada: `PlayerDataService.prestige(player)`.
- **Perfil v2:** o formato ganhou `levelReachedAt`. A migração v1 → v2 é automática ao carregar.
- **Na tela:**
  - **Cartão no lobby:** fica no canto superior esquerdo, com nível, estrelas de prestígio e barra de XP; o botão PERFIL abre as estatísticas da carreira. Se o progresso não estiver sendo salvo, o cartão avisa.
  - **Fim de cada rodada:** o XP ganho aparece no painel de pós-partida (entrega 3.3).
  - **Subida de nível:** faixa "NÍVEL N!" com som.
- **Telemetria:**
  - `XpGained` (por fonte) e `XpRound` (total, com a faixa de nível e se venceu, para cruzar nível com vitória);
  - `LevelUp` (tempo no nível anterior) e `RoundAfterLevelUp` (replay depois de subir de nível);
  - `Prestige`.
- **Ajustes:** `shared/config/ProgressionConfig`.
- **Código:** `LevelCurve`, `XpCalculator` e `PlayerDataService`. No cliente, `ProgressionController` e `ProfileCardView`.

### Perfil persistente (Fase 3, entrega 3.1)

Escopo em `docs/FASE_3_PROGRESSAO_COMPETICAO.md`.

- **O que é salvo** (DataStore `BlocoPuffProfiles_v1`, chave `u_<UserId>`):
  - partidas, vitórias, Top 3 (só em partidas com 4 ou mais participantes);
  - derrubadas, blocos destruídos e blocos construídos;
  - cofres abertos e conquistados, fugas do Barão, passagens descobertas e Voltas por Cima;
  - XP, nível e prestígio, preparados para a 3.2.
- **Quem calcula:** tudo é calculado pelo servidor no fim da rodada, a partir do resultado (`RoundService.commitProfiles`). O cliente nunca envia estatística nem XP. Quem sai no meio da rodada não recebe a rodada. Se o perfil ainda estiver carregando no fim da rodada, a rodada fica guardada e é somada quando ele carregar.
- **Sem duplicação:** cada rodada tem uma chave única (servidor + rodada + início). O perfil guarda as últimas 10 chaves aplicadas, então a mesma rodada nunca é somada duas vezes, nem ao reconectar.
- **Trava de sessão:** só um servidor por vez salva o perfil de um jogador. Ao entrar, o servidor grava no perfil uma trava única: JobId mais um identificador do carregamento, para que sair e voltar rápido no mesmo servidor não confunda as sessões. O salvamento automático grava quem mudou e renova as travas, um jogador por vez; ao sair, o servidor salva e libera a trava.
  - **Troca de servidor:** se outro servidor ainda segura o perfil, o novo continua tentando enquanto o jogador estiver lá: a cada 5 s por 30 s e depois a cada 20 s (evento de telemetria `ProfileLoadDelayed`). O jogador nunca recebe um perfil vazio no lugar do dele. Enquanto isso, a Puffdex mostra "Carregando sua coleção…" e as rodadas jogadas ficam guardadas (até 20) para somar quando o perfil carregar.
  - **Trava abandonada:** uma trava sem renovação há 10 min, de um servidor que caiu, é assumida pelo próximo.
  - **Fechamento do servidor:** `BindToClose` espera os carregamentos em andamento e salva todos os perfis.
- **Valores impossíveis:** cada soma de rodada é limitada ao máximo possível (por exemplo, derrubadas ≤ jogadores − 1, blocos ≤ total da arena). Um corte gera aviso no log do servidor e o evento de telemetria `ProfileAnomaly`.
- **Versões do formato:** `ProfileSchema.CurrentVersion` com passos de migração em `MIGRATIONS`. Dados de uma versão mais nova que o servidor conhece (atualização em andamento) são carregados só para leitura, para não apagar campos novos. Valores corrompidos (negativos, NaN, tipos errados) viram 0 ao carregar.
- **Procedimento para dados inválidos** (correção administrativa):
  1. Confirme o problema pelo log (`Profile anomaly for ...`) ou pela telemetria `ProfileAnomaly`.
  2. Peça ao jogador para sair de todos os servidores; sem isso, a trava de sessão sobrescreve a correção.
  3. No Creator Hub (Data Stores Manager) ou via Open Cloud, abra `BlocoPuffProfiles_v1` / `u_<UserId>` e corrija só os campos de `stats` (inteiros ≥ 0). Não mexa em `session` nem em `appliedRounds`. Para **diminuir** um valor (dado explorado), corrija também a cópia de segurança `BlocoPuffProfiles_backup_v1` / `u_<UserId>`: a cópia só soma e devolveria o valor antigo no próximo carregamento.
  4. Se `session` estiver preso a um servidor que não existe mais, apague só `session` ou espere 10 min.
  5. Registre a correção (quem, quando, o quê e por quê) fora do jogo.
- **Studio:** para salvar de verdade, ative "Enable Studio Access to API Services". Sem isso, o perfil funciona só na memória e o log avisa. É o único caso de perfil temporário.
- **Nada some** (`data/ProfileGuard`): toda gravação junta o que está salvo com o que vai ser salvo, e o que o jogador conquistou nunca diminui.
  - Puffs e a quantidade de cada um, conquistas secretas, estatísticas, XP, nível e prestígio (o XP só cai quando o prestígio sobe).
  - Tickets: gastar é normal, mas o total ganho nunca cai. Se cair, a carteira salva volta.
  - Se o guarda precisar devolver algo, isso fica no log (`Profile ... restored from ...`) e na telemetria `ProfileGuard`, e o jogador recebe de volta na hora. Em uso normal isso nunca acontece.
  - Uma gravação feita por uma versão mais nova do jogo nunca é sobrescrita por uma mais velha.
  - Testes: `lune run tests/ProfileGuard.spec`.
- **Cópia de segurança** (DataStore `BlocoPuffProfiles_backup_v1`, mesma chave): atualizada a cada 10 min e ao sair, e só soma. A cada carregamento, o que o perfil principal tiver perdido volta da cópia.
- **Recuperação:** `tools/profile-recovery` lista as versões do perfil de um jogador (o Roblox guarda 30 dias), com data e quantos Puffs cada uma tem, e restaura a escolhida sem perder nada do atual. Veja o README da pasta.
- **Código:** `PlayerDataService`, `ProfileSchema`, `RoundStatsService`, `config/ProfileConfig` e `ProfileTypes`. No cliente, `ProfileController`, que recebe a cópia, pede de novo ao iniciar e avisa as telas.

### Alertas, Momentos Puff e telemetria dos segredos (Fase 2, entrega 2.4)

- **Prioridade dos alertas** (`NotificationManager`, faixa do topo): alertas críticos passam na frente dos menores e nada se sobrepõe.

  | Prioridade | Alertas |
  |------------|---------|
  | Crítica | Barão acordou / cofre destrancou; cofre aberto (com o Barão bravo) |
  | Alta | Passagem secreta descoberta; Cofre Conquistado (Puffador do Cofre obtido); avisos do admin |
  | Normal | Momentos Puff; "AU AU!" (contato do Barão); aviso de saída da Toca |
  | Baixa | Toca Segura; modo Construir; quadro errado |

- **Momentos Puff** (`PuffMomentService` / `PuffMomentController`): cada jogador conta no máximo uma vez por tipo por rodada.
  - **Escapou do Barão:** pulou por cima dele, ou fugiu de uma perseguição de pelo menos 3 s sem ser pego.
  - **Volta por Cima:** depois de usar a Segunda Chance, derrubou alguém ou venceu a rodada.
  - **Cofre Conquistado:** pegou o Puffador do Cofre.
  - **Descoberta secreta:** revelou uma passagem.

  Cofre e descoberta usam a faixa que já existia; os demais ganham faixa própria.
- **Tensão:** quem está sendo perseguido ouve uma batida grave sem direção (`BaraoTensionController`), que acelera e sobe de volume enquanto a perseguição dura. Ela não indica de onde o Barão vem; a pista de posição continua sendo o som 3D. O som fica em `GameConfig.Barao.TensionSoundId`.
- **Telemetria** (`CorridorTelemetryService` e ganchos nos serviços):
  - **Corredores:** `CorridorEntered` (andar de entrada) e `CorridorExited` (duração, andar de saída e de entrada).
  - **Descobertas:** `PassageRevealed`, com `FirstOfRound` no primeiro da rodada; o valor é o tempo até a descoberta.
  - **Tocas:** `TocaEntered` e `TocaLeft` (segundos, `Leave` ou `Eject`).
  - **Barão:** `BaraoEncounter`, `BaraoContact`, `BaraoEscape` (`Jump` ou `Run`) e `LeftAfterBarao` (saiu do jogo até 30 s depois de encontrá-lo).
  - **Cofre:** `VaultExpelled`, `VaultOpened`, `VaultPrizeTaken`, `BlockBuilt` e `RoundVaultShots` (tiros com o Puffador do Cofre).
  - **Momentos:** `PuffMoment`.

### O Cofre e o Puffador do Cofre (Fase 2, entrega 2.3)

A mansão pertence ao Barão Puff, inventor do Puffador. O protótipo dele, o **Puffador do Cofre**, fica guardado num cofre atrás da porta da parede oeste do andar de baixo, separado dos corredores secretos.

- **Relação com o Barão:** o cofre destranca no instante em que o Barão acorda, sorteado entre 20% e 35% da rodada (`GameConfig.Barao.WakeMin/MaxFraction`). Todos recebem "O BARÃO ACORDOU!" e um brilho dourado escapa por baixo da porta. Antes disso, a porta responde "O cofre abre quando o Barão acordar…".
- **Abrir:** exige segurar o prompt por 1,5 s. O primeiro a abrir dispara o alarme para a partida inteira (aviso crítico, com o nome dele) e deixa o Barão **bravo** por 25 s: ele acorda na hora se ainda dormia, late mais e corre 10% mais rápido, ainda mais devagar que o jogador.
- **Disputa:** o prêmio é um por rodada e exige segurar o prompt do pedestal por 0,8 s; a briga é no empurrão. Não existe mais eliminação por tiro dentro do cofre. Cada jogador pode ficar no máximo 15 s no cofre por rodada, com aviso aos 10 s; depois o Barão o põe para fora.
- **Puffador do Cofre:** tem 15 Puffs que derrubam 2 blocos cada e empurram 35% mais forte, e 3 construções. Quem o carrega fica com contorno dourado, visível para todos. Quando os Puffs acabam, volta ao Puffador comum e as construções que sobraram se perdem.
- **Modo Construir:**
  - **Como usar:** Q (teclado), Y (controle) ou o botão 🧱 acima do PUFF (toque) alternam entre Puff e Construir. No modo Construir, cada aperto do disparo reconstrói um bloco, e um bloco fantasma dourado mostra onde ele vai voltar.
  - **O que dá para construir:** só blocos derrubados da própria grade da arena, no lugar original, a até 40 studs: o primeiro buraco que a mira atravessa antes de bater em algo. Isso serve para refazer passagem, criar apoio, fazer ponte curta ou recuperar rota. Não dá para criar paredes nem blocos soltos, então não dá para prender ninguém.
  - **Quando é recusado:** se houver alguém no espaço do bloco ou logo acima (quem está caindo no buraco), para ninguém ficar enterrado.
  - **Limites:** 3 construções por posse e 0,5 s entre elas. O servidor valida tudo.
- **Estatísticas:** telemetria `VaultOpened`, `VaultPrizeTaken` e `BlockBuilt`.
- **Ajustes:** `GameConfig.SecretRoom` (cargas, alcance, tempos e `AlertSoundId`) e `GameConfig.Barao` (despertar e fúria).
- **Código:** `VaultService` (regras), `VaultProps` (porta, brilho, alarme e prêmio), `SecretRoomBuilder` (arquitetura), `BuildModeService` (validação da construção), `BuildTargeting` (alvo compartilhado entre servidor e cliente), `ArenaService.rebuildBlock` e `PuffadorModel`. No cliente, `VaultController`, `BuildModeController`, `BuildToggleView` e `SuperChargeView`.

### Identidade visual

A interface segue uma identidade própria definida em `src/client/ui/UiTheme.luau`: "noite na mansão" (fundos roxo-escuros) com as duas cores do Puffador como marca, lilás Puff e dourado Puff; títulos em FredokaOne com contorno escuro; painéis com gradiente, borda em gradiente lilás→dourado e sombra sólida. O logotipo "BLOCO PUFF" aparece no lobby e no painel admin. `UiKit` oferece o botão 3D da marca (afunda ao clicar, cresce no hover, toca um clique e é selecionável por gamepad) e animações de destaque. O botão de tiro mobile é redondo, com recarga enchendo o círculo. `FeedbackView` mostra um "+1" pequeno que escorrega para a direita da mira a cada bloco derrubado e, no lado direito da tela (abaixo do HUD superior), o contador de combo, as chamadas de sequência ("TRIPLO!", "EM CHAMAS!", "IMPARÁVEL!", "LENDÁRIO!") e as notificações curtas de marcos de blocos. Os anúncios centrais (`AnnouncementView`) aparecem no topo, abaixo da faixa de avisos: o centro da tela fica livre para mirar. O painel admin usa cartões por seção, lista de jogadores com avatar e seleção destacada, contadores de caracteres e uma pílula de status para o retorno do servidor.

Uma trilha de fundo (`MusicController`) toca localmente em cada cliente, em loop: baixa no lobby e bem mais baixa enquanto o jogador está competindo, com transição suave (eliminados voltam ao volume do lobby). O ID do áudio, os volumes e o tempo de transição ficam em `GameConfig.Music`.

### Artes da loja

**Modo foto (só no Studio).** `PhotoModeService` monta cenas prontas para prints: bonecos R15 em pose com o Puffador, buracos no piso, projéteis e pedaços congelados no ar, com a câmera já enquadrada. Aperte **Run** (F8, sem entrar como jogador) e, na barra de comandos, rode:

```lua
workspace:SetAttribute("PhotoScene", "acao")   -- tiroteio no piso de cima (thumbnail principal)
workspace:SetAttribute("PhotoScene", "queda")  -- visto do andar de baixo, alguém caindo pelo buraco
workspace:SetAttribute("PhotoScene", "icone")  -- close de um personagem mirando (base do ícone)
workspace:SetAttribute("PhotoScene", "lobby")  -- galeria envidraçada com jogadores assistindo
workspace:SetAttribute("PhotoScene", "")       -- limpa a cena e restaura os blocos
```

Depois é só tirar o print da janela do Studio (dá para ajustar a câmera à mão antes).

**Editor de capas.** Abra `tools/store-art/editor-de-capas.html` no navegador, solte o print e escolha **Thumbnail** (1920×1080) ou **Ícone** (512×512). O editor aplica o logotipo BLOCO PUFF, uma chamada e um selo opcional no estilo da identidade visual, com zoom, enquadramento por arraste, vinheta, saturação e guias de área segura, e exporta o PNG pronto para o Creator Hub.

Ainda não há dano direto, resistência de blocos, regeneração durante a rodada, persistência ou monetização.

Para testar a zona de eliminação manualmente: entre em `Active` com 2+ jogadores, destrua o bloco sob um participante e confirme que ele cai e é eliminado com a mensagem "Você caiu da arena" no HUD, sem perda de vida instantânea no momento do disparo. Os atributos `IsEliminated`, `EliminationReason` e `EliminatedAtRoundId` no `Player` refletem a causa e a rodada.

Um jogador eliminado durante `Active`/`Ending` tem sua câmera automaticamente redirecionada para acompanhar um participante ainda ativo, em vez de ficar parada no próprio personagem já eliminado no lobby. É um comportamento puramente do cliente (`SpectatorController`, lendo apenas atributos já replicados de `Player`), sem impacto em nenhum estado autoritativo. O alvo observado pode ser alternado manualmente entre os participantes ainda ativos — setas do teclado, D-Pad do gamepad, ou os botões `<`/`>` que aparecem na tela durante o modo espectador, que também mostra quantos participantes ainda seguem ativos.
