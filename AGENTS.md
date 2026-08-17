# Instruções para agentes

## Linguagem e comunicação

- Use Luau como linguagem principal e adicione `--!strict` a todos os scripts e módulos.
- Escreva código, nomes de arquivos, módulos, variáveis e funções em inglês.
- Documentação e comunicação podem ser escritas em português.

## Arquitetura

- Mantenha a separação entre código de servidor (`src/server`), cliente (`src/client`) e compartilhado (`src/shared`).
- O servidor deve ser autoritativo para o estado da partida, disparos, blocos e eliminações.
- Nunca confie em dados enviados pelo cliente sem validação no servidor.
- Evite scripts monolíticos; prefira módulos pequenos, coesos e tipados.

## Segurança e dependências

- Não adicione dependências externas sem autorização explícita.
- Não use modelos ou scripts gratuitos da Toolbox sem inspeção prévia.

## Escopo e compatibilidade

- Preserve a compatibilidade com computador, celular e tablet.
- Não implemente funcionalidades além do escopo solicitado.
- Preserve arquivos e alterações existentes que não pertençam à tarefa atual.

## Validação e entrega

- Sempre valide o projeto após alterações, incluindo o JSON do projeto Rojo e um build quando o Rojo estiver disponível.
- Nunca publique a experiência.
- Nunca realize commit ou push sem solicitação explícita.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
