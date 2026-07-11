@echo off
setlocal
chcp 65001 >nul

cd /d "%~dp0"

echo ███╗   ██╗ ██╗   ██╗ ██╗  ██╗ ███████╗
echo ████╗  ██║ ██║   ██║ ██║ ██╔╝ ██╔════╝
echo ██╔██╗ ██║ ██║   ██║ █████╔╝  █████╗
echo ██║╚██╗██║ ██║   ██║ ██╔═██╗  ██╔══╝
echo ██║ ╚████║ ╚██████╔╝ ██║  ██╗ ███████╗
echo ╚═╝  ╚═══╝  ╚═════╝  ╚═╝  ╚═╝ ╚══════╝
echo           limpeza de cache de dev e temporarios
echo.
echo Limpa cache de pip/uv/npm/cargo/docker/git/huggingface/ollama
echo e temporarios do sistema pra liberar espaco em disco.
echo Nao mexe em login, senha ou token de nada.
echo.

if not exist "%~dp0nuke.sh" (
    echo [ERRO] Nao achei o nuke.sh nesta pasta.
    echo Ele precisa estar junto com este arquivo .bat
    echo.
    pause
    exit /b 1
)

rem --- procura um bash instalado (Git Bash ou WSL) ---
set "BASH_EXE="

where bash >nul 2>nul
if %errorlevel%==0 set "BASH_EXE=bash"

if not defined BASH_EXE if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH_EXE=%LocalAppData%\Programs\Git\bin\bash.exe"

if not defined BASH_EXE (
    echo [ERRO] Nao encontrei bash instalado nesta maquina.
    echo Este script e feito em bash, entao precisa de um destes:
    echo.
    echo   - Git Bash:  https://git-scm.com/downloads
    echo   - WSL:       abra o PowerShell como administrador e rode: wsl --install
    echo.
    echo Depois de instalar um dos dois, so clicar de novo neste arquivo.
    echo.
    pause
    exit /b 1
)

set /p PREVIEW="Quer ver antes o que seria feito, sem apagar nada de verdade? [S/n] "
if /i "%PREVIEW%"=="n" goto :runreal

"%BASH_EXE%" ./nuke.sh --dry-run
echo.
set /p CONFIRMAR="Quer rodar de verdade agora? [s/N] "
if /i "%CONFIRMAR%"=="s" goto :runreal
echo Nada foi apagado.
goto :fim

:runreal
"%BASH_EXE%" ./nuke.sh

:fim
echo.
pause
