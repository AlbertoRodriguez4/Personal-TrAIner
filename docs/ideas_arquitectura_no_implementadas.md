Subsistema de Arquitectura	Tecnología y Lenguaje Seleccionado	Justificación Tecnológica y Arquitectónica
Framework de Cliente (Frontend)	Flutter (Lenguaje Dart)	
Dictamina un desarrollo multiplataforma (iOS/Android) con base de código único sin el cuello de botella de rendimiento de los puentes JavaScript, ofreciendo un control de renderizado de nivel de píxel optimizado para GPU (motor Impeller) indispensable para la fluidez en el mapeo en vivo de avatares 3D y análisis de movimiento en tiempo real.

Orquestación de Backend	
Enrutamiento: Node.js (TS)


Motor IA: Python (FastAPI)

Microservicios distribuidos: La naturaleza impulsada por eventos de Node.js garantiza una escalabilidad excepcional para el streaming continuo de WebSockets y MQTT sin bloqueo I/O. Python es insustituible para integrar de forma nativa los marcos de ML (PyTorch, TensorFlow) y las pesadas bibliotecas de procesamiento científico/médico.

Telemetría y Conectividad	
BLE (Local) + MQTT (Subida)


WebSockets (Interacción AI)

Bluetooth Low Energy (GATT) permite sincronización permanente de pulseras conservando el ciclo de vida de la batería del dispositivo. MQTT soporta robustamente las inestabilidades de las redes celulares manteniendo bajo overhead. WebSockets provee un conducto full-duplex de muy baja latencia, necesario para interrumpir las interacciones conversacionales e inyectar telemetría visual de inmediato.

Análisis Físico y Postural	
Estimación de Pose (CNNs)


Recuperación de Mallas (SAM 3D)

Migración de métricas heurísticas imprecisas a fotogrametría computacional; permite mapeo de asimetrías y deducción volumétrica del tejido graso visceral y periférico comparable a validaciones clínicas (DXA). Su ejecución en el hardware neuronal periférico del móvil protege íntegramente la privacidad del paciente al evitar la transmisión externa de fotografías.

Extracción de Datos DEXA	DICOM SR Parser + Mistral OCR	
Genera historiales longitudinales clínicos fiables y estructurados (JSON/FHIR). Extrae componentes volumétricos directamente de la metadata del DICOM SR cuando está disponible, utilizando OCR impulsado por Inteligencia Artificial Visuo-Espacial como una matriz de respaldo infalible para leer impresiones en PDF heredadas de centros médicos y transformar datos no estructurados en variables relacionales predecibles.

Razonamiento Nutricional	MLLMs (GPT-4V, Claude 3.5 Sonnet)	
Evolución crítica desde la tortuosa cuantificación calórica hacia el reconocimiento semántico holístico. Modelos visual-lingüísticos emplean matrices de atención para discriminar ingredientes complejos dentro de platos enteros, determinando niveles de hiper-procesamiento (NOVA) y distribuciones de macronutrientes basadas en contexto volumétrico sin inducir fatiga transaccional.

Personalidad y Dinámica Conversacional	System Prompting + Base Vectorial RAG + Modelos Full-Duplex	
Proporciona perfiles de entrenador fluidamente adaptables (modulados a nivel textual por el prompt del sistema) enraizados permanentemente en la memoria a largo plazo del paciente almacenada vectorialmentes (RAG). Modelos de audio end-to-end full-duplex (ej. derivados de Moshi o PersonaPlex) infunden empatía paramétrica de audio, tolerando asimilación de tonos de estrés e interrupciones dinámicas con latencias imperceptibles al sistema perceptivo humano.

Predicción y Análisis de Patrones	Transformers de Series Temporales (Autoformer, Informer)	
Supera el desvanecimiento de contexto de LSTMs clásicas al operar descomposición armónica de las frecuencias temporales. Discierne entre ruidos de sensores irregulares y vectores fundamentales de estabilización fisiológica y progresión de hábitos, permitiendo emitir alertas clínicas anticipadas sobre agotamiento sistémico y sobreentrenamiento estructural con semanas de antelación.