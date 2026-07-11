#!/usr/bin/env bash
# =============================================================================
#  nuke.sh — detona cache de dev, docker e temporários pra liberar espaço
#
#  PRINCÍPIO: nuka cache/build/artefato (coisa que se reconstrói sozinha).
#  NUNCA toca em credencial/login, mesmo que isso limite um pouco a "faxina":
#    - ~/.git-credentials, credential helpers, ~/.ssh
#    - login do gh CLI (~/.config/gh)
#    - token do Hugging Face (arquivo 'token' dentro do cache dele)
#    - login do Docker (~/.docker/config.json)
#    - ~/.npmrc, ~/.cargo/credentials.toml
# =============================================================================
set -uo pipefail

# fallback defensivo: garante que $HOME sempre existe (tilde expande via /etc/passwd
# mesmo sem a variável setada), pra não estourar com "set -u" em ambientes exóticos
: "${HOME:=$(cd ~ 2>/dev/null && pwd || echo /tmp)}"

# ---------------------------------------------------------------------------
# estado / flags (default)
# ---------------------------------------------------------------------------
DRY_RUN=false
ASSUME_YES=false
SKIP_DOCKER_VOLUMES=false
ONLY_LIST=""
KNOWN_TARGETS="pip uv npm yarn pnpm go cargo ccache sccache vcpkg msys2 vs git huggingface ollama docker temp"

# ---------------------------------------------------------------------------
# cores / helpers de output
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'
  ORANGE=$'\033[38;5;208m'
else
  BOLD=''; RESET=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; ORANGE=''
fi

section() { echo -e "\n${BOLD}${CYAN}▶ $*${RESET}"; }
ok()      { echo -e "  ${GREEN}✔${RESET} $*"; }
skip()    { echo -e "  ${YELLOW}—${RESET} $* ${YELLOW}(não encontrado, pulando)${RESET}"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
fail()    { echo -e "  ${RED}✘${RESET} $*"; }
keep()    { echo -e "  ${CYAN}🔒${RESET} preservado: $*"; }

has() { command -v "$1" >/dev/null 2>&1; }

run() {
  if $DRY_RUN; then
    echo -e "    ${YELLOW}[dry-run]${RESET} $*"
    return 0
  fi
  "$@"
}

confirm() {
  $ASSUME_YES && return 0
  local reply=""
  read -r -p "$(echo -e "  ${YELLOW}?${RESET} $1 [y/N] ")" reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

wanted() {
  [[ -z "$ONLY_LIST" ]] && return 0
  [[ ",${ONLY_LIST}," == *",$1,"* ]]
}

# path do %LOCALAPPDATA% do Windows, convertido pra path unix (WSL ou Git Bash). Vazio se não achar.
get_win_localappdata() {
  case "$OS" in
    wsl)
      if has cmd.exe && has wslpath; then
        local raw
        raw=$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')
        [[ -n "$raw" ]] && wslpath -u "$raw" 2>/dev/null
      fi
      ;;
    gitbash)
      if has cygpath && [[ -n "${LOCALAPPDATA:-}" ]]; then
        cygpath -u "$LOCALAPPDATA" 2>/dev/null
      fi
      ;;
  esac
}

# path do %TEMP% do Windows, convertido pra path unix (WSL ou Git Bash). Vazio se não achar.
get_win_temp() {
  case "$OS" in
    wsl)
      if has cmd.exe && has wslpath; then
        local raw
        raw=$(cmd.exe /c "echo %TEMP%" 2>/dev/null | tr -d '\r')
        [[ -n "$raw" ]] && wslpath -u "$raw" 2>/dev/null
      fi
      ;;
    gitbash)
      if has cygpath && [[ -n "${TEMP:-}" ]]; then
        cygpath -u "$TEMP" 2>/dev/null
      fi
      ;;
  esac
}

show_help() {
  cat <<'EOF'
nuke.sh — detona cache de dev, docker e temporários pra liberar espaço em disco

USO:
  ./nuke.sh [opções]

OPÇÕES:
  -n, --dry-run              mostra o que seria feito, sem apagar nada de verdade
  -y, --yes                  não pergunta confirmação (assume "sim" nos passos destrutivos)
      --skip-docker-volumes  pula a limpeza de volumes docker (evita risco de apagar dados)
      --only <lista>         roda só os alvos da lista, separados por vírgula
                              alvos: pip,uv,npm,yarn,pnpm,go,cargo,ccache,sccache,
                                     vcpkg,msys2,vs,git,huggingface,ollama,docker,temp
  -h, --help                 mostra essa ajuda

NUNCA TOCA EM LOGIN/CREDENCIAL:
  git credentials, SSH, gh CLI, token do Hugging Face, login do Docker,
  ~/.npmrc, ~/.cargo/credentials.toml — mesmo no --yes.

EXEMPLOS:
  ./nuke.sh --dry-run
  ./nuke.sh --only pip,npm,go,cargo,huggingface
  ./nuke.sh --yes --skip-docker-volumes
EOF
}

# ---------------------------------------------------------------------------
# limpadores — gerenciadores de linguagem
# ---------------------------------------------------------------------------
clean_pip() {
  wanted pip || return 0
  section "pip"
  if has pip; then
    run pip cache purge && ok "pip cache purge" || fail "pip cache purge falhou"
  elif has pip3; then
    run pip3 cache purge && ok "pip3 cache purge" || fail "pip3 cache purge falhou"
  else
    skip "pip"
  fi
}

clean_uv() {
  wanted uv || return 0
  section "uv"
  if has uv; then
    run uv cache clean && ok "uv cache clean" || fail "uv cache clean falhou"
  else
    skip "uv"
  fi
}

clean_npm() {
  wanted npm || return 0
  section "npm"
  if has npm; then
    run npm cache clean --force && ok "npm cache clean --force" || fail "npm cache clean falhou"
  else
    skip "npm"
  fi
}

clean_yarn() {
  wanted yarn || return 0
  section "yarn"
  if has yarn; then
    run yarn cache clean && ok "yarn cache clean" || fail "yarn cache clean falhou"
  else
    skip "yarn"
  fi
}

clean_pnpm() {
  wanted pnpm || return 0
  section "pnpm"
  if has pnpm; then
    run pnpm store prune && ok "pnpm store prune" || fail "pnpm store prune falhou"
  else
    skip "pnpm"
  fi
}

clean_go() {
  wanted go || return 0
  section "go"
  if has go; then
    run go clean -cache -modcache -testcache && ok "go clean -cache -modcache -testcache"
    run go clean -fuzzcache 2>/dev/null || true
  else
    skip "go"
  fi
}

clean_cargo() {
  wanted cargo || return 0
  section "cargo / rust"
  if has cargo; then
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    run rm -rf "${cargo_home:?}/registry/cache" \
               "${cargo_home:?}/registry/src" \
               "${cargo_home:?}/git/checkouts" \
               "${cargo_home:?}/git/db" \
      && ok "limpou ${cargo_home}/registry/{cache,src} e git/{checkouts,db}"
    keep "${cargo_home}/credentials.toml (token do crates.io/registries privados)"
    echo -e "  ${CYAN}dica:${RESET} 'cargo install cargo-cache' dá um controle mais fino se quiser"
  else
    skip "cargo/rust"
  fi
}

# ---------------------------------------------------------------------------
# limpadores — cache de compilador C/C++ (nativo, MinGW, MSVC)
# ---------------------------------------------------------------------------
clean_ccache() {
  wanted ccache || return 0
  section "ccache"
  if has ccache; then
    run ccache -C && ok "ccache -C (cache limpo, config mantida)" || fail "ccache -C falhou"
  else
    skip "ccache"
  fi
}

clean_sccache() {
  wanted sccache || return 0
  section "sccache"
  local found=false

  if has sccache; then
    found=true
    run sccache --stop-server >/dev/null 2>&1 || true
    local dir="${SCCACHE_DIR:-}"
    if [[ -z "$dir" ]]; then
      case "$OS" in
        macos) dir="$HOME/Library/Caches/Mozilla.sccache" ;;
        *)     dir="$HOME/.cache/sccache" ;;
      esac
    fi
    if [[ -d "$dir" ]]; then
      run rm -rf "${dir:?}" && ok "removido cache do sccache: $dir"
    else
      warn "sccache achado, mas sem diretório de cache em $dir (talvez já vazio)"
    fi
  fi

  if [[ "$OS" == "wsl" || "$OS" == "gitbash" ]] && has sccache.exe; then
    found=true
    run sccache.exe --stop-server >/dev/null 2>&1 || true
    local win_local win_dir
    win_local=$(get_win_localappdata)
    if [[ -n "$win_local" ]]; then
      win_dir="${win_local}/Mozilla/sccache"
      [[ -d "$win_dir" ]] && run rm -rf "${win_dir:?}" && ok "removido cache do sccache (Windows): $win_dir"
    fi
  fi

  $found || skip "sccache"
}

clean_vcpkg() {
  wanted vcpkg || return 0
  section "vcpkg"
  local root="${VCPKG_ROOT:-}"
  if [[ -z "$root" || ! -d "$root" ]] && has vcpkg; then
    root="$(dirname "$(command -v vcpkg)")"
  fi
  if [[ -z "$root" || ! -d "$root" ]]; then
    skip "vcpkg"
    return
  fi
  local freed_any=false
  for sub in buildtrees downloads; do
    if [[ -d "$root/$sub" ]]; then
      run rm -rf "${root:?}/$sub" && ok "limpou $root/$sub" && freed_any=true
    fi
  done
  keep "$root/installed e $root/packages (bibliotecas já compiladas em uso)"
  $freed_any || warn "vcpkg em $root, mas buildtrees/downloads já vazios ou não encontrados"
}

clean_msys2() {
  wanted msys2 || return 0
  section "MSYS2 / pacman (toolchain MinGW)"
  if has pacman; then
    run pacman -Scc --noconfirm && ok "pacman -Scc (cache de pacotes limpo)" || fail "pacman -Scc falhou (precisa de sudo?)"
  else
    skip "pacman/MSYS2"
  fi
}

# ---------------------------------------------------------------------------
# limpador — visual studio / .net / nuget / msvc
# ---------------------------------------------------------------------------
clean_visual_studio() {
  wanted vs || return 0
  section "Visual Studio / NuGet / MSVC"
  local found=false

  if has dotnet; then
    found=true
    run dotnet nuget locals all --clear && ok "dotnet nuget locals all --clear"
  fi

  local win_local
  win_local=$(get_win_localappdata)
  if [[ -n "$win_local" && -d "$win_local" ]]; then
    found=true
    local vs_dir="${win_local}/Microsoft/VisualStudio"
    if [[ -d "$vs_dir" ]]; then
      while IFS= read -r -d '' cache_dir; do
        run rm -rf "$cache_dir" && ok "removido: $cache_dir"
      done < <(find "$vs_dir" -maxdepth 2 -type d -iname "ComponentModelCache" -print0 2>/dev/null)
    fi
  fi

  # pastas .vs (IntelliSense/cache de solução por projeto) — sempre seguras de apagar
  local vs_count=0
  while IFS= read -r -d '' vsdir; do
    run rm -rf "$vsdir" && vs_count=$((vs_count + 1))
  done < <(find "$HOME" -maxdepth 6 -type d \
              \( -name node_modules -o -name .cache -o -name .git -o -name target \) -prune \
              -o -type d -name ".vs" -print0 2>/dev/null)
  if (( vs_count > 0 )); then
    found=true
    ok "removeu $vs_count pasta(s) .vs (cache de IntelliSense/solução)"
  fi

  $found || skip "Visual Studio / dotnet / nuget"
}

# ---------------------------------------------------------------------------
# limpador — git / github cli
# ---------------------------------------------------------------------------
clean_git() {
  wanted git || return 0
  section "Git / GitHub CLI"

  if has gh; then
    run gh config clear-cache && ok "gh config clear-cache" || fail "gh config clear-cache falhou"
    keep "~/.config/gh (seu login do gh CLI)"
  else
    skip "gh (GitHub CLI)"
  fi

  if has git; then
    local count=0
    while IFS= read -r -d '' gitdir; do
      local repo
      repo="$(dirname "$gitdir")"
      run git -C "$repo" gc --prune=now --quiet 2>/dev/null
      count=$((count + 1))
    done < <(find "$HOME" -maxdepth 6 -type d \
                \( -name node_modules -o -name .cache -o -name target -o -name dist -o -name build -o -name venv -o -name .venv \) -prune \
                -o -type d -name ".git" -print0 2>/dev/null)

    if (( count > 0 )); then
      ok "rodou 'git gc --prune=now' em $count repositório(s) (compacta, não apaga histórico)"
    else
      warn "nenhum repositório git encontrado em $HOME pra compactar"
    fi
    keep "~/.git-credentials e credential helpers"
  else
    skip "git"
  fi
}

# ---------------------------------------------------------------------------
# limpador — hugging face hub (modelos/datasets em cache)
# ---------------------------------------------------------------------------
clean_huggingface() {
  wanted huggingface || return 0
  section "Hugging Face (cache de modelos/datasets)"
  local hf_home="${HF_HOME:-$HOME/.cache/huggingface}"
  if [[ ! -d "$hf_home" ]]; then
    skip "huggingface (sem cache em $hf_home)"
    return
  fi

  local hub_dir="${HF_HUB_CACHE:-${HUGGINGFACE_HUB_CACHE:-$hf_home/hub}}"
  local freed_any=false
  for sub_path in "$hub_dir" "$hf_home/xet" "$hf_home/datasets" "$hf_home/modules"; do
    if [[ -d "$sub_path" ]]; then
      run rm -rf "${sub_path:?}" && ok "removido: $sub_path" && freed_any=true
    fi
  done

  if [[ -f "$hf_home/token" ]]; then
    keep "$hf_home/token (seu login do Hugging Face continua válido)"
  fi

  $freed_any || warn "cache de modelos/datasets não encontrado em $hf_home"
}

# ---------------------------------------------------------------------------
# limpador — ollama (cache de modelos baixados)
# ---------------------------------------------------------------------------
clean_ollama() {
  wanted ollama || return 0
  section "Ollama (cache de modelos)"
  local ollama_home="$HOME/.ollama"
  if [[ ! -d "$ollama_home" ]]; then
    skip "ollama (sem cache em $ollama_home)"
    return
  fi

  local models_dir="${OLLAMA_MODELS:-$ollama_home/models}"
  local freed_any=false
  for sub_path in "$models_dir/blobs" "$models_dir/manifests" "$ollama_home/cache"; do
    if [[ -d "$sub_path" ]]; then
      run rm -rf "${sub_path:?}" && ok "removido: $sub_path" && freed_any=true
    fi
  done

  if [[ -f "$ollama_home/id_ed25519" ]]; then
    keep "$ollama_home/id_ed25519 (chave de identidade pra publicar modelos no ollama.com)"
  fi
  keep "$ollama_home/history (histórico de conversas)"

  if $freed_any; then
    echo -e "  ${CYAN}dica:${RESET} os modelos precisam ser baixados de novo com 'ollama pull <modelo>'"
  else
    warn "ollama achado em $ollama_home, mas sem cache de modelos pra limpar"
  fi
}

# ---------------------------------------------------------------------------
# limpador — docker
# ---------------------------------------------------------------------------
clean_docker() {
  wanted docker || return 0
  section "Docker"
  if ! has docker; then
    skip "docker"
    return
  fi
  if ! docker info >/dev/null 2>&1; then
    warn "docker instalado, mas o daemon não respondeu (rodando? permissão de grupo docker?) — pulando"
    return
  fi

  run docker container prune -f && ok "containers parados removidos"
  run docker image prune -af && ok "imagens não usadas removidas"
  run docker network prune -f && ok "redes não usadas removidas"
  run docker builder prune -af && ok "cache de build removido"
  keep "~/.docker/config.json (seu login nos registries)"

  if $SKIP_DOCKER_VOLUMES; then
    warn "pulando volumes docker (--skip-docker-volumes)"
    return
  fi

  echo
  warn "volumes docker não usados (não presos a nenhum container) serão apagados PERMANENTEMENTE."
  if $DRY_RUN || confirm "quer mesmo rodar 'docker volume prune'?"; then
    run docker volume prune -f && ok "volumes não usados removidos"
  else
    warn "volumes preservados"
  fi
}

# ---------------------------------------------------------------------------
# limpador — temporários do sistema
# ---------------------------------------------------------------------------
clean_temp() {
  wanted temp || return 0
  section "Temporários do sistema"

  case "$OS" in
    macos)
      local t="${TMPDIR:-/tmp}"
      run find "$t" -mindepth 1 -user "$(id -un)" -exec rm -rf {} + 2>/dev/null
      ok "limpou temporários do usuário em $t"
      ;;
    linux)
      run find /tmp -mindepth 1 -user "$(id -un)" -exec rm -rf {} + 2>/dev/null
      run find /var/tmp -mindepth 1 -user "$(id -un)" -exec rm -rf {} + 2>/dev/null
      ok "limpou temporários do usuário em /tmp e /var/tmp"
      ;;
    wsl)
      run find /tmp -mindepth 1 -user "$(id -un)" -exec rm -rf {} + 2>/dev/null
      ok "limpou /tmp (lado Linux do WSL)"
      local win_temp
      win_temp=$(get_win_temp)
      if [[ -n "$win_temp" && -d "$win_temp" ]]; then
        run find "$win_temp" -mindepth 1 -delete 2>/dev/null
        ok "limpou %TEMP% do Windows"
      fi
      ;;
    gitbash)
      local win_temp
      win_temp=$(get_win_temp)
      if [[ -n "$win_temp" && -d "$win_temp" ]]; then
        run find "$win_temp" -mindepth 1 -delete 2>/dev/null
        ok "limpou %TEMP% do Windows"
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# parse de argumentos
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=true; shift ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    --skip-docker-volumes) SKIP_DOCKER_VOLUMES=true; shift ;;
    --only)
      if [[ -z "${2:-}" ]]; then
        echo "erro: --only precisa de uma lista (ex: --only pip,npm,go)" >&2
        exit 1
      fi
      ONLY_LIST="$2"
      shift 2
      ;;
    -h|--help) show_help; exit 0 ;;
    *)
      echo "opção desconhecida: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

if [[ -n "$ONLY_LIST" ]]; then
  IFS=',' read -ra _targets <<< "$ONLY_LIST"
  for t in "${_targets[@]}"; do
    [[ " $KNOWN_TARGETS " == *" $t "* ]] || warn "alvo desconhecido em --only: '$t' (válidos: $KNOWN_TARGETS)"
  done
fi

# ---------------------------------------------------------------------------
# detecção de ambiente
# ---------------------------------------------------------------------------
OS="linux"
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  MINGW*|MSYS*|CYGWIN*) OS="gitbash" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      OS="wsl"
    fi
    ;;
esac

# ---------------------------------------------------------------------------
# banner
# ---------------------------------------------------------------------------
echo -e "${BOLD}${ORANGE}"
cat <<'NUKEART'
███╗   ██╗ ██╗   ██╗ ██╗  ██╗ ███████╗
████╗  ██║ ██║   ██║ ██║ ██╔╝ ██╔════╝
██╔██╗ ██║ ██║   ██║ █████╔╝  █████╗
██║╚██╗██║ ██║   ██║ ██╔═██╗  ██╔══╝
██║ ╚████║ ╚██████╔╝ ██║  ██╗ ███████╗
╚═╝  ╚═══╝  ╚═════╝  ╚═╝  ╚═╝ ╚══════╝
NUKEART
echo -e "${RESET}${BOLD}${CYAN}          ☢  cache & temp cleaner  ☢${RESET}"
echo -e "ambiente detectado: ${BOLD}${OS}${RESET}"
$DRY_RUN && echo -e "${YELLOW}(modo dry-run: nada será apagado de verdade)${RESET}"

# ---------------------------------------------------------------------------
# medição de espaço (antes)
# ---------------------------------------------------------------------------
DISK_TARGET="$HOME"
space_before=$(df -Pk "$DISK_TARGET" 2>/dev/null | awk 'NR==2{print $4}')
[[ "$space_before" =~ ^[0-9]+$ ]] || space_before=""

# ---------------------------------------------------------------------------
# execução
# ---------------------------------------------------------------------------
clean_pip
clean_uv
clean_npm
clean_yarn
clean_pnpm
clean_go
clean_cargo
clean_ccache
clean_sccache
clean_vcpkg
clean_msys2
clean_visual_studio
clean_git
clean_huggingface
clean_ollama
clean_docker
clean_temp

# ---------------------------------------------------------------------------
# resumo
# ---------------------------------------------------------------------------
section "Resumo"
if ! $DRY_RUN && [[ -n "$space_before" ]]; then
  space_after=$(df -Pk "$DISK_TARGET" 2>/dev/null | awk 'NR==2{print $4}')
  if [[ "$space_after" =~ ^[0-9]+$ ]]; then
    freed_kb=$(( space_after - space_before ))
    if (( freed_kb > 1048576 )); then
      freed_h="$(awk -v kb="$freed_kb" 'BEGIN{printf "%.2f GB", kb/1048576}')"
    else
      freed_h="$(awk -v kb="$freed_kb" 'BEGIN{printf "%.0f MB", kb/1024}')"
    fi
    if (( freed_kb > 0 )); then
      echo -e "  ${GREEN}${BOLD}liberado em $DISK_TARGET: ~${freed_h}${RESET}"
    else
      echo -e "  ${YELLOW}sem variação mensurável em $DISK_TARGET${RESET}"
      echo -e "  ${YELLOW}(docker e coisas do lado Windows/WSL2 costumam liberar espaço em outro disco/VHDX)${RESET}"
    fi
  fi
else
  echo -e "  ${CYAN}(sem medição em modo dry-run)${RESET}"
fi

echo -e "\n💥 nuke completo.\n"
