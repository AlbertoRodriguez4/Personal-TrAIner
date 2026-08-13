import base64
import os
from google import genai
from google.genai import types

from chat_tools import TOOLS_BY_MODE, EXECUTORS, SYSTEM_PROMPTS, BASE_GUIDELINES

MODEL = "gemini-3.5-flash"  # mismo modelo que ya usa regenerate_design_context.py
MAX_TOOL_ITERATIONS = 5     # guarda contra loops infinitos de function calling

# Grounding con Google Search, apagado por defecto.
# Verificado contra la API real: la búsqueda tiene su propia cuota, aparte de la de
# generate_content, y con la key actual devuelve 429 RESOURCE_EXHAUSTED tanto sola como
# combinada con function_declarations (las llamadas normales y las de function calling
# sí funcionan). No es una incompatibilidad técnica entre grounding y tools: es cuota de
# facturación. Cuando la cuenta tenga búsqueda habilitada, poner
# GEMINI_ENABLE_SEARCH_GROUNDING=1 en el .env y esto se activa sin tocar código.
ENABLE_SEARCH_GROUNDING = os.environ.get("GEMINI_ENABLE_SEARCH_GROUNDING", "").lower() in ("1", "true", "yes")

_client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY", ""))


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
    """
    if mode not in TOOLS_BY_MODE:
        raise ValueError(f"Modo desconocido: {mode}")

    tools = [types.Tool(function_declarations=TOOLS_BY_MODE[mode])]
    if ENABLE_SEARCH_GROUNDING:
        tools.append(types.Tool(google_search=types.GoogleSearch()))

    # Las reglas de formato y rigor son las mismas para los 6 modos; el prompt del modo
    # solo aporta lo suyo encima.
    system_instruction = f"{SYSTEM_PROMPTS[mode]}\n\n{BASE_GUIDELINES}"

    contents = [
        types.Content(role=turn["role"], parts=[types.Part.from_text(text=turn["text"])])
        for turn in history
    ]

    user_text = message
    if health_context:
        user_text += f"\n\n[Contexto Health Connect — datos reales, no inventar]\n{health_context}"

    user_parts = []
    if images:
        for img in images:
            user_parts.append(
                types.Part.from_bytes(
                    data=base64.b64decode(img["data"]),
                    mime_type=img["mime_type"],
                )
            )
    user_parts.append(types.Part.from_text(text=user_text))
    contents.append(types.Content(role="user", parts=user_parts))

    config = types.GenerateContentConfig(
        system_instruction=system_instruction,
        tools=tools,
    )

    actions_taken = []

    for _ in range(MAX_TOOL_ITERATIONS):
        response = _client.models.generate_content(model=MODEL, contents=contents, config=config)
        
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
                
            executor = EXECUTORS.get(name)
            if executor is None:
                result = {"error": f"tool '{name}' no implementada"}
            else:
                try:
                    result = executor(user_id=user_id, **args)
                    actions_taken.append({"tool": name, "result": result})
                except Exception as exc:  # noqa: BLE001
                    result = {"error": str(exc)}
            response_parts.append(types.Part.from_function_response(name=name, response={"result": result}))

        contents.append(types.Content(role="user", parts=response_parts))

    return {
        "reply": "Se alcanzó el límite de pasos permitidos para esta consulta. ¿Podés reformularla?",
        "actions_taken": actions_taken,
    }
