# Recuperação de perfil

Serve para ver e recuperar o perfil de um jogador quando ele disser que perdeu Puffs, tickets ou nível.

## Antes de começar

1. Abra o jogo **publicado** no Studio (File → Open from Roblox), não o `.rbxl` gerado pelo `rojo build`.
2. Sincronize os scripts com o Rojo (`rojo serve` e conectar pelo plugin).
3. Ligue Game Settings → Security → **Enable Studio Access to API Services**.

## Ver o perfil (não muda nada)

1. Abra `recovery.luau` e preencha:
   - `USER_ID`: o número que aparece no link do perfil do jogador no Roblox;
   - deixe `ACTION = "list"`.
2. Copie o arquivo inteiro e cole na Command Bar (View → Command Bar). Aperte Enter.
3. O Output mostra:
   - **Atual**: o perfil de agora (quantos Puffs, XP, nível, tickets e partidas; e se está preso por um servidor);
   - **Cópia**: a cópia de segurança, que só soma;
   - **Versões antigas**: cada gravação dos últimos 30 dias, com data e resumo.

## Restaurar

O jogador precisa estar **fora do jogo**. Restaurar só devolve o que falta: nada do perfil atual é perdido.

- Da cópia de segurança: `ACTION = "restore"`, `SOURCE = "backup"`.
- De uma versão antiga: `ACTION = "restore"`, `SOURCE = "main"`, `VERSION = "<versão copiada da lista>"`.

Por padrão (`DRY_RUN = true`) o script só **simula**: mostra o perfil antes e depois e o que voltaria, sem gravar. Confira e, se estiver certo, troque para `DRY_RUN = false` e rode de novo. O Output diz o que voltou (por exemplo, `puffs+20`) e mostra o perfil depois.

`KEEP_WALLET = true` (padrão) mantém os tickets de agora, porque a versão antiga pode ter tickets que o jogador já gastou. Use `false` só se a carteira atual também tiver sido zerada.

A trava de sessão só prova que o jogador saiu há um tempo. Confirme também que ele está fora do jogo (por exemplo, pelo perfil dele no Roblox) antes de gravar.
