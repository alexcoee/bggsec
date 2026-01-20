#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# bggsec - tool manager
# =========================

# ---- Cores (verde e roxo) ----
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---- Config ----
APP_NAME="bggsec"
VERSION="v0.1"
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

banner() {
  clear
  echo -e "${PURPLE}   ____  ____   ____  ____  ____   ______"
  echo -e "  / __ )/ __ \\ / __ \\/ __ \\/ __ \\ / ____/"
  echo -e " / __  / /_/ // /_/ / /_/ / /_/ // __/   "
  echo -e "/ /_/ / ____// _, _/ ____/ _, _// /___   "
  echo -e "/_____/_/    /_/ |_/_/   /_/ |_|/_____/   ${NC}"
  echo -e "  ${GREEN}${APP_NAME}${NC} ${CYAN}${VERSION}${NC}  |  Tool Manager (Wireless/Radio)  |  ${YELLOW}Git required${NC}"
  echo -e "  ------------------------------------------------------------"
  echo ""
}

# Lê o TSV ignorando header, vazias e comentários
tools_lines() {
  [[ -f "$TOOLS_FILE" ]] || die "Arquivo não encontrado: $TOOLS_FILE"
  awk -F'\t' '
    NR==1 {next}
    /^\s*$/ {next}
    $0 ~ /^\s*#/ {next}
    {print}
  ' "$TOOLS_FILE"
}

# Busca uma tool pelo ID (retorna linha inteira)
tool_by_id() {
  local id="$1"
  tools_lines | awk -F'\t' -v id="$id" '$1==id {print; exit}'
}

repo_is_git_cloneable() {
  local repo="$1"
  # Heurística simples: URLs .git ou git@... ou https://...git
  [[ "$repo" =~ \.git$ ]] && return 0
  [[ "$repo" =~ ^git@ ]] && return 0
  [[ "$repo" =~ ^https:// ]] && [[ "$repo" =~ \.git($|\?) ]] && return 0
  return 1
}

install_tool() {
  local id="$1"
  local line
  line="$(tool_by_id "$id" || true)"
  [[ -n "$line" ]] || die "ID inválido: $id"

  local _id cat name dir repo desc
  IFS=$'\t' read -r _id cat name dir repo desc <<<"$line"

  [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
  local dest="${DOWNLOAD_DIR}/${dir}"

  mkdir -p "$DOWNLOAD_DIR"
  need_cmd git

  if ! repo_is_git_cloneable "$repo"; then
    echo -e "${RED}[x]${NC} Esse repo não parece clonável via git diretamente:"
    echo -e "    ${CYAN}${repo}${NC}"
    echo -e "${YELLOW}Dica:${NC} abra o link e procure a URL .git (Clone)."
    return 1
  fi

  if [[ -d "$dest/.git" ]]; then
    echo -e "${CYAN}[*]${NC} Já existe: ${GREEN}${name}${NC} -> atualizando..."
    git -C "$dest" pull --rebase --autostash || die "Falha ao atualizar: $name"
  else
    echo -e "${YELLOW}[*]${NC} Baixando ${GREEN}${name}${NC}..."
    git clone "$repo" "$dest" || die "Falha ao clonar: $repo"
  fi

  echo -e "${GREEN}[+]${NC} Pronto: ${name}"
  echo -e "${CYAN}    Pasta:${NC} $dest"
}

list_tools() {
  mkdir -p "$DOWNLOAD_DIR"
  echo -e "${YELLOW}ID | Categoria | Nome | Status${NC}"
  echo "-----------------------------------------------"
  while IFS=$'\t' read -r id cat name dir repo desc; do
    [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"
    local dest="${DOWNLOAD_DIR}/${dir}"
    local status="NAO_INSTALADA"
    [[ -d "$dest/.git" ]] && status="INSTALADA"
    printf "%s | %s | %s | %s\n" "$id" "$cat" "$name" "$status"
  done < <(tools_lines)
  echo ""
}

help_screen() {
  banner
  cat <<EOF
${GREEN}${APP_NAME}${NC} ajuda

- Digite o ID (número) de uma ferramenta para ver detalhes e confirmar download.
- Opções:
  1) Listar ferramentas
  2) Buscar por nome (filtro simples)
  3) Atualizar/Instalar tudo (cuidado: pode demorar e baixar muita coisa)
  0) Sair

Diretórios:
- Tools: ${DOWNLOAD_DIR}
- Base de dados: ${TOOLS_FILE}

EOF
  read -rp "ENTER para voltar..." _
}

search_tools() {
  local q="$1"
  banner
  echo -e "${YELLOW}Resultados para:${NC} ${CYAN}${q}${NC}"
  echo "-----------------------------------------------"
  tools_lines | awk -F'\t' -v q="$q" '
    BEGIN{IGNORECASE=1}
    $3 ~ q || $2 ~ q || $6 ~ q {printf "%s | %s | %s\n", $1, $2, $3}
  '
  echo ""
  read -rp "ENTER para voltar..." _
}

tool_details_screen() {
  local id="$1"
  local line
  line="$(tool_by_id "$id" || true)"
  [[ -n "$line" ]] || { echo -e "${RED}[x]${NC} ID inválido."; read -rp "ENTER..." _; return; }

  local _id cat name dir repo desc
  IFS=$'\t' read -r _id cat name dir repo desc <<<"$line"
  [[ -n "$dir" ]] || dir="$(safe_dirname "$name")"

  local dest="${DOWNLOAD_DIR}/${dir}"
  local status="NAO_INSTALADA"
  [[ -d "$dest/.git" ]] && status="INSTALADA"

  while true; do
    banner
    echo -e "${YELLOW}Ferramenta:${NC} ${GREEN}${name}${NC}"
    echo -e "${YELLOW}Categoria:${NC} ${CYAN}${cat}${NC}"
    echo -e "${YELLOW}Status:${NC} ${CYAN}${status}${NC}"
    echo ""
    echo -e "${YELLOW}Resumo:${NC}"
    echo -e "  ${desc}"
    echo ""
    echo -e "${YELLOW}Repo:${NC} ${CYAN}${repo}${NC}"
    echo -e "${YELLOW}Destino:${NC} ${CYAN}${dest}${NC}"
    echo ""
    echo -e "${PURPLE}Opções:${NC}"
    echo "  1) Baixar / Atualizar"
    echo "  2) Voltar"
    echo "  0) Sair"
    echo ""

    read -rp "Escolha: " opt
    case "$opt" in
      1)
        read -rp "Confirmar download/atualização de '${name}'? [s/N]: " conf
        if [[ "${conf,,}" == "s" || "${conf,,}" == "sim" ]]; then
          install_tool "$id" || true
          status="INSTALADA"
        else
          echo -e "${CYAN}[*]${NC} Cancelado."
        fi
        read -rp "ENTER para continuar..." _
        ;;
      2) return ;;
      0) echo "Até a próxima!"; exit 0 ;;
      *) echo -e "${RED}[x]${NC} Opção inválida."; read -rp "ENTER..." _ ;;
    esac
  done
}

install_update_all() {
  banner
  echo -e "${YELLOW}Isso vai tentar clonar/atualizar TODAS as ferramentas.${NC}"
  read -rp "Confirmar? [s/N]: " conf
  [[ "${conf,,}" == "s" || "${conf,,}" == "sim" ]] || return

  need_cmd git
  mkdir -p "$DOWNLOAD_DIR"

  while IFS=$'\t' read -r id cat name dir repo desc; do
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

main_menu() {
  need_cmd awk

  while true; do
    banner
    echo -e "${PURPLE}Menu:${NC}"
    echo "  1) Listar ferramentas"
    echo "  2) Buscar por nome"
    echo "  3) Instalar/Atualizar tudo"
    echo "  4) Ajuda"
    echo "  0) Sair"
    echo ""
    echo -e "${YELLOW}Ou digite um ID (número) para ver detalhes e confirmar download.${NC}"
    echo ""

    read -rp "Escolha: " opt
    case "$opt" in
      1) banner; list_tools; read -rp "ENTER para voltar..." _ ;;
      2)
        read -rp "Buscar (termo): " q
        [[ -n "$q" ]] && search_tools "$q"
        ;;
      3) install_update_all ;;
      4) help_screen ;;
      0) echo "Até a próxima!"; exit 0 ;;
      *)
        # Se for número e existir ID, abre detalhes
        if [[ "$opt" =~ ^[0-9]+$ ]] && [[ -n "$(tool_by_id "$opt" || true)" ]]; then
          tool_details_screen "$opt"
        else
          echo -e "${RED}[x]${NC} Opção inválida."
          read -rp "ENTER..." _
        fi
        ;;
    esac
  done
}

main_menu
