#!/bin/bash
# ==============================================================================
# OPSEC LAB TOOLKIT - THREAT RADAR (v2.0)
# ==============================================================================
# Proposito: Visualizacion en tiempo real de paquetes bloqueados por UFW,
#            con resaltado de puertos criticos y estadisticas en vivo.
# Requisitos: root (lectura de logs del kernel)
# ==============================================================================

RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;201m'
YELLOW='\033[38;5;226m'
WHITE='\033[38;5;231m'
DIM='\033[2m'
RESET='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Se requieren privilegios de root para leer los logs del kernel.${RESET}"
  exit 1
fi

clear
echo -e "${CYAN}==========================================================================${RESET}"
echo -e "${CYAN} ${MAGENTA}/// THREAT RADAR /// MONITOR DE PAQUETES BLOQUEADOS POR UFW /// ${CYAN}${RESET}"
echo -e "${CYAN}==========================================================================${RESET}"
echo -e "${DIM}[*] A la espera de eventos. Ctrl+C para abortar y ver resumen.${RESET}\n"

# --- Seleccion de fuente de logs con triple fallback ---
LOG_FILE=""
if [ -f /var/log/ufw.log ]; then
    LOG_FILE="/var/log/ufw.log"
    log_cmd=(tail -n 0 -f "$LOG_FILE")
elif [ -f /var/log/kern.log ]; then
    LOG_FILE="/var/log/kern.log"
    log_cmd=(tail -n 0 -f "$LOG_FILE")
elif command -v journalctl > /dev/null 2>&1; then
    # Sistemas con journald sin rsyslog
    log_cmd=(journalctl -kf)
    echo -e "${DIM}[*] Fuente: journald (kernel).${RESET}"
else
    echo -e "${RED}[!] No se encontro fuente de logs (ufw.log / kern.log / journald).${RESET}"
    exit 1
fi

# --- Estadisticas en vivo ---
declare -A SRC_COUNT
TOTAL=0
SUMMARY_FILE=$(mktemp)
trap 'echo "$TOTAL" > "$SUMMARY_FILE"; for k in "${!SRC_COUNT[@]}"; do echo "${SRC_COUNT[$k]} $k" >> "$SUMMARY_FILE"; done' EXIT

print_summary() {
    echo -e "\n${YELLOW}=== RESUMEN DE LA SESION ===${RESET}"
    echo -e "${WHITE}Total de paquetes bloqueados: ${RED}${TOTAL}${RESET}"
    echo -e "${WHITE}Top orígenes (SRC) por paquetes bloqueados:${RESET}"
    # Ordenar las IPs por contador descendente
    for k in "${!SRC_COUNT[@]}"; do echo "${SRC_COUNT[$k]} $k"; done \
        | sort -rn | head -5 \
        | while read -r count ip; do
            echo -e "  ${YELLOW}${ip}${RESET}: ${GREEN}${count}${RESET} bloqueos"
          done
    echo -e "${DIM}(El resumen también se guardo en: $SUMMARY_FILE)${RESET}"
}
trap 'print_summary; exit 0' SIGINT SIGTERM

# --- Motor de parseo en vivo ---
# Se usa process substitution (< <(...)) en lugar de un pipe para que el bucle
# while se ejecute en el shell PRINCIPAL: si se usara un pipe, TOTAL y SRC_COUNT
# se incrementarian en un subshell y el resumen al salir mostraria siempre 0.
while read -r line; do

    TIMESTAMP=$(echo "$line" | awk '{print $1, $2, $3}')
    SRC=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+')
    DST=$(echo "$line" | grep -oP 'DST=\K[0-9.]+')
    DPT=$(echo "$line" | grep -oP 'DPT=\K[0-9]+' || true)
    PROTO=$(echo "$line" | grep -oP 'PROTO=\K[A-Za-z0-9]+' || true)
    IN_IF=$(echo "$line" | grep -oP 'IN=\K[a-zA-Z0-9]+' || true)

    # Ignorar lineas corruptas sin IP de origen
    [ -z "$SRC" ] && continue

    DPT="${DPT:---}"
    PROTO="${PROTO:-???}"
    IN_IF="${IN_IF:---}"

    # Contadores usados por el resumen (el bucle corre en el shell principal
    # gracias a process substitution, no en un subshell de pipe)
    TOTAL=$((TOTAL+1))
    SRC_COUNT["$SRC"]=$(( ${SRC_COUNT["$SRC"]:-0} + 1 ))

    # Resaltado de puertos criticos (SSH, HTTP/S, RDP, SMB)
    PORT_COLOR=$WHITE
    case "$DPT" in
        22|80|443|3389|445|135) PORT_COLOR=$RED ;;
    esac

    echo -e "${RED}[DROP]${RESET} ${DIM}[${TIMESTAMP}]${RESET} ${CYAN}INT:${IN_IF}${RESET} ${MAGENTA}>${RESET} ${YELLOW}SRC:${RESET} ${SRC} ${MAGENTA}>${RESET} ${YELLOW}DST:${RESET} ${DST} ${MAGENTA}>${RESET} ${GREEN}${PROTO}${RESET} ${MAGENTA}>${RESET} ${YELLOW}PORT:${RESET} ${PORT_COLOR}${DPT}${RESET} ${DIM}(total: ${TOTAL})${RESET}"

done < <("${log_cmd[@]}" | grep --line-buffered "UFW BLOCK")
