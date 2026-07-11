#!/usr/bin/env bash
# nuke.command — clique duas vezes no macOS pra abrir o Terminal e rodar o nuke.sh
# (mesma pasta que este arquivo precisa ter o nuke.sh)
cd "$(dirname "$0")" || { echo "Não achei a pasta do script."; read -rp "Pressione Enter para fechar..."; exit 1; }

if [[ ! -f "./nuke.sh" ]]; then
  echo "Não achei o nuke.sh nesta pasta. Ele precisa estar junto com este arquivo."
  read -rp "Pressione Enter para fechar..."
  exit 1
fi
chmod +x ./nuke.sh 2>/dev/null

clear
echo "=================================================="
echo "  NUKE — limpeza de cache de dev e temporários"
echo "=================================================="
echo
echo "Limpa cache de pip/uv/npm/cargo/docker/git/huggingface"
echo "e temporários do sistema pra liberar espaço em disco."
echo "Não mexe em login, senha ou token de nada."
echo

read -rp "Quer ver antes o que seria feito, sem apagar nada de verdade? [S/n] " preview
if [[ ! "$preview" =~ ^[Nn]$ ]]; then
  ./nuke.sh --dry-run
  echo
  read -rp "Quer rodar de verdade agora? [s/N] " confirmar
  if [[ "$confirmar" =~ ^[Ss]$ ]]; then
    ./nuke.sh
  else
    echo "Nada foi apagado."
  fi
else
  ./nuke.sh
fi

echo
read -rp "Pressione Enter para fechar..."
