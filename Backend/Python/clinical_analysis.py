"""Pipeline de un documento clínico (PDF, DICOM o foto de una analítica) a un
informe guardado en base de datos.

Son DOS pasadas al modelo, no una, y el orden es lo importante:

  1. **Extraer** — con el documento delante y `temperature` casi 0, el modelo
     solo transcribe: nombre literal, valor, unidad y el rango que imprima el
     laboratorio. No interpreta nada.
  2. **Contrastar** — sin modelo de por medio: los nombres se normalizan contra
     `clinical_reference`, se clasifica cada valor (mandando siempre el rango
     del propio informe sobre el de la tabla) y se consulta MedlinePlus
     (NIH/NLM) por cada prueba encontrada.
  3. **Redactar** — segunda pasada, ya SIN el documento, con los valores
     normalizados y el bloque de referencia contrastado como única base.

Hacerlo en una sola pasada era la opción obvia y es justo la que falla: el
modelo mezcla transcripción con interpretación, y acaba clasificando valores
como "altos" contra rangos que recuerda de memoria en vez de contra una fuente.
Separándolo, la interpretación solo puede apoyarse en lo que se le pasó.

**Composición corporal.** La pasada de extracción también saca el bloque de un
DEXA o un InBody (peso, grasa, masa magra…), que va a otra tabla y lo maneja
`body_composition`. Se aprovecha esta misma pasada porque el documento ya está
delante y transcribirlo es el mismo trabajo. Si el documento resulta ser solo de
composición y no trae ningún biomarcador de sangre, no se redacta informe
clínico: se devuelve la lectura de la composición, que es lo que ese documento
decía de verdad.
"""
import base64
from datetime import date

from google.genai import types

import body_composition
import clinical_reference as ref
import gemini_client
import medlineplus_client
import nest_client as nest

# Formatos que Gemini acepta como `inline_data`. El DICOM (.dcm) no está entre
# ellos: se avisa en vez de mandar bytes que la API rechaza con un 400 opaco.
MIMES_SOPORTADOS = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}

# Techo de marcadores que se enriquecen con MedlinePlus. Una analítica completa
# trae 40+ valores; los del catálogo rara vez pasan de 20, y cada consulta suma
# ~300 ms y ~150 tokens de referencia al prompt de redacción.
MAX_MARCADORES_ENRIQUECIDOS = 15


class DocumentoNoSoportadoError(Exception):
    """El formato del archivo no lo puede leer el modelo de visión."""


# ============================================================
# Paso 1 — extracción literal
# ============================================================

_SCHEMA_EXTRACCION = types.Schema(
    type="OBJECT",
    properties={
        "tipo_documento": types.Schema(
            type="STRING",
            enum=["analitica", "dexa", "informe_medico", "prueba_imagen", "otro"],
            description="Qué clase de documento es.",
        ),
        "fecha_informe": types.Schema(
            type="STRING",
            description="Fecha impresa en el documento en formato AAAA-MM-DD. Cadena vacía si no aparece — NO la inventes ni uses la de hoy.",
        ),
        "confianza_extraccion": types.Schema(
            type="STRING",
            enum=["alta", "media", "baja"],
            description="alta = texto nítido y completo; baja = foto borrosa, cortada o manuscrita.",
        ),
        "observaciones_texto": types.Schema(
            type="STRING",
            description="Comentarios o conclusiones que el propio documento traiga escritos, transcritos tal cual. Vacío si no hay.",
        ),
        "marcadores": types.Schema(
            type="ARRAY",
            items=types.Schema(
                type="OBJECT",
                properties={
                    "nombre_literal": types.Schema(
                        type="STRING",
                        description="El nombre EXACTO como aparece impreso, sin traducir ni normalizar (ej. 'GPT (ALT)', 'Colesterol HDL').",
                    ),
                    "valor": types.Schema(type="NUMBER", description="Solo el número, con punto decimal."),
                    "unidad": types.Schema(type="STRING", description="Unidad tal cual aparece (mg/dL, %, U/L…). Vacío si no aparece."),
                    "rango_min": types.Schema(type="NUMBER", description="Extremo inferior del rango de referencia IMPRESO en el informe. Omitir si no aparece."),
                    "rango_max": types.Schema(type="NUMBER", description="Extremo superior del rango de referencia IMPRESO en el informe. Omitir si no aparece."),
                },
                required=["nombre_literal", "valor"],
            ),
        ),
        # Los informes de composición corporal (DEXA, InBody, Tanita, una
        # bioimpedancia de gimnasio) traen sus cifras en un bloque propio con
        # nombres fijos, no como una lista de parámetros de laboratorio. Se
        # extraen aparte y a campo nombrado porque van a una tabla distinta: son
        # el dato que la app usa para calorías y macros, no un biomarcador más.
        "composicion_corporal": types.Schema(
            type="OBJECT",
            description=(
                "SOLO si el documento es un informe de composición corporal (DEXA/densitometría, "
                "InBody, Tanita, bioimpedancia, plicometría). Omite el objeto entero si es una "
                "analítica de sangre o cualquier otra cosa. Incluye únicamente los campos que "
                "aparezcan impresos: no calcules los que falten."
            ),
            properties={
                "peso_kg": types.Schema(type="NUMBER", description="Peso corporal total en kg."),
                "porcentaje_grasa": types.Schema(type="NUMBER", description="Porcentaje de grasa corporal total ('Grasa Corporal'). Si el informe da varios (tronco, brazos…), usa el TOTAL."),
                "masa_grasa_kg": types.Schema(type="NUMBER", description="Kilos de masa grasa total ('Masa grasa')."),
                "masa_magra_kg": types.Schema(
                    type="NUMBER",
                    description=(
                        "Kilos de masa magra / libre de grasa. OJO: algunas básculas lo rotulan mal "
                        "como 'Pérdida de grasa' — si ese número es aproximadamente el peso total "
                        "menos la masa grasa, es masa magra y va aquí, NO es grasa perdida."
                    ),
                ),
                "masa_muscular_kg": types.Schema(type="NUMBER", description="Kilos de masa muscular ('Masa Muscular')."),
                "musculo_pct": types.Schema(type="NUMBER", description="Masa muscular como porcentaje del peso. Fitdays lo rotula 'Frecuencia muscular'."),
                "musculo_esqueletico_pct": types.Schema(type="NUMBER", description="Porcentaje de músculo esquelético ('Músculo esquelético'). Distinto de musculo_pct."),
                "masa_osea_kg": types.Schema(type="NUMBER", description="Kilos de hueso: 'Masa Esquelética', 'Masa ósea' o contenido mineral óseo."),
                "densidad_osea": types.Schema(type="NUMBER", description="Densidad mineral ósea total en g/cm². NO el T-score ni el Z-score."),
                "proteina_kg": types.Schema(type="NUMBER", description="Kilos de proteína corporal ('Cantidad de proteína')."),
                "proteina_pct": types.Schema(type="NUMBER", description="Proteína como porcentaje del peso ('Proteína')."),
                "agua_corporal_kg": types.Schema(type="NUMBER", description="Kilos de agua corporal ('Contenido de agua')."),
                "agua_corporal_pct": types.Schema(type="NUMBER", description="Porcentaje de agua corporal ('Agua Corporal')."),
                "grasa_subcutanea_pct": types.Schema(type="NUMBER", description="Porcentaje de grasa subcutánea."),
                "grasa_visceral": types.Schema(type="NUMBER", description="Nivel o índice de grasa visceral, en la escala que imprima el aparato."),
                "tmb_kcal": types.Schema(type="NUMBER", description="Metabolismo basal / TMB / BMR en kcal al día."),
                "edad_corporal": types.Schema(type="NUMBER", description="Edad corporal o metabólica en años."),
                "peso_ideal_kg": types.Schema(type="NUMBER", description="Peso estándar / ideal que propone el aparato ('Peso corporal estándar')."),
            },
        ),
        "metodo_composicion": types.Schema(
            type="STRING",
            enum=["dexa", "bioimpedancia", "plicometria", "bascula", "otro"],
            description="Con qué se midió la composición corporal, si la hay. Vacío si el documento no es de composición.",
        ),
    },
    required=["tipo_documento", "confianza_extraccion", "marcadores"],
)

_PROMPT_EXTRACCION = (
    "Eres un extractor de datos de documentos clínicos. Tu ÚNICA tarea es transcribir lo "
    "que ves, no interpretarlo.\n"
    "- Copia el nombre de cada parámetro EXACTAMENTE como está impreso, sin traducirlo ni "
    "abreviarlo.\n"
    "- Copia el valor numérico y su unidad tal cual.\n"
    "- Si el informe imprime un rango de referencia junto al valor, cópialo también. Si NO "
    "lo imprime, omite rango_min y rango_max — no pongas un rango que recuerdes de memoria.\n"
    "- No clasifiques nada como alto, bajo ni normal. No opines. No añadas parámetros que no "
    "estén en el documento.\n"
    "- Si un valor está borroso o dudoso, no lo incluyas y baja la confianza_extraccion.\n"
    "\n"
    "HAY DOS DESTINOS Y NO SE MEZCLAN:\n"
    "- `marcadores` es SOLO para parámetros de laboratorio medidos en sangre u orina "
    "(colesterol, glucosa, ferritina, testosterona, creatinina…). Extrae todos los que veas; "
    "ya se filtrarán después.\n"
    "- `composicion_corporal` es para las métricas corporales de un DEXA, InBody, Tanita, "
    "Fitdays o cualquier báscula de bioimpedancia: peso, IMC, grasa, masa magra, masa "
    "muscular, masa ósea, proteína, agua, grasa visceral, metabolismo basal, edad corporal. "
    "Rellena también `metodo_composicion`.\n"
    "- **NUNCA metas una métrica corporal en `marcadores`.** 'Masa Esquelética', 'Cantidad de "
    "proteína', 'Contenido de agua' y similares son composición corporal, NO son calcio, "
    "proteínas totales en sangre ni electrolitos, por mucho que el nombre se parezca.\n"
    "- Coge siempre los valores TOTALES de cuerpo entero, nunca los de una región (tronco, "
    "pierna izquierda…).\n"
    "- Si el documento no es de composición corporal, omite los dos campos."
)


def _extraer(documento: bytes, mime_type: str) -> dict:
    parte_documento = types.Part.from_bytes(data=documento, mime_type=mime_type)
    contenido = types.Content(
        role="user",
        parts=[
            parte_documento,
            types.Part.from_text(text="Transcribe los parámetros de este documento clínico."),
        ],
    )
    return gemini_client.generar_json(
        [contenido],
        system_instruction=_PROMPT_EXTRACCION,
        schema=_SCHEMA_EXTRACCION,
        temperature=0.0,
    )


# ============================================================
# Paso 2 — normalización y contraste (sin modelo)
# ============================================================

def _normalizar_marcadores(crudos: list[dict]) -> list[dict]:
    """Nombre literal → código canónico, y clasificación contra el rango que
    corresponda. Descarta lo que no está en el catálogo: una analítica trae
    decenas de parámetros que no dicen nada sobre construir físico, y guardarlos
    solo ensucia el historial y el prompt."""
    normalizados: list[dict] = []
    vistos: set[str] = set()

    for crudo in crudos:
        nombre = (crudo.get("nombre_literal") or "").strip()
        codigo = ref.normalizar_codigo(nombre)
        if not codigo or codigo in vistos:
            continue
        try:
            valor = float(crudo.get("valor"))
        except (TypeError, ValueError):
            continue

        ficha = ref.BIOMARCADORES[codigo]
        rango_min = crudo.get("rango_min")
        rango_max = crudo.get("rango_max")
        rango_del_informe = rango_min is not None or rango_max is not None
        if not rango_del_informe:
            rango_min, rango_max = ficha["rango"]

        vistos.add(codigo)
        normalizados.append({
            "codigo": codigo,
            "nombre": ficha["nombre"],
            "nombre_literal": nombre,
            "valor": valor,
            "unidad": (crudo.get("unidad") or "").strip() or ficha["unidad"],
            "rango_min": rango_min,
            "rango_max": rango_max,
            "rango_del_informe": rango_del_informe,
            "estado": ref.clasificar(codigo, valor, rango_min, rango_max),
        })

    return normalizados


def _bloque_contrastado(marcadores: list[dict]) -> tuple[str, list[dict]]:
    """Texto de referencia para el prompt + las fuentes que se persisten junto al
    informe. Solo se enriquecen los marcadores realmente presentes."""
    codigos = [m["codigo"] for m in marcadores][:MAX_MARCADORES_ENRIQUECIDOS]
    fichas = ref.fichas_referencia(codigos)
    info_nlm = medlineplus_client.info_pruebas([f["loinc"] for f in fichas])

    lineas = [
        "## Referencia contrastada (única base admitida para interpretar)",
        "Rangos y explicaciones verificados contra las fuentes citadas. No uses rangos "
        "de memoria: si un parámetro no está aquí, di que no puedes clasificarlo.",
        "",
    ]
    fuentes: list[dict] = []

    for ficha in fichas:
        rango = ficha["rango_referencia"]
        texto_rango = "sin rango definido"
        if rango["min"] is not None and rango["max"] is not None:
            texto_rango = f"{rango['min']}–{rango['max']} {ficha['unidad']}"
        elif rango["max"] is not None:
            texto_rango = f"< {rango['max']} {ficha['unidad']}"
        elif rango["min"] is not None:
            texto_rango = f"≥ {rango['min']} {ficha['unidad']}"

        # El `codigo` va en el encabezado, y no solo el LOINC, porque es la clave
        # con la que después se casa `relevancia_por_marcador`: con solo el LOINC
        # delante, el modelo devuelve el LOINC y las relevancias no casan con
        # ningún marcador (se pierden en silencio al guardar).
        lineas.append(f"### {ficha['nombre']} — codigo: `{ficha['codigo']}` (LOINC {ficha['loinc']})")
        lineas.append(f"- Rango de referencia: {texto_rango} — {ficha['fuente']}")
        if ficha.get("nota"):
            lineas.append(f"- Matiz: {ficha['nota']}")
        lineas.append(f"- Por qué importa para el físico: {ficha['porque_importa_para_el_fisico']}")

        nlm = info_nlm.get(ficha["loinc"])
        if nlm:
            lineas.append(f"- {nlm['fuente']}: {nlm['resumen']}")
            fuentes.append({
                "marcador": ficha["codigo"],
                "titulo": nlm["titulo"],
                "url": nlm["url"],
                "fuente": nlm["fuente"],
                "loinc": ficha["loinc"],
            })
        fuentes.append({
            "marcador": ficha["codigo"],
            "tipo": "rango_referencia",
            "fuente": ficha["fuente"],
            "loinc": ficha["loinc"],
        })
        lineas.append("")

    return "\n".join(lineas), fuentes


# ============================================================
# Paso 3 — redacción del informe
# ============================================================

_SCHEMA_INFORME = types.Schema(
    type="OBJECT",
    properties={
        "resumen": types.Schema(
            type="STRING",
            description="4-8 frases en español de España, dirigidas al usuario, sobre qué dice esta analítica para su entrenamiento y su alimentación. Markdown simple.",
        ),
        "hallazgos_clave": types.Schema(
            type="ARRAY",
            items=types.Schema(type="STRING"),
            description="Entre 2 y 6 frases cortas, cada una un hallazgo concreto con su cifra.",
        ),
        "implicaciones_entrenamiento": types.Schema(
            type="STRING",
            description="Qué cambia (o no) en cómo debe entrenar, según estos valores. Si no cambia nada, dilo.",
        ),
        "implicaciones_nutricion": types.Schema(
            type="STRING",
            description="Qué cambia (o no) en calorías, macros o micronutrientes.",
        ),
        "banderas_rojas": types.Schema(
            type="ARRAY",
            items=types.Schema(type="STRING"),
            description="Valores que justifican consultar con un profesional sanitario. Lista vacía si no hay ninguno. Nunca un diagnóstico, solo el motivo de consulta.",
        ),
        "relevancia_por_marcador": types.Schema(
            type="ARRAY",
            items=types.Schema(
                type="OBJECT",
                properties={
                    "codigo": types.Schema(
                        type="STRING",
                        description="El `codigo` EXACTO del bloque de referencia (ej. 'glucosa', 'ferritina', 'colesterol_total'). NUNCA el código LOINC ni el nombre traducido.",
                    ),
                    "relevancia": types.Schema(
                        type="STRING",
                        description=(
                            "Una frase (máx. 25 palabras) sobre qué implica este valor para construir "
                            "físico. NO repitas la cifra ni la unidad: la app ya las muestra al lado, y "
                            "al reescribirlas se cuelan números equivocados. Habla solo de la implicación."
                        ),
                    ),
                },
                required=["codigo", "relevancia"],
            ),
        ),
    },
    required=["resumen", "hallazgos_clave", "implicaciones_entrenamiento", "implicaciones_nutricion", "banderas_rojas"],
)

_PROMPT_REDACCION = (
    "Eres el analista clínico de Personal TrAIner. Traduces una analítica ya extraída a lo "
    "que significa para entrenar y comer, en español de España, tuteando al usuario.\n"
    "\n"
    "REGLAS INNEGOCIABLES:\n"
    "- Apóyate SOLO en el bloque de referencia contrastada que se te ha pasado y en los "
    "valores del usuario. No uses rangos ni umbrales que recuerdes de memoria; si un "
    "parámetro no aparece en la referencia, di que no puedes clasificarlo.\n"
    "- La clasificación (bajo/normal/alto) ya viene calculada. NO la recalcules ni la "
    "contradigas: explícala.\n"
    "- NO haces diagnósticos. Ante cualquier valor fuera de rango, el mensaje es 'esto "
    "conviene que lo mire un profesional', nunca 'tienes X'.\n"
    "- No inventes estudios, autores ni porcentajes con falsa precisión.\n"
    "- Si un valor fuera de rango tiene una explicación conocida y benigna en alguien que "
    "entrena (creatinina y CK altas por masa muscular, creatina o entrenamiento reciente), "
    "dilo explícitamente en vez de alarmar.\n"
    "- Si la confianza de extracción es baja, avísalo al principio del resumen.\n"
    "\n"
    "Escribe para una pantalla de móvil: frases cortas, negrita en las cifras clave, sin "
    "tablas y sin emojis."
)


def _redactar(marcadores: list[dict], bloque_referencia: str, extraccion: dict, perfil_prompt: str) -> dict:
    resumen_valores = "\n".join(
        f"- `{m['codigo']}` — {m['nombre']}: {m['valor']} {m['unidad']} → **{m['estado']}** "
        f"(rango aplicado {m['rango_min']}–{m['rango_max']}, "
        f"{'del propio informe' if m['rango_del_informe'] else 'de la tabla de referencia'})"
        for m in marcadores
    ) or "- (No se ha reconocido ningún biomarcador del catálogo en el documento.)"

    partes = [
        bloque_referencia,
        "\n## Valores de este usuario (ya clasificados, no los recalcules)\n" + resumen_valores,
        f"\n- Tipo de documento: {extraccion.get('tipo_documento')}",
        f"- Confianza de la extracción: {extraccion.get('confianza_extraccion')}",
    ]
    if extraccion.get("observaciones_texto"):
        partes.append(f"- Comentarios escritos en el propio informe: {extraccion['observaciones_texto']}")
    if perfil_prompt:
        partes.append("\n" + perfil_prompt)

    contenido = types.Content(role="user", parts=[types.Part.from_text(text="\n".join(partes))])
    return gemini_client.generar_json(
        [contenido],
        system_instruction=_PROMPT_REDACCION,
        schema=_SCHEMA_INFORME,
        temperature=0.3,
    )


# ============================================================
# Orquestación
# ============================================================

def _mapear_relevancias(crudas: list[dict], marcadores: list[dict]) -> dict[str, str]:
    """Casa cada relevancia con su marcador aunque el modelo haya identificado
    el parámetro por su LOINC o por su nombre en vez de por el `codigo`. Sin
    esta red, una desviación del schema hace que `relevancia_fisico` se guarde
    vacío en TODOS los marcadores sin que nada falle a la vista."""
    por_loinc = {ref.BIOMARCADORES[m["codigo"]]["loinc"]: m["codigo"] for m in marcadores}
    por_nombre = {ref.BIOMARCADORES[m["codigo"]]["nombre"].lower(): m["codigo"] for m in marcadores}
    validos = {m["codigo"] for m in marcadores}

    relevancias: dict[str, str] = {}
    for cruda in crudas:
        clave = (cruda.get("codigo") or "").strip()
        texto = (cruda.get("relevancia") or "").strip()
        if not clave or not texto:
            continue
        codigo = (
            clave if clave in validos
            else por_loinc.get(clave)
            or por_nombre.get(clave.lower())
            or ref.normalizar_codigo(clave)
        )
        if codigo in validos:
            relevancias[codigo] = texto
    return relevancias


def _fecha_valida(valor: str | None) -> str | None:
    if not valor:
        return None
    try:
        return date.fromisoformat(valor.strip()[:10]).isoformat()
    except ValueError:
        return None


def _persistir(user_id: str, marcadores: list[dict], informe: dict, fuentes: list[dict],
               tipo_documento: str, fecha_informe: str | None, nombre_archivo: str | None,
               confianza: str | None) -> dict:
    relevancias = _mapear_relevancias(informe.get("relevancia_por_marcador") or [], marcadores)
    payload = {
        "userId": user_id,
        "fecha_informe": fecha_informe,
        "tipo_documento": tipo_documento,
        "nombre_archivo": nombre_archivo,
        "resumen_ia": informe["resumen"],
        "hallazgos_clave": informe.get("hallazgos_clave") or [],
        "implicaciones_entrenamiento": informe.get("implicaciones_entrenamiento"),
        "implicaciones_nutricion": informe.get("implicaciones_nutricion"),
        "banderas_rojas": informe.get("banderas_rojas") or [],
        "fuentes_consultadas": fuentes,
        "confianza_extraccion": confianza,
        "marcadores": [
            {
                "codigo": m["codigo"],
                "nombre": m["nombre"],
                "valor": m["valor"],
                "unidad": m["unidad"],
                "rango_min": m["rango_min"],
                "rango_max": m["rango_max"],
                "estado": m["estado"],
                "relevancia_fisico": relevancias.get(m["codigo"]),
                "fecha": fecha_informe,
            }
            for m in marcadores
        ],
    }
    return nest.post("/clinical-reports", payload)


def _perfil_prompt(user_id: str) -> str:
    # Import local: evita que el pipeline arrastre el módulo de chat al importarse.
    import ai_profile
    return ai_profile.bloque_prompt(ai_profile.obtener(user_id))


def analizar_valores_manuales(user_id: str, valores: list[dict], fecha: str | None = None) -> dict:
    """Mismo tratamiento que un documento, pero partiendo de valores tecleados a
    mano: se clasifican contra la referencia, se contrastan con MedlinePlus y se
    redacta un informe. Escribir un número en un formulario y que no pase nada
    más es exactamente lo que hacía inútil la pantalla de Clínica."""
    crudos = [
        {
            "nombre_literal": v.get("codigo") or v.get("nombre") or "",
            "valor": v.get("valor"),
            "unidad": v.get("unidad"),
            "rango_min": v.get("rango_min"),
            "rango_max": v.get("rango_max"),
        }
        for v in valores
    ]
    marcadores = _normalizar_marcadores(crudos)
    if not marcadores:
        raise ValueError("No se ha reconocido ningún biomarcador válido entre los valores introducidos.")

    bloque_referencia, fuentes = _bloque_contrastado(marcadores)
    extraccion = {
        "tipo_documento": "manual",
        "confianza_extraccion": "alta",
        "observaciones_texto": "Valores introducidos a mano por el usuario en la app.",
    }
    informe = _redactar(marcadores, bloque_referencia, extraccion, _perfil_prompt(user_id))
    fecha_informe = _fecha_valida(fecha) or date.today().isoformat()

    guardado = _persistir(
        user_id, marcadores, informe, fuentes,
        tipo_documento="manual", fecha_informe=fecha_informe,
        nombre_archivo=None, confianza="alta",
    )
    return {
        "informe": guardado,
        "resumen": informe["resumen"],
        "hallazgos_clave": informe.get("hallazgos_clave") or [],
        "banderas_rojas": informe.get("banderas_rojas") or [],
        "marcadores_reconocidos": len(marcadores),
        "marcadores_extraidos": len(valores),
        "confianza_extraccion": "alta",
        "fuentes_consultadas": fuentes,
    }


def analizar_documento(user_id: str, data_b64: str, mime_type: str, file_name: str | None = None) -> dict:
    """Analiza y GUARDA. Devuelve el informe tal y como quedó persistido más el
    resumen redactado, para que la app pueda enseñarlo sin una segunda llamada."""
    mime = (mime_type or "").lower().strip()
    if mime not in MIMES_SOPORTADOS:
        raise DocumentoNoSoportadoError(
            f"El formato '{mime_type}' no se puede analizar. Sube un PDF o una foto (JPG/PNG) del informe."
        )

    try:
        documento = base64.b64decode(data_b64, validate=True)
    except Exception as exc:  # noqa: BLE001
        raise ValueError("El archivo no llegó correctamente codificado.") from exc
    if not documento:
        raise ValueError("El archivo está vacío.")

    extraccion = _extraer(documento, mime)
    fecha_informe = _fecha_valida(extraccion.get("fecha_informe"))

    # La composición se guarda ANTES de redactar, no después: así el perfil que
    # se le pasa al redactor ya la incluye y el informe puede hablar de las
    # cifras nuevas en vez de las de la medición anterior.
    composicion = body_composition.desde_documento(
        user_id,
        extraccion.get("composicion_corporal"),
        fecha=fecha_informe,
        metodo=extraccion.get("metodo_composicion"),
        notas=f"Extraído de {file_name}" if file_name else None,
    )

    marcadores = _normalizar_marcadores(extraccion.get("marcadores") or [])

    # Un DEXA o un InBody no traen biomarcadores de sangre. Antes se redactaba
    # igualmente un informe clínico sobre una lista vacía; ahora se devuelve la
    # lectura de la composición, que es lo que el documento sí decía.
    if not marcadores and composicion and composicion.get("medicion"):
        return {
            "informe": None,
            "composicion": composicion,
            "resumen": "\n\n".join(composicion["lecturas"]),
            "hallazgos_clave": composicion["lecturas"],
            "banderas_rojas": [],
            "marcadores_reconocidos": 0,
            "marcadores_extraidos": len(extraccion.get("marcadores") or []),
            "confianza_extraccion": extraccion.get("confianza_extraccion"),
            "fuentes_consultadas": composicion["fuentes_consultadas"],
        }

    bloque_referencia, fuentes = _bloque_contrastado(marcadores)

    # El perfil del usuario entra en la redacción para que el informe hable de
    # SU caso (su objetivo, su nivel, su análisis físico), no de un adulto medio.
    informe = _redactar(marcadores, bloque_referencia, extraccion, _perfil_prompt(user_id))

    guardado = _persistir(
        user_id, marcadores, informe, fuentes,
        tipo_documento=extraccion.get("tipo_documento") or "analitica",
        fecha_informe=fecha_informe,
        nombre_archivo=file_name,
        confianza=extraccion.get("confianza_extraccion"),
    )

    return {
        "informe": guardado,
        "composicion": composicion,
        "resumen": informe["resumen"],
        "hallazgos_clave": informe.get("hallazgos_clave") or [],
        "banderas_rojas": informe.get("banderas_rojas") or [],
        "marcadores_reconocidos": len(marcadores),
        "marcadores_extraidos": len(extraccion.get("marcadores") or []),
        "confianza_extraccion": extraccion.get("confianza_extraccion"),
        "fuentes_consultadas": fuentes + (composicion or {}).get("fuentes_consultadas", []),
    }
