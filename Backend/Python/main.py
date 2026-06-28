import json
import requests
import subprocess
import time
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from schemas import SetTelemetryInput
from skills import analyze_failure
# Inicializamos la API
app = FastAPI()

# CORS abierto
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Definimos cómo esperamos recibir los datos desde NestJS
class AnalysisRequest(BaseModel):
    image_base64: str
    prompt: str
    user_profile: Optional[dict] = None

class RoutineAnalysisRequest(BaseModel):
    prompt: str
    user_profile: Optional[dict] = None
    routine: dict

class BodyAnalysisRequest(BaseModel):
    image_base64: str
    prompt: str
    user_profile: Optional[dict] = None
    body_history: Optional[list] = None

def ensure_ollama_is_running():
    """
    Verifica si el servidor de Ollama responde. 
    Si no lo hace, intenta levantarlo ejecutando 'ollama serve' en segundo plano.
    """
    url = "http://localhost:11434/"
    try:
        # Intentamos hacer un GET a la raíz para ver si responde
        requests.get(url, timeout=2)
    except requests.ConnectionError:
        print("Ollama no está en ejecución. Intentando iniciar 'ollama serve'...")
        try:
            # Ejecutamos ollama en segundo plano (ignorando su salida para no ensuciar la consola)
            subprocess.Popen(["ollama", "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Esperamos a que el servidor se levante (intentamos durante 15 segundos)
            for i in range(15):
                time.sleep(1)
                try:
                    requests.get(url, timeout=2)
                    print("Ollama se ha iniciado correctamente.")
                    return
                except requests.ConnectionError:
                    pass
            
            # Si pasados 15 segundos no responde, lanzamos un error
            raise HTTPException(
                status_code=500, 
                detail="Se intentó iniciar Ollama, pero el servidor no respondió después de 15 segundos."
            )
            
        except FileNotFoundError:
            # Esto ocurre si el sistema no tiene 'ollama' instalado o no está en el PATH
            raise HTTPException(
                status_code=500, 
                detail="No se encontró el ejecutable de Ollama en el sistema. Asegúrate de que está instalado y en el PATH."
            )

def build_body_history_prompt(history: Optional[list]) -> str:
    if not history:
        return ""
    lines = ["\n=== HISTORIAL DE ANÁLISIS FÍSICO PREVIO ==="]
    for i, record in enumerate(history):
        fecha = record.get("fecha_analisis", "fecha desconocida")
        lines.append(f"\n--- Registro {i+1} ({fecha}) ---")
        if record.get("peso_estimado_kg") is not None:
            lines.append(f"- Peso estimado: {record['peso_estimado_kg']} kg")
        if record.get("porcentaje_grasa_estimado") is not None:
            lines.append(f"- % grasa estimado: {record['porcentaje_grasa_estimado']}%")
        if record.get("masa_muscular_estimada_kg") is not None:
            lines.append(f"- Masa muscular estimada: {record['masa_muscular_estimada_kg']} kg")
        if record.get("somatotipo_estimado"):
            lines.append(f"- Somatotipo: {record['somatotipo_estimado']}")
        if record.get("nivel_fitness_estimado"):
            lines.append(f"- Nivel fitness: {record['nivel_fitness_estimado']}")
        if record.get("puntos_fuertes_fisicos"):
            lines.append(f"- Puntos fuertes: {', '.join(record['puntos_fuertes_fisicos'])}")
        if record.get("areas_mejora_fisicas"):
            lines.append(f"- Áreas de mejora: {', '.join(record['areas_mejora_fisicas'])}")
        if record.get("recomendaciones"):
            lines.append(f"- Recomendaciones previas: {record['recomendaciones']}")
    lines.append("=== FIN HISTORIAL ===\n")
    return "\n".join(lines)

def build_context_prompt(profile: Optional[dict]) -> str:
    if not profile:
        return ""
    lines = ["\n=== CONTEXTO DEL USUARIO ==="]
    dias = profile.get("dias_entrenamiento_semana")
    if dias is not None:
        lines.append(f"- Entrena {dias} días por semana.")
    intensidad = profile.get("intensidad")
    if intensidad:
        lines.append(f"- Intensidad preferida: {intensidad}.")
    nivel = profile.get("nivel_experiencia")
    if nivel:
        lines.append(f"- Nivel de experiencia: {nivel}.")
    objetivos = profile.get("objetivos")
    if objetivos:
        if isinstance(objetivos, list):
            lines.append(f"- Objetivos: {', '.join(objetivos)}.")
        else:
            lines.append(f"- Objetivos: {objetivos}.")
    tipo_cuerpo = profile.get("tipo_cuerpo")
    if tipo_cuerpo:
        lines.append(f"- Tipo de cuerpo: {tipo_cuerpo}.")
    bmi = profile.get("bmi")
    if bmi is not None:
        lines.append(f"- BMI: {bmi}.")
    grasa = profile.get("dexa_porcentaje_grasa")
    if grasa is not None:
        lines.append(f"- DEXA % grasa: {grasa}%.")
    musculo = profile.get("dexa_masa_muscular_kg")
    if musculo is not None:
        lines.append(f"- DEXA masa muscular: {musculo} kg.")
    condiciones = profile.get("condiciones_medicas")
    if condiciones:
        lines.append(f"- Condiciones médicas/restricciones: {condiciones}.")
    notas = profile.get("notas_adicionales")
    if notas:
        lines.append(f"- Notas adicionales: {notas}.")
    lines.append("=== FIN CONTEXTO ===\n")
    return "\n".join(lines)

@app.post("/api/ia/analizar-nutricion")
async def analyze_food(request: AnalysisRequest):
    try:
        # 1. VERIFICAMOS Y LEVANTAMOS OLLAMA SI ES NECESARIO
        ensure_ollama_is_running()

        contexto = build_context_prompt(request.user_profile)

        # Forzamos respuesta en JSON compatible con NestJS y guiamos el rol del modelo.
        prompt_formatted = (
            "Eres Gemma 4, experta en nutricion deportiva y entrenadora personal. "
            "Debes responder a la consulta del usuario usando su prompt y la imagen recibida. "
            "Si la consulta es de nutricion, estima calorias y macronutrientes. "
            "Si la consulta es de analisis fisico/postural/entrenamiento, deja en 0 los campos nutricionales "
            "y entrega en notas un analisis practico con mejoras, riesgos y recomendaciones."
            f"{contexto}\n"
            f"Consulta del usuario: {request.prompt}\n\n"
            "Responde UNICAMENTE con JSON valido usando estas claves exactas: "
            "calorias_consumidas, proteinas_g, carbohidratos_g, grasas_g, notas. "
            "Los cuatro campos numericos deben ser numeros (sin comillas). "
            "No incluyas texto fuera del JSON."
        )

        images_payload = [] if request.image_base64 == "bm8taW1hZ2U=" else [request.image_base64]

        # Llamada a la API local de Ollama
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "gemma4:e4b", 
                "prompt": prompt_formatted,
                "images": images_payload,
                "stream": False,
                "format": "json" 
            },
            timeout=120
        )
        response.raise_for_status()

        generated_text = response.json()["response"]
        
        # Limpiamos el texto por si la IA añade etiquetas markdown como ```json
        clean_text = generated_text.replace("```json", "").replace("```", "").strip()
        
        # Convertimos el texto limpio a un diccionario de Python real
        resultado_json = json.loads(clean_text)
        try:
            resultado_json["calorias_consumidas"] = float(resultado_json["calorias_consumidas"])
            resultado_json["proteinas_g"] = float(resultado_json["proteinas_g"])
            resultado_json["carbohidratos_g"] = float(resultado_json["carbohidratos_g"])
            resultado_json["grasas_g"] = float(resultado_json["grasas_g"])
            resultado_json["notas"] = str(resultado_json["notas"])
        except (KeyError, TypeError, ValueError):
            raise HTTPException(
                status_code=500,
                detail="El modelo devolvio un JSON sin el formato numerico esperado.",
            )
        print("Respuesta JSON generada por la IA:", resultado_json)
        # Lo enviamos de vuelta a NestJS
        return resultado_json

    except json.JSONDecodeError:
        # Si la IA se confunde y responde con texto normal, lanzamos un error que NestJS podrá leer
        raise HTTPException(status_code=500, detail=f"El modelo no generó un JSON. Respuesta bruta: {generated_text}")
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"No se pudo conectar a Ollama tras intentar iniciarlo: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/ia/analizar-rutina")
async def analyze_routine(request: RoutineAnalysisRequest):
    try:
        ensure_ollama_is_running()

        contexto = build_context_prompt(request.user_profile)
        routine_json = json.dumps(request.routine, ensure_ascii=False, indent=2)

        prompt_formatted = (
            "Eres Gemma 4, experta en entrenamiento deportivo, fisiología del ejercicio y programación de rutinas. "
            "Tu tarea es analizar la rutina de entrenamiento del usuario y proporcionar un análisis detallado. "
            "Debes ser objetiva, profesional y basar tus recomendaciones en principios científicos del entrenamiento.\n\n"
            f"{contexto}\n"
            "=== RUTINA DEL USUARIO ===\n"
            f"{routine_json}\n"
            "=== FIN RUTINA ===\n\n"
            f"Consulta del usuario: {request.prompt}\n\n"
            "Responde UNICAMENTE con JSON válido usando esta estructura exacta:\n"
            "{\n"
            '  "analisis_general": "string - evaluación general de la rutina",\n'
            '  "puntos_fuertes": ["array de strings - aspectos positivos de la rutina"],\n'
            '  "areas_mejora": ["array de strings - aspectos que necesitan mejora"],\n'
            '  "propuesta_cambios": {\n'
            '    "descripcion": "string - descripción general de los cambios propuestos",\n'
            '    "dias_modificados": [\n'
            '      {\n'
            '        "numero_dia": number,\n'
            '        "cambios": ["array de strings - cambios específicos para este día"],\n'
            '        "ejercicios_sugeridos": [\n'
            '          {\n'
            '            "nombre": "string",\n'
            '            "series": number,\n'
            '            "repeticiones": number,\n'
            '            "descanso_segundos": number,\n'
            '            "razon": "string - por qué sugieres este ejercicio"\n'
            '          }\n'
            '        ]\n'
            '      }\n'
            '    ]\n'
            '  } o null si no propones cambios,\n'
            '  "recomendaciones_adicionales": ["array de strings - consejos generales"],\n'
            '  "consulta_usuario_satisface": "string - pregunta al usuario si los cambios propuestos le satisfacen o si prefiere mantener su rutina actual"\n'
            "}\n\n"
            "REGLAS IMPORTANTES:\n"
            "1. El campo 'propuesta_cambios' debe ser null SOLO si consideras que la rutina es perfecta y no necesita ningún cambio.\n"
            "2. Si propones cambios, incluye siempre la pregunta de confirmación en 'consulta_usuario_satisface'.\n"
            "3. Sé específica con los ejercicios sugeridos (nombre, series, repeticiones, descanso).\n"
            "4. Considera el nivel de experiencia, objetivos y condiciones médicas del usuario.\n"
            "5. No incluyas texto fuera del JSON."
        )

        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "gemma4:e4b",
                "prompt": prompt_formatted,
                "stream": False,
                "format": "json"
            },
            timeout=180
        )
        response.raise_for_status()

        generated_text = response.json()["response"]
        clean_text = generated_text.replace("```json", "").replace("```", "").strip()
        resultado_json = json.loads(clean_text)

        # Validar estructura mínima
        campos_requeridos = [
            "analisis_general", "puntos_fuertes", "areas_mejora",
            "propuesta_cambios", "recomendaciones_adicionales", "consulta_usuario_satisface"
        ]
        for campo in campos_requeridos:
            if campo not in resultado_json:
                raise HTTPException(
                    status_code=500,
                    detail=f"El modelo devolvió un JSON sin el campo requerido: {campo}",
                )

        print("Respuesta JSON generada por la IA (rutina):", resultado_json)
        return resultado_json

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail=f"El modelo no generó un JSON válido. Respuesta bruta: {generated_text}")
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"No se pudo conectar a Ollama: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/ia/analizar-fisico")
async def analyze_body(request: BodyAnalysisRequest):
    try:
        ensure_ollama_is_running()

        contexto = build_context_prompt(request.user_profile)
        historial = build_body_history_prompt(request.body_history)

        prompt_formatted = (
            "Eres Gemma 4, experta en análisis físico, composición corporal, antropometría y fisiología del ejercicio. "
            "Tu tarea es analizar la imagen del usuario y proporcionar una evaluación detallada de su físico. "
            "Debes ser objetiva, profesional y ética. No hagas juicios de valor negativos. "
            "Base tus estimaciones en principios de antropometría visual y experiencia clínica.\n\n"
            f"{contexto}\n"
            f"{historial}\n"
            f"Consulta del usuario: {request.prompt}\n\n"
            "Responde UNICAMENTE con JSON válido usando esta estructura exacta:\n"
            "{\n"
            '  "analisis_general": "string - evaluación general del físico observado",\n'
            '  "peso_estimado_kg": number o null - estimación de peso en kg,\n'
            '  "porcentaje_grasa_estimado": number o null - estimación de % grasa corporal,\n'
            '  "masa_muscular_estimada_kg": number o null - estimación de masa muscular en kg,\n'
            '  "somatotipo_estimado": "string o null - ectomorfo, mesomorfo, endomorfo o mixto",\n'
            '  "nivel_fitness_estimado": "string o null - principiante, intermedio, avanzado, elite",\n'
            '  "puntos_fuertes_fisicos": ["array de strings - aspectos físicos positivos observados"],\n'
            '  "areas_mejora_fisicas": ["array de strings - aspectos físicos que podrían mejorar"],\n'
            '  "recomendaciones": "string - recomendaciones específicas basadas en el análisis",\n'
            '  "metricas_adicionales": {\n'
            '    "circunferencia_cintura_estimada_cm": number o null,\n'
            '    "circunferencia_brazo_estimada_cm": number o null,\n'
            '    "circunferencia_pecho_estimada_cm": number o null,\n'
            '    "balance_muscular_observado": "string o null",\n'
            '    "postura_general": "string o null",\n'
            '    "simetria_observada": "string o null"\n'
            '  } o null si no puedes estimar métricas adicionales,\n'
            '  "notas_adicionales": "string - cualquier observación adicional relevante",\n'
            '  "comparacion_progreso": "string o null - compara con registros previos si existen, mencionando cambios observados, mejoras o retrocesos. Si no hay historial, usa null"\n'
            "}\n\n"
            "REGLAS IMPORTANTES:\n"
            "1. Usa null (no texto vacío) cuando no puedas estimar un valor con confianza razonable.\n"
            "2. Las estimaciones numéricas deben ser números sin comillas.\n"
            "3. Sé honesta pero constructiva en tus observaciones.\n"
            "4. Si hay historial previo, compara explícitamente y menciona progreso o cambios.\n"
            "5. No incluyas texto fuera del JSON."
        )

        images_payload = [] if request.image_base64 == "bm8taW1hZ2U=" else [request.image_base64]

        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "gemma4:e4b",
                "prompt": prompt_formatted,
                "images": images_payload,
                "stream": False,
                "format": "json"
            },
            timeout=180
        )
        response.raise_for_status()

        generated_text = response.json()["response"]
        clean_text = generated_text.replace("```json", "").replace("```", "").strip()
        resultado_json = json.loads(clean_text)

        # Validar estructura mínima
        campos_requeridos = [
            "analisis_general", "peso_estimado_kg", "porcentaje_grasa_estimado",
            "masa_muscular_estimada_kg", "somatotipo_estimado", "nivel_fitness_estimado",
            "puntos_fuertes_fisicos", "areas_mejora_fisicas", "recomendaciones",
            "metricas_adicionales", "notas_adicionales", "comparacion_progreso"
        ]
        for campo in campos_requeridos:
            if campo not in resultado_json:
                raise HTTPException(
                    status_code=500,
                    detail=f"El modelo devolvió un JSON sin el campo requerido: {campo}",
                )

        print("Respuesta JSON generada por la IA (físico):", resultado_json)
        return resultado_json

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail=f"El modelo no generó un JSON válido. Respuesta bruta: {generated_text}")
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"No se pudo conectar a Ollama: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ai/analyze-set")
async def analyze_set(data: SetTelemetryInput):
    try:
        return analyze_failure(data)
    except ValueError as e:
        raise HTTPException(status_code=500, detail=f"Formato inválido: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Para ejecutar: uvicorn main:app --reload --port 8000