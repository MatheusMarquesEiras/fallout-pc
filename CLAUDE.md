# Projeto: FALLOUT PC (nuke.sh) — limpeza de cache de dev multiplataforma

## O que é
Script bash que limpa cache de ferramentas de dev (pip, uv, npm, yarn, pnpm,
go, cargo/rust, ccache, sccache, vcpkg, MSYS2, Visual Studio/NuGet, git,
GitHub CLI, Hugging Face), Docker (containers/imagens/build cache/volumes) e
temporários do sistema, pra liberar espaço em disco. Vai ser distribuído pra
várias pessoas em Windows, macOS e Linux.

## Arquivos
Tudo que é distribuído pra quem for usar mora junto em `nuke/`:
- `nuke/nuke.sh` — script principal, roda em qualquer bash (Linux/macOS/WSL/Git Bash)
- `nuke/nuke.command` — lançador duplo-clique pro macOS (abre Terminal, chama `./nuke.sh`)
- `nuke/nuke.bat` — lançador duplo-clique pro Windows (acha Git Bash/WSL, chama `nuke.sh`)

`README.md` na raiz é a documentação pra quem for usar (substituiu o antigo
`nuke/LEIA-ME.txt`). `assets/logo/` guarda a identidade visual do projeto.

`.gitattributes` na raiz força LF em `.sh`/`.command` e CRLF em `.bat`,
independente do `core.autocrlf` de quem clonar (crítico pro shebang/heredoc
do `nuke.sh` não quebrar se alguém commitar do Windows).

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

## Bug já corrigido (histórico)
Ao rodar `nuke.bat` de verdade (PowerShell 5.1 + Git Bash instalado), deu:

    /bin/bash: C:\Users\mathe\OneDrive\Desktop\files\nuke.sh: No such file or directory

Causa: `nuke.bat` já fazia `cd /d "%~dp0"` (certo), mas depois chamava
`"%BASH_EXE%" "%~dp0nuke.sh"` — passando um path absoluto do Windows (barra
invertida) como argumento pro `bash.exe`. Bash não traduz isso quando recebe
como argumento de linha de comando (só traduz em certos contextos internos
do MSYS) — ele tenta abrir um arquivo chamado literalmente com aquele texto
todo, incluindo as barras invertidas, e não acha.

Fix aplicado: como já tem `cd /d "%~dp0"` no topo, as duas chamadas pro bash
viraram `"%BASH_EXE%" ./nuke.sh` (caminho relativo, sem `%~dp0`).

## Validação desta sessão (confirmado numa máquina Windows real)
Máquina de teste: Windows 11, com Git Bash **e** WSL2/Ubuntu instalados —
deu pra cobrir os dois caminhos de detecção de bash sem precisar simular nada:

- **`where bash` → Git Bash**: quando o PATH do processo que chama `nuke.bat`
  tem os diretórios do Git na frente (ex: aberto de dentro de um shell Git
  Bash), `where bash` acha o Git Bash primeiro. `OS` detectado como
  `gitbash`. Preview (`--dry-run`) e execução real, ambos OK.
- **`where bash` → WSL**: quando o PATH é o do usuário/Explorer "puro"
  (sem os diretórios do Git na frente — é o caso normal de duplo-clique),
  `where bash` acha primeiro o `C:\Windows\System32\bash.exe` (stub do WSL).
  Esse stub traduz sozinho o cwd do Windows pro equivalente `/mnt/c/...` e
  achou o `nuke.sh` certinho. `OS` detectado como `wsl` (via `/proc/version`
  contendo "microsoft"). Preview e execução real, ambos OK.
- **Fallback pro caminho fixo do Git** (`if not defined BASH_EXE if exist
  "%ProgramFiles%\Git\bin\bash.exe"...`): testado forçando um PATH restrito
  (sem nada que resolva `bash` via `where`) — cai certinho no caminho fixo
  do Git e roda normalmente.
- **Pasta com espaço no nome**: copiado `nuke.bat`+`nuke.sh` pra uma pasta
  tipo `...\Temp\nuke test dir\` — funciona igual (preview e execução real),
  tanto no branch `gitbash` quanto no `wsl`. As aspas em volta de `%~dp0` e
  o uso de caminho relativo (`./nuke.sh`) não quebram.
- **Execução real (sem `--dry-run`)**: rodada de verdade, aprovada
  explicitamente pelo usuário. Confirmado que apagou cache de verdade (VS
  ComponentModelCache, cache do Hugging Face) e que preservou 100% do que a
  regra inegociável exige — `~/.ssh`, `~/.docker/config.json` e o login do
  `gh` (keyring) continuaram intactos depois da rodada.

Achado à parte (não é bug do `nuke.sh`/`nuke.bat`, é do meu próprio setup de
teste): `set /p` do cmd.exe, lendo stdin redirecionado de um arquivo com
quebra de linha só-LF (Unix), engole mais de uma linha de uma vez. Testes
de resposta automática precisam de arquivo com CRLF.

Nenhum ajuste de código foi necessário nesta sessão além do fix já descrito
acima — todos os cenários passaram.
