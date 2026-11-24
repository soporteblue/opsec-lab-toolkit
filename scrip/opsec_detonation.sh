#!/bin/bash
# ==============================================================================
# OPSEC LAB TOOLKIT - GUEST VM ISOLATION / DETONATION CHAMBER (v3.1)
# ==============================================================================
# Proposito: Contencion de red a nivel de HOST para maquinas virtuales de
#            analisis de malware (libvirt/KVM, VirtualBox, Docker).
#            Bloquea trafico VM<->Host, VM<->LAN y VM<->Internet (FORWARD).
# Notas de alcance:
#   - UFW reduce el riesgo de escape de red, pero NO sustituye un air-gap
#     fisico/total. Para contencion maxima, tambien desconecta el bridge de la
#     VM (virt-manager -> NIC -> isolate / deshabilitar NAT).
#   - libvirt inserta sus propias reglas iptables/nftables en virbrX
#     (masquerade, DHCP/DNS). Verifica el bloqueo con:
#       sudo iptables -L -v -n
# Requisitos: ufw, root
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Patron de interfaces virtuales que se sellaran automaticamente
BRIDGE_PATTERN='virbr|docker0|vboxnet|br-'

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] Se requieren privilegios de root (sudo).${NC}"
        exit 1
    fi
}

draw_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ___  ___ ___ ___ ___   ___ _  _ ___  ___ _____ "
    echo " / _ \| _ / __| __/ __| / __| || / _ \/ __|_   _|"
    echo "| (_) |  _\__ | _| (__ | (_ | __ | (_) \__ \ | |  "
    echo -e "${YELLOW}:: OPSEC FIREWALL & THREAT MONITOR v3.1 (MALWARE LAB EDITION) ::${NC}"
    echo "=================================================="
}

mostrar_menu() {
    draw_banner
    echo -e "${GREEN}[1] ENGAGE GHOST MODE${NC}    (Drop entrante / Allow saliente)"
    echo -e "${RED}[2] DETONATION CHAMBER${NC}  (Aislamiento total Host <-> VMs <-> LAN/Internet)"
    echo -e "${YELLOW}[3] STAND DOWN${NC}          (Desactiva el firewall por completo)"
    echo -e "${CYAN}[4] THREAT RADAR${NC}        (Monitor en tiempo real de paquetes bloqueados)"
    echo -e "${CYAN}[5] OPSEC AUDIT${NC}         (Estado del firewall, bridges detectados, reglas iptables)"
    echo -e "    [6] EXIT"
    echo "=================================================="
    read -p "[OPSEC@LOCAL] > " opcion
}

# Descubre dinamicamente los bridges/interfaces virtuales presentes.
# Evita el hardcodeo de virbr0/virbr1: si libvirt crea virbr2, o el usuario
# usa docker0 o vboxnet0, tambien quedan sellados.
detect_bridges() {
    ip -o link show | awk -F': ' -v pat="$BRIDGE_PATTERN" '$2 ~ pat {print $2}' | sort -u
}

engage_ghost_mode() {
    echo -e "\n${YELLOW}[*] Aislamiento basico del host...${NC}"
    ufw --force reset > /dev/null
    ufw logging on > /dev/null
    ufw default deny incoming > /dev/null
    ufw default allow outgoing > /dev/null
    ufw --force enable > /dev/null
    echo -e "${GREEN}[+] GHOST MODE activado.${NC}"
    sleep 2
}

detonation_chamber() {
    echo -e "\n${RED}[!] PROTOCOLO DE CONTENCION (AIR-GAP DE RED) PARA ANALISIS DE MALWARE${NC}"

    local bridges
    bridges=$(detect_bridges)
    if [ -z "$bridges" ]; then
        echo -e "${YELLOW}[!] No se detectaron bridges virtuales (virbr/docker/vboxnet).${NC}"
        read -p "    ¿Aplicar solo aislamiento basico? [s/N]: " confirm
        [ "$confirm" = "s" ] || [ "$confirm" = "S" ] || return
        engage_ghost_mode
        return
    fi

    echo -e "${CYAN}[*] Bridges/interfaces virtuales detectadas:${NC}"
    for br in $bridges; do echo "    - $br"; done
    read -p "    ¿Sellado total de estas interfaces? [s/N]: " confirm
    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
        echo -e "${CYAN}[*] Operacion cancelada.${NC}"
        return
    fi

    # Base: aislamiento del host
    ufw --force reset > /dev/null
    ufw logging on > /dev/null
    ufw default deny incoming > /dev/null
    ufw default allow outgoing > /dev/null

    # 1. Sellado de cada interfaz virtual detectada (VM -> Host)
    for br in $bridges; do
        echo -e "${YELLOW}[*] Sellando interfaz ${br} (tráfico de entrada al Host)...${NC}"
        ufw deny in on "$br" comment "detonation-in-$br"   > /dev/null
        echo -e "${YELLOW}[*] Sellando interfaz ${br} (tráfico de salida del Host)...${NC}"
        ufw deny out on "$br" comment "detonation-out-$br" > /dev/null
        # 2. Destruccion de la cadena de enrutamiento (VM -> LAN / Internet)
        echo -e "${YELLOW}[*] Bloqueando FORWARD en ${br} (enrutamiento VM -> LAN/Internet)...${NC}"
        ufw route deny in on "$br"  comment "detonation-fwd-in-$br"  > /dev/null
        ufw route deny out on "$br" comment "detonation-fwd-out-$br" > /dev/null
    done

    ufw --force enable > /dev/null

    echo -e "${RED}[+] CAMARA DE DETONACION SELLADA.${NC}"
    echo -e "${RED}[+] Host y VMs aislados a nivel de red (INPUT y FORWARD).${NC}"
    echo -e "${YELLOW}[!] IMPORTANTE:${NC}"
    echo -e "${YELLOW}    1. Verifica el bloqueo real con:  sudo iptables -L -v -n${NC}"
    echo -e "${YELLOW}       (libvirt inserta sus propias reglas que pueden adelantarse a UFW)${NC}"
    echo -e "${YELLOW}    2. Interactua con la muestra solo via consola grafica (SPICE/VNC).${NC}"
    echo -e "${YELLOW}    3. Para contencion maxima, desconecta ademas el bridge de la VM.${NC}"
    sleep 4
}

stand_down() {
    echo -e "\n${YELLOW}[!] Esto desactiva UFW por completo.${NC}"
    read -p "    ¿Continuar? [s/N]: " confirm
    [ "$confirm" = "s" ] || [ "$confirm" = "S" ] || return
    ufw disable > /dev/null
    echo -e "${YELLOW}[-] Firewall inactivo.${NC}"
    sleep 2
}

active_threat_monitor() {
    echo -e "\n${CYAN}[*] THREAT RADAR (Ctrl+C para abortar)...${NC}\n"
    if [ -f /var/log/ufw.log ]; then
        tail -n 0 -f /var/log/ufw.log | grep --line-buffered --color=auto "UFW BLOCK"
    elif command -v journalctl > /dev/null 2>&1; then
        journalctl -kf | grep --line-buffered --color=auto "UFW BLOCK"
    else
        dmesg -w | grep --line-buffered --color=auto "UFW BLOCK"
    fi
}

opsec_audit() {
    echo -e "\n${YELLOW}[*] Reporte de auditoria OPSEC...${NC}"
    echo -e "\n${CYAN}---[ ESTADO DEL FIREWALL ]---${NC}"
    ufw status verbose
    echo -e "\n${CYAN}---[ BRIDGES VIRTUALES DETECTADOS ]---${NC}"
    detect_bridges | sed 's/^/    /'
    echo -e "\n${CYAN}---[ REGLAS iptables/nft DE LIBVIRT (verificacion de contencion) ]---${NC}"
    iptables -L -v -n 2>/dev/null | head -40
    echo -e "\n${GREEN}[+] ENTER para volver al menu.${NC}"
    read
}

check_root
while true; do
    mostrar_menu
    case $opcion in
        1) engage_ghost_mode ;;
        2) detonation_chamber ;;
        3) stand_down ;;
        4) active_threat_monitor ;;
        5) opsec_audit ;;
        6) echo -e "\n${GREEN}[*] Sesion finalizada.${NC}"; exit 0 ;;
        *) echo -e "\n${RED}[!] Opcion no reconocida.${NC}"; sleep 1 ;;
    esac
done
