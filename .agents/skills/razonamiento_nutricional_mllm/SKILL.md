---
name: razonamiento_nutricional_mllm
description: Reglas para el modo `nutricion` — razonamiento visual con Gemini sobre fotos de comida, contrastado con bases de datos reales (Open Food Facts, Edamam, USDA FDC) antes de guardar calorías/macros cuantificados. Único punto de entrada para comida-por-foto (chat del AI Coach y botón de cámara de Nutrición).
---

# Razonamiento Nutricional Visual (modo `nutricion`)

- **Modelo real: Gemini, no GPT-4V ni Claude.** El razonamiento visual sobre fotos
  de comida lo hace `GEMINI_MODEL` (`gemini-3.5-flash-lite` por defecto) vía
  `google-genai` (`Backend/Python/chat_engine.py`), en el modo `nutricion` de
  `chat_tools.py::SYSTEM_PROMPTS`. `nutricion` es un `IMAGE_MODE`: siempre corre
  contra Gemini, con imagen adjunta o no — ver `backend_python_ai/SKILL.md`
  para el enrutamiento.
- **La salida es cuantitativa, no una clasificación semántica:** el prompt del
  modo pide explícitamente estimar calorías y macros a partir de la imagen o
  descripción y guardarlos con la tool `registrar_comida`
  (`chat_tools.py::registrar_comida_decl`), que persiste
  `calorias_consumidas, proteinas_g, carbohidratos_g, grasas_g, notas` en
  `NutritionLog`
  (`Backend/Nestjs/src/modules/nutrition/entities/nutrition_log.entity.ts`). Si
  ajustás este flujo, mantené ese contrato de campos — es lo que consume el resto
  de la app (resúmenes diarios, gráficos, etc.).
- **UX real — sí es "sacar una foto y listo", desde DOS pantallas:** el usuario
  adjunta una foto desde `image_picker`, se envía en base64 dentro del mensaje de
  chat, y el modelo la analiza en el mismo turno sin pasos intermedios de
  formulario. Dos puntos de entrada llaman a
  `ApiService.sendChatMessage(mode: 'nutricion', ...)` con el mismo payload
  `{data, mimeType}`: la pantalla de chat del AI Coach (`ai_coach_page.dart`) y el
  botón de cámara de la pantalla de Nutrición
  (`home_page.dart::_NutritionScreenState._takePhoto`).
- **El modelo puede no guardar nada en el turno:** guardar queda a criterio del
  modelo — puede pedir una aclaración en vez de llamar a `registrar_comida` (ej.
  foto poco clara). `home_page.dart` maneja ese caso leyendo `actions_taken`: si
  viene vacío, muestra el `reply` del modelo en un SnackBar en vez de la tarjeta de
  macros. No guardar silenciosamente es comportamiento esperado, no un bug.
- **`obtener_resumen_diario`** trae lo consumido en el día vs. objetivos de
  macros — usalo para preguntas tipo "¿cómo voy hoy?" en vez de recalcular a mano.

## Contraste con bases de datos reales antes de guardar

Ya no es diseño pendiente — implementado en `chat_tools.py` (División 7).
Antes, la cifra de macros salía enteramente de la memoria/estimación visual
de Gemini. Ahora, cuando el alimento sea identificable, el prompt del modo le
pide a Gemini que contraste su lectura visual contra una base de datos real
ANTES de llamar a `registrar_comida`, en vez de inventar la cifra de memoria —
igual principio que ya aplica `analyze_failure()` en `skills.py`
(determinístico sobre datos reales, no una alucinación del modelo). Tres
tools, cada una para un caso de uso distinto — el modelo elige cuál llamar (o
ninguna) según lo que vea:

1. **Producto envasado con marca/etiqueta legible en la foto** (yogur, barrita,
   cereal) → `buscar_producto_openfoodfacts` (`consulta`: nombre+marca o
   código de barras — el cliente detecta solo dígitos como código de barras).
   Devuelve macros por 100g y, de regalo, Nutri-Score/NOVA/Eco-Score del
   producto — se puede sumar al `notas` de `registrar_comida` como contexto
   extra, no como campo nuevo del esquema. Sin coste, sin API key (solo un
   `User-Agent` descriptivo, env `OPENFOODFACTS_USER_AGENT`). Verificado en
   vivo contra la API real.
2. **Plato casero / varios ingredientes mezclados** ("arroz con pollo y
   verduras") → `estimar_macros_ingredientes` (`ingredientes`: lista de líneas
   en lenguaje natural, ej. `["arroz blanco, 1 taza", "pechuga de pollo a la
   plancha, 150g"]` — el modelo arma la lista, no manda un párrafo). Vía
   Edamam Nutrition Analysis/RapidAPI, tier gratuito — límites en
   `backend_python_ai/SKILL.md`. **Sin verificar en vivo** (falta
   `RAPIDAPI_KEY` en el entorno de desarrollo): si el contrato no coincide
   exactamente, la tool degrada a `{"encontrado": False}`, no rompe el turno,
   pero probala con una key real antes de asumir que funciona.
3. **Ingrediente crudo/individual identificado con confianza** ("pechuga de
   pollo a la plancha, ~150g") → `buscar_alimento_usda` (`nombre_alimento`, en
   inglés da mejores resultados — el prompt ya se lo aclara al modelo), dataset
   *Foundation Foods* de USDA FoodData Central, perfil preciso por 100g. Datos
   en inglés/EE.UU. pero los valores numéricos de un ingrediente crudo no
   dependen del idioma — sirve igual para un usuario en España. Verificado en
   vivo.
4. **Ninguna tool devuelve un match confiable** → se mantiene el comportamiento
   de siempre: Gemini estima de su propio conocimiento y lo deja explícito
   como estimación.

Estas tools son de **enriquecimiento, no de persistencia**: si la API externa
falla o no encuentra el alimento, el tool devuelve un resultado vacío/degradado
(ver patrón en `backend_python_ai/SKILL.md`) y el modelo sigue con su propia
estimación — nunca bloquean el turno ni impiden guardar la comida.

- **No cambia la cautela sobre porciones:** estimar porciones desde una foto
  sigue siendo aproximado por naturaleza (ninguna de estas tres bases de datos
  "ve" la foto ni sabe el tamaño real de la porción sobre el plato) — seguí sin
  presentar las calorías como medición exacta, y si la foto no permite juzgar
  la cantidad, decilo y pedí el dato en vez de adivinar.

## No implementado (no asumir que existe)

- **Clasificación NOVA/Nutri-Score como campo propio de la app:** Open Food
  Facts trae esos datos para productos envasados, pero hoy no hay campo en
  `NutritionLog` para guardarlos estructuradamente — como mucho viajan como
  texto libre en `notas`. No asumas que existe una columna `nova_group` o
  similar sin confirmar contra la entidad real.
- **Búsqueda por foto directa contra Open Food Facts (image recognition propia
  de OFF):** la tool consulta por nombre/marca/código de barras que el propio
  Gemini lee de la foto — no hay integración con el reconocedor de imágenes de
  Open Food Facts en sí.
