# Fase 5F — Torre do Relógio Encantada

**Entrega:** refazer o mapa da Corrida da Torre do Relógio (Fase 5D.2) para ficar imponente, robusto e com cara de castelo de escola de magia (só o estilo). A torre fica mais larga e alta, numa ilha de pedra ao lado do Casarão. A rampa ganha mureta, ninguém consegue pular para fora, e os obstáculos ficam novos e variados. Os modelos 3D vêm da Creator Store.
**Dependência:** Fase 5E entregue. As regras da Corrida (checkpoints, chegada, pódio, bots pelo caminho da rampa) continuam as mesmas: muda o mapa e os obstáculos.

---

## Problema

Avaliação no Studio em 24/10/2026:

1. **Torre solta no vazio.** Fica em (−420, 100, 0), a ~600 studs do Casarão. Ninguém a vê do lobby e não há chão em volta: é uma base redonda de pedra flutuando no céu.
2. **Cenário pobre.** É uma coluna de tijolo lisa com uma rampa de tábuas, bandeirinhas nos checkpoints e uma bola de "sino" no alto. Não há relógio, janela, telhado, nem nada em volta.
3. **Pista estreita.** A rampa tem 16 studs. Com 4 a 8 corredores e obstáculos, não dá para desviar nem ultrapassar.
4. **Dá para pular para fora.** A rampa não tem mureta, e o topo é um disco de mármore sem borda. Do alto, qualquer um pula para o vazio.
5. **Obstáculos repetidos.** Só barris rolando e 3 blocos caindo (caixote, baú, quadro), sempre iguais.

---

## Resultado esperado

O jogador passa a:
- ver do lobby, ao lado do Casarão, uma torre de pedra enorme com relógio de 4 faces iluminado e campanário pontudo;
- chegar a ela pela ilha de pedra, com pátio, muralhas, torrinhas de telhado azul, estandartes, gárgulas, tochas, velas flutuantes e névoa nos penhascos;
- subir uma rampa larga com mureta e ameias, sem cair para fora;
- desviar de livros voadores, caldeirões e barris rolando, do ponteiro gigante que varre um patamar e de engrenagens que caem;
- ouvir o sino tocar quando alguém chega ao topo.

---

## Princípios

1. **Estilo de castelo de magia, sem marca.** Pedra cinza-azulada, telhados cônicos de ardósia, janelas góticas acesas, velas, corujas e livros. Nenhum nome, brasão ou personagem de outra obra.
2. **Robusto antes de bonito.** Mureta e barreira invisível em toda a borda de fora da rampa e do topo. Nenhum lugar da pista deixa cair para o vazio.
3. **Modelos 3D da Creator Store, limpos.** Modelos gratuitos são recriados por código a partir das malhas (FileMesh e `AssetService:CreateMeshPartAsync`), como a faca da 5E. Assim não entra arquivo binário, script de terceiros nem união (`UnionOperation`), que não dá para recriar. Peças que faltarem são feitas com peças nativas.
4. **Celular primeiro.** Orçamento de peças e de luzes parecido com o do Casarão. Enfeites longe da pista não colidem e não recebem consulta de raio.
5. **Todo obstáculo avisa.** Sombra no chão, som ou brilho antes de acertar. Quem é atingido é empurrado rampa abaixo e fica tonto um instante. Ninguém é eliminado.
6. **Servidor decide, cliente desenha.** Posição e acerto dos obstáculos são do servidor. Ponteiros do relógio, velas e partículas são do cliente quando possível.

---

## Escopo

### 5F.1 — Estrutura robusta
- **Posição.** Ilha de pedra flutuante ao lado do Casarão, a confirmar no Studio. A ideia é o lado norte, perto de (180, 100, −220), à vista do lobby. Penhasco irregular embaixo, com névoa.
- **Ponte coberta de enfeite** (madeira e telhado) ligando o Casarão à ilha. A partida continua começando por teletransporte.
- **Torre maior.** Raio de 30 para 42, rampa de 16 para 24 studs, 4 voltas de 30 de subida (~120 de altura). Contrafortes, janelas góticas acesas e anéis de pedra a cada volta.
- **Relógio gigante de 4 faces** perto do topo, com o desenho do `ClockFace` e ponteiros que andam.
- **Campanário** com telhado cônico de ardósia e o sino, que toca quando alguém chega.
- **Mureta com ameias** em toda a borda de fora da rampa, mais uma barreira invisível alta. O topo vira um terraço cercado.
- **Patamares de checkpoint** com arco de pedra e estandarte.

### 5F.2 — Cenário fantástico
- Pátio da ilha com chafariz, muralha baixa com ameias e 3 ou 4 torrinhas de telhado pontudo azul.
- Modelos da Creator Store: gárgulas na mureta, tochas e lanternas, árvores retorcidas na beira da ilha.
- Velas flutuantes balançando ao longo da subida, e corvos ou morcegos voando em volta do campanário (cliente).
- Luz quente nas janelas e no relógio, névoa fria nos penhascos.

### 5F.3 — Obstáculos novos
- **Livros voadores.** Um bando cruza a rampa de lado a lado num trecho à frente dos corredores, com aviso de brilho na mureta antes.
- **Caldeirões rolando.** Maiores e mais lentos que os barris, rolam rampa abaixo junto com eles.
- **Ponteiro gigante.** Num dos patamares, o ponteiro do relógio varre o chão de tempos em tempos. Tem que pular na hora certa.
- **Engrenagens caindo.** Caem do mecanismo do relógio, com sombra de aviso, no lugar dos caixotes, baús e quadros.
- **Atingido.** É empurrado rampa abaixo (não para fora) e fica tonto por 1 s.

---

## Números iniciais

| O quê | Hoje | Novo |
|---|---|---|
| Raio da torre (centro até o meio da rampa) | 30 | 42 |
| Largura da rampa | 16 | 24 |
| Voltas × subida por volta | 4 × 26 | 4 × 30 |
| Altura da mureta visível | — | 3,5 |
| Altura da barreira invisível acima da rampa | — | 14 |
| Ilha (raio aproximado) | base de 52 | ~85 |
| Tontura depois de atingido | — | 1 s |

---

## Arquitetura técnica

- `RaceConfig.Tower`: novo centro, raio, largura, subida e alturas da mureta e da barreira.
- `TowerBuilder` dividido por responsabilidade, com cada arquivo abaixo de 800 linhas:
  - `TowerBuilder`: estrutura, rampa, mureta, barreira e topo.
  - `TowerIsland`: ilha, penhasco, pátio, muralha, torrinhas e ponte.
  - `TowerDecor`: relógio, campanário, velas e modelos da Creator Store.
- `TowerAssets` (compartilhado): os modelos da Creator Store descritos em dados (malha, textura, tamanho, posição relativa) e montados por código.
- `RaceHazards` ganha os obstáculos novos, cada um num módulo pequeno (`HazardBooks`, `HazardCauldron`, `HazardClockHand`, `HazardGears`). A conta de acerto fica em `RaceRules`, pura e testada no Lune.
- O caminho dos bots continua vindo do `TowerLayout.path`, que se adapta sozinho ao raio e à largura novos.

---

## Testes automatizados (Lune)

- Espiral com os números novos: largura, altura do topo e checkpoints.
- Acerto do ponteiro varrendo um ângulo do patamar: quem está no chão é atingido, quem está pulando não.
- Trajeto do bando de livros: só cruza a rampa no trecho escolhido.
- Empurrão "rampa abaixo": a direção é a tangente para baixo, nunca para fora.

---

## Critérios de aceite

1. Do lobby do Casarão, a torre aparece inteira e imponente.
2. Em nenhum ponto da rampa ou do topo dá para pular ou cair para fora da torre.
3. A rampa comporta 4 corredores lado a lado.
4. Os 4 obstáculos novos aparecem na mesma corrida, sempre com aviso.
5. Os bots completam a subida pelo caminho da rampa.
6. O desempenho no celular fica no orçamento de peças e de luzes.

---

## Ordem das entregas

1. **5F.1** — estrutura robusta, mureta, barreira, relógio, campanário, nova posição e ponte.
2. **5F.2** — cenário fantástico: ilha, pátio, torrinhas, modelos da Creator Store, velas e névoa.
3. **5F.3** — obstáculos novos e o empurrão rampa abaixo com tontura.

Cada entrega é testada no Studio com capturas, e o commit é feito quando o dono pedir.

---

## Andamento

- **Plano aprovado (24/10/2026).** Decisões: ilha ao lado do Casarão com ponte coberta; rampa de 24 com 4 voltas; atingido só escorrega rampa abaixo (sem cair para a volta de baixo); os 4 obstáculos novos.
- **5F.1 — estrutura robusta.**
  - **Ilha:** em (180, 120, −230), ao norte do Casarão, com gramado, pátio de laje, penhasco de rocha pendurado, muralha com ameias, 4 torrinhas de telhado azul e a ponte coberta até a parede do Casarão.
  - **Torre:** raio 42, rampa de 24 em 4 voltas de 30; coluna de pedra com janelas góticas acesas; 8 contrafortes com pináculos.
  - **Segurança:** mureta com ameias e barreira invisível até a volta de cima (23,5) em toda a rampa. O patamar de chegada tem mureta e parede no fim, e o terraço é cercado (barreira de 14), com abertura só por onde a rampa chega. A checagem por raios no Studio não achou fresta até a altura de pulo.
  - **Topo:** bloco do relógio com 4 mostradores (hora de Brasília), pináculos, campanário com sino que toca a cada chegada, e telhado cônico de ardósia com ponta dourada.
  - **Modelos e montagem:** o cone vem da Creator Store (malha 703458158), recriado por código. A torre fica de pé desde a partida do servidor (`TowerBuilder.get`).
  - **Empurrão:** sem componente para fora (`PushOutward = 0`, vertical 14).
- **5F.2 — cenário fantástico.**
  - **Modelos da Creator Store** (`TowerAssets`): só a malha e a textura, recriadas por código; os scripts e interfaces que vinham com os modelos ficam de fora. São eles: grifo sem textura como gárgula de pedra, tocha, árvore seca, árvore retorcida, vela e morcego.
  - **Gárgulas:** 5 na mureta do terraço e 2 nos pilares do portão da ilha.
  - **Tochas:** 16 com fogo na mureta da rampa, metade com luz.
  - **Ilha:** 6 árvores no gramado, chafariz com jato d'água e névoa fria embaixo.
  - **Velas e morcegos:** 20 velas flutuam ao longo da subida e 6 morcegos voam em volta do campanário. Quem anima é o cliente (`TowerAmbienceController`), só com a câmera perto da torre.
- **5F.3 — obstáculos novos.**
  - **Saco embaralhado:** os tipos saem de um saco (`RaceConfig.Hazards.Bag`), então os quatro aparecem na mesma corrida.
  - **Caldeirões** (`HazardProps`): rolam de lado junto com os barris, maiores e mais lentos, com a boca verde borbulhando.
  - **Engrenagens de latão** (`HazardGears`): caem girando, com sombra de aviso, no lugar dos caixotes, baús e quadros.
  - **Livros voadores** (`HazardBooks`): um bando cruza a rampa de dentro para fora na altura do peito, depois de um brilho roxo na coluna. Pulando, passa por cima.
  - **Ponteiro gigante** (`HazardClockHand`): na terceira volta, sai devagar da coluna (o aviso), varre o trecho rente ao chão e volta, alternando o sentido a cada 7 s, com um mostrador na coluna marcando o trecho.
  - **Atingido:** é empurrado só rampa abaixo (`RaceRules.downhillPush`) e fica tonto por 1 s, andando a 5, com estrelinhas na cabeça (`RaceDizzy`).
  - **Contas puras testadas no Lune:** `bandHits`, `handSweeps` e `downhillPush`.
  - **Studio:** os quatro tipos e o ponteiro apareceram na mesma corrida. O golpe e a tontura foram conferidos, e a velocidade volta a 16 depois.
- **Fechamento da 5F.**
  - **Vista da torre:** janelão de vidro com caixilhos de madeira, peitoril acima da vitrine de Puffs e placa "🕰️ TORRE DO RELÓGIO" na parede norte do Salão da Coleção. Pela janela se vê a torre inteira. O `BuildingDecor` ganhou vãos com peitoril (`DoorGap.sill`). A ponte coberta desceu para chegar por baixo da janela sem tapar a vista.
  - **Corrida com bots (Studio, rodada de 60 s):** os 3 bots subiram sem travar, num ritmo de cerca de 1,7 studs de altura por segundo, levando golpes e tontura pelo caminho. Chegaram a 90–103 dos 120. Na rodada normal (150 s), isso leva ao topo em uns 75 s.
  - **Tela final:** conferida, mostra "Ninguém chegou ao topo da torre".
- **Ilha no chão (out/2026).** Com o lado de fora (`docs/FASE_5G_LADO_DE_FORA.md`), a ilha deixou de flutuar: o terraço fica assentado no chão da floresta, sem o penhasco pendurado e sem a névoa fria de baixo. A ponte coberta ganhou pilares de pedra descendo até o chão.
