import json
import requests
import subprocess
import time
from dotenv import load_dotenv

load_dotenv()

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



@app.post("/ai/analyze-set")
async def analyze_set(data: SetTelemetryInput):
    try:
        return analyze_failure(data)
    except ValueError as e:
        raise HTTPException(status_code=500, detail=f"Formato inválido: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Para ejecutar: uvicorn main:app --reload --port 8000

from chat_engine import run_chat
from schemas import ChatRequest, ChatResponse

@app.post("/api/ia/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        result = run_chat(
            user_id=request.user_id,
            mode=request.mode,
            message=request.message,
            history=[t.model_dump() for t in request.history],
            health_context=request.health_context,
            images=[i.model_dump(by_alias=False) for i in request.images],
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))