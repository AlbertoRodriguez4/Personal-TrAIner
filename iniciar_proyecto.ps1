#Requires -Version 5.1
<#
.SYNOPSIS
    Script para iniciar todos los servicios del Proyecto Entrenador Personal IA.
.DESCRIPTION
    Este script verifica prerequisitos y levanta en paralelo:
      - Backend Python (FastAPI + Ollama) en http://localhost:8000
      - Backend NestJS en http://localhost:3000
      - Frontend Flutter (web por defecto)
.NOTES
    Ejecutar desde la raiz del proyecto:
      .\iniciar_proyecto.ps1
    O haz doble clic en iniciar_proyecto.bat
#>

$ErrorActionPreference = "Stop"

# ============================================
# CONFIGURACION
# ============================================
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$PythonBackendPath = Join-Path $ProjectRoot "Backend\Python"
$NestJSBackendPath = Join-Path $ProjectRoot "Backend\Nestjs"
$FlutterFrontendPath = Join-Path $ProjectRoot "Frontend\personaltrainer"

$PythonPort = 8000
$NestJSPort = 3000

# ============================================
# FUNCIONES AUXILIARES
# ============================================
function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-PortInUse {
    param([int]$Port)
    $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    return $null -ne $connection
}

function Wait-ForPort {
    param(
        [int]$Port,
        [string]$ServiceName,
        [int]$TimeoutSeconds = 60
    )
    Write-Host "  Esperando a que $ServiceName responda en puerto $Port..." -NoNewline
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect("127.0.0.1", $Port)
            $tcp.Close()
            Write-Host " OK" -ForegroundColor Green
            return $true
        } catch {
            Start-Sleep -Seconds 1
            $elapsed++
            Write-Host "." -NoNewline
        }
    }
    Write-Host " TIMEOUT" -ForegroundColor Red
    return $false
}

function Show-Banner {
    Clear-Host
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  ENTRENADOR PERSONAL IA - INICIO RAPIDO" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================
# VERIFICACION DE PREREQUISITOS
# ============================================
Show-Banner

Write-Host "[1/5] Verificando prerequisitos..." -ForegroundColor Yellow

$checks = @()

# Node.js
if (Test-CommandExists "node") {
    $nodeVersion = node --version
    Write-Host "  Node.js.......: $nodeVersion" -ForegroundColor Green
    $checks += $true
} else {
    Write-Host "  Node.js.......: NO ENCONTRADO. Instala Node.js desde https://nodejs.org" -ForegroundColor Red
    $checks += $false
}

# Python (py launcher)
if (Test-CommandExists "py") {
    $pyVersion = py --version 2>&1
    Write-Host "  Python........: $pyVersion" -ForegroundColor Green
    $checks += $true
} else {
    Write-Host "  Python........: NO ENCONTRADO. Instala Python desde https://python.org" -ForegroundColor Red
    $checks += $false
}

# Flutter
if (Test-CommandExists "flutter") {
    $flutterVersion = (flutter --version | Select-Object -First 1)
    Write-Host "  Flutter.......: $flutterVersion" -ForegroundColor Green
    $checks += $true
} else {
    Write-Host "  Flutter.......: NO ENCONTRADO. Instala Flutter desde https://docs.flutter.dev/get-started/install" -ForegroundColor Red
    $checks += $false
}

# PostgreSQL
$pgService = Get-Service | Where-Object { $_.Name -like "*postgres*" -and $_.Status -eq "Running" } | Select-Object -First 1
if ($pgService) {
    Write-Host "  PostgreSQL....: $($pgService.Name) (Running)" -ForegroundColor Green
    $checks += $true
} else {
    Write-Host "  PostgreSQL....: NO DETECTADO EN EJECUCION. Asegurate de que este corriendo." -ForegroundColor Red
    $checks += $false
}

if ($checks -contains $false) {
    Write-Host ""
    Write-Host "ERROR: Faltan prerequisitos. Corrige los errores marcados en rojo e intenta de nuevo." -ForegroundColor Red
    pause
    exit 1
}

# ============================================
# VERIFICAR DEPENDENCIAS INSTALADAS
# ============================================
Write-Host ""
Write-Host "[2/5] Verificando dependencias del proyecto..." -ForegroundColor Yellow

# NestJS node_modules
if (-not (Test-Path (Join-Path $NestJSBackendPath "node_modules"))) {
    Write-Host "  Instalando dependencias de NestJS..." -ForegroundColor Yellow
    Set-Location $NestJSBackendPath
    npm install
    Set-Location $ProjectRoot
} else {
    Write-Host "  NestJS deps...: OK" -ForegroundColor Green
}

# Flutter pub get
if (-not (Test-Path (Join-Path $FlutterFrontendPath "pubspec.lock"))) {
    Write-Host "  Descargando dependencias de Flutter..." -ForegroundColor Yellow
    Set-Location $FlutterFrontendPath
    flutter pub get
    Set-Location $ProjectRoot
} else {
    Write-Host "  Flutter deps..: OK" -ForegroundColor Green
}

# Python deps
Write-Host "  Verificando paquetes Python (fastapi, uvicorn)..." -NoNewline
$pythonCheck = py -3.10 -c "import fastapi, uvicorn, requests" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  Instalando paquetes Python requeridos..." -ForegroundColor Yellow
    py -3.10 -m pip install fastapi uvicorn requests pydantic
}

# ============================================
# VERIFICAR PUERTOS LIBRES
# ============================================
Write-Host ""
Write-Host "[3/5] Verificando puertos..." -ForegroundColor Yellow

if (Test-PortInUse -Port $PythonPort) {
    Write-Host "  Puerto $PythonPort (Python) YA ESTA EN USO. " -ForegroundColor Red -NoNewline
    Write-Host "Cierra el proceso que lo usa o cambia el puerto." -ForegroundColor Yellow
    pause
    exit 1
}

if (Test-PortInUse -Port $NestJSPort) {
    Write-Host "  Puerto $NestJSPort (NestJS) YA ESTA EN USO. " -ForegroundColor Red -NoNewline
    Write-Host "Cierra el proceso que lo usa o cambia el puerto." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "  Puerto $PythonPort (Python): LIBRE" -ForegroundColor Green
Write-Host "  Puerto $NestJSPort (NestJS): LIBRE" -ForegroundColor Green

# ============================================
# INICIAR SERVICIOS
# ============================================
Write-Host ""
Write-Host "[4/5] Iniciando servicios..." -ForegroundColor Yellow
Write-Host ""

# --- Backend Python ---
Write-Host "  -> Levantando Backend Python en http://localhost:$PythonPort" -ForegroundColor Cyan
$pythonCmd = "Write-Host 'Backend Python iniciandose...' -ForegroundColor Cyan ; py -3.10 -m uvicorn main:app --reload --port $PythonPort ; pause"
Start-Process powershell.exe -WorkingDirectory $PythonBackendPath -ArgumentList "-NoExit", "-Command", $pythonCmd

# Esperar a que Python esté listo
if (-not (Wait-ForPort -Port $PythonPort -ServiceName "Backend Python" -TimeoutSeconds 30)) {
    Write-Host "ADVERTENCIA: El backend Python no respondio a tiempo. Revisa su ventana." -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

# --- Backend NestJS ---
Write-Host "  -> Levantando Backend NestJS en http://localhost:$NestJSPort" -ForegroundColor Cyan
$nestCmd = "Write-Host 'Backend NestJS iniciandose...' -ForegroundColor Cyan ; npm run start:dev ; pause"
Start-Process powershell.exe -WorkingDirectory $NestJSBackendPath -ArgumentList "-NoExit", "-Command", $nestCmd

# Esperar a que NestJS esté listo
if (-not (Wait-ForPort -Port $NestJSPort -ServiceName "Backend NestJS" -TimeoutSeconds 60)) {
    Write-Host "ADVERTENCIA: El backend NestJS no respondio a tiempo. Revisa su ventana." -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

# --- Frontend Flutter ---
Write-Host "  -> Levantando Frontend Flutter" -ForegroundColor Cyan
$flutterCmd = "Write-Host 'Frontend Flutter iniciandose...' -ForegroundColor Cyan ; flutter run -d chrome ; pause"
Start-Process powershell.exe -WorkingDirectory $FlutterFrontendPath -ArgumentList "-NoExit", "-Command", $flutterCmd

# ============================================
# RESUMEN
# ============================================
Write-Host ""
Write-Host "[5/5] Resumen de servicios iniciados:" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host "  Backend Python : http://localhost:$PythonPort" -ForegroundColor White
Write-Host "  Backend NestJS : http://localhost:$NestJSPort" -ForegroundColor White
Write-Host "  Frontend       : Se abrira en Chrome" -ForegroundColor White
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Se abrieron 3 ventanas de terminal. No las cierres mientras uses la app." -ForegroundColor Yellow
Write-Host "Presiona cualquier tecla para cerrar esta ventana (los servicios seguiran corriendo)..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
