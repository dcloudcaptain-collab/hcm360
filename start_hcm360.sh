#!/usr/bin/env bash
# ============================================================================
#  start_hcm360.sh — Bring the HCM360 HRIS stack up locally.
#
#  Containers (Docker):
#    • hris_db   — PostgreSQL 15  (port 5440 → :5432)
#    • hris_web  — Flask app      (port 8093 → :5000)
#
#  Usage:   ./start_hcm360.sh
#           ./start_hcm360.sh --rebuild   # also `docker-compose up -d --build`
#           ./start_hcm360.sh --logs      # tail logs after starting
# ============================================================================
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────
G='\033[0;32m'  # green
B='\033[1;34m'  # blue
Y='\033[1;33m'  # yellow
R='\033[0;31m'  # red
N='\033[0m'     # no color

CONTAINERS=(hris_db hris_web)
WEB_URL="http://localhost:8093"
DB_PORT=5440
WEB_PORT=8093

# ── Helpers ─────────────────────────────────────────────────────────
say()  { printf "${B}[hcm360]${N} %s\n" "$*"; }
ok()   { printf "${G}  ✓${N} %s\n" "$*"; }
warn() { printf "${Y}  ⚠${N} %s\n" "$*"; }
die()  { printf "${R}  ✗${N} %s\n" "$*" >&2; exit 1; }

# ── Pre-flight ──────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || die "Docker is not installed or not on PATH."
docker info >/dev/null 2>&1       || die "Docker daemon is not running. Start Docker Desktop first."

REBUILD=0
TAIL_LOGS=0
for arg in "$@"; do
  case "$arg" in
    --rebuild) REBUILD=1 ;;
    --logs)    TAIL_LOGS=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \?//'
      exit 0 ;;
  esac
done

cd "$(dirname "$0")"

# ── Optionally rebuild ──────────────────────────────────────────────
if [[ $REBUILD -eq 1 ]]; then
  say "Rebuilding containers via docker-compose…"
  if [[ -f docker-compose.yml ]]; then
    docker-compose up -d --build
  else
    warn "docker-compose.yml not found here — falling back to plain start."
  fi
fi

# ── Start each container ────────────────────────────────────────────
say "Starting containers…"
for name in "${CONTAINERS[@]}"; do
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
    die "Container ${name} does not exist. Run: docker-compose up -d --build"
  fi
  state=$(docker inspect --format '{{.State.Status}}' "$name")
  if [[ "$state" == "running" ]]; then
    ok "${name} already running"
  else
    docker start "$name" >/dev/null
    ok "${name} started"
  fi
done

# ── Wait for DB to be healthy ───────────────────────────────────────
say "Waiting for hris_db to report healthy…"
for i in $(seq 1 30); do
  status=$(docker inspect --format='{{.State.Health.Status}}' hris_db 2>/dev/null || echo "unknown")
  if [[ "$status" == "healthy" ]]; then
    ok "hris_db is healthy"
    break
  fi
  printf "."
  sleep 1
done
[[ "$status" == "healthy" ]] || warn "DB health check timed out — continuing anyway."

# ── Wait for /login to respond ──────────────────────────────────────
say "Waiting for hris_web to respond on :${WEB_PORT}…"
for i in $(seq 1 30); do
  http=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "${WEB_URL}/login" 2>/dev/null || echo "000")
  if [[ "$http" == "200" ]]; then
    ok "hris_web responds (HTTP 200)"
    break
  fi
  printf "."
  sleep 1
done
[[ "$http" == "200" ]] || warn "/login didn't return 200 yet — try again in a moment."

# ── Banner ──────────────────────────────────────────────────────────
echo ""
printf "${B}╔══════════════════════════════════════════════════════════════╗${N}\n"
printf "${B}║${N}  ${G}HCM360 HRIS — up and running${N}                                 ${B}║${N}\n"
printf "${B}╠══════════════════════════════════════════════════════════════╣${N}\n"
printf "${B}║${N}  Web app  :  %-49s${B}║${N}\n" "${WEB_URL}"
printf "${B}║${N}  Database :  %-49s${B}║${N}\n" "localhost:${DB_PORT}  (psql -h localhost -p ${DB_PORT} -U hris_admin)"
printf "${B}║${N}                                                              ${B}║${N}\n"
printf "${B}║${N}  Tail logs:  docker logs -f hris_web                         ${B}║${N}\n"
printf "${B}║${N}  Stop all :  docker stop hris_web hris_db                    ${B}║${N}\n"
printf "${B}╚══════════════════════════════════════════════════════════════╝${N}\n"
echo ""

# ── Optionally tail logs ────────────────────────────────────────────
if [[ $TAIL_LOGS -eq 1 ]]; then
  say "Tailing hris_web logs (Ctrl-C to stop)…"
  docker logs -f hris_web
fi
