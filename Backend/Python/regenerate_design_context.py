#!/usr/bin/env python3
"""
regenerate_design_context.py

Regenera Backend/Python/design_context.md a partir del estado actual del
repo de Lovable (trainer-mind-flow), usando Gemini 3.5 Flash para extraer
y documentar los patrones de diseño reales del código React/Tailwind.

USO
---
    python regenerate_design_context.py
    python regenerate_design_context.py --repo-path /ruta/local/trainer-mind-flow
    python regenerate_design_context.py --dry-run   # muestra el resultado sin escribir el archivo

REQUISITOS
----------
    pip install google-genai --break-system-packages
    export GEMINI_API_KEY=tu_api_key

QUÉ HACE
--------
1. Clona (o actualiza si ya existe) AlbertoRodriguez4/trainer-mind-flow
2. Lee styles.css + todos los archivos de src/routes/*.tsx
3. Envía el contenido a Gemini con instrucciones de extraer SOLO los
   patrones de diseño reales (tokens, componentes, utilidades) - nada
   inventado, nada de lo que ya hay en design_context.md previo se pierde
   si sigue siendo válido.
4. Sobreescribe Backend/Python/design_context.md con el resultado
5. Si --dry-run, solo imprime el resultado y no toca el archivo

Pensado para ejecutarse manualmente cuando hayas hecho cambios de diseño
en Lovable, o engancharlo a un cron/GitHub Action que se dispare con cada
push a trainer-mind-flow.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("❌ Falta google-genai. Instala con:")
    print("   pip install google-genai --break-system-packages")
    sys.exit(1)


REPO_URL = "https://github.com/AlbertoRodriguez4/trainer-mind-flow.git"
DEFAULT_REPO_PATH = Path.home() / "trainer-mind-flow"
# Ruta del design_context.md dentro del proyecto Personal-TrAIner.
# Ajusta esta constante si ejecutas el script desde otra ubicación.
DEFAULT_OUTPUT_PATH = Path(__file__).resolve().parent / "design_context.md"

# Extensiones / carpetas relevantes para el sistema de diseño.
# No se incluye components/ui/ (shadcn) porque son primitivas genéricas,
# no patrones específicos del proyecto.
RELEVANT_GLOBS = [
    "src/styles.css",
    "src/routes/*.tsx",
]

SYSTEM_PROMPT = """Eres un extractor de design systems. Tu única tarea es leer código \
React + TailwindCSS v4 de la app "Personal TrAIner" (repo trainer-mind-flow, prototipado \
en Lovable) y producir un archivo design_context.md actualizado.

REGLAS ESTRICTAS:
1. Documenta SOLO patrones que existen literalmente en el código proporcionado. \
No inventes componentes, colores, ni utilidades que no aparezcan en el código fuente.
2. Mantén EXACTAMENTE la misma estructura de secciones que el design_context.md anterior \
(si se proporciona uno), para que el archivo siga siendo predecible entre regeneraciones:
   - Stack
   - Tokens de Color (oklch exactos del CSS)
   - Utilidades CSS Custom
   - Border Radius
   - Tipografía
   - Patrones de pantalla / componentes (con snippets TSX reales, copiados o muy cercanos al original)
   - Reglas invariables (numeradas)
3. Si una pantalla usa un sistema visual distinto al resto (ej. una pantalla dark-only entre \
pantallas claras), documéntalo explícitamente en su propia sub-sección y aclara cuándo usar \
cada sistema — no fusiones ambos.
4. Los snippets de código deben ser representativos y reutilizables como plantilla, no el \
componente completo línea por línea si es muy largo — usa buen criterio para que sirvan de \
referencia rápida a otro LLM que vaya a generar componentes nuevos siguiendo este sistema.
5. Devuelve ÚNICAMENTE el contenido del archivo .md, sin explicaciones antes o después, \
sin backticks de markdown envolviendo todo el archivo.
6. Empieza el archivo con la línea: \
"# Personal TrAIner — Design Context (trainer-mind-flow)" \
seguida de una línea indicando que se generó automáticamente y la fecha.
"""


def run(cmd: list[str], cwd: Path | None = None) -> str:
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Comando falló: {' '.join(cmd)}")
        print(result.stderr)
        sys.exit(1)
    return result.stdout


def sync_repo(repo_path: Path) -> None:
    if repo_path.exists() and (repo_path / ".git").exists():
        print(f"🔄 Actualizando repo existente en {repo_path}")
        run(["git", "fetch", "origin"], cwd=repo_path)
        # Detecta la rama por defecto remota y resetea duro a ella
        default_branch = run(
            ["git", "remote", "show", "origin"], cwd=repo_path
        )
        branch = "main"
        for line in default_branch.splitlines():
            if "HEAD branch" in line:
                branch = line.split(":")[-1].strip()
        run(["git", "reset", "--hard", f"origin/{branch}"], cwd=repo_path)
    else:
        print(f"📥 Clonando {REPO_URL} en {repo_path}")
        run(["git", "clone", REPO_URL, str(repo_path)])


def collect_source_files(repo_path: Path) -> str:
    chunks = []
    for pattern in RELEVANT_GLOBS:
        for filepath in sorted(repo_path.glob(pattern)):
            if filepath.is_file():
                try:
                    content = filepath.read_text(encoding="utf-8")
                except UnicodeDecodeError:
                    continue
                rel = filepath.relative_to(repo_path)
                chunks.append(f"=== {rel} ===\n{content}\n")
    if not chunks:
        print("⚠️  No se encontró ningún archivo relevante. ¿Cambió la estructura del repo?")
    return "\n".join(chunks)


def load_previous_context(output_path: Path) -> str | None:
    if output_path.exists():
        return output_path.read_text(encoding="utf-8")
    return None


def generate_design_context(source_code: str, previous_context: str | None) -> str:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Falta la variable de entorno GEMINI_API_KEY")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    user_parts = [f"CÓDIGO FUENTE ACTUAL DEL REPO trainer-mind-flow:\n\n{source_code}"]
    if previous_context:
        user_parts.insert(
            0,
            "DESIGN_CONTEXT.MD ANTERIOR (úsalo como referencia de estructura, "
            "pero el código fuente de abajo es la fuente de verdad para el contenido):\n\n"
            f"{previous_context}\n\n---\n\n",
        )

    response = client.models.generate_content(
        model="gemini-3.5-flash",
        contents="\n".join(user_parts),
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            temperature=0.1,
        ),
    )
    return response.text.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-path",
        type=Path,
        default=DEFAULT_REPO_PATH,
        help=f"Ruta local donde clonar/actualizar trainer-mind-flow (default: {DEFAULT_REPO_PATH})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_PATH,
        help=f"Ruta de salida del design_context.md (default: {DEFAULT_OUTPUT_PATH})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Genera el contenido y lo imprime, pero no sobreescribe el archivo",
    )
    parser.add_argument(
        "--skip-sync",
        action="store_true",
        help="No hacer git fetch/reset, usar el repo local tal cual está",
    )
    args = parser.parse_args()

    if not args.skip_sync:
        sync_repo(args.repo_path)
    elif not args.repo_path.exists():
        print(f"❌ {args.repo_path} no existe y se pasó --skip-sync")
        sys.exit(1)

    print("📖 Leyendo archivos de diseño relevantes...")
    source_code = collect_source_files(args.repo_path)
    print(f"   {len(source_code):,} caracteres recolectados")

    previous_context = load_previous_context(args.output)
    if previous_context:
        print(f"📄 design_context.md anterior encontrado ({len(previous_context):,} caracteres), se usará como guía de estructura")

    print("🤖 Generando design_context.md con Gemini 3.5 Flash...")
    new_context = generate_design_context(source_code, previous_context)

    if args.dry_run:
        print("\n" + "=" * 60)
        print("DRY RUN — resultado (no se escribió ningún archivo):")
        print("=" * 60 + "\n")
        print(new_context)
        return

    args.output.write_text(new_context, encoding="utf-8")
    print(f"✅ {args.output} actualizado ({len(new_context):,} caracteres)")


if __name__ == "__main__":
    main()