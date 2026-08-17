#!/bin/bash
set -e

echo "Installing HCE Labs MOTD..."

# 1. Clean default Debian/Ubuntu MOTD noise
> /etc/motd 2>/dev/null || true

# 2. Write dynamic MOTD script
cat << 'EOF' > /etc/profile.d/00_hce_motd.sh
#!/bin/sh

# Colors & Styles
C1='\033[38;5;39m'   # Deep Sky Blue
C2='\033[38;5;45m'   # Bright Cyan
C3='\033[38;5;51m'   # Aqua
WHT='\033[1;37m'
GRY='\033[38;5;244m'
GRN='\033[1;32m'
NC='\033[0m'

# Dynamic Environment & Host Details
OS_NAME="$(grep ^NAME /etc/os-release | cut -d= -f2 | tr -d '"') $(grep ^VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
DEFAULT_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
[ -z "$DEFAULT_IP" ] && DEFAULT_IP="$(hostname -I | awk '{print $1}')"
VIRT_TYPE="$(systemd-detect-virt 2>/dev/null || echo "baremetal")"

# Dynamic Metrics
UPTIME="$(uptime -p 2>/dev/null | sed 's/up //')"
LOAD="$(awk '{print $1", "$2", "$3}' /proc/loadavg)"
MEM_USAGE="$(free -m | awk '/Mem:/ { printf "%s/%sMB (%.1f%%)", $3, $2, $3*100/$2 }')"
DISK_USAGE="$(df -h / | awk 'NR==2 { printf "%s/%s (%s)", $3, $2, $5 }')"

# Dynamic Detection of Listening Network Services
LISTEN_SERVICES="$(ss -tulpn 2>/dev/null | awk 'NR>1 {print $7}' | grep -oP '(?<=users:\(\(")[^"]+' | sort -u | tr '\n' ', ' | sed 's/, $//')"
[ -z "$LISTEN_SERVICES" ] && LISTEN_SERVICES="none detected"

# Dynamic Container Engine Status
RUNNING_CONTAINERS=0
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + $(docker ps -q 2>/dev/null | wc -l)))
fi
if command -v podman >/dev/null 2>&1; then
    RUNNING_CONTAINERS=$((RUNNING_CONTAINERS + $(podman ps -q 2>/dev/null | wc -l)))
fi

echo -e ""
echo -e "${C1}██╗  ██╗ ██████╗███████╗    ${C2}██╗      █████╗ ██████╗ ███████╗"
echo -e "${C1}██║  ██║██╔════╝██╔════╝    ${C2}██║     ██╔══██╗██╔══██╗██╔════╝"
echo -e "${C2}███████║██║     █████╗      ${C3}██║     ███████║██████╔╝███████╗"
echo -e "${C2}██╔══██║██║     ██╔══╝      ${C3}██║     ██╔══██║██╔══██╗╚════██║"
echo -e "${C3}██║  ██║╚██████╗███████╗    ${C3}███████╗██║  ██║██████╔╝███████║"
echo -e "${C3}╚═╝  ╚═╝ ╚═════╝╚══════╝    ${C3}╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝${NC}"
echo -e "                 ${GRY}─── ${WHT}INFRASTRUCTURE LABS ${GRY}───${NC}"
echo -e ""
echo -e "  ${C2}OPS${NC}        : Maintained & Run by ${WHT}HCE Labs Team${NC}"
echo -e "  ${C2}PLATFORM${NC}   : ${OS_NAME} (${VIRT_TYPE})"
echo -e "  ${C2}NODE${NC}       : ${HOSTNAME_FQDN} [${C3}${DEFAULT_IP}${NC}]"
echo -e "  ${GRY}────────────────────────────────────────────────────────────${NC}"
echo -e "  ${C2}UPTIME${NC}     : ${UPTIME}"
echo -e "  ${C2}LOAD AVG${NC}   : ${LOAD}"
echo -e "  ${C2}MEMORY${NC}     : ${MEM_USAGE}"
echo -e "  ${C2}ROOT DISK${NC}  : ${DISK_USAGE}"
echo -e "  ${C2}LISTEN SVC${NC} : ${LISTEN_SERVICES}"
[ "$RUNNING_CONTAINERS" -gt 0 ] && echo -e "  ${C2}CONTAINERS${NC} : ${GRN}${RUNNING_CONTAINERS} running${NC}"
echo -e ""
EOF

chmod +x /etc/profile.d/00_hce_motd.sh
echo "HCE Labs MOTD installed successfully!"
