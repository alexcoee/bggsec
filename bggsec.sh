#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# bggsec - unified tool manager
# =========================

# ---- Cores (verde e roxo) ----
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_NAME="bggsec"
VERSION="v0.2"

DOWNLOAD_DIR="${DOWNLOAD_DIR:-bggsec-tools}"
TOOLS_FILE="${TOOLS_FILE:-./data/tools.tsv}"

die() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Comando obrigatório não encontrado: $1"; }

safe_dirname() {
  local s="$1"
  s="${s//\//_}"
  s="${s// /_}"
  s="$(echo "$s" | tr -cd '[:alnum:]_.-')"
  echo "$s"
}

repo_is_git_cloneable() {
  local repo="$1"
  [[ "$repo" =~ \.git$ ]] && return 0
  [[ "$repo" =~ ^git@ ]] && return 0
  [[ "$repo" =~ ^https:// ]] && [[ "$repo" =~ \.git($|\?) ]] && return 0
  return 1
}

banner() {
  clear
  echo -e "${PURPLE}   ____  ______ ______  _____ ______ _____ "
  echo -e "  / __ )/ ____// ____/ / ___// ____// ___/ "
  echo -e " / __  / / __ / / __   \\__ \\/ __/   \\__ \\  "
  echo -e "/ /_/ / /_/ // /_/ /  ___/ / /___  ___/ /  "
  echo -e "/_____/\\____/ \\____/  /____/_____/ /____/   ${NC}"
  echo -e "  ${GREEN}${APP_NAME}${NC} ${CYAN}${VERSION}${NC} | unified tool manager | ${YELLOW}git required${NC}"
  echo -e "  ------------------------------------------------------------"
}

# TSV: id, categoria, nome, dir, repo, run, desc
tools_lines() {
  [[ -f "$TOOLS_FILE" ]] || die "Arquivo não encontrado: $TOOLS_FILE"
  awk -F'\t' '
    NR==1 {next}
    /^\s*$/ {next}
    $0 ~ /^\s*#/ {next}
    {print}
  ' "$TOOLS_FILE"
}

tool_by_id() {
  local id="$1"
  tools_lines | awk -F'\t' -v id="$id" '$1==id {print; exit}'
}

tool_status() {
  local dir="$1"
  local dest="${DOWNLOAD_DIR}/${dir}"
  [[ -d "$dest/.git" ]] && echo "INSTALADA" || echo "NAO_INSTALADA"
}

count_installed() {
  mkdir -p "$DOWNLOAD_DIR"
  local n=0
  while IFS=$'\t' read -r id cat name dir repo run desc; do
    [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
    [[ -d "${DOWNLOAD_DIR}/${dir}/.git" ]] && n=$((n+1))
  done < <(tools_lines)
  echo "$n"
}

count_total() {
  tools_lines | wc -l | tr -d ' '
}

install_tool_by_line() {
  local line="$1"
  local id cat name dir repo run desc
  IFS=$'\t' read -r id cat name dir repo run desc <<<"$line"
  [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
  local dest="${DOWNLOAD_DIR}/${dir}"

  mkdir -p "$DOWNLOAD_DIR"
  need_cmd git

  if ! repo_is_git_cloneable "$repo"; then
    echo -e "${RED}[x]${NC} Repo não clonável via git (.git ausente):"
    echo -e "    ${CYAN}${repo}${NC}"
    echo -e "${YELLOW}Dica:${NC} abra o link e pegue a URL de clone (.git)."
    return 1
  fi

  if [[ -d "$dest/.git" ]]; then
    echo -e "${CYAN}[*]${NC} Atualizando ${GREEN}${name}${NC}..."
    git -C "$dest" pull --rebase --autostash || die "Falha ao atualizar: $name"
  else
    echo -e "${YELLOW}[*]${NC} Baixando ${GREEN}${name}${NC}..."
    git clone "$repo" "$dest" || die "Falha ao clonar: $repo"
  fi

  echo -e "${GREEN}[+]${NC} Pronto: ${name}"
  echo -e "${CYAN}    Pasta:${NC} $dest"
}

remove_tool_dir() {
  local dir="$1"
  local dest="${DOWNLOAD_DIR}/${dir}"
  [[ -d "$dest" ]] || { echo -e "${RED}[x]${NC} Nada para remover."; return 1; }

  read -rp "Remover completamente '${dir}'? [s/N]: " conf
  if [[ "${conf,,}" == "s" || "${conf,,}" == "sim" ]]; then
    rm -rf "$dest"
    echo -e "${GREEN}[+]${NC} Removido."
  else
    echo -e "${CYAN}[*]${NC} Cancelado."
  fi
}

open_tool_dir() {
  local dir="$1"
  local dest="${DOWNLOAD_DIR}/${dir}"
  [[ -d "$dest" ]] || { echo -e "${RED}[x]${NC} Ferramenta não instalada."; return 1; }
  echo -e "${CYAN}Pasta:${NC} $dest"
  # Não tenta abrir GUI (WSL/SSH). Só mostra path.
}

run_tool() {
  local dir="$1"
  local run_cmd="$2"

  local dest="${DOWNLOAD_DIR}/${dir}"
  [[ -d "$dest" ]] || { echo -e "${RED}[x]${NC} Ferramenta não instalada."; return 1; }
  [[ -n "$run_cmd" && "$run_cmd" != "-" ]] || { echo -e "${RED}[x]${NC} Sem comando de execução definido."; return 1; }

  echo -e "${CYAN}[*]${NC} Executando em ${dest}"
  echo -e "${YELLOW}[*]${NC} Comando: ${run_cmd}"
  echo -e "${YELLOW}[*]${NC} (CTRL+C para sair)"
  echo ""

  (cd "$dest" && bash -c "$run_cmd")
}

list_view() {
  local mode="${1:-all}"   # all | installed
  banner
  local installed total
  installed="$(count_installed)"
  total="$(count_total)"
  echo -e "  Status: ${GREEN}${installed}${NC} instaladas / ${CYAN}${total}${NC} total"
  echo ""
  echo -e "${YELLOW}ID | Cat | Nome | Status${NC}"
  echo "-----------------------------------------------"

  while IFS=$'\t' read -r id cat name dir repo run desc; do
    [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
    local st
    st="$(tool_status "$dir")"
    [[ "$mode" == "installed" && "$st" != "INSTALADA" ]] && continue
    printf "%s | %s | %s | %s\n" "$id" "$cat" "$name" "$st"
  done < <(tools_lines)

  echo ""
  echo -e "${CYAN}Comandos:${NC} digite um ID | l=lista | li=instaladas | s termo=buscar | q=sair"
}

search_view() {
  local q="$1"
  banner
  echo -e "${YELLOW}Busca:${NC} ${CYAN}${q}${NC}"
  echo "-----------------------------------------------"
  tools_lines | awk -F'\t' -v q="$q" '
    BEGIN{IGNORECASE=1}
    $3 ~ q || $2 ~ q || $7 ~ q {printf "%s | %s | %s\n", $1, $2, $3}
  '
  echo ""
  echo -e "${CYAN}Digite um ID para abrir a ferramenta, ou ENTER para voltar.${NC}"
}

tool_screen() {
  local id="$1"
  local line
  line="$(tool_by_id "$id" || true)"
  [[ -n "$line" ]] || return 1

  local _id cat name dir repo run desc
  IFS=$'\t' read -r _id cat name dir repo run desc <<<"$line"
  [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"

  while true; do
    banner
    local st dest
    st="$(tool_status "$dir")"
    dest="${DOWNLOAD_DIR}/${dir}"

    echo -e "${YELLOW}Ferramenta:${NC} ${GREEN}${name}${NC}   (${CYAN}ID ${_id}${NC})"
    echo -e "${YELLOW}Categoria:${NC} ${CYAN}${cat}${NC}"
    echo -e "${YELLOW}Status:${NC} ${CYAN}${st}${NC}"
    echo ""
    echo -e "${YELLOW}Resumo:${NC}"
    echo -e "  ${desc}"
    echo ""
    echo -e "${YELLOW}Repo:${NC} ${CYAN}${repo}${NC}"
    echo -e "${YELLOW}Run:${NC}  ${CYAN}${run}${NC}"
    echo -e "${YELLOW}Dir:${NC}  ${CYAN}${dest}${NC}"
    echo ""
    echo -e "${PURPLE}Opções:${NC}"
    echo "  1) Baixar / Atualizar"
    echo "  2) Executar"
    echo "  3) Mostrar pasta"
    echo "  4) Remover"
    echo "  9) Voltar (lista)"
    echo "  0) Sair"
    echo ""

    read -rp "Escolha: " opt
    case "$opt" in
      1)
        read -rp "Confirmar baixar/atualizar '${name}'? [s/N]: " conf
        if [[ "${conf,,}" == "s" || "${conf,,}" == "sim" ]]; then
          install_tool_by_line "$line" || true
        else
          echo -e "${CYAN}[*]${NC} Cancelado."
        fi
        read -rp "ENTER..." _
        ;;
      2)
        if [[ "$st" != "INSTALADA" ]]; then
          echo -e "${RED}[x]${NC} Instale primeiro (opção 1)."
        else
          run_tool "$dir" "$run" || true
        fi
        read -rp "ENTER..." _
        ;;
      3)
        open_tool_dir "$dir" || true
        read -rp "ENTER..." _
        ;;
      4)
        remove_tool_dir "$dir" || true
        read -rp "ENTER..." _
        ;;
      9) return 0 ;;
      0) echo "Até a próxima!"; exit 0 ;;
      *) echo -e "${RED}[x]${NC} Opção inválida."; read -rp "ENTER..." _ ;;
    esac
  done
}

main_loop() {
  need_cmd awk
  mkdir -p "$DOWNLOAD_DIR"

  local view="all"  # all | installed
  list_view "$view"

  while true; do
    echo -n "> "
    read -r input || exit 0
    input="${input#"${input%%[![:space:]]*}"}"   # trim left
    input="${input%"${input##*[![:space:]]}"}"   # trim right

    case "$input" in
      q|quit|exit)
        echo "Até a próxima!"
        exit 0
        ;;
      l)
        view="all"
        list_view "$view"
        ;;
      li)
        view="installed"
        list_view "$view"
        ;;
      "")
        # Enter só redesenha
        list_view "$view"
        ;;
      s\ *)
        local q="${input#s }"
        [[ -n "$q" ]] || { list_view "$view"; continue; }
        search_view "$q"
        read -rp "> " pick
        pick="${pick#"${pick%%[![:space:]]*}"}"
        pick="${pick%"${pick##*[![:space:]]}"}"
        if [[ "$pick" =~ ^[0-9]+$ ]] && [[ -n "$(tool_by_id "$pick" || true)" ]]; then
          tool_screen "$pick" || true
        fi
        list_view "$view"
        ;;
      *)
        if [[ "$input" =~ ^[0-9]+$ ]] && [[ -n "$(tool_by_id "$input" || true)" ]]; then
          tool_screen "$input" || true
          list_view "$view"
        else
          echo -e "${RED}[x]${NC} Comando inválido."
          echo -e "${CYAN}Use:${NC} ID | l | li | s termo | q"
        fi
        ;;
    esac
  done
}

main_loop
