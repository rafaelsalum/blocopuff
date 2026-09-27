# Fase 3 — Progressão & Competição

**Entrega:** cada partida passa a contribuir para identidade, carreira e competição persistente.  
**Dependência:** core e sistemas de mapa estabilizados.

---

## Resultado esperado

O jogador deve terminar uma partida sabendo:
- como foi;
- o que conquistou;
- quanto progrediu;
- qual objetivo pode perseguir na próxima.

Nenhuma progressão pode aumentar força competitiva paga ou tornar novatos inviáveis.

---

## Escopo

### 1. Perfil persistente

Definir perfil com:
- partidas;
- vitórias;
- Top 3;
- eliminações;
- blocos destruídos;
- cofre;
- Barão;
- outras estatísticas aprovadas;
- XP;
- nível;
- prestígio futuro.

Dados devem ser versionáveis e seguros.

### 2. XP

Fontes possíveis:
- concluir partida;
- colocação;
- vitória;
- eliminações;
- blocos;
- descoberta;
- cofre;
- fuga do Barão;
- Momentos Puff;
- desafios futuros.

Aplicar limites/normalização para evitar farming trivial.

### 3. Nível BlocoPuff

- progressão visível;
- curva configurável;
- não altera poder;
- feedback de level-up;
- perfil exibe nível.

### 4. Prestígio

Preparar e, se validado, liberar Prestígio ao teto definido.

- status visual;
- títulos/cosméticos futuros;
- não aumenta força.

### 5. Resultado avançado

Pódio/destaques:
- vencedor;
- Demolidor;
- desempenho no cofre;
- eliminações;
- fugas do Barão;
- outras categorias.

Evitar premiar comportamento antijogo.

### 6. Ranking global

Categorias iniciais recomendadas:
- vitórias;
- eliminações;
- blocos destruídos;
- cofres conquistados.

Não criar dezenas de rankings no início.

### 7. Hall da Fama

No lobby:
- painéis legíveis;
- atualização controlada;
- avatar/nome quando apropriado;
- destaque para Lenda do BlocoPuff;
- espaço preparado para ranking sazonal futuro.

### 8. Proteção de integridade

- servidor calcula estatísticas;
- detectar valores impossíveis;
- não confiar no cliente;
- logs para alterações relevantes;
- estratégia para correções administrativas futuras.

---

## Fora de escopo

- trading;
- Party completa;
- Puffdex final;
- loja paga;
- temporadas completas;
- Live Control;
- eventos globais.

---

## Telemetria

- XP ganho por fonte;
- XP médio por partida;
- distribuição de nível;
- tempo por nível;
- frequência de level-up;
- abertura do ranking;
- interação com Hall da Fama;
- replay após level-up;
- retenção D1/D7;
- estatísticas por faixa de nível;
- correlação entre nível e vitória para identificar desequilíbrio.

---

## Critérios de aceite

- progresso persiste entre sessões;
- nenhuma ação do cliente concede XP diretamente;
- XP não pode ser duplicado ao reconectar;
- nível é calculado de forma determinística;
- resultado apresenta destaques corretos;
- rankings refletem dados persistentes;
- Hall da Fama não trava o lobby;
- estatísticas não são perdidas entre updates compatíveis;
- novato e veterano têm mesma força-base competitiva;
- existe procedimento/documentação para dados inválidos.

---

## Testes manuais prioritários

1. Ganhar/perder partidas e conferir estatísticas.
2. Reconectar após ganhar XP.
3. Sair durante Ending.
4. Queda de servidor/sessão interrompida.
5. Level-up.
6. Múltiplos level-ups próximos.
7. Ranking com contas de teste.
8. Empate de estatística.
9. Valores anormais/exploit simulado.
10. Migração de versão de perfil.
11. 10+ partidas consecutivas.
12. Comparar resultado local com persistência global.

---

## Perguntas do playtest

- progresso parece rápido demais ou lento?
- perder ainda gera sensação de avanço?
- destaques pós-partida são valorizados?
- jogadores consultam Hall da Fama?
- ranking motiva replay sem gerar frustração?
- alguma métrica incentiva farming em vez de jogar para vencer?

---

## Gate para Fase 4

Avançar quando progressão e rankings forem confiáveis, compreensíveis e resistentes a duplicação/exploit básico.
