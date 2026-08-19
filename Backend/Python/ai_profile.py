"""Perfil clínico y físico del usuario, formateado para meterlo en el system
prompt de CUALQUIER modo de Pulso.

Por qué se inyecta siempre en vez de exponerlo como una tool: si fuera una tool,
el modelo decidiría cuándo mirarlo, y en la práctica no la llamaría al recomendar
macros ni al editar una rutina — justo los casos donde el usuario espera que ya
lo sepa. Inyectado, no hay turno en el que se le olvide.

El coste está acotado a propósito: NestJS ya devuelve una vista resumida
(`GET /ai-context/:userId`) y aquí se aplana a texto plano recortado. Los modos
de texto van a Groq con 8000 TPM de techo, así que cada línea de más compite con
la respuesta.
"""
import clinical_reference as ref
import nest_client as nest

# Techos de recorte. Los resúmenes de informes clínicos los redacta la IA sin
# límite duro, y un par de informes largos se comen el presupuesto entero.
#
# Medido con un perfil real completo (analítica de 14 marcadores + análisis de
# físico): con estos topes el bloque ronda los 700 tokens. Los modos de texto
# van a Groq con 8000 TPM contando entrada + reserva de salida, y el esquema de
# `crear_rutina_personalizada` ya se lleva ~1500 él solo, así que cada línea de
# más aquí sale del presupuesto de la respuesta.
MAX_CARACTERES_RESUMEN_INFORME = 260
# Solo el último informe: los valores de los anteriores ya están en la lista de
# marcadores (que es por último valor de cada código), así que repetir sus
# resúmenes es pagar tokens por información duplicada.
MAX_INFORMES = 1
MAX_MARCADORES = 10
MAX_CARACTERES_RELEVANCIA = 90


def obtener(user_id: str) -> dict | None:
    """Contexto consolidado, o None si NestJS no responde. Nunca levanta: que el
    perfil no cargue tiene que degradar el chat, no tumbarlo."""
    if not user_id:
        return None
    try:
        return nest.get(f"/ai-context/{user_id}")
    except Exception:  # noqa: BLE001 — cualquier fallo de red/404 degrada a "sin perfil"
        return None


def _recortar(texto: str | None, limite: int) -> str:
    if not texto:
        return ""
    texto = " ".join(str(texto).split())
    return texto if len(texto) <= limite else texto[:limite].rsplit(" ", 1)[0] + "…"


def _linea_marcador(m: dict) -> str:
    unidad = f" {m['unidad']}" if m.get("unidad") else ""
    relevancia = _recortar(m.get("relevancia_fisico"), MAX_CARACTERES_RELEVANCIA)
    sufijo = f" — {relevancia}" if relevancia else ""
    return f"  - {m.get('nombre')}: {m.get('valor')}{unidad} ({m.get('estado')}){sufijo}"


# Nombres legibles de cada método de medida, para que el encabezado diga de
# dónde salen las cifras sin gastar una línea entera en explicarlo.
_NOMBRE_METODO = {
    "dexa": "DEXA",
    "bioimpedancia": "bioimpedancia",
    "plicometria": "plicometría",
    "bascula": "báscula",
    "otro": "método sin especificar",
}

# Las fuentes de `clinical_reference` van con su cita completa porque se guardan
# en `fuentes_consultadas` y se enseñan en la app. En el prompt basta la
# etiqueta corta: el modelo solo necesita saber que la escala está citada, y las
# citas enteras cuestan ~40 tokens cada una del presupuesto de Groq.
_CITA_CORTA = {
    ref.FUENTES["ffmi_kouri"]: "Kouri 1995",
    ref.FUENTES["issn"]: "ISSN",
    ref.FUENTES["ace"]: "ACE",
    ref.FUENTES["who_imc"]: "OMS",
}


def _bloque_composicion(composicion: dict, sexo: str | None, altura_cm: float | None) -> list[str]:
    """Sección de composición corporal: peso, IMC, grasa y masa magra medidos,
    clasificados contra ACE/OMS/Kouri.

    Va la primera y marcada como dato principal a propósito. Es lo único
    *medido* del perfil — las fotos dan una estimación visual y la analítica
    habla de otra cosa —, y es de donde salen las calorías, los macros y la
    decisión de si toca superávit o recomposición. Enterrada al final, el modelo
    acababa razonando sobre el porcentaje de grasa estimado a ojo teniendo un
    DEXA a mano."""
    actual = composicion.get("actual") if composicion.get("tiene_datos") else None
    if not actual:
        return []

    metodo = _NOMBRE_METODO.get(actual.get("metodo"), actual.get("metodo") or "medición")
    fecha = str(actual.get("fecha"))[:10]
    clasificacion = ref.clasificar_composicion(actual, sexo, altura_cm)

    def etiqueta(clave: str) -> str:
        dato = clasificacion.get(clave)
        return f" ({dato['categoria']})" if dato else ""

    lineas = [f"\n### Composición corporal — DATO PRINCIPAL ({metodo}, {fecha})"]

    principales = []
    if actual.get("peso_kg") is not None:
        principales.append(f"Peso {actual['peso_kg']} kg")
    if actual.get("imc") is not None:
        principales.append(f"IMC {actual['imc']}{etiqueta('imc')}")
    if actual.get("porcentaje_grasa") is not None:
        principales.append(f"grasa {actual['porcentaje_grasa']} %{etiqueta('grasa')}")
    if actual.get("masa_grasa_kg") is not None:
        principales.append(f"masa grasa {actual['masa_grasa_kg']} kg")
    if actual.get("masa_magra_kg") is not None:
        principales.append(f"masa magra {actual['masa_magra_kg']} kg")
    if principales:
        lineas.append("- " + " · ".join(principales))

    # Los pares kg/% van juntos en el mismo elemento: separarlos duplicaba la
    # línea entera y el modelo llegaba a citar los dos como si fueran medidas
    # distintas de cosas distintas.
    def _par(nombre: str, clave_kg: str, clave_pct: str, unidad: str = "kg") -> str | None:
        kg, pct = actual.get(clave_kg), actual.get(clave_pct)
        if kg is None and pct is None:
            return None
        if kg is not None and pct is not None:
            return f"{nombre} {kg} {unidad} ({pct} %)"
        return f"{nombre} {kg} {unidad}" if kg is not None else f"{nombre} {pct} %"

    detalle = [
        p
        for p in (
            _par("masa muscular", "masa_muscular_kg", "musculo_pct"),
            _par("proteína", "proteina_kg", "proteina_pct"),
            _par("agua", "agua_corporal_kg", "agua_corporal_pct"),
        )
        if p
    ]
    if actual.get("musculo_esqueletico_pct") is not None:
        detalle.append(f"músculo esquelético {actual['musculo_esqueletico_pct']} %")
    if actual.get("masa_osea_kg") is not None:
        detalle.append(f"masa ósea {actual['masa_osea_kg']} kg")
    if actual.get("densidad_osea") is not None:
        detalle.append(f"densidad ósea {actual['densidad_osea']} g/cm²")
    if actual.get("grasa_subcutanea_pct") is not None:
        detalle.append(f"grasa subcutánea {actual['grasa_subcutanea_pct']} %")
    if actual.get("grasa_visceral") is not None:
        detalle.append(f"grasa visceral {actual['grasa_visceral']}")
    if actual.get("tmb_kcal") is not None:
        detalle.append(f"TMB {actual['tmb_kcal']} kcal")
    if actual.get("edad_corporal") is not None:
        detalle.append(f"edad corporal {actual['edad_corporal']} años")
    if detalle:
        lineas.append("- " + " · ".join(detalle))

    # El "peso estándar" lo calcula cada fabricante con su fórmula, no es un
    # objetivo clínico. Va aparte y etiquetado para que el modelo no lo proponga
    # como meta de peso cuando el usuario pregunte por su dieta.
    if actual.get("peso_ideal_kg") is not None:
        lineas.append(
            f"- Peso «estándar» que sugiere el aparato: {actual['peso_ideal_kg']} kg "
            "(fórmula del fabricante, NO un objetivo — no lo propongas como meta)"
        )

    if clasificacion.get("ffmi"):
        ffmi = clasificacion["ffmi"]
        cita = _CITA_CORTA.get(ffmi["fuente"], "")
        lineas.append(f"- FFMI {ffmi['ffmi']} → {ffmi['categoria']} ({cita})")

    proteina = clasificacion.get("proteina_objetivo_g_dia")
    if proteina:
        cita = _CITA_CORTA.get(proteina["fuente"], "")
        lineas.append(
            f"- Proteína objetivo por su peso: {proteina['min']}–{proteina['max']} g/día ({cita})"
        )

    if clasificacion.get("fiabilidad"):
        lineas.append("- Fiabilidad de la medida: " + clasificacion["fiabilidad"]["nota"])

    evolucion = composicion.get("evolucion") or []
    hitos = []
    for e in evolucion:
        partes = []
        if e.get("peso_kg") is not None:
            partes.append(f"{e['peso_kg']} kg")
        if e.get("porcentaje_grasa") is not None:
            partes.append(f"{e['porcentaje_grasa']} % grasa")
        if e.get("masa_magra_kg") is not None:
            partes.append(f"{e['masa_magra_kg']} kg magra")
        if partes:
            hitos.append(f"{str(e.get('fecha'))[:10]}: " + " / ".join(partes))
    if hitos:
        lineas.append("- Mediciones anteriores: " + "; ".join(hitos))

    return lineas


def bloque_prompt(perfil: dict | None) -> str:
    """Texto plano listo para concatenar al system prompt. Cadena vacía si no
    hay nada que contar (así el prompt no gana una sección vacía)."""
    if not perfil:
        return ""

    basicos = perfil.get("datos_basicos") or {}
    fisico = perfil.get("fisico") or {}
    clinico = perfil.get("clinico") or {}
    composicion = perfil.get("composicion") or {}

    lineas: list[str] = ["## Datos reales del usuario (base de datos de la app)"]

    identidad = []
    if basicos.get("edad") is not None:
        identidad.append(f"{basicos['edad']} años")
    if basicos.get("sexo"):
        identidad.append(str(basicos["sexo"]))
    if basicos.get("altura_cm") is not None:
        identidad.append(f"{basicos['altura_cm']} cm")
    if basicos.get("peso_kg") is not None:
        # Si el peso viene de una medición, se dice cuándo: un peso de hace seis
        # meses no sirve para recalcular macros y el modelo tiene que saberlo.
        fecha_peso = basicos.get("peso_fecha")
        sufijo = f" (medido el {str(fecha_peso)[:10]})" if fecha_peso else ""
        identidad.append(f"{basicos['peso_kg']} kg{sufijo}")
    if basicos.get("nivel_experiencia"):
        identidad.append(f"nivel {basicos['nivel_experiencia']}")
    if identidad:
        lineas.append("- Perfil: " + ", ".join(identidad))

    if basicos.get("objetivos"):
        lineas.append("- Objetivos: " + ", ".join(basicos["objetivos"]))
    if basicos.get("dias_entrenamiento_semana"):
        lineas.append(f"- Días de entrenamiento por semana: {basicos['dias_entrenamiento_semana']}")
    if basicos.get("condiciones_medicas"):
        lineas.append("- Condiciones médicas declaradas: " + _recortar(basicos["condiciones_medicas"], 200))

    metas = basicos.get("metas") or {}
    if metas.get("kcal"):
        lineas.append(
            f"- Metas diarias actuales: {metas['kcal']} kcal, "
            f"P {metas.get('proteinas_g')} g / C {metas.get('carbohidratos_g')} g / G {metas.get('grasas_g')} g"
        )

    # ---- Composición corporal (lo medido) ----
    lineas.extend(_bloque_composicion(composicion, basicos.get("sexo"), basicos.get("altura_cm")))

    # ---- Físico (lo estimado a partir de fotos) ----
    ultimo = fisico.get("ultimo") if fisico.get("tiene_datos") else None
    if ultimo:
        lineas.append(f"\n### Análisis del físico por fotos (último: {str(ultimo.get('fecha'))[:10]})")
        estimado = []
        # Solo se repiten las estimaciones visuales si NO hay una medición real:
        # teniendo un DEXA delante, un porcentaje calculado a ojo no aporta nada
        # y encima invita al modelo a promediar los dos.
        if not composicion.get("tiene_datos"):
            if ultimo.get("porcentaje_grasa_estimado") is not None:
                estimado.append(f"~{ultimo['porcentaje_grasa_estimado']} % de grasa (estimado a ojo)")
            if ultimo.get("masa_muscular_estimada_kg") is not None:
                estimado.append(f"~{ultimo['masa_muscular_estimada_kg']} kg de masa magra")
        if ultimo.get("somatotipo"):
            estimado.append(f"somatotipo {ultimo['somatotipo']}")
        if ultimo.get("nivel_fitness"):
            estimado.append(f"nivel {ultimo['nivel_fitness']}")
        if estimado:
            lineas.append("- Lectura visual: " + ", ".join(estimado))
        if ultimo.get("grupos_retrasados"):
            lineas.append("- **Grupos musculares retrasados**: " + ", ".join(ultimo["grupos_retrasados"]))
        if ultimo.get("grupos_dominantes"):
            lineas.append("- Grupos dominantes: " + ", ".join(ultimo["grupos_dominantes"]))
        if ultimo.get("postura"):
            lineas.append("- Postura: " + _recortar(ultimo["postura"], 180))
        if ultimo.get("prioridad_entrenamiento"):
            lineas.append("- **Prioridad de entrenamiento**: " + _recortar(ultimo["prioridad_entrenamiento"], 220))
        evolucion = fisico.get("evolucion") or []
        if evolucion:
            hitos = ", ".join(
                f"{str(e.get('fecha'))[:10]}: {e.get('porcentaje_grasa_estimado')}%"
                for e in evolucion
                if e.get("porcentaje_grasa_estimado") is not None
            )
            if hitos:
                lineas.append(f"- Evolución de grasa estimada: {hitos}")

    # ---- Clínico ----
    if clinico.get("tiene_datos"):
        lineas.append("\n### Analíticas de sangre (complemento)")
        fuera = (clinico.get("marcadores_fuera_de_rango") or [])[:MAX_MARCADORES]
        if fuera:
            lineas.append("- Valores FUERA de rango:")
            lineas.extend(_linea_marcador(m) for m in fuera)
        else:
            lineas.append("- Todos los biomarcadores registrados están dentro de rango.")

        for informe in (clinico.get("informes") or [])[:MAX_INFORMES]:
            fecha = str(informe.get("fecha"))[:10]
            lineas.append(f"- Informe {fecha}: " + _recortar(informe.get("resumen"), MAX_CARACTERES_RESUMEN_INFORME))
            if informe.get("implicaciones_entrenamiento"):
                lineas.append("  · Entrenamiento: " + _recortar(informe["implicaciones_entrenamiento"], 220))
            if informe.get("implicaciones_nutricion"):
                lineas.append("  · Nutrición: " + _recortar(informe["implicaciones_nutricion"], 220))
            if informe.get("banderas_rojas"):
                lineas.append("  · Derivar a profesional: " + ", ".join(informe["banderas_rojas"]))

    lineas.append(
        "\nEstos datos son la fuente de verdad sobre este usuario: úsalos y cítalos al "
        "justificar lo que recomiendes (ejercicios, calorías, macros, cambios de rutina). "
        "No los contradigas ni rellenes con supuestos lo que no esté aquí.\n"
        "Jerarquía cuando dos secciones digan cosas distintas: manda la **composición "
        "corporal medida** (peso, IMC, grasa, masa magra) — de ahí salen las calorías y los "
        "macros. Los porcentajes estimados desde fotos son aproximados: trátalos como un "
        "rango, no como una medición, y úsalos para lo que sí aportan (grupos retrasados, "
        "postura, simetría). La analítica de sangre es un complemento: matiza el plan, no lo "
        "define. Nada de esto es un diagnóstico: ante valores fuera de rango, deriva a un "
        "profesional en vez de interpretarlos tú."
    )
    return "\n".join(lineas)


def instruccion_si_faltan_datos(perfil: dict | None) -> str:
    """Instrucción sobre los huecos del perfil. Vacía cuando no hay ninguno.

    Distingue dos niveles a propósito. **Peso y altura bloquean**: sin ellos no
    hay gasto calórico ni macros que calcular y cualquier cifra sería inventada.
    Todo lo demás (composición, fotos, analítica, sexo, edad) es recomendable
    pero no puede frenar la conversación: un perfil a medias que responde vale
    más que uno completo que el usuario nunca llega a rellenar.

    Es una instrucción y no un texto fijo devuelto al usuario para que el modelo
    siga contestando lo genérico que sí sabe, pero con prohibición expresa de
    presentar como personalizado algo que no lo es."""
    if perfil is None:
        return (
            "\n\n## Aviso: no se pudo leer el perfil del usuario\n"
            "No hay acceso a sus datos ahora mismo. Responde en general, avisando de que no "
            "estás viendo sus datos y que por eso la respuesta no está personalizada."
        )

    completitud = perfil.get("completitud") or {}
    faltantes = completitud.get("faltantes") or []

    if faltantes:
        lista = ", ".join(faltantes)
        return (
            "\n\n## OBLIGATORIO: faltan los datos mínimos\n"
            f"No está registrado: {lista}. Sin peso y altura no se puede calcular ni una "
            "caloría, así que cualquier cifra que dieras sería inventada.\n"
            "En ESTA respuesta:\n"
            "1. Responde lo que puedas de forma general y honesta.\n"
            "2. Pídeselo explícitamente y dile dónde se rellena: en su perfil, o registrando "
            "una medición en **Clínica** (Inicio → apartado de salud).\n"
            "3. Deja claro que hasta entonces tus recomendaciones son genéricas, no suyas."
        )

    if not completitud.get("tiene_composicion"):
        # No bloquea, pero sí acota: con peso y altura se calculan calorías y
        # macros perfectamente, y el hueco que queda es justo el que el modelo
        # tiende a rellenar de su cosecha.
        return (
            "\n\n## Aviso: no hay composición corporal registrada\n"
            "Tienes su peso y su altura, así que sí puedes calcular calorías y macros. Lo que "
            "NO puedes es dar por sabido su porcentaje de grasa, su masa magra ni su nivel de "
            "musculatura: no están medidos. No los estimes ni los des por supuestos. Si la "
            "conversación lo pide (definición, recomposición, objetivos de grasa), sugiérele "
            "registrar una medición — DEXA, bioimpedancia o báscula — en **Clínica**."
        )

    recomendados = completitud.get("recomendados") or []
    if recomendados:
        return (
            "\n\n## Datos que faltan por afinar\n"
            f"Sin registrar: {', '.join(recomendados)}. No bloquea nada: responde con "
            "normalidad usando lo que sí tienes. Solo evita dar por sabido lo que está en esa "
            "lista, y menciónalo únicamente si viene a cuento de lo que te está preguntando."
        )

    return ""


def contexto_para_prompt(user_id: str) -> tuple[str, dict | None]:
    """Atajo para el motor de chat: devuelve (bloque a concatenar, perfil crudo)."""
    perfil = obtener(user_id)
    return bloque_prompt(perfil) + instruccion_si_faltan_datos(perfil), perfil
