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
