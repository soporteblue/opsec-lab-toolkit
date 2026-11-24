# OPSEC Lab Toolkit

**Firewall host-based y monitorización de amenazas para laboratorios de análisis de malware y práctica de seguridad ofensiva/defensiva.**

Colección de herramientas bash para Linux que automatizan la postura de seguridad de un host de laboratorio: aislamiento de red (drop-by-default), contención de máquinas virtuales de análisis y monitorización en tiempo real de paquetes bloqueados.

> **Estado:** v2.1 / v3.1 — probado en Ubuntu 22.04/24.04 con UFW + libvirt/KVM.

---

## Por qué existe

Al montar un laboratorio de análisis de malware o práctica red team, el problema recurrente es la **contención de red**: la VM de análisis puede escapar hacia el host, hacia la LAN o hacia Internet. Este toolkit:

1. Aísla el **host de laboratorio** con políticas estrictas de UFW (drop entrante por defecto).
2. Sella las **interfaces virtuales** (virbrX, docker0, vboxnetX) para impedir que una VM comprometida ataque al host o pivote a la LAN.
3. Da **visibilidad** de todo lo que el firewall bloquea, en tiempo real.

## Componentes

### `opsec_ghost.sh` — Host Firewall & Threat Monitor (v2.1)
Menú interactivo para el host de laboratorio:

| Modo | Función |
|---|---|
| **Engage Ghost Mode** | `ufw reset` + política `deny incoming` / `allow outgoing` + logging. Preserva acceso SSH desde la red de gestión (`OPSEC_MGMT_NET`) **antes** de activar el firewall, para no cortar la sesión remota. |
| **Stand Down** | Desactiva UFW por completo (con confirmación). |
| **Threat Radar** | Monitor en vivo de paquetes bloqueados (`ufw.log` → `journald` → `dmesg`, triple fallback). |
| **OPSEC Audit** | Puertos a la escucha (`ss -tuln`), estado del firewall, interfaces. |

**Variables de entorno opcionales:**
```bash
export OPSEC_MGMT_NET="192.168.1.0/24"   # red que conserva acceso SSH
export OPSEC_MGMT_PORT="22"
```

### `opsec_detonation.sh` — Guest VM Isolation / Detonation Chamber (v3.1)
Edición para laboratorios de análisis de malware con KVM/VirtualBox/Docker:

| Modo | Función |
|---|---|
| **Detonation Chamber** | Detecta **dinámicamente** los bridges virtuales (no hardcodeados) y aplica bloqueo en INPUT (`VM → Host`), OUTPUT (`Host → VM`) y FORWARD (`VM → LAN/Internet`) para cada uno. |
| **OPSEC Audit** | Muestra además las reglas iptables de libvirt para verificar la contención real. |

### `cyber_radar.sh` — Threat Radar (v2.0)
Visualizador en tiempo real del log de bloqueos de UFW:
- Parseo en vivo con `grep --line-buffered` (sin buffering en pipelines).
- Resaltado de puertos críticos: 22, 80, 443, 3389, 445, 135.
- Contador total y, al salir con Ctrl+C, **resumen con top 5 IPs de origen** por número de bloqueos.

## Requisitos

- Linux (probado en Ubuntu/Debian), `root`/sudo.
- `ufw` (instalado por defecto en Ubuntu).
- Opcional: `libvirt`/KVM, VirtualBox o Docker para el modo Detonation Chamber.

## Instalación

```bash
git clone https://github.com/<tu-usuario>/opsec-lab-toolkit.git
cd opsec-lab-toolkit
chmod +x *.sh
sudo ./opsec_ghost.sh        # o ./opsec_detonation.sh / ./cyber_radar.sh
```

## Uso recomendado en un lab de malware

1. En el **host**: ejecuta `opsec_detonation.sh` → opción **2 (Detonation Chamber)** antes de arrancar la VM de análisis.
2. Verifica la contención con la opción **5 (OPSEC Audit)**: revisa que las reglas `deny` de UFW estén presentes en `iptables -L -v -n`.
3. Interactúa con la muestra **solo vía consola gráfica** (SPICE/VNC), nunca por SSH a la VM.
4. En otra terminal, `sudo ./cyber_radar.sh` para ver intentos de escape de la VM en tiempo real.

## Limitaciones conocidas (léelo, en serio)

- **UFW no sustituye un air-gap real.** Para contención máxima, desconecta además el bridge de la VM (virt-manager → NIC → "isolate") o usa una red virtual sin gateway. UFW reduce el riesgo de escape de red; no lo elimina.
- **libvirt inserta sus propias reglas** iptables/nftables (masquerade, DHCP/DNS) que pueden preceder a las de UFW en el orden de evaluación. Verifica siempre con `iptables -L -v -n`.
- `ufw reset` **borra todas las reglas de usuario**. Los scripts piden confirmación, pero revisa si tu host tiene reglas que necesites conservar.
- El modo **Stand Down** desactiva el firewall por completo; no es "exposición controlada".

## Advertencia y uso responsable

Este toolkit está diseñado para **laboratorios propios y entornos con autorización explícita**. No está pensado para hosts de producción sin revisar los mecanismos de reset y las políticas por defecto. El autor no se hace responsable del uso indebido ni de configuraciones aplicadas fuera de entornos controlados.

## Licencia

MIT — consulta [LICENSE](LICENSE).
