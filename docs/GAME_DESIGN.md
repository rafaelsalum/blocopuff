# BlocoPuff — Game Design Document

**Status:** direção oficial de produto  
**Versão:** 1.0  
**Objetivo:** consolidar a visão do BlocoPuff antes da implementação incremental.

---

## 1. Visão do jogo

**BlocoPuff** é um jogo competitivo, rápido, social e caótico no Roblox em que os jogadores usam o **Puffador** para destruir a arena e empurrar adversários, sem combate baseado em pontos de vida.

A fantasia central é simples:

> Sobreviva à arena, derrube adversários, explore passagens secretas, dispute o cofre, fuja do Barão e conquiste Puffs raros.

O jogo deve ser fácil de entender nos primeiros segundos, mas oferecer profundidade suficiente para que jogadores experientes dominem movimentação, mira, rotas secretas, uso do cenário, timing e decisões de risco/recompensa.

### Pilares

1. **Diversão imediata:** movimentar, mirar e disparar precisam ser agradáveis antes de qualquer metajogo.
2. **Caos compreensível:** muita coisa pode acontecer, mas o jogador precisa entender por que aconteceu.
3. **Sem dano tradicional:** o Puffador empurra e altera a arena; a eliminação acontece pela queda.
4. **Partidas rápidas:** ciclo curto que incentive "só mais uma".
5. **Segredos e descoberta:** corredores, quadros, atalhos e conquistas recompensam conhecimento.
6. **Progressão sem pay-to-win:** nível, coleção e cosméticos geram prestígio, não força competitiva comprada.
7. **Momentos compartilháveis:** fugas, quedas, Barão, cofre e jogadas excepcionais devem gerar histórias e clipes.
8. **Live game:** temporadas, eventos e novidades devem manter o mundo vivo.

---

## 2. Público e posicionamento

O BlocoPuff deve ser acessível para crianças e famílias, mas não infantilizado a ponto de afastar jogadores mais velhos.

A violência é substituída por humor físico: Puff, empurrões, quedas, blocos quebrando, perseguições e sons engraçados.

O jogo deve funcionar bem em **mobile, desktop e gamepad**, com prioridade especial para mobile.

---

## 3. Estrutura de servidores e partidas

Cada servidor/sala comportará **até 12 jogadores por partida**.

O jogo deve ser arquitetado assumindo que, se houver milhares de jogadores simultâneos, existirão muitas instâncias de servidor em paralelo.

Dados persistentes e globais, como perfil, nível, Puffdex, inventário, rankings e temporada, não podem depender de uma única sala.

### Party

A visão inclui sistema de **Party** para permitir que amigos entrem juntos no matchmaking sempre que houver capacidade.

Party é uma feature posterior ao core gameplay, mas a arquitetura não deve impedir sua introdução.

---

## 4. Ciclo de uma partida

Meta inicial de duração:

- aproximadamente **3 min 30 s de gameplay**;
- aproximadamente **30 s de encerramento/transição**;
- ciclo total próximo de **4 minutos**.

Valores devem permanecer configuráveis e sujeitos a telemetria/playtest.

### Macrofluxo

1. Waiting / Lobby
2. Countdown
3. Active
4. Exploração e combate
5. Cofre/corredores/Barão entram no conflito
6. Caos Final
7. Vencedor e destaques
8. Recompensas/progresso
9. Replay / próxima rodada

### Caos Final

Nos últimos ~30 segundos:

- Segunda Chance é desativada;
- quedas passam a eliminar definitivamente;
- a arena se torna progressivamente mais perigosa;
- a pressão deve aumentar de forma legível;
- o objetivo é evitar finais arrastados e criar clímax.

A forma exata de degradação da arena deve ser validada em playtest.

---

## 5. Arena

A arena principal possui **dois andares jogáveis**.

Cair do andar superior para o inferior não significa eliminação.

A queda definitiva acontece ao sair da arena inferior, sujeita à mecânica de Segunda Chance.

O mapa deve permitir:

- confrontos diretos;
- rotas alternativas;
- reposicionamento;
- oportunidades de recuperação;
- acesso a corredores secretos;
- leitura visual rápida;
- destruição progressiva sem tornar a partida incompreensível.

O layout deve evitar áreas excessivamente abertas ou distâncias que reduzam interação.

---

## 6. Puffador

O Puffador é a ferramenta central do BlocoPuff.

### Puffador comum

O disparo deve:

- ser satisfatório visual e sonoramente;
- quebrar blocos válidos da arena;
- aplicar knockback em jogadores;
- não utilizar dano/HP como condição de vitória;
- permitir jogadas defensivas e ofensivas;
- ser validado de forma autoritativa pelo servidor.

A força, cadência, alcance, comportamento por distância e quantidade de blocos afetados são parâmetros de balanceamento.

### Evolução do protótipo existente

O protótipo técnico atual possui projétil autoritativo e raycast no servidor, mas o impacto é apenas visual. A visão oficial evolui esse comportamento para **destruição de blocos e knockback**, mantendo a autoridade do servidor.

---

## 7. Puffador do Cofre

O cofre concede uma versão especial do Puffador.

Características desejadas:

- quebra **2 blocos por disparo**;
- knockback superior, sujeito a balanceamento;
- possui modo alternativo de **construção de blocos**;
- construção deve ser limitada por carga/munição para impedir abuso.

Exemplo inicial: até 3 construções por posse, a validar.

Usos esperados:

- reconstruir passagem;
- criar apoio após uma queda;
- formar ponte curta;
- recuperar acesso a corredor;
- alterar temporariamente uma rota.

O Puffador especial deve criar opções estratégicas, não uma vitória automática.

---

## 8. Cofre

O cofre é uma área de alto risco e alta recompensa.

Ele **não é a entrada dos corredores secretos**.

Cofre e corredores são sistemas separados.

Abrir/acessar o cofre:

- concede o Puffador especial segundo as regras da rodada;
- gera alerta importante para a partida;
- está relacionado ao despertar/atividade do Barão;
- cria um ponto de disputa entre jogadores.

O sistema deve permitir registrar estatísticas relacionadas ao cofre.

---

## 9. Corredores secretos

Os corredores conectam os dois andares da arena.

Eles oferecem:

- retorno do andar inferior para o superior;
- descida alternativa;
- rotas de fuga;
- risco de encontro com Barão;
- confrontos com Puffador;
- segredos e atalhos.

### Descoberta por quadros

Cada andar possui quadros nas paredes.

Atingir o quadro correto daquele andar revela visualmente o acesso secreto **daquele andar para todos os jogadores da partida**.

Regras:

- revelar no andar superior não revela automaticamente o inferior;
- a passagem existe mesmo antes da revelação;
- jogadores que conhecem a localização podem entrar antes;
- conhecimento do mapa deve ser recompensado;
- o segredo não deve depender de uma porta de cofre.

Isso cria valor para veteranos e momentos de descoberta para novatos.

---

## 10. Tocas Seguras

Dentro dos corredores existem pequenos pontos de proteção, provisoriamente chamados **Tocas Seguras**.

Regras:

- comportam somente **1 jogador**;
- Barão não consegue atingir o ocupante enquanto ele estiver corretamente protegido;
- outros jogadores ainda podem acertá-lo com o Puffador;
- knockback causado por outro jogador pode expulsá-lo da Toca;
- não devem permitir camping indefinido sem custo ou risco.

O objetivo é gerar decisões e situações emergentes, não invulnerabilidade permanente.

---

## 11. Barão

**Barão** é o mascote do BlocoPuff.

### Identidade

- cachorro vira-lata caramelo;
- camisa inspirada nas cores do Brasil;
- personalidade cômica, territorial e memorável;
- não mata;
- expulsa invasores dos corredores.

A representação deve ser original e não depender da reprodução de um cachorro/meme específico protegido por direitos de terceiros.

### Gameplay

Barão patrulha/persegue jogadores nos corredores.

Ao tocar em um jogador:

- aplica forte empurrão em direção à saída/fora da zona protegida;
- toca aleatoriamente um som engraçado;
- não causa dano tradicional.

Jogadores podem **pular por cima dele** com habilidade/timing.

### Tensão

Não haverá indicador preciso de distância/minimapa para Barão.

O jogador deve percebê-lo principalmente por:

- áudio espacial;
- latidos;
- ruídos de movimento;
- pistas ambientais.

A tensão de não saber exatamente de onde ele virá é parte da experiência.

### Variações futuras

Eventos podem introduzir:

- Barão em Dobro;
- variantes sazonais;
- comportamentos especiais;
- aparições temáticas.

Um segundo Barão não faz parte da regra normal inicial.

---

## 12. Segunda Chance e eliminação

Para reduzir frustração e evitar que novatos sejam eliminados em segundos, cada jogador começa a rodada com **uma Segunda Chance**.

Na primeira queda definitiva:

- jogador não é eliminado;
- recebe feedback claro;
- reaparece em ponto seguro apropriado, inicialmente no andar inferior;
- passa a estar em "Última Vida".

Na queda seguinte, é eliminado.

Durante o **Caos Final**, a Segunda Chance fica desativada.

Parâmetros e regras de respawn devem impedir exploração intencional da mecânica.

---

## 13. Espectador

Jogadores eliminados não devem ficar presos em uma experiência passiva longa.

O modo espectador deve permitir:

- alternar jogador observado;
- acompanhar o final rapidamente;
- ver resultado e progresso;
- usar reações sociais discretas que **não alteram o resultado competitivo**.

Permanecer até o encerramento pode conceder XP/recompensa de conclusão, sem transformar sair da partida em punição severa.

---

## 14. UX, câmera e controles

A qualidade do controle é prioridade de produto.

A referência de qualidade são shooters mobile com:

- câmera responsiva;
- mira pequena e legível;
- polegar esquerdo para movimento;
- polegar direito para câmera/mira;
- botão principal de Puff;
- botão de pulo bem posicionado;
- controles contextuais adicionais quando necessário.

Isso é referência de **princípios de usabilidade**, não cópia de interface, assets ou identidade de terceiros.

### Puffador do Cofre

Quando equipado, deve existir controle claro para alternar/acionar:

- Puff;
- Construir.

### Mira

A mira atual deve ser reduzida e refinada.

Pode existir assistência de mira leve em mobile, desde que:

- não jogue automaticamente;
- não dê vantagem injusta;
- seja ajustável por telemetria/playtest.

### Alertas

Deve existir um sistema unificado de notificações com:

- prioridade;
- fila;
- duração;
- categoria;
- regra de substituição;
- prevenção de sobreposição.

Alertas críticos, como Barão/cofre/Caos Final, têm prioridade sobre eventos menores.

---

## 15. Momentos Puff

O jogo deve reconhecer jogadas memoráveis.

Exemplos:

- Triplo Puff;
- Escapou do Barão;
- Salvo no Último Bloco;
- Cofre Conquistado;
- Retorno Impossível;
- Tiro Perfeito;
- Volta por Cima.

Esses eventos devem ser curtos e não bloquear a visão.

Objetivos:

- reforço emocional;
- reconhecimento;
- compartilhamento;
- estatísticas;
- futuras conquistas.

---

## 16. Resultado da partida

O pós-partida não deve reconhecer apenas o vencedor.

### Destaques possíveis

- 1º lugar;
- mais blocos destruídos;
- mais eliminações;
- melhor desempenho no cofre;
- mais fugas do Barão;
- mais acertos;
- outras categorias futuras.

Isso permite que jogadores que não venceram ainda terminem com sensação de conquista.

---

## 17. Perfil, XP e nível

Cada jogador terá **Nível BlocoPuff**.

XP pode ser conquistado por:

- concluir partidas;
- sobreviver;
- vencer;
- Top 3;
- eliminar;
- acertar jogadores;
- destruir blocos;
- descobrir passagem;
- acessar/conquistar cofre;
- escapar do Barão;
- completar desafios;
- conquistas/eventos.

### Regra absoluta

**Nível não aumenta força competitiva.**

Um jogador nível 100 não deve ter Puffador mais forte simplesmente por seu nível.

---

## 18. Prestígio

Ao alcançar o teto de nível definido para um ciclo, inicialmente pensado em 100, o jogador poderá avançar em Prestígio.

Prestígio:

- demonstra veterania;
- concede identidade/status;
- pode desbloquear cosméticos/títulos;
- não concede vantagem direta na arena.

A apresentação final de tiers será definida posteriormente.

---

## 19. Rankings

### Ranking da partida

Exibido no encerramento com vencedor e destaques.

### Rankings globais

Categorias planejadas:

- mais vitórias;
- mais eliminações;
- mais blocos destruídos;
- mais conquistas de cofre;
- outras métricas validadas.

### Ranking sazonal

Reiniciado/renovado por temporada conforme regras específicas.

Dados permanentes de carreira não precisam ser apagados.

### Hall da Fama

O lobby deve exibir rankings e jogadores de destaque.

Pode incluir:

- nomes;
- avatares;
- títulos;
- campeão da temporada;
- estátua/avatar da Lenda do BlocoPuff.

Rankings devem possuir proteção contra exploração e dados impossíveis.

---

## 20. Puffdex

O **Puffdex** é um dos principais sistemas de progressão permanente.

Puffs são colecionáveis/cosméticos relacionados aos disparos, impactos, partículas, sons e identidade visual.

Eles **não aumentam poder competitivo**.

### Estrutura de um Puff

- ID;
- nome;
- raridade;
- origem;
- data de descoberta;
- quantidade, se aplicável;
- efeito visual/sonoro;
- status de desbloqueio;
- regras de negociação futura.

### Raridades iniciais

- Comum;
- Raro;
- Épico;
- Lendário;
- categorias superiores podem ser introduzidas futuramente.

Exemplos conceituais:

- Puff Branco;
- Puff Gelo;
- Puff Elétrico;
- Puff Galáxia;
- Puff Brasil;
- Puff Barão.

Alguns Puffs devem ser conquistados por façanhas e não simplesmente comprados.

---

## 21. Coleções e Barão

Barão pode possuir coleção temática própria.

Exemplos conceituais:

- Patinha Caramelo;
- Brasil;
- Dorminhoco;
- Bravo;
- Ninja;
- Rei Barão;
- Dourado;
- Galáctico.

Completar conjuntos pode desbloquear cosméticos, títulos ou itens de exibição.

---

## 22. Puff Machine

O lobby pode possuir uma **Puff Machine**.

Princípio:

- utiliza tickets obtidos por gameplay/recompensas;
- cria momento de revelação de colecionável;
- não deve ser estruturada como aposta paga;
- probabilidades e experiência precisam ser transparentes/adequadas às políticas aplicáveis do Roblox.

A monetização não deve transformar a Puff Machine em mecanismo predatório.

---

## 23. Desafios e retorno diário

Desafios devem estimular comportamentos divertidos.

Exemplos:

- pular sobre Barão;
- descobrir passagem;
- destruir blocos;
- acertar jogadores nos corredores;
- entrar no cofre;
- terminar Top 3.

Evitar missões baseadas apenas em tempo passivo.

### Streak

Pode existir sequência de retorno diário com recompensas crescentes.

O sistema deve evitar punição excessiva por perder um dia.

---

## 24. Conquistas secretas

Parte das conquistas não deve explicar antecipadamente a solução.

Exemplos:

- entrar em passagem antes de revelá-la;
- pular Barão várias vezes;
- sobreviver em situação extrema;
- descobrir interação secreta;
- acessar segredo do lobby.

Segredos devem alimentar exploração e conversa entre jogadores.

---

## 25. Lobby

O lobby é parte da experiência, não apenas sala de espera.

Elementos planejados:

- Hall da Fama;
- rankings;
- Puffdex;
- Puff Machine;
- loja;
- exibição de jogadores/cosméticos;
- área de treino;
- Barão em estado não hostil/dormindo;
- portais/entrada da próxima partida;
- segredos;
- conteúdo sazonal.

O jogador deve ter algo interessante para fazer enquanto aguarda.

---

## 26. Social e Party

Direção futura:

- formar Party;
- convidar amigos;
- matchmaking conjunto;
- jogar novamente em grupo;
- servidor privado quando apropriado;
- expressão social via emotes/reactions;
- exibição de coleção e títulos.

O design deve incentivar amigos a permanecerem juntos sem criar vantagem injusta.

---

## 27. Trading

Troca de Puffs é uma feature futura e **não faz parte do lançamento inicial**.

A arquitetura de inventário deve prever a possibilidade.

Antes de ativar trading serão necessários:

- economia madura;
- IDs/ownership confiáveis;
- logs;
- prevenção de duplicação;
- confirmação clara;
- proteção contra golpes;
- limites/regras;
- análise das políticas aplicáveis à faixa etária.

---

## 28. Temporadas

O BlocoPuff deve operar como jogo vivo.

Exemplo de primeira temporada:

**Season 1 — O Despertar do Barão**

Uma temporada pode incluir:

- Puffs;
- desafios;
- ranking sazonal;
- cosméticos;
- segredos;
- eventos;
- pequenas alterações de arena;
- narrativa ambiental.

Temporadas não devem invalidar o progresso permanente do jogador.

---

## 29. LiveOps e eventos

### Eventos administrados

Sistema futuro de Live Control para contas autorizadas.

Possíveis eventos:

- Barão em Dobro;
- Super Knockback;
- Chuva de Blocos;
- Puff Party;
- Cofre Maluco;
- Blackout;
- Turbo Puff;
- Disco Puff.

### Eventos globais

Um evento pode ser anunciado para múltiplos servidores:

- contagem regressiva;
- início coordenado;
- duração;
- regras especiais;
- recompensa temática.

### Eventos de calendário

Exemplos:

- Halloween;
- Natal;
- aniversário do BlocoPuff;
- evento temático do Barão.

Conteúdo deve respeitar a identidade própria do jogo.

### Presença de criadores/admins

A presença autorizada de criadores pode gerar eventos/recompensas especiais, sem obrigar jogadores a derrotá-los ou favorecer admins competitivamente.

---

## 30. Monetização

Princípio central:

> **Monetizar expressão, coleção e identidade; não vender vitória.**

Possibilidades:

- skins do Puffador;
- efeitos Puff;
- partículas;
- trilhas de queda;
- emotes;
- comemorações;
- títulos;
- tags;
- cosméticos do perfil;
- bundles temáticos;
- conteúdo de temporada compatível com políticas do Roblox.

Evitar:

- força superior paga;
- mais knockback por Robux;
- mais vidas competitivas pagas;
- acesso pago a vantagens decisivas;
- mecânicas predatórias.

---

## 31. Telemetria

Telemetria deve existir desde as primeiras fases.

### Core gameplay

- duração real das partidas;
- tempo até primeira queda;
- eliminações por minuto;
- distribuição de vitórias;
- abandono durante partida;
- rematch;
- precisão;
- disparos;
- blocos destruídos;
- causas/local de queda;
- desempenho por dispositivo.

### Barão/corredores

- corredores acessados;
- passagens reveladas;
- uso de Tocas;
- encontros com Barão;
- expulsões;
- fugas;
- cofre aberto;
- tempo até cofre;
- uso do modo Construir.

### Progressão

- XP por partida;
- níveis;
- retorno D1/D7/D28;
- desafios;
- Puffdex;
- itens obtidos/equipados;
- frequência de sessões.

### Social

- Party;
- partidas com amigos;
- replay em grupo;
- convites, quando aplicável.

Métricas servem para orientar balanceamento; não substituem playtests qualitativos.

---

## 32. Segurança e autoridade

O servidor deve continuar sendo autoridade sobre:

- estado da rodada;
- participação;
- disparos válidos;
- impacto;
- destruição;
- knockback;
- eliminação;
- cofre;
- Barão;
- recompensas;
- XP;
- inventário;
- ranking.

O cliente é responsável principalmente por input, câmera, apresentação e feedback imediato seguro.

Nunca confiar em valores críticos enviados pelo cliente sem validação.

---

## 33. Estado técnico existente a preservar

O projeto já possui protótipos/estrutura para:

- estados de rodada;
- HUD responsivo baseado em estado replicado;
- atributos individuais de participação/eliminação;
- Puffador;
- RemoteEvent de disparo;
- validações de servidor;
- projéteis simulados por raycast autoritativo.

A evolução deve preferir extensão/refatoração consciente em vez de descartar a arquitetura sem necessidade.

O Puffador atual ainda não possui, no protótipo documentado, destruição/knockback real. Essa é uma evolução planejada.

---

## 34. Ordem estratégica de evolução

A implementação será dividida em cinco entregas independentes:

1. **Core Gameplay & UX**
2. **Segredos, Cofre & Barão**
3. **Progressão & Competição**
4. **Puffdex, Recompensas & Social**
5. **LiveOps, Temporadas & Monetização**

Cada fase deve resultar em uma versão publicável/testável.

Não implementar uma fase inteira como mega-release quando for possível liberar incrementos menores dentro dela.

---

## 35. Critério máximo de decisão

Quando houver dúvida entre adicionar mais conteúdo e melhorar a sensação de jogar:

> **melhorar a sensação de jogar vem primeiro.**

Movimento, câmera, mira, impacto, leitura da arena, feedback e estabilidade são mais importantes do que quantidade de sistemas.

O jogador precisa amar o ato de jogar BlocoPuff antes de ser convidado a colecionar, progredir ou comprar qualquer coisa.
