# Fase 2 — Segredos, Cofre & Barão

**Entrega:** a arena ganha identidade própria, exploração, risco/recompensa e o mascote Barão.  
**Dependência:** Fase 1 estável.

---

## Resultado esperado

A partida deixa de ser apenas combate sobre blocos. Jogadores passam a descobrir rotas, usar corredores para voltar entre andares, disputar o cofre, esconder-se em Tocas e lidar com Barão.

A fase deve gerar histórias memoráveis mesmo sem progressão persistente.

---

## Escopo

### 1. Corredores secretos

- corredores separados fisicamente/conceitualmente do cofre;
- conectar andar superior e inferior;
- permitir subida e descida;
- entradas inicialmente ocultas;
- passagem existe mesmo quando não revelada;
- jogador veterano pode atravessar conhecendo o local.

### 2. Quadros reveladores

- múltiplos quadros decorativos;
- quadro correto por andar revela entrada daquele andar;
- revelação vale para todos na rodada;
- superior e inferior independentes;
- feedback visual/sonoro;
- registrar descobridor.

### 3. Tocas Seguras

- nichos dentro dos corredores;
- capacidade de 1 jogador;
- proteção contra Barão;
- sem proteção contra Puffador de outros jogadores;
- knockback pode expulsar ocupante;
- desenho deve evitar camping permanente.

### 4. Barão

Identidade:
- vira-lata caramelo;
- camisa com cores do Brasil;
- personagem original;
- mascote cômico.

Comportamento:
- patrulha/perseguição nos corredores;
- não usa dano;
- contato aplica empurrão para expulsar;
- pode ser pulado;
- respeita Tocas;
- sons engraçados aleatórios no contato;
- áudio espacial como principal pista;
- sem minimapa/indicador preciso de distância.

### 5. Cofre

- separado das entradas secretas;
- objetivo de risco/recompensa;
- alerta importante ao ser aberto;
- relação clara com ativação/estado de Barão;
- disputa entre jogadores;
- estatísticas próprias.

### 6. Puffador do Cofre

- quebra dois blocos por disparo;
- knockback diferenciado sujeito a balanceamento;
- modo Construir;
- quantidade limitada de construções;
- construção somente em locais/regras válidos;
- não permitir prender jogadores de forma abusiva;
- não permitir reconstrução infinita.

### 7. Alertas e áudio

Notification Manager da Fase 1 deve receber prioridades para:
- passagem descoberta;
- cofre aberto;
- Barão acordou;
- Puffador especial obtido;
- evento crítico do corredor.

Áudio:
- direção e distância percebidas;
- tensão crescente;
- sons não podem tornar localização perfeita.

### 8. Momentos Puff iniciais

Detectar e apresentar alguns eventos:
- Escapou do Barão;
- Cofre Conquistado;
- Volta por Cima;
- descoberta secreta.

Manter mensagens breves.

---

## Fora de escopo

- Puffdex persistente;
- XP/nível;
- ranking global;
- Party;
- trading;
- loja;
- temporadas;
- Live Control;
- monetização.

---

## Telemetria

- entrada em corredor;
- andar de entrada/saída;
- passagem revelada;
- primeiro descobridor;
- tempo até primeira descoberta;
- Toca ocupada;
- tempo em Toca;
- Barão avistado/encontro;
- contato com Barão;
- fuga/pulo bem-sucedido;
- expulsão;
- cofre aberto;
- jogador do cofre;
- uso do Puffador especial;
- blocos construídos;
- abandono após encontro com Barão.

---

## Critérios de aceite

- corredores conectam corretamente os dois andares;
- entradas podem ser usadas antes de reveladas;
- revelar superior não revela inferior;
- Barão não causa dano tradicional;
- Barão consegue expulsar jogadores;
- é possível evitá-lo com habilidade;
- Toca protege de Barão e não de outros jogadores;
- somente um jogador ocupa uma Toca;
- cofre não é confundido com corredor;
- Puffador especial quebra dois blocos conforme regra;
- modo Construir é limitado e validado;
- áudio permite tensão sem entregar posição exata;
- alertas não se sobrepõem;
- partida continua compreensível com todos os sistemas ativos.

---

## Testes manuais prioritários

1. Entrar em passagem ainda oculta.
2. Revelar somente andar superior.
3. Revelar somente andar inferior.
4. Dois jogadores tentando a mesma Toca.
5. Jogador em Toca atingido por Puffador.
6. Barão tentando alcançar jogador protegido.
7. Pular Barão.
8. Barão tocando jogador em diferentes geometrias.
9. Abrir cofre.
10. Disputar cofre com vários jogadores.
11. Construir bloco em situações válidas.
12. Tentar construir em posições inválidas.
13. Recuperar rota usando construção.
14. Validar áudio com fones e alto-falante mobile.
15. Testar corredores lotados.

---

## Perguntas do playtest

- jogadores entendem que corredores e cofre são coisas diferentes?
- descobrir uma passagem parece especial?
- Barão é engraçado e tenso, não irritante?
- jogadores aprendem a usar som?
- Tocas geram jogadas ou camping?
- Puffador do Cofre é desejável sem ser vitória automática?
- construção gera criatividade ou exploits?
- corredores aumentam chance de recuperação após cair?

---

## Gate para Fase 3

Avançar quando Barão, corredores e cofre forem reconhecidos pelos jogadores como parte da identidade do BlocoPuff, sem comprometer clareza do core.
