# Barão v002

Revisão da modelagem com base no ícone `assets/icon-blocopuff.png` e na capa `assets/blocopuff-01.png`. A versão anterior permanece em `v001`.

## O que mudou

- Orelhas com base estreita, curvatura para a frente e volume maior na parte caída.
- Focinho com mais segmentos, nariz triangular com narinas, bochechas e contorno do sorriso com profundidade.
- Língua curva, ponta arredondada e sulco central.
- Faixa clara que continua sobre a cabeça, sobrancelhas e dois reflexos em cada olho.
- Patas com pé, tornozelo e ombro contínuos, além das mangas da camisa.
- Camisa com tronco arredondado e afunilado, faixas amarelas e bandeiras nas costas e nos dois lados.
- Textura de pelo curto e tecido, com mapas de normal e rugosidade. Olhos e nariz têm mais brilho que o pelo e a camisa.

É um personagem estilizado para jogo, baseado nas formas da capa. A pose neutra em quatro patas e o limite de polígonos seguem a ficha. Iluminação, sombras e cenário da capa não fazem parte da textura.

## Entrega

| Arquivo | Uso |
| --- | --- |
| `barao.glb` | Modelo 3D com cor, normal e ORM embutidos |
| `textures/barao_basecolor.png` | Atlas de cor, sRGB |
| `textures/barao_normal.png` | Relevo fino da superfície, espaço linear |
| `textures/barao_roughness.png` | Rugosidade em tons de cinza, espaço linear |
| `textures/barao_orm.png` | Mapa empacotado do GLB: R=255, G=rugosidade, B=0, sem metal |
| `pivots.json` | Pivôs e identificação dos lados dos olhos |
| `validation.json` | Medidas, contagens, verificações e hashes dos arquivos |
| `previews/` | Frente, lado, cima, costas, perspectiva e prancha |
| `reference/` | Cópias das referências usadas e da ficha técnica |
| `source/` | Fontes reproduzíveis da malha, texturas, exportação e conferência |

As prévias foram renderizadas a partir do GLB exportado. A luz e o chão pertencem à cena de conferência e não são objetos do modelo.

## Especificações verificadas

- 12 objetos: Body, Head, EarL, EarR, Tongue, Tail, LegFL, LegFR, LegBL, LegBR e dois objetos chamados Eye.
- 4.884 triângulos no total, abaixo do limite de 5.000; 1.736 na peça Head.
- Altura de 3,50 unidades e comprimento de aproximadamente 4,82 unidades.
- Y para cima, focinho para −Z e origem geral em (0, 0, 0), no chão entre as patas.
- Um conjunto de atlas de 1024 × 1024 para todas as peças, com um material opaco e sem fios de pelo em geometria.
- Pivôs locais nas articulações. Orelhas e língua têm coordenadas ajustadas à nova malha, registradas em `pivots.json`.
- Boca aberta, língua para fora, patas para baixo e rabo levantado.

Não há esqueleto ou clipes de animação no arquivo. São peças rígidas separadas, conforme a ficha. Jaw e pálpebras são opcionais e não foram incluídos.

## Importação e integração

Importe `barao.glb` pelo Studio, preservando as peças separadas. Confira escala, orientação, nomes, pivôs e texturas. Alguns importadores renomeiam nomes duplicados; os dois olhos devem se chamar Eye no resultado e continuar separados. Seus lados também estão em `pivots.json`.

Os PNGs estão separados caso seja necessário reassociar as texturas. Para um campo de rugosidade, use `barao_roughness.png`; `barao_orm.png` é o mapa empacotado usado pelo material glTF.

A importação no Studio, a exportação `.rbxm` e a conferência das animações não foram executadas. A integração com o jogo ainda precisa usar as coordenadas desta versão, vincular os olhos à animação da cabeça e manter a troca de cor dos olhos quando o Barão fica bravo. O Barão atual do jogo não foi substituído.

## Reproduzir esta versão

Use um Python com NumPy e Pillow já disponíveis:

```sh
python3 assets/barao/v002/source/build_model.py
python3 assets/barao/v002/source/inspect_model.py
```

O primeiro comando gera malha, mapas e pivôs. O segundo relê o GLB e verifica nomes, índices, faces degeneradas, orientação das faces, normais, UVs, dimensões, contagens, material, pivôs e correspondência entre os mapas embutidos e externos. Depois renderiza as vistas.

As verificações são locais; não equivalem a um teste no importador do Studio. O JSON Rojo e o build do projeto foram conferidos separadamente.

Para a próxima revisão, crie `v003` e preserve `v001` e `v002`. Não execute uma geração modificada sobre uma revisão já aprovada.
