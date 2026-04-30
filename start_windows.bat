@echo off
docker compose down
docker compose up -d --build
echo HCM v1.6 Clean Build running at http://localhost:8093
pause
