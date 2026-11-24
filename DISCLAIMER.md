# Advertencia y Uso Responsable

## Alcance

**OPSEC Lab Toolkit** es un conjunto de herramientas de administración de firewall y monitorización de logs diseñado para:

- Laboratorios de análisis de malware propios.
- Entornos de práctica de seguridad ofensiva/defensiva con autorización explícita.
- Máquinas virtuales de análisis controladas.

## Uso prohibido

- Aplicar sobre sistemas que no te pertenezcan o para los que no cuentes con autorización escrita del propietario.
- Utilizar en infraestructura de producción sin una revisión previa de los mecanismos de reset (`ufw reset`) y de las políticas por defecto.
- Cualquier uso que contravenga leyes locales, nacionales o internacionales aplicables.

## Aviso técnico

Los scripts modifican la configuración del firewall del host (`ufw reset` elimina todas las reglas de usuario existentes). Ejecútalos únicamente sobre hosts dedicados al laboratorio y tras revisar el código, que es breve e intencionadamente legible.

## Limitación de responsabilidad

El software se proporciona "tal cual", sin garantía de ningún tipo. El autor no se hace responsable de daños derivados de su uso en entornos no controlados o del uso indebido por terceros.
