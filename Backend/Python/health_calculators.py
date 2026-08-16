"""Calculadoras de salud (IMC, TMB, TDEE) — fórmulas estándar en Python puro,
sin llamadas de red. Ver backend_python_ai/SKILL.md: no hace falta una API
externa para esto ("Gym-Fit API" fue evaluada y descartada por frágil)."""

FACTORES_ACTIVIDAD = {
    "sedentario": 1.2,
    "ligero": 1.375,
    "moderado": 1.55,
    "activo": 1.725,
    "muy_activo": 1.9,
}


def _categoria_imc(imc: float) -> str:
    if imc < 18.5:
        return "bajo peso"
    if imc < 25:
        return "normopeso"
    if imc < 30:
        return "sobrepeso"
    return "obesidad"


def calcular_metricas_salud(
    user_id: str,
    peso_kg: float,
    altura_cm: float,
    edad: int,
    sexo: str,
    nivel_actividad: str = "moderado",
) -> dict:
    """IMC + TMB (Mifflin-St Jeor) + TDEE. `sexo`: 'masculino' | 'femenino'."""
    imc = peso_kg / ((altura_cm / 100) ** 2)

    tmb = 10 * peso_kg + 6.25 * altura_cm - 5 * edad
    tmb += 5 if sexo.lower().startswith("m") else -161

    factor = FACTORES_ACTIVIDAD.get(nivel_actividad.lower(), FACTORES_ACTIVIDAD["moderado"])
    tdee = tmb * factor

    return {
        "imc": round(imc, 1),
        "categoria_imc": _categoria_imc(imc),
        "tmb_kcal": round(tmb),
        "tdee_kcal": round(tdee),
        "formula": "Mifflin-St Jeor",
    }
