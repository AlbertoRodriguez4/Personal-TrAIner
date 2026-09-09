import base64
import json
import time

from google.genai import types
from groq import (
    Groq,
    APIStatusError as GroqAPIStatusError,
    BadRequestError as GroqBadRequestError,
    RateLimitError as GroqRateLimitError,
)

from chat_tools import TOOLS_BY_MODE, EXECUTORS, SYSTEM_PROMPTS, BASE_GUIDELINES
from gemini_client import (
    _env,
    # Las dos excepciones de Gemini se reexportan a propósito: main.py las importa
    # desde aquí desde antes de que existiera gemini_client.
    GeminiQuotaExhaustedError,
    GeminiSobrecargadoError,
    LLMProviderExhaustedError,
    RETRY_ATTEMPTS,
    RETRY_BACKOFF_SECONDS,
    generate as _generate_with_model_fallback,
)
import ai_profile
import pose_analysis

# Presupuesto de pasos de function calling por turno. No es solo una guarda contra
# loops infinitos: es el techo real de trabajo del modelo. Con 5, creador_rutina se
# quedaba sin pasos investigando (una búsqueda por grupo muscular entre
# buscar_ejercicios_catalogo y buscar_ejercicios_wger) y nunca llegaba a llamar a
# crear_rutina_personalizada — el usuario veía "se alcanzó el límite de pasos" y no se
# creaba nada. 8 deja margen para 2-3 búsquedas + la creación. Barato en Groq (30 RPM),
# y los modos de imagen (Gemini, cuota ajustada) casi nunca encadenan tantas tools.
MAX_TOOL_ITERATIONS = 8

LIMITE_PASOS_MSG = "Se alcanzó el límite de pasos permitidos para esta consulta. ¿Podés reformularla?"

# Groq no procesa imágenes: estos modos se quedan exclusivamente en Gemini y nunca caen a
# Groq, aunque agoten los reintentos.
IMAGE_MODES = {"nutricion", "analisis_fisico"}

GROQ_API_KEY = _env("GROQ_API_KEY")
# openai/gpt-oss-120b es el reemplazo oficial recomendado por Groq. NUNCA usar
# llama-3.3-70b-versatile ni qwen/qwen3-32b como default: ambos deprecados.
GROQ_MODEL = _env("GROQ_MODEL", "openai/gpt-oss-120b")

# Techo de tokens por minuto del tier gratuito ("on_demand") de Groq, verificado
# contra la API real: 8000 TPM para openai/gpt-oss-120b, y cuenta ENTRADA +
# max_completion_tokens RESERVADOS en la misma petición (no el output real). Pedir
# más devuelve 413 antes de generar nada. Ajustable por env si se sube de tier.
GROQ_TPM_LIMIT = int(_env("GROQ_TPM_LIMIT", "8000"))
GROQ_TOKENS_MARGEN = 600        # colchón para el error de la estimación de entrada
GROQ_MAX_COMPLETION_TOKENS = 5000   # suficiente para una rutina de 6 días / 42 ejercicios
GROQ_MIN_COMPLETION_TOKENS = 1200   # por debajo de esto la respuesta sale truncada igual

# ── Recortes para que la conversación quepa en el presupuesto ──
# El historial que manda la app es la conversación ENTERA, y las respuestas de
# los modos de rutina son largas por diseño (el prompt exige justificar ejercicio
# por ejercicio). Sin tope, crear una rutina y pedir que la revisen a continuación
# ya se pasa de las 8000 TPM. Seis turnos son de sobra para el hilo de una
# consulta; lo anterior lo aporta el perfil, que va aparte y siempre completo.
MAX_TURNOS_HISTORIAL = 6
MAX_CHARS_TURNO_HISTORIAL = 1500
# Resultados de tools: el catálogo de ejercicios o una rutina de 6 días ocupan
# más que todo el resto junto si se reenvían crudos.
MAX_CHARS_RESULTADO_TOOL = 3500

# Grounding con Google Search, apagado por defecto.
# Verificado contra la API real: la búsqueda tiene su propia cuota, aparte de la de
# generate_content, y con la key actual devuelve 429 RESOURCE_EXHAUSTED tanto sola como
# combinada con function_declarations (las llamadas normales y las de function calling
# sí funcionan). No es una incompatibilidad técnica entre grounding y tools: es cuota de
# facturación. Cuando la cuenta tenga búsqueda habilitada, poner
# GEMINI_ENABLE_SEARCH_GROUNDING=1 en el .env y esto se activa sin tocar código.
ENABLE_SEARCH_GROUNDING = _env("GEMINI_ENABLE_SEARCH_GROUNDING").lower() in ("1", "true", "yes")

_groq_client = Groq(api_key=GROQ_API_KEY) if GROQ_API_KEY else None


class GroqQuotaExhaustedError(LLMProviderExhaustedError):
    """Groq agotó los reintentos: 429/rate limit sostenido."""


class RespuestaDemasiadoGrandeError(Exception):
    """La petición no cabe en el presupuesto de tokens del tier gratuito de Groq, o el
    modelo truncó su propia respuesta a medio generar el JSON de una tool (Groq lo
    rechaza con 400 `tool_use_failed`). Ninguno de los dos se arregla reintentando lo
    mismo: hay que pedirle al usuario algo más corto."""


def _lowercase_schema_types(node):
    if isinstance(node, dict):
        return {
            key: (value.lower() if key == "type" and isinstance(value, str) else _lowercase_schema_types(value))
            for key, value in node.items()
        }
    if isinstance(node, list):
        return [_lowercase_schema_types(item) for item in node]
    return node


def _function_decl_to_groq_tool(decl: types.FunctionDeclaration) -> dict:
    """Convierte una types.FunctionDeclaration de Gemini (parameters: types.Schema, con
    type="OBJECT"/"STRING"/etc.) al formato de tool OpenAI/Groq-style, que espera JSON
    Schema en minúsculas ("object"/"string"/etc.)."""
    parameters = _lowercase_schema_types(decl.parameters.model_dump(mode="json", exclude_none=True))
    return {
        "type": "function",
        "function": {
            "name": decl.name,
            "description": decl.description or "",
            "parameters": parameters,
        },
    }


def _execute_tool(user_id: str, name: str, args: dict, actions_taken: list) -> dict:
    executor = EXECUTORS.get(name)
    if executor is None:
        return {"error": f"tool '{name}' no implementada"}
    try:
        result = executor(user_id=user_id, **args)
    except Exception as exc:  # noqa: BLE001
        return {"error": str(exc)}
    actions_taken.append({"tool": name, "result": result})
    return result


def run_chat(
    user_id: str,
    mode: str,
    message: str,
    history: list[dict],
    health_context: dict | None,
    images: list[dict] | None = None,
) -> dict:
    """
    history: [{"role": "user"|"model", "text": "..."}]  (turnos previos, sin function calls)
    Devuelve {"reply": str, "actions_taken": [ {"tool": str, "result": dict} ]}

    Enrutamiento ESTRICTO por modo, decidido antes de llamar a nada — no es un fallback
    reactivo. Los modos con imagen (IMAGE_MODES) van siempre a Gemini; el resto va siempre
    a Groq. Nunca se mezclan proveedores dentro de un mismo turno, porque el historial de
    function-calls de uno no es compatible con el formato del otro, y ninguno de los dos
    cae al otro ante un 429 — cada uno agota sus propios reintentos y sube su propia
    LLMProviderExhaustedError (GeminiQuotaExhaustedError / GroqQuotaExhaustedError), que
    main.py traduce a 503 con un mensaje distinto por proveedor.
    """
    if mode not in TOOLS_BY_MODE:
        raise ValueError(f"Modo desconocido: {mode}")

    # El perfil clínico/físico se lee una vez por turno y se antepone al system
    # prompt de cualquier modo: ver ai_profile para por qué no es una tool.
    perfil_prompt, _ = ai_profile.contexto_para_prompt(user_id)

    if mode in IMAGE_MODES:
        return _run_chat_gemini(user_id, mode, message, history, health_context, images, perfil_prompt)

    if _groq_client is None:
        raise RuntimeError(
            "GROQ_API_KEY no configurada: los modos de texto requieren Groq (openai/gpt-oss-120b)."
        )
    return _run_chat_groq(user_id, mode, message, history, health_context, perfil_prompt)


def _run_chat_gemini(
    user_id: str,
    mode: str,
    message: str,
    history: list[dict],
    health_context: dict | None,
    images: list[dict] | None,
    perfil_prompt: str = "",
) -> dict:
    tools = [types.Tool(function_declarations=TOOLS_BY_MODE[mode])]
    if ENABLE_SEARCH_GROUNDING:
        tools.append(types.Tool(google_search=types.GoogleSearch()))

    # Las reglas de formato y rigor son las mismas para los 6 modos; el prompt del modo
    # solo aporta lo suyo encima, y el perfil real del usuario cierra el bloque.
    system_instruction = f"{SYSTEM_PROMPTS[mode]}\n\n{BASE_GUIDELINES}"
    if perfil_prompt:
        system_instruction += f"\n\n{perfil_prompt}"

    contents = [
        types.Content(role=turn["role"], parts=[types.Part.from_text(text=turn["text"])])
        for turn in history
    ]

    user_text = message
    if health_context:
        user_text += f"\n\n[Contexto Health Connect — datos reales, no inventar]\n{health_context}"

    user_parts = []
    if images:
        for idx, img in enumerate(images):
            image_bytes = base64.b64decode(img["data"])
            user_parts.append(types.Part.from_bytes(data=image_bytes, mime_type=img["mime_type"]))

            # Preprocesado automático (no una tool) solo en analisis_fisico — ver
            # vision_computacional_postura/SKILL.md. Nunca bloquea el turno: si no
            # detecta a nadie o algo falla, extraer_metricas_pose ya devuelve None.
            if mode == "analisis_fisico":
                metricas_pose = pose_analysis.extraer_metricas_pose(image_bytes)
                if metricas_pose:
                    etiqueta = f"foto {idx + 1}" if len(images) > 1 else "la foto"
                    user_text += (
                        f"\n\n[Geometría de pose detectada automáticamente en {etiqueta} "
                        f"(MediaPipe, referencia geométrica — no reemplaza tu criterio visual, "
                        f"no es una medición corporal)]\n{metricas_pose}"
                    )
    user_parts.append(types.Part.from_text(text=user_text))
    contents.append(types.Content(role="user", parts=user_parts))

    config = types.GenerateContentConfig(
        system_instruction=system_instruction,
        tools=tools,
    )

    actions_taken = []

    for _ in range(MAX_TOOL_ITERATIONS):
        response = _generate_with_model_fallback(contents, config)

        # Verify the structure of candidate parts based on actual SDK (it might vary slightly)
        if not response.candidates:
            return {"reply": "No se recibió respuesta del modelo.", "actions_taken": actions_taken}

        candidate_parts = response.candidates[0].content.parts

        function_calls = [p for p in candidate_parts if getattr(p, "function_call", None)]
        if not function_calls:
            final_text = "".join(getattr(p, "text", "") or "" for p in candidate_parts)
            return {"reply": final_text, "actions_taken": actions_taken}

        contents.append(response.candidates[0].content)  # turno del modelo con la/s function_call

        response_parts = []
        for part in function_calls:
            name = part.function_call.name
            args = part.function_call.args

            # args can be a mapping or a dict, safely handle it
            if args is None:
                args = {}
            elif hasattr(args, "model_dump"):
                args = args.model_dump()
            elif not isinstance(args, dict):
                args = dict(args)

            result = _execute_tool(user_id, name, args, actions_taken)
            response_parts.append(types.Part.from_function_response(name=name, response={"result": result}))

        contents.append(types.Content(role="user", parts=response_parts))

    # Agotadas las iteraciones: en vez de devolver un callejón sin salida, una última
    # pasada SIN tools obliga al modelo a redactar lo que tenga con lo ya recabado.
    try:
        cierre = _generate_with_model_fallback(
            contents,
            types.GenerateContentConfig(system_instruction=system_instruction),
        )
        texto = "".join(getattr(p, "text", "") or "" for p in cierre.candidates[0].content.parts)
    except Exception:  # noqa: BLE001 — si el cierre falla, cae al mensaje genérico
        texto = ""

    return {"reply": texto or LIMITE_PASOS_MSG, "actions_taken": actions_taken}


def _history_to_groq_messages(history: list[dict]) -> list[dict]:
    """Historial de la app → mensajes de Groq, quedándose solo con los últimos
    turnos y recortando los muy largos.

    La app manda la conversación entera en cada turno. Sin este recorte, el
    historial crece sin techo dentro de la misma sesión de chat y acaba comiéndose
    el presupuesto de 8000 TPM él solo."""
    recientes = history[-MAX_TURNOS_HISTORIAL:]
    return [
        {
            "role": "assistant" if turn["role"] == "model" else turn["role"],
            "content": _recortar(turn["text"], MAX_CHARS_TURNO_HISTORIAL),
        }
        for turn in recientes
    ]


def _recortar(texto: str, limite: int) -> str:
    if len(texto) <= limite:
        return texto
    return texto[:limite] + "\n[...recortado por longitud]"


def _tokens_aprox(messages: list[dict], tools_groq: list[dict] | None) -> int:
    """~4 caracteres por token: no es exacto, pero para decidir qué recortar
    sobra, y el margen de GROQ_TOKENS_MARGEN absorbe el error."""
    payload = json.dumps(messages, ensure_ascii=False)
    if tools_groq:
        payload += json.dumps(tools_groq, ensure_ascii=False)
    return len(payload) // 4


def _es_descartable(msg: dict) -> bool:
    """Un mensaje de conversación suelta (texto de usuario o del modelo), sin
    tool_calls asociados.

    Los que NO lo son hay que dejarlos: Groq exige que cada mensaje `tool` vaya
    precedido de su `assistant` con el `tool_call_id` que le corresponde, así
    que descartar uno de los dos por separado devuelve un 400."""
    return msg.get("role") in ("user", "assistant") and not msg.get("tool_calls")


def _ajustar_a_presupuesto(
    messages: list[dict], tools_groq: list[dict] | None
) -> tuple[list[dict], int]:
    """Recorta la conversación hasta que quepa, y devuelve (mensajes, max_completion).

    Antes esto solo calculaba el `max_completion_tokens` y aplicaba un suelo de
    GROQ_MIN_COMPLETION_TOKENS. Ese suelo era justo el bug: con una entrada de más
    de ~6800 tokens, reservar 1200 de salida da >8000 y Groq responde 413 sin
    generar nada. Pasaba al crear o revisar una rutina, porque el argumento de la
    tool lleva el plan entero y encima el historial venía completo.

    Ahora, si no entra, se van descartando los mensajes de conversación más
    antiguos (nunca el system, nunca el último mensaje, nunca un bloque de
    tool-calls a medias). Perder contexto viejo degrada la respuesta; un 413 la
    deja sin responder."""
    trabajo = list(messages)

    while True:
        disponible = GROQ_TPM_LIMIT - _tokens_aprox(trabajo, tools_groq) - GROQ_TOKENS_MARGEN
        if disponible >= GROQ_MIN_COMPLETION_TOKENS:
            return trabajo, min(GROQ_MAX_COMPLETION_TOKENS, disponible)

        # Se descarta el más antiguo que se pueda soltar sin romper el pareado
        # assistant/tool. El índice 0 es el system y el último es el turno que
        # se está respondiendo: ninguno de los dos se toca.
        indice = next(
            (i for i, m in enumerate(trabajo[1:-1], start=1) if _es_descartable(m)),
            None,
        )
        if indice is None:
            # Ya no queda nada suelto que soltar: lo que ocupa es el system, las
            # tools y el turno en curso. Mejor un mensaje claro que un 413 crudo.
            if disponible < GROQ_MIN_COMPLETION_TOKENS // 2:
                raise RespuestaDemasiadoGrandeError(
                    f"La consulta no cabe en el presupuesto de {GROQ_TPM_LIMIT} tokens "
                    f"del tier actual (faltan {GROQ_MIN_COMPLETION_TOKENS - disponible})."
                )
            return trabajo, max(disponible, 256)
        trabajo.pop(indice)


def _es_tool_use_failed(exc: GroqBadRequestError) -> bool:
    """400 `tool_use_failed`: el modelo cortó el JSON de la tool a medio generar y Groq
    no pudo parsearlo. Pasa con payloads grandes (una rutina de 6 días entera)."""
    return "tool_use_failed" in str(exc) or "Failed to parse tool call arguments" in str(exc)


def _create_groq_completion_with_retry(messages: list[dict], tools_groq: list[dict] | None = None):
    """chat.completions.create con hasta RETRY_ATTEMPTS intentos ante 429 de Groq — mismo
    patrón que _generate_with_retry para Gemini. Necesario porque, con el enrutamiento
    estricto, Groq es el ÚNICO proveedor de 4 de los 6 modos: un 429 sin manejar acá se
    colaría como excepción cruda hasta el 500 genérico de main.py.

    Además traduce los dos fallos de tamaño (413 por TPM, 400 tool_use_failed) a
    RespuestaDemasiadoGrandeError: reintentar lo mismo no los arregla, así que no se
    reintentan — se le pide al usuario algo más corto.

    reasoning_effort='low': gpt-oss-120b es un modelo de razonamiento y gasta tokens de
    "pensamiento" que compiten con el JSON de salida dentro del mismo presupuesto de
    8000 TPM. Medido: ahorra ~600 tokens por llamada sin degradar el resultado en tareas
    estructuradas como estas (rellenar el schema de una tool)."""
    messages, max_completion = _ajustar_a_presupuesto(messages, tools_groq)
    kwargs = {"model": GROQ_MODEL, "messages": messages, "reasoning_effort": "low"}
    if tools_groq:
        kwargs["tools"] = tools_groq
    kwargs["max_completion_tokens"] = max_completion

    last_exc = None
    ya_pedimos_concision = False
    for attempt in range(RETRY_ATTEMPTS):
        try:
            return _groq_client.chat.completions.create(**kwargs)
        except GroqRateLimitError as exc:
            last_exc = exc
            if attempt < RETRY_ATTEMPTS - 1:
                time.sleep(RETRY_BACKOFF_SECONDS[attempt])
        except GroqBadRequestError as exc:
            if not _es_tool_use_failed(exc):
                raise
            # El modelo cortó su propio JSON. Reintentar igual volvería a cortarlo, pero
            # pidiéndole explícitamente que compacte la salida sí suele entrar — es la
            # diferencia entre "no se creó la rutina" y una rutina con notas más cortas.
            if ya_pedimos_concision:
                raise RespuestaDemasiadoGrandeError(str(exc)) from exc
            ya_pedimos_concision = True
            kwargs["messages"] = messages + [{
                "role": "system",
                "content": (
                    "Tu respuesta anterior se cortó por tamaño y se perdió. Repetí la MISMA "
                    "llamada a la función, pero mucho más compacta: omití 'notas' o dejalas "
                    "en 4 palabras como máximo, y no pongas más de 6 ejercicios por día. "
                    "Lo prioritario es que el JSON quede COMPLETO."
                ),
            }]
        except GroqAPIStatusError as exc:
            if exc.status_code == 413:
                raise RespuestaDemasiadoGrandeError(str(exc)) from exc
            raise
    raise GroqQuotaExhaustedError(str(last_exc)) from last_exc


def _run_chat_groq(
    user_id: str,
    mode: str,
    message: str,
    history: list[dict],
    health_context: dict | None,
    perfil_prompt: str = "",
) -> dict:
    """Replica el loop de _run_chat_gemini contra la API de Groq (formato OpenAI-style:
    role/content, tool_calls, respuestas con tool_call_id). Devuelve el mismo shape que
    _run_chat_gemini para que main.py y el frontend no puedan distinguir qué proveedor
    respondió."""
    tools_groq = [_function_decl_to_groq_tool(decl) for decl in TOOLS_BY_MODE[mode]]
    system_instruction = f"{SYSTEM_PROMPTS[mode]}\n\n{BASE_GUIDELINES}"
    if perfil_prompt:
        system_instruction += f"\n\n{perfil_prompt}"

    user_text = message
    if health_context:
        user_text += f"\n\n[Contexto Health Connect — datos reales, no inventar]\n{health_context}"

    messages = [{"role": "system", "content": system_instruction}]
    messages.extend(_history_to_groq_messages(history))
    messages.append({"role": "user", "content": user_text})

    actions_taken = []

    for _ in range(MAX_TOOL_ITERATIONS):
        response = _create_groq_completion_with_retry(messages, tools_groq)
        choice_message = response.choices[0].message
        tool_calls = choice_message.tool_calls or []

        if not tool_calls:
            return {"reply": choice_message.content or "", "actions_taken": actions_taken}

        messages.append({
            "role": "assistant",
            "content": choice_message.content,
            "tool_calls": [
                {
                    "id": tc.id,
                    "type": "function",
                    "function": {"name": tc.function.name, "arguments": tc.function.arguments},
                }
                for tc in tool_calls
            ],
        })

        for tc in tool_calls:
            try:
                args = json.loads(tc.function.arguments) if tc.function.arguments else {}
            except json.JSONDecodeError:
                args = {}

            result = _execute_tool(user_id, tc.function.name, args, actions_taken)
            # El resultado va recortado hacia el modelo, pero `actions_taken` ya
            # guarda el original entero: la app sigue recibiendo el dato completo
            # (lo necesita para pintar la estimación de una comida, por ejemplo),
            # el recorte es solo para lo que se reenvía en el siguiente turno.
            messages.append({
                "role": "tool",
                "tool_call_id": tc.id,
                "content": _recortar(
                    json.dumps({"result": result}, ensure_ascii=False),
                    MAX_CHARS_RESULTADO_TOOL,
                ),
            })

    # Agotadas las iteraciones: última pasada SIN tools (el modelo ya no puede pedir
    # más function calls, tiene que redactar) para no dejar al usuario sin respuesta.
    try:
        cierre = _create_groq_completion_with_retry(messages)
        texto = cierre.choices[0].message.content or ""
    except Exception:  # noqa: BLE001 — si el cierre falla, cae al mensaje genérico
        texto = ""

    return {"reply": texto or LIMITE_PASOS_MSG, "actions_taken": actions_taken}
