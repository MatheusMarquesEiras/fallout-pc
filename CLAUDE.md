# Projeto: nuke.sh — limpeza de cache de dev multiplataforma

## O que é
Script bash que limpa cache de ferramentas de dev (pip, uv, npm, yarn, pnpm,
go, cargo/rust, ccache, sccache, vcpkg, MSYS2, Visual Studio/NuGet, git,
GitHub CLI, Hugging Face), Docker (containers/imagens/build cache/volumes) e
temporários do sistema, pra liberar espaço em disco. Vai ser distribuído pra
várias pessoas em Windows, macOS e Linux.

## Arquivos
- `nuke.sh` — script principal, roda em qualquer bash (Linux/macOS/WSL/Git Bash)
- `nuke.command` — lançador duplo-clique pro macOS (abre Terminal, chama `./nuke.sh`)
- `nuke.bat` — lançador duplo-clique pro Windows (acha Git Bash/WSL, chama `nuke.sh`)
- `LEIA-ME.txt` — instrução por sistema pra quem for usar

## Regra inegociável
O script NUNCA pode mexer em login/senha/token de nada: git credentials,
SSH, gh CLI, token do Hugging Face, login do Docker, `~/.npmrc`,
`~/.cargo/credentials.toml`. Qualquer mudança precisa preservar isso.

## Convenções de teste
- Validar sintaxe antes de considerar pronto: `bash -n nuke.sh` (e o mesmo
  pro `nuke.command`)
- Testar em `--dry-run` antes de rodar de verdade
- `nuke.bat` só pode ser validado de verdade rodando no Windows — não tem
  como emular isso num Linux puro

## Bug já corrigido nesta sessão (contexto — não precisa refazer)
Ao rodar `nuke.bat` de verdade (PowerShell 5.1 + Git Bash instalado), deu:

    /bin/bash: C:\Users\mathe\OneDrive\Desktop\files\nuke.sh: No such file or directory

Causa: `nuke.bat` já fazia `cd /d "%~dp0"` (certo), mas depois chamava
`"%BASH_EXE%" "%~dp0nuke.sh"` — passando um path absoluto do Windows (barra
invertida) como argumento pro `bash.exe`. Bash não traduz isso quando recebe
como argumento de linha de comando (só traduz em certos contextos internos
do MSYS) — ele tenta abrir um arquivo chamado literalmente com aquele texto
todo, incluindo as barras invertidas, e não acha.

Fix aplicado: como já tem `cd /d "%~dp0"` no topo, as duas chamadas pro bash
viraram `"%BASH_EXE%" ./nuke.sh` (caminho relativo, sem `%~dp0`). Ainda não
foi confirmado rodando de novo numa máquina Windows de verdade.

## Tarefa agora
1. Testar `nuke.bat` de novo na mesma máquina onde o bug apareceu — confirmar
   que acha o `nuke.sh` e que tanto o preview (dry-run) quanto a execução
   real funcionam.
2. Se der pra simular um cenário só com WSL (sem Git Bash instalado), testar
   esse caminho também — o script tenta achar bash via `where bash` e depois
   via caminhos fixos do Git; quero saber se os dois casos ficam cobertos.
3. Testar rodando de uma pasta com espaço no nome, pra garantir que as aspas
   em volta dos paths não quebram.
4. Se achar mais algum caso quebrando, ajustar o `nuke.bat` (e só mexer no
   `nuke.sh`/`nuke.command` se o problema for compartilhado entre os três) e
   testar de novo antes de considerar resolvido.
