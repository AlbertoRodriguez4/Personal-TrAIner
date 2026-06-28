---
name: procesamiento_dicom_ocr
description: Directivas para la extracción de datos DEXA, metadatos DICOM SR y conversión de PDFs médicos usando Mistral OCR.
---

# Extracción de Datos Clínicos (DEXA y OCR)

- **Priorización de Fuentes:** Siempre intenta extraer los componentes volumétricos directamente de la metadata del archivo DICOM SR (Structured Report) cuando esté disponible.
- **Respaldo con IA Visuo-Espacial (Mistral OCR):** Cuando te enfrentes a impresiones PDF heredadas o imágenes escaneadas de centros médicos, usa OCR impulsado por IA como matriz de respaldo infalible.
- **Estructuración:** El objetivo final de toda ingesta clínica es transformar los datos no estructurados en variables relacionales predecibles, preferentemente en formatos estandarizados como JSON o FHIR, para construir historiales longitudinales fiables.
