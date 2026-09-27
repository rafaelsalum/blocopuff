# Fase 4 — Puffdex, Recompensas & Social

**Entrega:** criar o principal loop de coleção e aumentar o motivo para voltar/jogar com amigos.  
**Dependência:** persistência da Fase 3 confiável.

---

## Resultado esperado

Além de competir, o jogador passa a querer:
- completar coleção;
- encontrar Puffs raros;
- equipar identidade própria;
- cumprir desafios;
- voltar em outro dia;
- mostrar conquistas;
- jogar com amigos.

---

## Escopo

### 1. Puffdex

Criar catálogo persistente de Puffs.

Cada entrada deve suportar:
- ID;
- nome;
- raridade;
- origem;
- desbloqueado/não desbloqueado;
- data;
- quantidade se aplicável;
- equipado;
- metadata para trading futuro.

### 2. Primeira coleção

Lançar conjunto inicial enxuto e de qualidade.

Categorias:
- comuns;
- raros;
- épicos;
- lendários.

Incluir Puffs conquistáveis por gameplay, incluindo pelo menos um relacionado ao Barão.

### 3. Equipamento cosmético

- selecionar Puff;
- visualizar;
- usar durante partida;
- efeito não altera hitbox, dano, knockback, cadência ou alcance;
- efeitos não podem prejudicar visibilidade competitiva.

### 4. Puff Machine

- ticket por gameplay/recompensas;
- animação de revelação;
- tabela de raridade clara;
- sem vantagem competitiva;
- evitar estrutura predatória;
- observar políticas Roblox antes da publicação.

### 5. Desafios

Desafios diários/recorrentes focados em gameplay:
- Barão;
- corredores;
- blocos;
- cofre;
- Top 3;
- acertos;
- exploração.

Evitar "fique online X minutos" como principal desenho.

### 6. Retorno diário

- recompensa de retorno;
- streak amigável;
- não punir excessivamente ausência;
- recompensas principalmente cosméticas/tickets/moeda não competitiva.

### 7. Conquistas secretas

Adicionar conjunto inicial de segredos.

Exemplos:
- entrar em passagem não revelada;
- pular Barão várias vezes;
- sobreviver em situação extrema;
- segredo do lobby.

### 8. Lobby expandido

Adicionar/organizar:
- Puffdex;
- Puff Machine;
- Hall da Fama;
- área de treino;
- exibição de cosméticos;
- Barão não hostil;
- segredos;
- preparação para loja.

### 9. Party / amigos

Primeira versão:
- formar grupo;
- convidar;
- tentar manter grupo na mesma partida;
- replay em conjunto;
- feedback quando não houver capacidade.

Definir limite de Party compatível com sala de 12.

### 10. Espectador social

- troca de câmera;
- reações discretas;
- sem interferência competitiva;
- recompensa de conclusão quando aplicável.

### 11. Trading — preparação, não ativação

O modelo de inventário deve suportar ownership futuro.

**Trading permanece desligado.**

---

## Fora de escopo

- trading público;
- monetização agressiva;
- temporadas completas;
- eventos globais;
- painel Live Control;
- bundles pagos finais.

---

## Telemetria

- Puff desbloqueado;
- raridade;
- origem;
- Puff equipado;
- abertura do Puffdex;
- progresso de coleção;
- tickets ganhos/gastos;
- Puff Machine;
- desafios aceitos/concluídos;
- streak;
- Party criada;
- convite;
- partida com Party;
- replay com Party;
- uso de espectador;
- reações;
- D1/D7/D28.

---

## Critérios de aceite

- Puffdex persiste corretamente;
- cosméticos não alteram poder;
- itens não duplicam por reconexão;
- recompensas são concedidas uma única vez;
- Puff Machine não utiliza mecânica paga inadequada;
- desafios validam progresso no servidor;
- Party consegue manter amigos juntos em condições normais;
- falha de matchmaking é comunicada;
- espectador não interfere na partida;
- trading está tecnicamente previsto, mas inacessível;
- lobby continua performático em mobile.

---

## Testes manuais prioritários

1. Desbloquear cada raridade.
2. Reconectar após desbloqueio.
3. Equipar/trocar Puff.
4. Verificar efeito em outros clientes.
5. Recompensa duplicada.
6. Puff Machine com múltiplas execuções.
7. Desafio diário.
8. Streak com mudança de dia.
9. Party de 2, 4 e grupo maior.
10. Servidor quase cheio com Party.
11. Replay em Party.
12. Espectador/reactions.
13. Inventário grande simulado.
14. Mobile no lobby expandido.

---

## Perguntas do playtest

- jogadores entendem o Puffdex?
- existe um Puff que eles realmente desejam?
- raridade parece especial?
- recompensas fazem querer outra partida?
- Party aumenta tempo de sessão?
- lobby é interessante sem ficar confuso?
- crianças conseguem entender como obter itens sem textos longos?

---

## Gate para Fase 5

Avançar quando coleção, recompensas e social aumentarem retorno sem prejudicar o core competitivo.
