# Fase 5 — LiveOps, Temporadas & Monetização

**Entrega:** transformar BlocoPuff em produto vivo, atualizável e sustentável.  
**Dependência:** core, persistência, coleção e social estáveis.

---

## Resultado esperado

A equipe consegue operar o jogo ao longo do tempo com temporadas, eventos, conteúdo temático e monetização cosmética, sem precisar alterar manualmente cada servidor e sem comprometer justiça competitiva.

---

## Escopo

### 1. Temporadas

Estrutura para:
- identificador de temporada;
- início/fim;
- conteúdo ativo;
- ranking sazonal;
- desafios;
- recompensas;
- cosméticos;
- narrativa/tema;
- preservação de carreira permanente.

Primeira proposta:
**Season 1 — O Despertar do Barão**

### 2. Ranking sazonal

- separado da carreira;
- reset/arquivamento controlado;
- recompensas cosméticas/status;
- Hall da Fama sazonal;
- histórico quando viável.

### 3. Live Control

Painel/fluxo administrativo seguro para contas autorizadas.

Ações previstas:
- ativar/desativar evento;
- agendar evento;
- mensagem global controlada;
- selecionar modificadores;
- encerrar evento;
- auditoria.

Nunca confiar apenas em UI cliente para autorização.

### 4. Eventos de partida

Catálogo inicial possível:
- Barão em Dobro;
- Super Knockback;
- Chuva de Blocos;
- Puff Party;
- Cofre Maluco;
- Blackout;
- Turbo Puff;
- Disco Puff.

Cada evento precisa declarar:
- regras;
- duração;
- impacto em ranking;
- recompensas;
- compatibilidade com matchmaking.

### 5. Eventos globais

- anúncio coordenado;
- contagem regressiva;
- ativação em servidores;
- entrada de novos servidores durante evento;
- término consistente;
- fallback se comunicação global falhar.

### 6. Eventos de calendário

Preparar conteúdo sazonal:
- Halloween;
- Natal;
- aniversário BlocoPuff;
- temas próprios adicionais.

Não depender de evento real para manter o core divertido.

### 7. Criadores/admins

Presença de conta autorizada pode:
- exibir identificação especial;
- ativar experiências/eventos permitidos;
- conceder conquista/recompensa conforme regra global;
- nunca receber poder competitivo injusto por ser admin.

### 8. Loja

Monetização focada em:
- skins do Puffador;
- Puffs/efeitos elegíveis;
- emotes;
- comemorações;
- trilhas;
- títulos/tags;
- bundles;
- cosméticos sazonais.

### 9. Regra anti-pay-to-win

Proibido vender:
- força;
- knockback superior;
- vidas competitivas;
- alcance;
- cadência;
- imunidade;
- vantagem decisiva no cofre/corredores.

### 10. Trading — avaliação para ativação

Somente considerar ativação após:
- inventário estável;
- logs;
- ownership confiável;
- proteção contra duplicação;
- confirmação bilateral;
- limites;
- tratamento de fraude;
- revisão das políticas atuais do Roblox;
- economia com quantidade suficiente de itens.

Ativação de trading pode ser uma entrega própria posterior, mesmo estando planejada aqui.

### 11. Economia

Definir:
- moedas/tickets;
- fontes;
- sinks;
- preços;
- raridade;
- inflação;
- duplicatas;
- recompensas sazonais;
- política de itens limitados.

Evitar criar escassez artificial prejudicial ou mecanismos predatórios.

---

## Fora de escopo desta entrega inicial

- vender poder;
- trading sem auditoria;
- eventos administrativos sem autorização robusta;
- reset de progresso permanente por temporada;
- mecânicas pagas aleatórias sem revisão específica de políticas.

---

## Telemetria

LiveOps:
- participação em evento;
- servidores ativos;
- conclusão;
- abandono;
- replay;
- efeito em CCU/sessão;
- retorno após evento.

Temporada:
- progressão;
- desafios;
- ranking;
- recompensas;
- retorno semanal.

Economia:
- moeda criada/gasta;
- ticket;
- compra;
- equip;
- conversão;
- itens mais/menos usados;
- concentração de riqueza virtual.

Monetização:
- conversão;
- ARPPU/receita conforme analytics disponível;
- compra por categoria;
- retenção de pagantes e não pagantes;
- sinais de impacto negativo na experiência.

---

## Critérios de aceite

- temporada pode mudar sem apagar carreira;
- ranking sazonal é isolado do ranking permanente;
- evento global tem início/fim consistente;
- servidor que inicia durante evento recebe estado correto;
- somente admins autorizados controlam LiveOps;
- ações administrativas são auditáveis;
- loja não altera força competitiva;
- compra é entregue de forma idempotente;
- falha de compra não duplica item;
- conteúdo sazonal pode ser desativado com segurança;
- eventos não quebram partidas em andamento;
- políticas atuais do Roblox são revisadas antes de ativar monetização/trading relevante.

---

## Testes manuais prioritários

1. Iniciar/finalizar temporada em ambiente de teste.
2. Virada de temporada com jogador online.
3. Ranking sazonal.
4. Evento global com múltiplos servidores.
5. Servidor iniciado no meio do evento.
6. Admin autorizado/não autorizado.
7. Encerrar evento abruptamente.
8. Dois eventos incompatíveis.
9. Compra bem-sucedida.
10. Compra interrompida/repetida.
11. Reconectar após compra.
12. Conteúdo sazonal expirado.
13. Economia com contas simuladas.
14. Performance mobile durante eventos visuais.

---

## Perguntas do playtest/operação

- eventos fazem jogadores chamar amigos?
- temporada cria objetivo sem virar obrigação?
- cosméticos são desejáveis?
- loja é compreensível?
- eventos alteram o jogo de forma divertida sem destruir habilidade?
- jogadores retornam em dias de evento?
- quais conteúdos geram clipes e conversa?

---

## Pós-Fase 5

A partir daqui, o roadmap deve ser orientado por dados e feedback.

Possíveis entregas independentes:
- Trading;
- novos mapas;
- novos tipos de Puff;
- novos segredos;
- novos comportamentos de Barão;
- torneios;
- clans/equipes, se fizer sentido;
- eventos colaborativos;
- ferramentas de criação/social adicionais.

Nenhuma dessas features deve ser assumida automaticamente. Cada uma precisa justificar impacto no core loop, retenção, social ou sustentabilidade.
