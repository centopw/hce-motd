#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (e.g., curl -fsSL ... | sudo bash)"
  exit 1
fi

echo "Cleaning legacy MOTD configurations..."
> /etc/motd 2>/dev/null || true
rm -f /etc/profile.d/*_motd.sh /etc/profile.d/*lxc-details.sh 2>/dev/null || true

echo "Installing HCE Labs MOTD..."

cat << 'EOF' > /etc/profile.d/00_hce_motd.sh
#!/bin/sh

# Color Codes
C1='\033[38;5;39m'    # Deep Sky Blue
C2='\033[38;5;45m'    # Bright Cyan
C3='\033[38;5;51m'    # Aqua
WHT='\033[1;37m'
GRY='\033[38;5;240m'  # Tree-line Grey
MUT='\033[38;5;245m'  # Label Muted Grey
GRN='\033[1;32m'
YLW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# Dynamic Host & Environment
OS_NAME="$(grep ^NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"') $(grep ^VERSION_ID /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
DEFAULT_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
[ -z "$DEFAULT_IP" ] && DEFAULT_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
VIRT_TYPE="$(systemd-detect-virt 2>/dev/null || echo "baremetal")"

# Dynamic System Metrics
UPTIME="$(uptime -p 2>/dev/null | sed 's/up //')"
LOAD="$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null)"

# Memory Gauge (Standardized ASCII)
MEM_USED_MB=$(free -m 2>/dev/null | awk '/Mem:/ {print $3}')
MEM_TOTAL_MB=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')
if [ -n "$MEM_USED_MB" ] && [ -n "$MEM_TOTAL_MB" ] && [ "$MEM_TOTAL_MB" -gt 0 ]; then
    MEM_PCT=$((MEM_USED_MB * 100 / MEM_TOTAL_MB))
else
    MEM_PCT=0
fi

BAR_SIZE=10
FILLED=$((MEM_PCT * BAR_SIZE / 100))
EMPTY=$((BAR_SIZE - FILLED))
BAR_COLOR="${GRN}"
[ "$MEM_PCT" -ge 70 ] && BAR_COLOR="${YLW}"
[ "$MEM_PCT" -ge 90 ] && BAR_COLOR="${RED}"

BAR=""
i=0; while [ $i -lt $FILLED ]; do BAR="${BAR}#"; i=$((i+1)); done
i=0; while [ $i -lt $EMPTY ]; do BAR="${BAR}-"; i=$((i+1)); done

DISK_USAGE="$(df -h / 2>/dev/null | awk 'NR==2 { printf "%s/%s (%s)", $3, $2, $5 }')"

# Port detection that works without root privileges
LISTEN_PORTS=$(awk 'NR>1 && $4=="0A" {split($2,a,":"); printf "%d\n", "0x" a[2]}' /proc/net/tcp /proc/net/tcp6 2>/dev/null | sort -n -u | tr '\n' ' ' | sed 's/ $//')
[ -z "$LISTEN_PORTS" ] && LISTEN_PORTS="none detected"

# Containers Check
RUNNING_CONTAINERS=0
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then
    RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + $(docker ps -q 2>/dev/null | wc -l)))
fi
if command -v crictl >/dev/null 2>&1; then
    RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + $(crictl ps -q 2>/dev/null | wc -l)))
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
echo -e "  ${GRY}┌── ${WHT}CLUSTER NODE INFO${NC}"
echo -e "  ${GRY}│${NC}   ${C2}ORGANIZATION${NC} : HCE Labs (${C3}https://hce.vn${NC})"
echo -e "  ${GRY}│${NC}   ${C2}PLATFORM${NC}     : ${OS_NAME} [${VIRT_TYPE}]"
echo -e "  ${GRY}│${NC}   ${C2}HOSTNAME${NC}     : ${WHT}${HOSTNAME_FQDN}${NC} (${C3}${DEFAULT_IP}${NC})"
echo -e "  ${GRY}│${NC}"
echo -e "  ${GRY}├── ${WHT}SYSTEM METRICS${NC}"
echo -e "  ${GRY}│${NC}   ${C2}UPTIME${NC}       : ${UPTIME}"
echo -e "  ${GRY}│${NC}   ${C2}LOAD AVG${NC}     : ${LOAD}"
echo -e "  ${GRY}│${NC}   ${C2}MEMORY${NC}       : [${BAR_COLOR}${BAR}${NC}] ${MEM_PCT}% (${MEM_USED_MB}/${MEM_TOTAL_MB} MB)"
echo -e "  ${GRY}│${NC}   ${C2}STORAGE${NC}      : ${DISK_USAGE}"
echo -e "  ${GRY}│${NC}"
echo -e "  ${GRY}└── ${WHT}SERVICES & RUNTIME${NC}"
echo -e "      ${C2}OPEN PORTS${NC}   : ${LISTEN_PORTS}"
[ "$RUNNING_CONTAINERS" -gt 0 ] && echo -e "      ${C2}CONTAINERS${NC}   : ${GRN}${RUNNING_CONTAINERS} active${NC}"
echo -e ""
EOF

chmod 755 /etc/profile.d/00_hce_motd.sh
echo "HCE Labs MOTD installed successfully!"
