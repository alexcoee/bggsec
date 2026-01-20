#!/usr/bin/env bash
set -Eeuo pipefail

# ---- Cores - green and purple ----
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_NAME="bggsec"
VERSION="v0.3"

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
  echo -e "${PURPLE}"
  echo "  ██████╗  ██████╗  ██████╗ ███████╗███████╗ ██████╗"
  echo "  ██╔══██╗██╔════╝ ██╔════╝ ██╔════╝██╔════╝██╔════╝"
  echo "  ██████╔╝██║  ███╗██║  ███╗███████╗█████╗  ██║     "
  echo "  ██╔══██╗██║   ██║██║   ██║╚════██║██╔══╝  ██║     "
  echo "  ██████╔╝╚██████╔╝╚██████╔╝███████║███████╗╚██████╗"
  echo "  ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝╚══════╝ ╚═════╝"
  echo -e "${NC}"
  echo -e "  ${GREEN}${APP_NAME}${NC} ${CYAN}${VERSION}${NC}  |  Unified Tool Manager  |  ${YELLOW}Kali / Pentest${NC}"
  echo -e "  ------------------------------------------------------------"
  echo ""
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
}

launch_new_terminal() {
  local dest="$1"
  local run_cmd="$2"
  local label="${3:-Ferramenta}"

  local payload='cd "$BGGSEC_DEST" && echo -e "\n[BGGSEC] Rodando: $BGGSEC_TOOL_NAME\n" && eval "$BGGSEC_RUN_CMD"; echo ""; read -rp "ENTER para fechar esta aba..." _'
  local -a env_payload=(
    BGGSEC_DEST="$dest"
    BGGSEC_RUN_CMD="$run_cmd"
    BGGSEC_TOOL_NAME="$label"
    BGGSEC_PAYLOAD="$payload"
  )

  if [[ -n "${NEW_TERMINAL_CMD:-}" ]]; then
    "${env_payload[@]}" bash -lc "$NEW_TERMINAL_CMD"
    return $?
  fi

  if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
    "${env_payload[@]}" tmux new-window -n "$label" "bash -lc '$payload'"
    return 0
  fi

  if command -v gnome-terminal >/dev/null 2>&1; then
    "${env_payload[@]}" gnome-terminal -- bash -lc "$payload" >/dev/null 2>&1 &
    disown || true
    return 0
  fi

  if command -v xfce4-terminal >/dev/null 2>&1; then
    "${env_payload[@]}" xfce4-terminal --title="$label" -e "bash -lc '$payload'" >/dev/null 2>&1 &
    disown || true
    return 0
  fi

  if command -v konsole >/dev/null 2>&1; then
    "${env_payload[@]}" konsole --new-tab -p tabtitle="$label" -e bash -lc "$payload" >/dev/null 2>&1 &
    disown || true
    return 0
  fi

  if command -v x-terminal-emulator >/dev/null 2>&1; then
    "${env_payload[@]}" x-terminal-emulator -T "$label" -e bash -lc "$payload" >/dev/null 2>&1 &
    disown || true
    return 0
  fi

  if command -v xterm >/dev/null 2>&1; then
    "${env_payload[@]}" xterm -T "$label" -e bash -lc "$payload" >/dev/null 2>&1 &
    disown || true
    return 0
  fi

  if command -v wt.exe >/dev/null 2>&1; then
    "${env_payload[@]}" wt.exe -w 0 nt --title "$label" wsl bash -lc "$payload" >/dev/null 2>&1 &
    disown || true
    return 0
  fi

  return 1
}

run_tool() {
  local dir="$1"
  local run_cmd="$2"
  local name="${3:-Ferramenta}"

  local dest="${DOWNLOAD_DIR}/${dir}"
  [[ -d "$dest" ]] || { echo -e "${RED}[x]${NC} Ferramenta não instalada."; return 1; }
  [[ -n "$run_cmd" && "$run_cmd" != "-" ]] || { echo -e "${RED}[x]${NC} Sem comando de execução definido."; return 1; }

  echo -e "${CYAN}[*]${NC} Executando em ${dest}"
  echo -e "${YELLOW}[*]${NC} Comando: ${run_cmd}"

  local spawn_requested=0
  if [[ "${BGGSEC_AUTOSPAWN_TERM:-0}" == "1" ]]; then
    spawn_requested=1
  fi
  if [[ -n "${NEW_TERMINAL_CMD:-}" ]]; then
    spawn_requested=1
  fi

  if [[ "$spawn_requested" == "1" ]]; then
    if launch_new_terminal "$dest" "$run_cmd" "$name"; then
      echo -e "${GREEN}[+]${NC} Terminal externo aberto (${name})."
      return 0
    elif [[ "${BGGSEC_AUTOSPAWN_TERM:-0}" == "1" ]]; then
      echo -e "${YELLOW}[!]${NC} Não consegui abrir novo terminal. Rodando inline."
    fi
  fi

  echo -e "${YELLOW}[*]${NC} Ctrl+C para encerrar a ferramenta e voltar."
  echo ""

  (cd "$dest" && bash -c "$run_cmd")
}

list_all_tools() {
  banner
  echo -e "${YELLOW}ID | Cat | Nome | Status${NC}"
  echo "-----------------------------------------------"
  mkdir -p "$DOWNLOAD_DIR"

  while IFS=$'\t' read -r id cat name dir repo run desc; do
    [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
    local st
    st="$(tool_status "$dir")"
    printf "%s | %s | %s | %s\n" "$id" "$cat" "$name" "$st"
  done < <(tools_lines)
  echo ""
  read -rp "ENTER para voltar..." _
}

search_tools() {
  local q="$1"
  banner
  echo -e "${YELLOW}Busca:${NC} ${CYAN}${q}${NC}"
  echo "-----------------------------------------------"
  tools_lines | awk -F'\t' -v q="$q" '
    BEGIN{IGNORECASE=1}
    $3 ~ q || $2 ~ q || $7 ~ q {printf "%s | %s | %s\n", $1, $2, $3}
  '
  echo ""
  read -rp "Digite um ID para abrir (ou ENTER para voltar): " pick
  [[ -z "$pick" ]] && return 0
  if [[ "$pick" =~ ^[0-9]+$ ]] && [[ -n "$(tool_by_id "$pick" || true)" ]]; then
    tool_screen "$pick" || true
  else
    echo -e "${RED}[x]${NC} ID inválido."
    read -rp "ENTER..." _
  fi
}

help_screen() {
  banner
  cat <<EOF
${GREEN}${APP_NAME}${NC} ajuda

- Menu por opções (1..5).
- Você pode abrir uma ferramenta digitando o ID quando estiver em:
  - Listagem
  - Busca
  - Instalados

Dica:
- No WSL/Windows, ferramentas wireless (monitor mode/injeção) podem não funcionar.

EOF
  read -rp "ENTER para voltar..." _
}

install_update_all() {
  banner
  echo -e "${YELLOW}Isso vai tentar clonar/atualizar TODAS as ferramentas.${NC}"
  read -rp "Confirmar? [s/N]: " conf
  [[ "${conf,,}" == "s" || "${conf,,}" == "sim" ]] || return 0

  need_cmd git
  mkdir -p "$DOWNLOAD_DIR"

  while IFS=$'\t' read -r id cat name dir repo run desc; do
    [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
    local dest="${DOWNLOAD_DIR}/${dir}"

    echo -e "${CYAN}[*]${NC} ${name}"
    if repo_is_git_cloneable "$repo"; then
      if [[ -d "$dest/.git" ]]; then
        git -C "$dest" pull --rebase --autostash || echo -e "${RED}[x]${NC} Falhou: $name"
      else
        git clone "$repo" "$dest" || echo -e "${RED}[x]${NC} Falhou: $name"
      fi
    else
      echo -e "${RED}[x]${NC} Repo não clonável (sem .git): ${repo}"
    fi
    echo ""
  done < <(tools_lines)

  echo -e "${GREEN}[+]${NC} Finalizado."
  read -rp "ENTER para voltar..." _
}

# --- Tela da ferramenta (detalhes + executar) ---
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
    echo "  9) Voltar"
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
          read -rp "ENTER..." _
        else
          run_tool "$dir" "$run" "$name" || true
        fi
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

# --- Tela Instalados: lista numerada só dos baixados ---
installed_screen() {
  while true; do
    banner
    echo -e "${YELLOW}Instalados:${NC}"
    echo "-----------------------------------------------"

    mkdir -p "$DOWNLOAD_DIR"

    # 
    # Mostra: 1) ID/Nome
    local idx=0
    local ids=()

    while IFS=$'\t' read -r id cat name dir repo run desc; do
      [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
      if [[ -d "${DOWNLOAD_DIR}/${dir}/.git" ]]; then
        idx=$((idx+1))
        ids+=("$id")
        printf "%d) [%s] %s\n" "$idx" "$id" "$name"
      fi
    done < <(tools_lines)

    echo ""
    echo "Selecione o ID da ferramenta para abrir."
    echo "  9) Voltar"
    echo "  0) Sair"
    echo ""

    read -rp "Escolha: " opt
    case "$opt" in
      9) return 0 ;;
      0) echo "Até a próxima!"; exit 0 ;;
      *)
        if [[ "$opt" =~ ^[0-9]+$ ]] && (( opt >= 1 && opt <= idx )); then
          local real_id="${ids[$((opt-1))]}"
          tool_screen "$real_id" || true
        else
          echo -e "${RED}[x]${NC} Opção inválida."
          read -rp "ENTER..." _
        fi
        ;;
    esac
  done
}

main_menu() {
  need_cmd awk
  mkdir -p "$DOWNLOAD_DIR"

  while true; do
    banner
    echo "Menu:"
    echo "  1) Lista de ferramentas"
    echo "  2) Buscar por nome"
    echo "  3) Instalar/Atualizar tudo"
    echo "  4) Instalados"
    echo ""
    echo "  5) Ajuda"
    echo "  0) Sair"
    echo ""
    echo -e "${YELLOW}Busca:${NC} digite o ID da ferramenta."
    echo ""

    read -rp "Escolha: " opt
    case "$opt" in
      1) list_all_tools ;;
      2)
        read -rp "Termo de busca: " q
        [[ -n "$q" ]] && search_tools "$q"
        ;;
      3) install_update_all ;;
      4) installed_screen ;;
      5) help_screen ;;
      0) echo "Até a próxima!"; exit 0 ;;
      *)
        # mensagem de erro se não achar o ID
        if [[ "$opt" =~ ^[0-9]+$ ]] && [[ -n "$(tool_by_id "$opt" || true)" ]]; then
          tool_screen "$opt" || true
        else
          echo -e "${RED}[x]${NC} Opção inválida."
          read -rp "ENTER..." _
        fi
        ;;
    esac
  done
}

main_menu
