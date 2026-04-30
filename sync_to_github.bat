@echo off
REM ============================================================================
REM HCM360 - Sync local working copy to GitHub
REM   Windows (cmd.exe / PowerShell)
REM
REM Usage:
REM   sync_to_github.bat                       (prompts for commit message)
REM   sync_to_github.bat "your message here"   (uses arg as commit message)
REM ============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0"

if not exist ".git" (
  echo [X] Not a git repository. Run 'git init' first or clone the repo.
  exit /b 1
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
  echo [X] No 'origin' remote configured.
  exit /b 1
)

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set BRANCH=%%b
for /f "delims=" %%r in ('git remote get-url origin') do set REMOTE=%%r
echo -^> Branch: !BRANCH!
echo -^> Remote: !REMOTE!
echo.

git add -A

git diff --cached --quiet
if not errorlevel 1 (
  echo [+] Nothing to commit. Pushing existing commits ^(if any^)...
  goto push
)

echo -^> Staged changes:
git diff --cached --stat
echo.

if not "%~1"=="" (
  set MSG=%~1
) else (
  for /f "tokens=1-3 delims=/-. " %%a in ("%date%") do set DATEPART=%%c-%%a-%%b
  for /f "tokens=1-2 delims=:" %%a in ("%time%") do set TIMEPART=%%a:%%b
  set DEFAULT_MSG=sync !DATEPART! !TIMEPART!
  set /p MSG=Commit message [!DEFAULT_MSG!]:
  if "!MSG!"=="" set MSG=!DEFAULT_MSG!
)

git commit -m "!MSG!"
if errorlevel 1 (
  echo [X] Commit failed.
  exit /b 1
)

:push
echo.
echo -^> Pushing to origin/!BRANCH!...
git push -u origin !BRANCH!
if errorlevel 1 (
  echo [X] Push failed.
  exit /b 1
)
echo.
echo [+] Done.
git log --oneline -1
endlocal
