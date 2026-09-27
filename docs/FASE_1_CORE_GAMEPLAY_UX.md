# Fase 1 — Core Gameplay & UX

**Entrega:** BlocoPuff divertido de jogar repetidamente mesmo sem metaprogressão.  
**Objetivo:** transformar o protótipo atual em um core competitivo sólido e publicável.

---

## Resultado esperado

Ao final desta fase, 2–12 jogadores devem conseguir entrar em rodadas rápidas, movimentar-se e mirar confortavelmente, usar o Puffador para destruir blocos e empurrar adversários, utilizar Segunda Chance, chegar ao Caos Final e receber um resultado claro.

Se essa versão não for divertida sem Puffdex, Barão, loja ou ranking global, não avançar por inércia: corrigir o core.

---

## Escopo

### 1. Estrutura da rodada

- preparar partida para até 12 jogadores;
- duração alvo ~3:30 de gameplay;
- transição/resultado curta;
- manter estados claros: Waiting, Countdown, Active, Ending;
- adicionar subestado/evento de Caos Final;
- parâmetros configuráveis para playtest.

### 2. Arena de dois níveis

- consolidar os dois andares como espaços competitivos;
- queda superior → inferior não elimina;
- queda definitiva inferior aciona Segunda Chance ou eliminação;
- spawns distribuídos;
- leitura visual clara;
- validar densidade com 2, 4, 8 e 12 jogadores.

### 3. Puffador real

Evoluir o protótipo existente:

- impacto em bloco válido destrói/desativa o bloco;
- impacto em jogador aplica knockback;
- sem HP/dano tradicional;
- feedback audiovisual satisfatório;
- parâmetros de força/cadência/alcance configuráveis;
- manter validação autoritativa no servidor.

### 4. Segunda Chance

- uma Segunda Chance por jogador;
- primeira queda definitiva retorna o jogador;
- feedback de "Última Vida";
- respawn seguro;
- Segunda Chance desativada no Caos Final;
- segunda queda definitiva elimina.

### 5. Caos Final

- iniciar aproximadamente nos últimos 30 s;
- comunicar claramente;
- aumentar risco;
- impedir final arrastado;
- definir degradação inicial simples e legível da arena;
- não introduzir Barão nesta fase.

### 6. Controles e câmera

Prioridade alta.

Mobile:
- movimento confortável;
- câmera/mira responsiva;
- botão Puff;
- pulo;
- mira central pequena;
- não cobrir área crítica da tela.

Desktop:
- mouse/câmera previsíveis;
- disparo responsivo;
- mira consistente.

Gamepad:
- input equivalente e legível.

Avaliar assistência leve de mira mobile somente se playtest demonstrar necessidade.

### 7. HUD e Notification Manager

Refinar HUD existente.

Criar especificação para:
- cronômetro;
- participantes restantes;
- Segunda Chance/Última Vida;
- Caos Final;
- eliminação;
- vencedor;
- fila de alertas;
- prioridade;
- duração;
- prevenção de sobreposição.

### 8. Pós-partida básico

Mostrar:
- vencedor;
- posição;
- blocos destruídos;
- eliminações/derrubadas;
- botão/fluxo claro para próxima rodada.

Ainda sem XP persistente.

---

## Fora de escopo

- Barão;
- corredores secretos;
- quadros;
- cofre especial;
- Puffador de construção;
- Puffdex;
- níveis persistentes;
- ranking global;
- Party;
- trading;
- loja;
- temporadas;
- eventos globais;
- monetização.

---

## Regras de produto

- servidor continua autoridade;
- nenhuma feature desta fase depende de compra;
- não adicionar complexidade de progressão para mascarar core fraco;
- valores de balanceamento devem ser configuráveis;
- UI mobile é requisito, não adaptação posterior.

---

## Telemetria mínima

Registrar:
- início/fim de rodada;
- quantidade de participantes;
- dispositivo;
- disparos;
- acertos em jogador;
- acertos em bloco;
- blocos destruídos;
- quedas por andar/local;
- Segunda Chance usada;
- eliminação;
- início do Caos Final;
- vencedor;
- abandono;
- rematch;
- duração.

---

## Critérios de aceite

- rodada funciona repetidamente sem resíduos entre partidas;
- 12 jogadores são suportados no design;
- Puffador quebra blocos válidos;
- Puffador empurra jogadores de forma consistente;
- não existe dano tradicional como condição de eliminação;
- primeira queda definitiva usa Segunda Chance;
- queda após Segunda Chance elimina;
- Caos Final desativa Segunda Chance;
- HUD não apresenta alertas sobrepostos;
- mira/controles são utilizáveis em mobile;
- resultado é apresentado sem ambiguidade;
- servidor valida ações críticas;
- versão pode ser publicada para playtest.

---

## Testes manuais prioritários

1. Rodadas consecutivas com 2 jogadores.
2. Teste com 4/8/12 jogadores.
3. Queda do superior para inferior.
4. Primeira queda definitiva.
5. Segunda queda.
6. Queda durante Caos Final com Segunda Chance ainda disponível.
7. Disparo contra jogador próximo/distante.
8. Disparo contra blocos.
9. Spam de disparos.
10. Entrada tardia.
11. Saída durante rodada.
12. Mobile horizontal.
13. Desktop.
14. Gamepad.
15. HUD com vários eventos próximos.
16. 10+ rodadas consecutivas para detectar vazamentos/resíduos.

---

## Perguntas que o playtest deve responder

- 3:30 é divertido ou longo?
- 12 jogadores é caos saudável ou excessivo?
- knockback é previsível?
- destruir blocos é satisfatório?
- Segunda Chance reduz frustração?
- Caos Final gera clímax?
- mobile parece um jogo deliberadamente projetado para toque?
- quem perde quer apertar "jogar novamente"?

---

## Gate para Fase 2

Avançar quando o core for compreensível, responsivo e divertido sem depender de progressão externa.
