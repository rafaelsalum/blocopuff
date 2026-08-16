# BlocoPuff!

BlocoPuff! é um jogo multiplayer infantil, colorido e cartunesco para 2 a 10 jogadores. Os participantes permanecem sobre uma plataforma de blocos enquanto partes dela desaparecem; vence a rodada o último jogador restante.

## Stack

- Roblox Studio
- Luau em modo estrito (`--!strict`)
- Rojo 7 para sincronização entre os arquivos locais e o Roblox Studio
- Git para controle de versão

## Estrutura

```text
src/
├── client/   # Scripts executados no cliente
├── server/   # Scripts executados no servidor
└── shared/   # Configurações, tipos e módulos compartilhados
tests/        # Testes futuros
```

O arquivo `default.project.json` mapeia essas pastas para `StarterPlayerScripts/Client`, `ServerScriptService/Server` e `ReplicatedStorage/Shared`, respectivamente.

## Pré-requisitos

- Git
- Roblox Studio para macOS
- Rokit 1.2.0 ou mais recente
- Rojo CLI 7.7.0, fixado pelo projeto
- Plugin do Rojo para Roblox Studio compatível com a versão principal da CLI

## Toolchain local

O projeto usa [Rokit](https://github.com/rojo-rbx/rokit) para instalar ferramentas Roblox de forma reproduzível. A versão do Rojo fica fixada no arquivo `rokit.toml`; não é necessário instalar Rojo globalmente por outro método.

### Instalação inicial no macOS

Instale o Rokit com o instalador oficial:

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

Reinicie o terminal para carregar o PATH. Se necessário na sessão atual, carregue-o manualmente:

```sh
source "$HOME/.rokit/env"
```

Na raiz deste repositório, confie no pacote oficial e instale a versão fixada:

```sh
rokit trust rojo-rbx/rojo
rokit install
```

Confirme a instalação:

```sh
rokit --version
rojo --version
```

A versão esperada atualmente é `Rojo 7.7.0`.

### Atualização futura

Verifique primeiro se há uma atualização disponível:

```sh
rokit update --check
```

Para atualizar somente o Rojo e registrar a nova versão em `rokit.toml`:

```sh
rokit update rojo
```

Revise a alteração do manifesto e repita o build de validação antes de compartilhar a atualização.

## Sincronização com o Roblox Studio

Na raiz do projeto, inicie o servidor de sincronização:

```sh
rojo serve
```

Abra uma experiência no Roblox Studio, selecione o plugin Rojo na barra de plugins e clique em **Connect**. Use o endereço exibido pelo comando; por padrão, o servidor local usa `localhost:34872`.

## Plugin do Rojo no Roblox Studio

Instale o [plugin oficial Rojo 7 no Creator Store](https://create.roblox.com/store/asset/13916111004). Na página, clique em **Install** e confirme que o plugin aparece na aba **Plugins** do Roblox Studio. A versão principal do plugin deve ser a mesma da CLI.

Para fazer a primeira sincronização:

1. Abra o Roblox Studio e crie ou abra um place local de desenvolvimento.
2. Na raiz deste repositório, execute `rojo serve` e mantenha o terminal aberto.
3. No Studio, abra o painel do Rojo pela aba **Plugins**.
4. Use o endereço mostrado no terminal, normalmente `localhost:34872`, e clique em **Connect**.
5. Revise e aceite a sincronização apresentada pelo plugin.

Depois da sincronização, o Explorer deve conter:

```text
ReplicatedStorage/Shared
ServerScriptService/Server
StarterPlayer/StarterPlayerScripts/Client
```

Para um teste simples, abra **View > Output** e clique em **Play**. Sem erros, devem aparecer estas mensagens:

```text
[BlocoPuff] Server initialized
[BlocoPuff] Client initialized
```

Encerre o teste pelo botão **Stop**. Essa verificação confirma somente que os contextos de servidor e cliente foram carregados; ainda não há mecânicas de jogo.

## Build local

Para gerar uma cópia local da experiência no formato XML:

```sh
rojo build -o BlocoPuff.rbxlx
```

Arquivos `.rbxl` e `.rbxlx` são artefatos locais e não fazem parte da fonte principal deste repositório.

## Estado atual

O projeto contém somente a estrutura técnica inicial. Nenhuma mecânica de rodada, arena, blocos, lançador, interface, persistência ou monetização foi implementada.
