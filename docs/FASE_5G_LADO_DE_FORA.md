# Fase 5G — Lado de fora do Casarão

**Entrega:** o lado de fora do Casarão deixa de ser céu vazio. O Casarão, a Torre do Relógio e a Ala do Assassinato ficam assentados num chão realista, no meio de uma floresta de pinheiros, como um castelo de escola de magia nas Terras Altas (só o estilo). Nada flutua no céu. O céu segue a hora de Brasília: dia, tarde e noite.

---

## Problema

Avaliação no Studio em 24/10/2026:

1. **Tudo flutua.** O Casarão, a Arena e a Torre são blocos soltos no céu, sem terreno nenhum. A ilha da Torre é um disco de pedra com um penhasco pendurado.
2. **Céu parado.** É sempre 14h30, com o mesmo céu claro.

## Escopo

- **Chão de terreno:** gramado plano em volta de cada construção, morros suaves, manchas de folhas e de terra, pedra nas encostas íngremes.
- **Lago** a leste do Casarão, visto das janelas da ala leste e da Torre.
- **Montanhas** em anel em volta de tudo, com cristas irregulares e pedra no alto.
- **Floresta de pinheiros** mais fechada perto do Casarão, rala nas encostas, com clareiras e algumas árvores secas, e sem árvore no gramado das construções, na água, em encosta íngreme ou acima da linha das árvores.
- **Postes de lampião antigos** de ferro em volta do Casarão e no portão da Torre, acesos à noite.
- **Céu na hora de Brasília (UTC−3):** amanhecer rosado, dia claro, tarde dourada, pôr do sol e noite com luar, estrelas e névoa azulada. Todos no servidor veem a mesma hora. A luz de dentro do Casarão não muda: lá dentro quem ilumina são os lustres.

Fora do escopo: a fachada do Casarão, que continua sendo a caixa de paredes de hoje.

## Decisões

- **Hora real de Brasília**, e não um ciclo acelerado nem a hora de cada aparelho.
- **Pinheiros da Creator Store**, recriados por código só com malha e textura, como nos modelos da Torre (`TowerAssets`). O SurfaceAppearance não pode ser criado por script, então ficou só a textura de cor. Dos pacotes testados, só as 11 ponderosas ficaram boas assim: os abetos ficavam com folhas opacas e os carvalhos sem textura nas folhas. O pacote de rochas veio com scripts escondidos e foi descartado: as pedras são do próprio terreno.

## Arquitetura técnica

- `config/OutdoorConfig` (shared): números do terreno, da floresta e os momentos do dia. Só números (sem tipos do Roblox).
- Regras puras em `server/data`, testadas no Lune:
  - `TerrainShape`: altura e material de cada ponto (morros, lago, montanhas) e o chão plano em volta das construções, que volta ao natural aos poucos. Também diz onde não entra terreno (o poço da Arena, abaixo do chão).
  - `ForestPlan`: onde nasce cada árvore, com semente fixa (todo servidor monta a mesma floresta).
  - `DayCycle`: a hora de Brasília e a luz de cada hora, passando aos poucos de um momento do dia para o outro.
- Serviços:
  - `OutdoorService`: lê onde estão o prédio da Arena, o Casarão, o Saguão e a ponte da Torre, a ilha e a Ala do Assassinato, monta o terreno (`OutdoorTerrain`) e planta a floresta (`ForestAssets`). Roda em segundo plano depois que a Torre fica pronta. É só cenário: a partida não espera por ele.
  - `OutdoorLamps`: monta os postes e os acende e apaga pela hora (`LampLayout`, puro, diz onde ficam e quando acendem).
  - `DayCycleService`: a cada 5 s ajusta o sol (`ClockTime`), a luz do sol, a luz ambiente de fora e a névoa (`Atmosphere`). Para testar, o atributo `ClockOverride` (0 a 24) no `Lighting` fixa a hora.

## Andamento

**Entregue (out/2026).**

- **Terreno:** quadrado de 2.300 studs em volta do mapa, em voxels de 4, só com uma casca embaixo da superfície. Fica pronto em cerca de 5,5 s, em pedaços, com o servidor respirando entre eles.
  - O chão fica em y = 118,6, logo abaixo do porão da ala leste. Ao redor da ilha da Torre ele sobe até o gramado dela, e no vale da Ala do Assassinato desce até a laje do térreo dela.
  - O lago fica em (480, 250), com raio de 150 e margem irregular de terra, e as montanhas sobem de 760 a 1.080 studs do centro.
- **Floresta:** 1.166 árvores (cerca de 2.400 peças), plantadas em cerca de 10 s, sem colisão nem raycast. Só as que ficam até 450 studs do Casarão fazem sombra. 4% são árvores secas.
- **Torre:** a ilha deixou de flutuar. O penhasco pendurado e a névoa de baixo saíram, e a ponte coberta ganhou pilares de pedra.
- **Céu:** oito momentos do dia em `OutdoorConfig.DayCycle.Keys`. O céu do place já escurece com estrelas à noite e foi mantido.
- **Noite mais clara e lampiões (out/2026).** A primeira noite ficou escura demais para ver o mapa.
  - A noite agora tem luar mais forte (luz do sol 1,2 e luz ambiente de fora azulada, 140, 150, 185) e névoa mais clara, para as árvores e o chão aparecerem.
  - **Lampiões:** 41 postes antigos com base de pedra, poste de ferro preto e lanterna de vidro com chama. Ficam em volta do Casarão e da Arena, a 12 studs das paredes e a no máximo 30 entre si, menos no caminho da ponte. Há também um de cada lado do portão da Torre.
  - Cada lampião tem uma luz quente (alcance 30, sem sombra). Eles acendem às 17h36 e apagam às 6h24, pela hora de Brasília.
- **Testes no Lune:** `TerrainShape` (24 checagens), `ForestPlan` (13), `DayCycle` (17) e `LampLayout` (12).
- **Studio:**
  - Vistas conferidas às 10h, 12h, 17h36 e 21h. Na noite nova dá para ver o chão, as árvores, a Torre e a ponte, com as poças de luz dos lampiões.
  - Os lampiões ficam apagados ao meio-dia e às 6h30, e acesos às 18h e na hora real (20h40).
  - Pela janela do Saguão da Torre se vê a floresta.
  - A leitura dos voxels não achou terreno dentro da Arena, do Casarão nem da área da Ala do Assassinato. Sem erros no console.

**Pendências:** o desempenho em celular com a floresta inteira ainda precisa de um playtest, e ainda falta jogar uma partida de Assassino com o terreno em volta da Ala.
