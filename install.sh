#!/bin/bash
set -e

# Enforce root execution
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g. curl ... | sudo bash)"
  exit 1
fi

echo "Installing HCE Labs MOTD..."

# 1. Clean default Debian/Ubuntu MOTD noise
> /etc/motd 2>/dev/null || true

# 2. Write dynamic MOTD script
cat << 'EOF' > /etc/profile.d/00_hce_motd.sh
#!/bin/sh

# Colors & Typography
C1='\033[38;5;39m'    # Deep Sky Blue
C2='\033[38;5;45m'    # Bright Cyan
C3='\033[38;5;51m'    # Aqua
WHT='\033[1;37m'
GRY='\033[38;5;240m'  # Border Grey
MUT='\033[38;5;245m'  # Muted Grey
GRN='\033[1;32m'
YLW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# OSC 8 Terminal Hyperlink for modern terminals (falls back cleanly)
HCE_LINK="\033]8;;https://hce.vn\033\\https://hce.vn\033]8;;\033\\"

# Dynamic Host & Environment
OS_NAME="$(grep ^NAME /etc/os-release | cut -d= -f2 | tr -d '"') $(grep ^VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
DEFAULT_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
[ -z "$DEFAULT_IP" ] && DEFAULT_IP="$(hostname -I | awk '{print $1}')"
VIRT_TYPE="$(systemd-detect-virt 2>/dev/null || echo "baremetal")"

# Dynamic Metrics
UPTIME="$(uptime -p 2>/dev/null | sed 's/up //')"
LOAD="$(awk '{print $1", "$2", "$3}' /proc/loadavg)"

# Dynamic Memory Calculation & Visual Bar
MEM_USED_MB=$(free -m | awk '/Mem:/ {print $3}')
MEM_TOTAL_MB=$(free -m | awk '/Mem:/ {print $2}')
MEM_PCT=$((MEM_USED_MB * 100 / MEM_TOTAL_MB))

BAR_SIZE=10
FILLED=$((MEM_PCT * BAR_SIZE / 100))
EMPTY=$((BAR_SIZE - FILLED))
BAR_COLOR="${GRN}"
[ "$MEM_PCT" -ge 70 ] && BAR_COLOR="${YLW}"
[ "$MEM_PCT" -ge 90 ] && BAR_COLOR="${RED}"

BAR=""
[ "$FILLED" -gt 0 ] && BAR="${BAR}$(printf "%0.s█" $(seq 1 $FILLED))"
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%0.s░" $(seq 1 $EMPTY))"

DISK_USAGE="$(df -h / | awk 'NR==2 { printf "%s/%s (%s)", $3, $2, $5 }')"

# Dynamic Detection of Listening Network Services
LISTEN_SERVICES="$(ss -tulpn 2>/dev/null | awk 'NR>1 {print $7}' | grep -oP '(?<=users:\(\(")[^"]+' | sort -u | tr '\n' ', ' | sed 's/, $//')"
[ -z "$LISTEN_SERVICES" ] && LISTEN_SERVICES="none detected"

# Dynamic Container Engine Detection
RUNNING_CONTAINERS=0
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + $(docker ps -q 2>/dev/null | wc -l)))
fi
if command -v podman >/dev/null 2>&1; then
    RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + $(podman ps -q 2>/dev/null | wc -l)))
fi

echo -e ""
echo -e "${C1}  ██╗  ██╗ ██████╗███████╗    ${C2}██╗      █████╗ ██████╗ ███████╗"
echo -e "${C1}  ██║  ██║██╔════╝██╔════╝    ${C2}██║     ██╔══██╗██╔══██╗██╔════╝"
echo -e "${C2}  ███████║██║     █████╗      ${C3}██║     ███████║██████╔╝███████╗"
echo -e "${C2}  ██╔══██║██║     ██╔══╝      ${C3}██║     ██╔══██║██╔══██╗╚════██║"
echo -e "${C3}  ██║  ██║╚██████╗███████╗    ${C3}███████╗██║  ██║██████╔╝███████║"
echo -e "${C3}  ╚═╝  ╚═╝ ╚═════╝╚══════╝    ${C3}╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝${NC}"
echo -e "                   ${MUT}─── ${WHT}INFRASTRUCTURE LABS ${MUT}───${NC}"
echo -e ""
echo -e "  ${GRY}┌─[ ${WHT}CLUSTER NODE INFO${GRY} ]─────────────────────────────────────────┐${NC}"
echo -e "  ${GRY}│${NC}  ${C2}ORGANIZATION${NC} : HCE Labs (${C3}${HCE_LINK}${NC})"
echo -e "  ${GRY}│${NC}  ${C2}PLATFORM${NC}     : ${OS_NAME} [${VIRT_TYPE}]"
echo -e "  ${GRY}│${NC}  ${C2}HOSTNAME${NC}     : ${WHT}${HOSTNAME_FQDN}${NC} (${C3}${DEFAULT_IP}${NC})"
echo -e "  ${GRY}├─[ ${WHT}SYSTEM METRICS${GRY} ]───────────────────────────────────────────┤${NC}"
echo -e "  ${GRY}│${NC}  ${C2}UPTIME${NC}       : ${UPTIME}"
echo -e "  ${GRY}│${NC}  ${C2}LOAD AVG${NC}     : ${LOAD}"
echo -e "  ${GRY}│${NC}  ${C2}MEMORY${NC}       : [${BAR_COLOR}${BAR}${NC}] ${MEM_PCT}% (${MEM_USED_MB}/${MEM_TOTAL_MB} MB)"
echo -e "  ${GRY}│${NC}  ${C2}STORAGE${NC}      : ${DISK_USAGE}"
echo -e "  ${GRY}├─[ ${WHT}SERVICES & CONTAINERS${GRY} ]────────────────────────────────────┤${NC}"
echo -e "  ${GRY}│${NC}  ${C2}ACTIVE PORTS${NC} : ${LISTEN_SERVICES}"
[ "$RUNNING_CONTAINERS" -gt 0 ] && echo -e "  ${GRY}│${NC}  ${C2}CONTAINERS${NC}   : ${GRN}${RUNNING_CONTAINERS} active${NC}"
echo -e "  ${GRY}└──────────────────────────────────────────────────────────────┘${NC}"
echo -e ""
EOF

chmod +x /etc/profile.d/00_hce_motd.sh
echo "HCE Labs MOTD installed successfully!"
