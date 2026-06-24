# Iniciar Proyecto - Entrenador Personal IA

Este documento explica como ejecutar todos los servicios del proyecto de forma simultanea.

## Archivos de inicio

| Archivo | Descripcion |
|---------|-------------|
| `iniciar_proyecto.bat` | Hacer doble clic para iniciar todo (Windows) |
| `iniciar_proyecto.ps1` | Script PowerShell con logica completa |

## Requisitos previos

Asegurate de tener instalado:

- **Node.js** (v18 o superior) → https://nodejs.org
- **Python** (3.10 o superior, con launcher `py`) → https://python.org
- **Flutter** (SDK estable) → https://docs.flutter.dev/get-started/install
- **PostgreSQL** (corriendo como servicio)
- **Ollama** (para el analisis con IA) → https://ollama.com

## Como ejecutar

### Opcion 1: Doble clic (Recomendada)
1. Ve a la carpeta raiz del proyecto
2. Haz **doble clic** en `iniciar_proyecto.bat`
3. Espera a que se abran las 3 ventanas de terminal

### Opcion 2: PowerShell
```powershell
.\iniciar_proyecto.ps1
```

> Nota: Si ves un error de politicas de ejecucion, ejecuta primero:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

## Que hace el script

1. **Verifica prerequisitos**: Comprueba que Node, Python, Flutter y PostgreSQL esten disponibles.
2. **Verifica dependencias**: Asegura que `node_modules` y `pub get` esten listos.
3. **Verifica puertos**: Comprueba que los puertos 8000 (Python) y 3000 (NestJS) esten libres.
4. **Inicia servicios**: Abre 3 ventanas de terminal independientes:
   - **Backend Python** (FastAPI + Ollama): http://localhost:8000
   - **Backend NestJS** (API principal): http://localhost:3000
   - **Frontend Flutter** (App en Chrome)

## Servicios y puertos

| Servicio | Puerto | URL |
|----------|--------|-----|
| Python FastAPI | 8000 | http://localhost:8000 |
| NestJS API | 3000 | http://localhost:3000 |
| Flutter Web | (dinamico) | Se abre automaticamente en Chrome |

## Detener los servicios

Cierra cada una de las 3 ventanas de terminal que se abrieron, o presiona `Ctrl + C` en cada una.

## Solucion de problemas

### "Puerto XXXX ya esta en uso"
Busca y cierra el proceso que esta usando ese puerto, o reinicia tu PC.

### "PostgreSQL no detectado"
Asegurate de que el servicio de PostgreSQL este corriendo en Windows:
```powershell
Get-Service | Where-Object { $_.Name -like "*postgres*" }
```

### "Ollama no responde"
El backend Python intenta iniciar Ollama automaticamente, pero si falla, abre una terminal y ejecuta:
```bash
ollama serve
```
