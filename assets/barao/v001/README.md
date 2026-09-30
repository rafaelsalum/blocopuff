# Barão v001

Modelo em pose neutra preparado a partir da ficha `docs/BARAO_MODELO_3D.html` e da capa `docs/capa-blocopuff.png`. As cópias usadas estão em `reference/`.

## Arquivos

- `barao.glb`: modelo glTF 2.0 binário, com o atlas PNG embutido.
- `textures/barao_basecolor.png`: o mesmo atlas em arquivo separado, RGB/sRGB, 1024 × 1024, sem transparência.
- `previews/`: vistas de frente, lado, cima, costas, perspectiva e prancha de conferência. Todas são renderizações da geometria e da textura lidas do GLB exportado.
- `pivots.json`: coordenadas das articulações e identificação dos dois olhos.
- `validation.json`: medidas, contagem de triângulos, verificações e hashes dos arquivos.
- `source/`: geração reproduzível e inspeção do arquivo. A geometria também pode ser editada em um editor que importe GLB.

## Conferência da ficha

| Requisito | Entrega |
| --- | --- |
| Formato | GLB + PNG |
| Peças | 12 objetos: Body, Head, EarL, EarR, Tongue, Tail, LegFL, LegFR, LegBL, LegBR e dois Eye |
| Orçamento | 4.400 triângulos no total; 1.420 em Head |
| Orientação | Y para cima; frente em −Z |
| Origem | Nó raiz Barao em (0, 0, 0), no chão entre as patas |
| Dimensões | Aproximadamente 3,50 de altura e 5,03 de comprimento; medidas exatas no relatório |
| Cabeça | 1,50 de altura, aproximadamente 43% da altura total |
| Pivôs | Posições de referência da ficha, preservadas nas translações dos nós; vértices locais relativos a cada pivô |
| Textura | Um atlas 1024 × 1024 compartilhado por todas as peças; um material opaco |
| Camisa | Verde, detalhes amarelos e bandeira nas costas e em ambos os lados |
| Pose | Quatro patas para baixo, orelhas caídas, boca aberta, língua para fora e rabo levantado |
| Pelo | Sem fios, camadas transparentes ou geometria de pelo |
| Luz | Sem iluminação ou sombras pintadas no atlas; a iluminação aparece apenas nas prévias |

As formas são uma interpretação simplificada da capa para o limite de polígonos da ficha. Não há armature nem animações exportadas: as peças rígidas separadas permitem a integração com a animação existente. Jaw e pálpebras, opcionais na ficha, não foram incluídos.

Os olhos têm exatamente o nome `Eye`. O lado está em `extras.side` no GLB e em `pivots.json`; programas que exijam nomes únicos podem renomear um deles durante a importação. Ambos devem continuar separados da cabeça para a futura mudança de cor.

## Etapa no Studio

Importe `barao.glb` pelo 3D Importer com a conta ou o grupo do jogo e preserve a separação das peças. Confira a orientação, escala, nomes e pivôs após importar; use `pivots.json` como referência se o importador centralizar as origens. O atlas também está separado para reassociação caso necessário. Salve o resultado como `.rbxm`.

A importação, o `.rbxm` e o teste das animações ficam pendentes. O modelo atual e os scripts do jogo não foram substituídos. A integração posterior ainda precisa associar cada peça ao grupo de animação correspondente, incluindo os olhos ao grupo Head, e conferir os atributos esperados pelo jogo.

## Reprodução e validação

Execute os arquivos abaixo com um Python que já tenha NumPy e Pillow:

```sh
python3 assets/barao/v001/source/build_model.py
python3 assets/barao/v001/source/inspect_model.py
```

O primeiro comando recria o GLB, o PNG e os pivôs desta versão. O segundo relê o GLB, verifica limites e estrutura e recria as imagens. Para mudanças futuras, copie a pasta para uma nova versão antes de executar os comandos.

A inspeção verifica nomes, quantidade de peças, índices, triângulos degenerados, orientação das faces, normais, UVs, atlas embutido, transparência, medidas e orçamento de triângulos. É uma verificação local própria, não uma certificação do importador Roblox. O JSON Rojo e o build do projeto também foram verificados separadamente.

Referência do formato: [especificação glTF 2.0 da Khronos](https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc).
