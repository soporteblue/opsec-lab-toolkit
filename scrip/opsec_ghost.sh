#!/bin/bash
# ==============================================================================
# OPSEC LAB TOOLKIT - HOST FIREWALL & THREAT MONITOR (v2.1)
# ==============================================================================
# Proposito: Aislamiento de un host de laboratorio (Drop-by-Default),
#            monitorizacion de conexiones entrantes y auditoria de superficie.
# Diseñado para: laboratorios de analisis propios. NO para hosts de produccion
#            sin revisar el mecanismo de reset de reglas.
# Requisitos: ufw, root
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Configuracion ---
# IP o red de administracion que SIEMPRE conservara acceso por SSH.
# Cambiala por la tuya antes de usar el modo remoto (ej. 192.168.1.0/24).
MANAGEMENT_NET="${OPSEC_MGMT_NET:-192.168.1.0/24}"
MANAGEMENT_PORT="${OPSEC_MGMT_PORT:-22}"

draw_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ___  ___ ___ ___ ___   ___ _  _ ___  ___ _____ "
    echo " / _ \| _ / __| __/ __| / __| || / _ \/ __|_   _|"
    echo "| (_) |  _\__ | _| (__ | (_ | __ | (_) \__ \ | |  "
    echo " \___/|_| |___|___|___| \___|_||_\___| \___|_||_  "
    echo -e "${YELLOW}:: OPSEC FIREWALL & THREAT MONITOR v2.1 ::${NC}"
    echo "=================================================="
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] Se requieren privilegios de root (sudo).${NC}"
        exit 1
    fi
}

mostrar_menu() {
    draw_banner
    echo -e "    Red de gestion protegida: ${CYAN}${MANAGEMENT_NET}:${MANAGEMENT_PORT}${NC} (export OPSEC_MGMT_NET para cambiarla)"
    echo "=================================================="
    echo -e "${GREEN}[1] ENGAGE GHOST MODE${NC}   (Drop entrante / Allow saliente / Log ON)"
    echo -e "${RED}[2] STAND DOWN${NC}          (Desactiva el firewall por completo)"
    echo -e "${CYAN}[3] THREAT RADAR${NC}        (Monitor en tiempo real de paquetes bloqueados)"
    echo -e "${YELLOW}[4] OPSEC AUDIT${NC}         (Puertos a la escucha, estado del firewall, interfaces)"
    echo -e "    [5] EXIT"
    echo "=================================================="
    read -p "[OPSEC@LOCAL] > " opcion
}

engage_ghost_mode() {
    echo -e "\n${YELLOW}[*] Iniciando aislamiento del host...${NC}"

    echo -e "${YELLOW}[!] AVISO: se ejecutara 'ufw reset'. Todas las reglas UFW existentes seran borradas.${NC}"
    read -p "    ¿Continuar? [s/N]: " confirm
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
        echo -e "${CYAN}[*] Operacion cancelada por el usuario.${NC}"
        sleep 1
        return
    fi

    ufw --force reset > /dev/null
    ufw logging on > /dev/null

    # Regla de seguridad: preservar la via de administracion ANTES de activar
    # las politicas por defecto. Sin esto, ejecutar el script por SSH corta
    # la sesion en el momento del 'ufw enable'.
    echo -e "${YELLOW}[*] Preservando acceso de administracion desde ${MANAGEMENT_NET}:${MANAGEMENT_PORT}...${NC}"
    ufw allow from "$MANAGEMENT_NET" to any port "$MANAGEMENT_PORT" proto tcp comment 'opsec-mgmt' > /dev/null

    ufw default deny incoming  > /dev/null
    ufw default allow outgoing > /dev/null
    ufw --force enable > /dev/null

    echo -e "${GREEN}[+] GHOST MODE activado: entrante DROP, saliente ALLOW, logging ON.${NC}"
    echo -e "${GREEN}[+] Acceso de gestion preservado desde ${MANAGEMENT_NET}.${NC}"
    sleep 3
}

stand_down() {
    echo -e "\n${RED}[!] Esto desactiva UFW por completo (no es exposicion controlada).${NC}"
    read -p "    ¿Continuar? [s/N]: " confirm
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
        return
    fi
    ufw disable > /dev/null
    echo -e "${RED}[-] Firewall inactivo. Postura defensiva reducida.${NC}"
    sleep 2
}

active_threat_monitor() {
    echo -e "\n${CYAN}[*] THREAT RADAR: paquetes bloqueados en tiempo real (Ctrl+C para abortar)...${NC}\n"
    if [ -f /var/log/ufw.log ]; then
        tail -n 0 -f /var/log/ufw.log | grep --line-buffered --color=auto "UFW BLOCK"
    elif command -v journalctl > /dev/null 2>&1; then
        # Fallback para sistemas sin rsyslog (journald persistente o en vivo)
        journalctl -kf | grep --line-buffered --color=auto "UFW BLOCK"
    else
        dmesg -w | grep --line-buffered --color=auto "UFW BLOCK"
    fi
}

opsec_audit() {
    echo -e "\n${YELLOW}[*] Reporte de auditoria OPSEC...${NC}"
    echo -e "\n${CYAN}---[ ESTADO DEL FIREWALL ]---${NC}"
    ufw status verbose
    echo -e "\n${CYAN}---[ PUERTOS LOCALES A LA ESCUCHA ]---${NC}"
    ss -tuln
    echo -e "\n${CYAN}---[ INTERFACES DE RED ]---${NC}"
    ip -brief address
    echo -e "\n${GREEN}[+] Auditoria completada. ENTER para volver al menu.${NC}"
    read
}

check_root
while true; do
    mostrar_menu
    case $opcion in
        1) engage_ghost_mode ;;
        2) stand_down ;;
        3) active_threat_monitor ;;
        4) opsec_audit ;;
        5) echo -e "\n${GREEN}[*] Sesion finalizada.${NC}"; exit 0 ;;
        *) echo -e "\n${RED}[!] Opcion no reconocida.${NC}"; sleep 1 ;;
    esac
done
