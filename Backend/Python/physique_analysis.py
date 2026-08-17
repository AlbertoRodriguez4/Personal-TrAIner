"""Pipeline de fotos del físico a un registro de seguimiento en base de datos.

Mismo principio que `clinical_analysis`: antes de que el modelo mire nada, se le
pone delante una referencia contrastada — las categorías de grasa corporal del
ACE, la clasificación de IMC de la OMS y el rango de proteína de la ISSN — para
que clasifique contra una escala publicada y no contra su propia impresión. A eso
se le suma la geometría de pose de MediaPipe (`pose_analysis`) y lo que la app ya
sabe del usuario: análisis anteriores y biomarcadores fuera de rango.

Lo que se persiste no es el texto bonito, sino los campos que luego cambian
decisiones: grupos musculares retrasados, prioridad de entrenamiento y
composición estimada. Es lo que Pulso relee en cada turno (ver `ai_profile`).
"""
import base64

from google.genai import types

import ai_profile
import clinical_reference as ref
import gemini_client
import nest_client as nest
import pose_analysis

MIMES_SOPORTADOS = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}

# Con más de 5 fotos el prompt crece mucho sin aportar ángulos nuevos: frontal,
# lateral, espalda y un par de variantes ya cubren lo que se puede juzgar a ojo.
MAX_FOTOS = 5


class FotoNoSoportadaError(Exception):
    """Alguna de las imágenes no está en un formato que el modelo pueda leer."""


class FotosNoAnalizablesError(Exception):
    """El formato es válido pero las fotos no permiten juzgar el físico (ropa
    holgada, encuadre, luz, no se ve a nadie). No se guarda nada: un registro
    inventado envenena el contexto de TODAS las respuestas posteriores de Pulso,
    porque `grupos_musculares_retrasados` es lo que dirige la rutina."""


_SCHEMA_ANALISIS = types.Schema(
    type="OBJECT",
    properties={
        "fotos_analizables": types.Schema(
            type="BOOLEAN",
            description="false si las fotos no permiten evaluar el físico (no se ve a una persona, ropa holgada, encuadre cortado, luz o resolución insuficientes). Ante la duda, false.",
        ),
        "motivo_no_analizable": types.Schema(
            type="STRING",
            description="Si fotos_analizables es false, qué le falta a las fotos, explicado al usuario para que sepa cómo repetirlas. Vacío en caso contrario.",
        ),
        "analisis_general": types.Schema(
            type="STRING",
            description="6-10 frases en español de España, tuteando, describiendo la composición y el desarrollo muscular observados. Markdown simple, sin juicios sobre el cuerpo de la persona.",
        ),
        "porcentaje_grasa_estimado": types.Schema(
            type="NUMBER",
            description="Punto medio del rango estimado. Omitir si las fotos no permiten estimarlo (ropa, luz, encuadre).",
        ),
        "rango_grasa_estimado": types.Schema(
            type="STRING",
            description="El rango real, ej. '14-18 %'. Es lo que se le enseña al usuario; el número suelto es solo para la base de datos.",
        ),
        "masa_muscular_estimada_kg": types.Schema(type="NUMBER", description="Omitir si no hay base para estimarla."),
        "somatotipo_estimado": types.Schema(type="STRING", enum=["Ectomorfo", "Mesomorfo", "Endomorfo"]),
        "nivel_fitness_estimado": types.Schema(type="STRING", enum=["Principiante", "Intermedio", "Avanzado"]),
        "grupos_musculares_retrasados": types.Schema(
            type="ARRAY",
            items=types.Schema(
                type="STRING",
                enum=["pecho", "espalda", "hombros", "brazos", "piernas", "gluteos", "pantorrillas", "abdomen", "trapecio", "antebrazos"],
            ),
            description="Los que van por detrás del resto de su propio cuerpo, entre 1 y 4. Este campo dirige después la selección de ejercicios de su rutina: rellénalo SOLO con lo que veas de verdad en las fotos. Si no puedes juzgarlo, déjalo vacío — es mejor vacío que adivinado.",
        ),
        "grupos_musculares_dominantes": types.Schema(
            type="ARRAY",
            items=types.Schema(
                type="STRING",
                enum=["pecho", "espalda", "hombros", "brazos", "piernas", "gluteos", "pantorrillas", "abdomen", "trapecio", "antebrazos"],
            ),
        ),
        "puntos_fuertes_fisicos": types.Schema(type="ARRAY", items=types.Schema(type="STRING")),
        "areas_mejora_fisicas": types.Schema(type="ARRAY", items=types.Schema(type="STRING")),
        "postura_observaciones": types.Schema(
            type="STRING",
            description="Lo observable en las fotos (báscula pélvica, hombros adelantados, asimetría). Si la geometría de pose sugiere algo, mátizalo: puede ser el ángulo de la cámara.",
        ),
        "prioridad_entrenamiento": types.Schema(
            type="STRING",
            description="UNA frase accionable: en qué se tiene que centrar su entrenamiento ahora y por qué. Es lo que leerá la IA al construirle la rutina.",
        ),
        "recomendaciones": types.Schema(type="STRING", description="Recomendaciones de entrenamiento y nutrición ancladas a lo observado."),
        "comparacion_progreso": types.Schema(
            type="STRING",
            description="Comparación con el análisis anterior si se te ha pasado uno. Cadena vacía si es el primero — no te lo inventes.",
        ),
        "medidas_estimadas": types.Schema(
            type="OBJECT",
            properties={
                "ratio_hombro_cintura": types.Schema(type="STRING", description="Ej. 'alto', 'medio', 'bajo' o un valor aproximado. Vacío si no se aprecia."),
                "simetria": types.Schema(type="STRING"),
                "definicion_abdominal": types.Schema(type="STRING"),
            },
        ),
    },
    # `grupos_musculares_retrasados` y `prioridad_entrenamiento` NO son required
    # a propósito: al serlo, ante una foto inservible el modelo rellenaba ambos a
    # ojo en vez de dejarlos vacíos (comprobado), y eso acaba dirigiendo la rutina
    # con datos inventados.
    required=["fotos_analizables", "analisis_general"],
)

_PROMPT = (
    "Eres el analista de composición corporal de Personal TrAIner. Evalúas fotos del físico "
    "para decidir en qué se tiene que centrar el entrenamiento de esta persona. Español de "
    "España, tuteando.\n"
    "\n"
    "REGLAS INNEGOCIABLES:\n"
    "- Clasifica el porcentaje de grasa usando ÚNICAMENTE las categorías del bloque de "
    "referencia contrastada que se te ha pasado. No uses escalas que recuerdes de memoria.\n"
    "- Estimar composición corporal a ojo tiene un margen de error amplio y depende de la "
    "luz, la pose y el ángulo. Habla SIEMPRE en rangos, no en cifras exactas, y di que no "
    "sustituye a un DEXA, una bioimpedancia ni un plicómetro.\n"
    "- Si una foto no permite juzgar algo (ropa holgada, encuadre, luz), dilo y omite ese "
    "campo en vez de rellenarlo a ojo.\n"
    "- Si las fotos directamente no sirven (no se ve a una persona, está vestida de calle, "
    "el encuadre corta el cuerpo, la resolución no da), pon `fotos_analizables` en false, "
    "explica en `motivo_no_analizable` qué le falta a la foto, y NO rellenes ningún otro "
    "campo de valoración. Adivinar sus puntos débiles es peor que no dar ninguno: esos "
    "campos se usan luego para construirle la rutina.\n"
    "- La geometría de pose que se te pasa son coordenadas normalizadas al encuadre, NO "
    "medidas corporales. Diferencias pequeñas pueden ser del ángulo de cámara. No las "
    "conviertas en un diagnóstico postural.\n"
    "- Tono constructivo y neutro: describes composición y márgenes de mejora, nunca juzgas "
    "el cuerpo de la persona ni usas lenguaje sobre peso con carga moral.\n"
    "- Si hay biomarcadores fuera de rango en su contexto, tenlos en cuenta al recomendar, "
    "pero NO hagas diagnósticos: deriva a un profesional.\n"
    "\n"
    "`grupos_musculares_retrasados` y `prioridad_entrenamiento` son los campos que después "
    "usará el generador de rutinas para elegir ejercicios: sé concreto y útil ahí."
)


def _bloque_contexto(perfil: dict | None) -> tuple[str, list[dict]]:
    """Referencia contrastada + lo que ya sabemos del usuario. Devuelve también
    las fuentes, que se guardan con el registro para poder auditarlo."""
    basicos = (perfil or {}).get("datos_basicos") or {}
    referencia = ref.referencia_composicion_corporal(
        basicos.get("sexo"), basicos.get("peso_kg"), basicos.get("altura_cm")
    )

    lineas = ["## Referencia contrastada (única escala admitida para clasificar)"]
    grasa = referencia["categorias_grasa_corporal"]
    lineas.append(f"Categorías de grasa corporal ({grasa['sexo_aplicado']}) — {grasa['fuente']}:")
    for tramo in grasa["tramos"]:
        hasta = f"{tramo['hasta']} %" if tramo["hasta"] is not None else "en adelante"
        lineas.append(f"  - {tramo['desde']}–{hasta}: {tramo['categoria']}")
    if referencia["imc"]:
        imc = referencia["imc"]
        lineas.append(f"IMC actual: {imc['imc']} → {imc['categoria']} ({imc['fuente']})")
    proteina = referencia["proteina_objetivo_g_por_kg"]
    lineas.append(
        f"Proteína para ganar masa magra: {proteina['min']}–{proteina['max']} g/kg/día — {proteina['fuente']}"
    )
    lineas.append(f"Aviso de método: {referencia['advertencia_metodo']}")

    fuentes = [
        {"tipo": "categorias_grasa_corporal", "fuente": grasa["fuente"]},
        {"tipo": "proteina_objetivo", "fuente": proteina["fuente"]},
    ]
    if referencia["imc"]:
        fuentes.append({"tipo": "clasificacion_imc", "fuente": referencia["imc"]["fuente"]})

    bloque_perfil = ai_profile.bloque_prompt(perfil)
    if bloque_perfil:
        lineas.append("\n" + bloque_perfil)

    return "\n".join(lineas), fuentes


def analizar_fotos(user_id: str, fotos: list[dict], notas: str | None = None) -> dict:
    """Analiza y GUARDA el registro con sus fotos. `fotos` es una lista de
    {data (base64), mime_type, angulo}."""
    if not fotos:
        raise ValueError("Hace falta al menos una foto del físico para analizar.")

    fotos = fotos[:MAX_FOTOS]
    decodificadas = []
    for foto in fotos:
        mime = (foto.get("mime_type") or "").lower().strip()
        if mime not in MIMES_SOPORTADOS:
            raise FotoNoSoportadaError(
                f"El formato '{foto.get('mime_type')}' no se puede analizar. Usa JPG o PNG."
            )
        try:
            imagen = base64.b64decode(foto["data"], validate=True)
        except Exception as exc:  # noqa: BLE001
            raise ValueError("Alguna de las fotos no llegó correctamente codificada.") from exc
        if not imagen:
            raise ValueError("Alguna de las fotos llegó vacía.")
        decodificadas.append({"bytes": imagen, "mime": mime, "angulo": foto.get("angulo") or "otro"})

    perfil = ai_profile.obtener(user_id)
    bloque_contexto, fuentes = _bloque_contexto(perfil)

    partes: list[types.Part] = []
    texto = [bloque_contexto, "\n## Fotos adjuntas"]

    for idx, foto in enumerate(decodificadas, start=1):
        partes.append(types.Part.from_bytes(data=foto["bytes"], mime_type=foto["mime"]))
        texto.append(f"- Foto {idx}: ángulo {foto['angulo']}")
        # Preprocesado de enriquecimiento, nunca obligatorio: si no detecta a
        # nadie o falla, extraer_metricas_pose devuelve None y seguimos igual.
        metricas = pose_analysis.extraer_metricas_pose(foto["bytes"])
        if metricas:
            texto.append(f"  · Geometría de pose (MediaPipe, referencia geométrica): {metricas}")

    if notas:
        texto.append(f"\n## Contexto que aporta el usuario\n{notas}")
    texto.append("\nAnaliza estas fotos y rellena el informe.")

    partes.append(types.Part.from_text(text="\n".join(texto)))
    contenido = types.Content(role="user", parts=partes)

    analisis = gemini_client.generar_json(
        [contenido],
        system_instruction=_PROMPT,
        schema=_SCHEMA_ANALISIS,
        temperature=0.3,
    )

    if not analisis.get("fotos_analizables"):
        raise FotosNoAnalizablesError(
            analisis.get("motivo_no_analizable")
            or "Las fotos no permiten evaluar el físico. Repítelas con buena luz, "
            "cuerpo entero en el encuadre y ropa ajustada o deportiva."
        )

    medidas = dict(analisis.get("medidas_estimadas") or {})
    if analisis.get("rango_grasa_estimado"):
        # El rango es lo honesto; el número suelto solo existe para poder
        # dibujar la tendencia. Se guarda junto a él para que nunca se enseñe
        # la cifra sin su margen.
        medidas["rango_grasa_estimado"] = analisis["rango_grasa_estimado"]

    payload = {
        "userId": user_id,
        "origen": "seguimiento_fotos",
        "analisis_general": analisis["analisis_general"],
        "peso_estimado_kg": analisis.get("peso_estimado_kg"),
        "porcentaje_grasa_estimado": analisis.get("porcentaje_grasa_estimado"),
        "masa_muscular_estimada_kg": analisis.get("masa_muscular_estimada_kg"),
        "somatotipo_estimado": analisis.get("somatotipo_estimado"),
        "nivel_fitness_estimado": analisis.get("nivel_fitness_estimado"),
        "puntos_fuertes_fisicos": analisis.get("puntos_fuertes_fisicos") or [],
        "areas_mejora_fisicas": analisis.get("areas_mejora_fisicas") or [],
        "grupos_musculares_retrasados": analisis.get("grupos_musculares_retrasados") or [],
        "grupos_musculares_dominantes": analisis.get("grupos_musculares_dominantes") or [],
        "postura_observaciones": analisis.get("postura_observaciones"),
        "prioridad_entrenamiento": analisis.get("prioridad_entrenamiento"),
        "recomendaciones": analisis.get("recomendaciones"),
        "comparacion_progreso": analisis.get("comparacion_progreso") or None,
        "medidas_estimadas": medidas or None,
        "fuentes_consultadas": fuentes,
        "notas_adicionales": notas,
        "angulos_fotos": [f["angulo"] for f in decodificadas],
        "fotos": [
            {
                "angulo": f["angulo"],
                "mime_type": f["mime"],
                "data": base64.b64encode(f["bytes"]).decode("ascii"),
            }
            for f in decodificadas
        ],
    }
    guardado = nest.post("/body-analysis/with-photos", payload)

    return {
        "registro": guardado,
        "analisis_general": analisis["analisis_general"],
        "rango_grasa_estimado": analisis.get("rango_grasa_estimado"),
        "grupos_musculares_retrasados": analisis.get("grupos_musculares_retrasados") or [],
        "prioridad_entrenamiento": analisis.get("prioridad_entrenamiento"),
        "recomendaciones": analisis.get("recomendaciones"),
        "fuentes_consultadas": fuentes,
    }
