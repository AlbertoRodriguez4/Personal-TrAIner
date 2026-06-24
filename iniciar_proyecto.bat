@echo off
chcp 65001 >nul
title Iniciar Proyecto - Entrenador Personal IA
echo ===========================================
echo   ENTRENADOR PERSONAL IA - INICIO RAPIDO
echo ===========================================
echo.

REM Verificar si PowerShell esta disponible
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: PowerShell no esta disponible en este sistema.
    pause
    exit /b 1
)

REM Ejecutar el script PowerShell con politica de ejecucion Bypass para este script concreto
echo Iniciando script de PowerShell...
powershell -ExecutionPolicy Bypass -File "%~dp0iniciar_proyecto.ps1"

exit /b %errorlevel%
