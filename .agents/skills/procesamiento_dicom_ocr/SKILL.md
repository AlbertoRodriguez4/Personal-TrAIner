---
name: procesamiento_dicom_ocr
description: "NO IMPLEMENTADO: la ingesta de datos DEXA/clínicos es 100% manual hoy, sin DICOM, OCR ni Mistral."
---

# Extracción de Datos Clínicos (DEXA) — no implementado

No hay ningún pipeline de ingestión de documentos clínicos en este código. El
módulo `clinical_data` (`Backend/Nestjs/src/modules/clinical_data/`) gestiona
`DexaScan` como un formulario manual de exactamente tres números —
`porcentaje_grasa`, `masa_muscular_kg`, `densidad_osea` — más una fecha
(`create-dexa-scan.dto.ts`, `dexa_scan.entity.ts`). El DTO no tiene ningún campo de
archivo, imagen o texto libre: quien carga el dato escribe esos tres números a
mano.

No existe:
- Lectura de metadata DICOM/DICOM SR.
- Ningún OCR (Mistral OCR ni ningún otro) para PDFs o imágenes escaneadas.
- Ninguna estructuración a JSON/FHIR más allá de las columnas fijas de la entidad.
- Ninguna clave de API relacionada — `Backend/Python/.env.example` solo define
  `GEMINI_API_KEY`.

Si una tarea pide procesar un DEXA/PDF/imagen médica real, es una feature nueva de
punta a punta (necesitaría, como mínimo: endpoint de subida de archivo, alguna
librería de parsing DICOM o servicio de OCR, y credenciales nuevas) — no una
extensión de código existente. Confirmá alcance y proveedor de OCR/DICOM con el
usuario antes de empezar; no asumas Mistral por defecto solo porque una versión
anterior de este doc lo mencionaba.
