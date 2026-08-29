# -*- coding: utf-8 -*-
"""Traduce el dataset `yuhonas/free-exercise-db` al vocabulario del catalogo.

Vive aqui, y no como un volcado de SQL sin mas, porque el dataset se actualiza
rio arriba: sin el generador, meter una tanda nueva de ejercicios significaria
volver a traducir 873 nombres a mano.

El nombre se arma en orden espanol, que no es el ingles: "Barbell Bench Press"
no es "Barra Banca Press" sino "Press de banca con barra". Por eso el
equipamiento se separa del nombre y se vuelve a pegar al final como
complemento, en vez de traducirse palabra por palabra donde estaba.

Uso:
    python traducir_catalogo.py exercises.json           # muestra una muestra
    python traducir_catalogo.py exercises.json --sql     # emite el INSERT
    python traducir_catalogo.py exercises.json --restos  # ingles sin traducir
"""

import json
import re
import sys
import unicodedata

# -- Equipamiento -----------------------------------------------------------
# Doble uso: la columna `equipamiento` y el complemento que cierra el nombre.
EQUIPAMIENTO = {
    "barbell": ("Barra", "con barra"),
    "dumbbell": ("Mancuernas", "con mancuernas"),
    "cable": ("Polea", "en polea"),
    "machine": ("Maquina", "en maquina"),
    "kettlebells": ("Kettlebell", "con kettlebell"),
    "bands": ("Bandas", "con banda elastica"),
    "body only": ("Peso corporal", ""),
    "e-z curl bar": ("Barra Z", "con barra Z"),
    "exercise ball": ("Fitball", "con fitball"),
    "medicine ball": ("Balon medicinal", "con balon medicinal"),
    "foam roll": ("Foam roller", "con foam roller"),
    "other": ("Otro", ""),
    "None": ("Otro", ""),
}

# -- Grupo muscular ---------------------------------------------------------
# Los valores tienen que existir como clave en `GRUPO_CATALOGO`
# (`modules/training_sessions/muscle_map.ts`) o el ejercicio se pinta gris en
# el mapa muscular sin dar ningun error.
GRUPO = {
    "abdominals": "Core",
    "abductors": "Abductores",
    "adductors": "Aductores",
    "biceps": "Biceps",
    "calves": "Gemelos",
    "chest": "Pecho",
    "forearms": "Antebrazo",
    "glutes": "Gluteos",
    "hamstrings": "Isquiotibiales",
    "lats": "Espalda",
    "lower back": "Lumbar",
    "middle back": "Espalda",
    "neck": "Cuello",
    "quadriceps": "Cuadriceps",
    "shoulders": "Hombros",
    "traps": "Trapecio",
    "triceps": "Triceps",
}

CATEGORIA = {
    "cardio": "cardio",
    "olympic weightlifting": "halterofilia",
    "plyometrics": "pliometria",
    "powerlifting": "powerlifting",
    "strength": "fuerza",
    "stretching": "estiramiento",
    "strongman": "strongman",
}

NIVEL = {
    "beginner": "principiante",
    "intermediate": "intermedio",
    "expert": "avanzado",
}

# -- Diccionario de nombres -------------------------------------------------
# Se aplica de mas largo a mas corto sobre el nombre en minusculas, siempre con
# limite de palabra. Lo de la longitud no es un capricho: "leg press" tiene que
# ganar a "press" a secas, o sale "press de pierna" en vez de "prensa".
TERMINOS = {
    # Movimientos compuestos, que hay que resolver enteros
    "bench press": "press de banca",
    "leg press": "prensa de piernas",
    "shoulder press": "press de hombro",
    "chest press": "press de pecho",
    "military press": "press militar",
    "overhead press": "press por encima de la cabeza",
    "push press": "push press",
    "floor press": "press en el suelo",
    "leg extension": "extension de cuadriceps",
    "leg extensions": "extensiones de cuadriceps",
    "leg curl": "curl femoral",
    "leg curls": "curl femoral",
    "leg raise": "elevacion de piernas",
    "leg raises": "elevaciones de piernas",
    "calf raise": "elevacion de gemelos",
    "calf raises": "elevaciones de gemelos",
    "lateral raise": "elevacion lateral",
    "lateral raises": "elevaciones laterales",
    "front raise": "elevacion frontal",
    "front raises": "elevaciones frontales",
    "upright row": "remo al menton",
    "bent over row": "remo inclinado",
    "bent-over row": "remo inclinado",
    "good morning": "buenos dias",
    "good mornings": "buenos dias",
    "pull-up": "dominada",
    "pull-ups": "dominadas",
    "pullup": "dominada",
    "pullups": "dominadas",
    "chin-up": "dominada supina",
    "chin-ups": "dominadas supinas",
    "chins": "dominadas supinas",
    "push-up": "flexion",
    "push-ups": "flexiones",
    "pushup": "flexion",
    "pushups": "flexiones",
    "push-off": "impulso",
    "sit-up": "abdominal",
    "sit-ups": "abdominales",
    "situp": "abdominal",
    "situps": "abdominales",
    "pulldown": "jalon",
    "pulldowns": "jalones",
    "pushdown": "extension en polea",
    "pull-in": "encogimiento",
    "skull crusher": "press frances",
    "skullcrusher": "press frances",
    "skullcrushers": "press frances",
    "muscle up": "muscle-up",
    "hip thrust": "empuje de cadera",
    "glute bridge": "puente de gluteos",
    "mountain climbers": "escaladores",
    "jumping jack": "salto de tijera",
    "jump rope": "comba",
    "jump squat": "sentadilla con salto",
    "box jump": "salto al cajon",
    "wall slide": "deslizamiento en pared",
    "get-up": "levantada",
    "wood chop": "lenador",
    "russian twist": "giro ruso",
    "russian twists": "giros rusos",
    "face pull": "face pull",
    "cross-body": "cruzado",
    "crossover": "cruce",
    "step-up": "subida al cajon",
    "step up": "subida al cajon",
    "flutter kick": "patada de aleteo",
    "flutter kicks": "patadas de aleteo",
    "kickback": "patada de triceps",
    "kickbacks": "patadas de triceps",
    "rear delt": "deltoides posterior",
    "rear-delt": "deltoides posterior",
    "stiff-legged": "con piernas rigidas",
    "stiff legged": "con piernas rigidas",
    "straight-arm": "con brazo estirado",
    "close-grip": "agarre cerrado",
    "wide-grip": "agarre ancho",
    "reverse grip": "agarre inverso",
    "neutral grip": "agarre neutro",
    "palms-up": "palmas arriba",
    "palms-down": "palmas abajo",
    "palms-in": "palmas hacia dentro",
    "palm-up": "palma arriba",
    "palm-in": "palma hacia dentro",
    "one-arm": "a una mano",
    "one arm": "a una mano",
    "one-armed": "a una mano",
    "single-arm": "a una mano",
    "two-arm": "a dos manos",
    "two-dumbbell": "con dos mancuernas",
    "one-leg": "a una pierna",
    "one-legged": "a una pierna",
    "single-leg": "a una pierna",
    "single leg": "a una pierna",
    "bent-arm": "con brazo flexionado",
    "bent-knee": "con rodilla flexionada",
    "bent over": "inclinado",
    "bent-over": "inclinado",
    "side-lying": "tumbado de lado",
    "on-your-back": "boca arriba",
    "behind the neck": "tras nuca",
    "behind neck": "tras nuca",
    "range of motion": "rango de movimiento",
    "range-of-motion": "rango de movimiento",
    "smith machine": "multipower",
    "t-bar": "barra T",
    "v-bar": "barra V",
    "ez-bar": "barra Z",
    "ez bar": "barra Z",
    "e-z bar": "barra Z",
    "medicine ball": "balon medicinal",
    "exercise ball": "fitball",
    "foam roll": "foam roller",
    "swiss ball": "fitball",
    "bosu ball": "bosu",
    "battling ropes": "cuerdas de batalla",
    "resistance band": "banda elastica",
    "low-pulley": "polea baja",
    "high-pulley": "polea alta",
    "calf-machine": "maquina de gemelos",
    "glute-ham": "isquio-gluteo",
    "hop-sprint": "salto y sprint",
    "single-cone": "un cono",
    "butt-ups": "elevaciones de cadera",
    "leg-over": "pierna cruzada",
    "leg-up": "pierna arriba",
    "body-up": "body-up",
    "otis-up": "Otis-up",
    "anti-gravity": "antigravedad",
    "bottoms-up": "invertida",
    "3-part": "en 3 partes",
    "all fours": "cuatro apoyos",
    # Movimientos sueltos
    "press": "press",
    "presses": "press",
    "curl": "curl",
    "curls": "curl",
    "squat": "sentadilla",
    "squats": "sentadillas",
    "deadlift": "peso muerto",
    "deadlifts": "peso muerto",
    "row": "remo",
    "rows": "remos",
    "rowing": "remo",
    "raise": "elevacion",
    "raises": "elevaciones",
    "extension": "extension",
    "extensions": "extensiones",
    "flexion": "flexion",
    "crunch": "crunch",
    "crunches": "crunches",
    "plank": "plancha",
    "lunge": "zancada",
    "lunges": "zancadas",
    "shrug": "encogimiento de hombros",
    "shrugs": "encogimientos de hombros",
    "dip": "fondo",
    "dips": "fondos",
    "fly": "apertura",
    "flye": "apertura",
    "flyes": "aperturas",
    "pullover": "pullover",
    "clean": "cargada",
    "snatch": "arrancada",
    "jerk": "envion",
    "thruster": "thruster",
    "swing": "swing",
    "swings": "swings",
    "twist": "giro",
    "twists": "giros",
    "rotation": "rotacion",
    "rotations": "rotaciones",
    "circles": "circulos",
    "stretch": "estiramiento",
    "jump": "salto",
    "jumps": "saltos",
    "hop": "salto",
    "hops": "saltos",
    "sprint": "sprint",
    "sprints": "sprints",
    "run": "carrera",
    "running": "carrera",
    "jogging": "trote",
    "walk": "paseo",
    "walking": "caminando",
    "carry": "acarreo",
    "throw": "lanzamiento",
    "drag": "arrastre",
    "drags": "arrastres",
    "pull": "traccion",
    "pulls": "tracciones",
    "push": "empuje",
    "lift": "levantamiento",
    "bridge": "puente",
    "bridges": "puentes",
    "rollout": "rueda abdominal",
    "hyperextension": "hiperextension",
    "hyperextensions": "hiperextensiones",
    "adduction": "aduccion",
    "adductions": "aducciones",
    "abduction": "abduccion",
    "scaption": "scaption",
    "pronation": "pronacion",
    "supination": "supinacion",
    # Posicion y modificadores
    "standing": "de pie",
    "seated": "sentado",
    "lying": "tumbado",
    "supine": "boca arriba",
    "prone": "boca abajo",
    "kneeling": "de rodillas",
    "incline": "inclinado",
    "decline": "declinado",
    "flat": "plano",
    "reverse": "inverso",
    "alternating": "alterno",
    "alternate": "alterno",
    "weighted": "lastrado",
    "assisted": "asistido",
    "suspended": "en suspension",
    "elevated": "elevado",
    "isometric": "isometrico",
    "dynamic": "dinamico",
    "static": "estatico",
    "wide": "abierto",
    "narrow": "cerrado",
    "close": "cerrado",
    "high": "alto",
    "low": "bajo",
    "front": "frontal",
    "rear": "posterior",
    "side": "lateral",
    "sides": "laterales",
    "lateral": "lateral",
    "laterals": "laterales",
    "overhead": "por encima de la cabeza",
    "underhand": "supino",
    "pronated": "pronado",
    "supinated": "supinado",
    "inverted": "invertido",
    "hanging": "colgado",
    "hang": "colgado",
    "bodyweight": "peso corporal",
    "freehand": "sin peso",
    "power": "de potencia",
    "heavy": "pesado",
    "split": "dividido",
    "sumo": "sumo",
    "romanian": "rumano",
    "single": "simple",
    "double": "doble",
    "half": "medio",
    "full": "completo",
    "forward": "hacia delante",
    "backward": "hacia atras",
    "upward": "hacia arriba",
    "downward": "hacia abajo",
    "external": "externa",
    "internal": "interna",
    "vertical": "vertical",
    "horizontal": "horizontal",
    "diagonal": "diagonal",
    "parallel": "paralelo",
    "linear": "lineal",
    "long": "largo",
    "short": "corto",
    "quick": "rapido",
    "speed": "de velocidad",
    "fast": "rapido",
    "deficit": "en deficit",
    "partials": "parciales",
    "olympic": "olimpico",
    "advanced": "avanzado",
    "intermediate": "intermedio",
    "beginner": "principiante",
    "medium": "medio",
    "mixed": "mixto",
    "extended": "extendido",
    "straight": "recto",
    "round": "circular",
    "open": "abierto",
    "natural": "natural",
    "manual": "manual",
    "stability": "estabilidad",
    "resistance": "resistencia",
    # Anatomia
    "chest": "pecho",
    "shoulder": "hombro",
    "shoulders": "hombros",
    "biceps": "biceps",
    "bicep": "biceps",
    "inner-biceps": "biceps interno",
    "triceps": "triceps",
    "tricep": "triceps",
    "forearm": "antebrazo",
    "wrist": "muneca",
    "finger": "dedos",
    "neck": "cuello",
    "back": "espalda",
    "lat": "dorsal",
    "lats": "dorsales",
    "latissimus": "dorsal ancho",
    "dorsi": "dorsal",
    "traps": "trapecio",
    "trap": "trapecio",
    "rhomboids": "romboides",
    "delt": "deltoides",
    "deltoid": "deltoides",
    "abs": "abdominales",
    "ab": "abdominal",
    "abdominal": "abdominal",
    "oblique": "oblicuo",
    "core": "core",
    "hip": "cadera",
    "glute": "gluteo",
    "glutes": "gluteos",
    "quad": "cuadriceps",
    "quads": "cuadriceps",
    "quadriceps": "cuadriceps",
    "hamstring": "isquiotibiales",
    "hamstrings": "isquiotibiales",
    "ham": "isquiotibiales",
    "calf": "gemelo",
    "calves": "gemelos",
    "gastrocnemius": "gastrocnemio",
    "soleus": "soleo",
    "achilles": "aquiles",
    "adductor": "aductor",
    "abductor": "abductor",
    "groin": "ingle",
    "thigh": "muslo",
    "leg": "pierna",
    "legs": "piernas",
    "knee": "rodilla",
    "knees": "rodillas",
    "ankle": "tobillo",
    "toe": "punta del pie",
    "heel": "talon",
    "foot": "pie",
    "feet": "pies",
    "elbow": "codo",
    "elbows": "codos",
    "arm": "brazo",
    "arms": "brazos",
    "hand": "mano",
    "hands": "manos",
    "handed": "manos",
    "palm": "palma",
    "palms": "palmas",
    "head": "cabeza",
    "torso": "torso",
    "body": "cuerpo",
    "spinal": "espinal",
    "piriformis": "piramidal",
    "peroneals": "peroneos",
    "tibialis": "tibial",
    "iliotibial": "iliotibial",
    "brachialis": "braquial",
    "flexor": "flexor",
    "flexors": "flexores",
    "anterior": "anterior",
    "posterior": "posterior",
    "upper": "superior",
    "lower": "inferior",
    "middle": "medio",
    "mid": "medio",
    "inner": "interno",
    "outer": "externo",
    "stomach": "abdomen",
    "butt": "gluteos",
    "pelvic": "pelvica",
    "sternum": "esternon",
    "scapular": "escapular",
    "smr": "automasaje",
    # Material y entorno
    "barbell": "barra",
    "dumbbell": "mancuerna",
    "dumbbells": "mancuernas",
    "kettlebell": "kettlebell",
    "kettlebells": "kettlebells",
    "cable": "polea",
    "pulley": "polea",
    "machine": "maquina",
    "leverage": "de palanca",
    "bench": "banco",
    "bar": "barra",
    "bars": "barras",
    "plate": "disco",
    "chains": "cadenas",
    "chain": "cadena",
    "rope": "cuerda",
    "ropes": "cuerdas",
    "ball": "balon",
    "box": "cajon",
    "board": "tabla",
    "wall": "pared",
    "floor": "suelo",
    "chair": "silla",
    "bike": "bicicleta",
    "bicycling": "bicicleta",
    "treadmill": "cinta",
    "elliptical": "eliptica",
    "stairmaster": "escaladora",
    "stairs": "escaleras",
    "rack": "rack",
    "pins": "pines",
    "pin": "pin",
    "handle": "agarre",
    "grip": "agarre",
    "attachment": "agarre",
    "straps": "correas",
    "harness": "arnes",
    "sled": "trineo",
    "prowler": "trineo",
    "tire": "rueda",
    "stone": "piedra",
    "stones": "piedras",
    "sandbag": "saco de arena",
    "keg": "barril",
    "log": "tronco",
    "axle": "eje",
    "yoke": "yugo",
    "roller": "rodillo",
    "wheel": "rueda",
    "towel": "toalla",
    "platform": "plataforma",
    "blocks": "bloques",
    "block": "bloque",
    "cone": "cono",
    "hurdle": "valla",
    "trainer": "entrenador",
    "physioball": "fitball",
    "ring": "anilla",
    "rings": "anillas",
    "bag": "saco",
    "car": "coche",
    "band": "banda elastica",
    "bands": "bandas elasticas",
    "landmine": "landmine",
    "jammer": "jammer",
    "rickshaw": "rickshaw",
    "cambered": "cambered",
    "iron": "hierro",
    "wood": "madera",
    "stance": "postura",
    "position": "posicion",
    "positions": "posiciones",
    "pose": "postura",
    "series": "serie",
    "drill": "ejercicio",
    "exercise": "ejercicio",
    "technique": "tecnica",
    "progression": "progresion",
    "version": "version",
    "start": "inicio",
    "catch": "recepcion",
    "release": "suelta",
    "balance": "equilibrio",
    "muscle": "muscular",
    "squeeze": "contraccion",
    "squeezes": "contracciones",
    "touch": "toque",
    "touches": "toques",
    "touchers": "toques",
    "slide": "deslizamiento",
    "slides": "deslizamientos",
    "climb": "escalada",
    "climbers": "escaladores",
    "skip": "salto de comba",
    "skipping": "comba",
    "shuffle": "desplazamiento lateral",
    "stride": "zancada",
    "tuck": "recogida",
    "tucks": "recogidas",
    "kick": "patada",
    "kicks": "patadas",
    "bend": "flexion",
    "bends": "flexiones",
    "tilt": "bascula",
    "thrust": "empuje",
    "load": "carga",
    "delivery": "lanzamiento",
    "movers": "movilizadores",
    "moving": "en movimiento",
    "concentration": "concentrado",
    "preacher": "en banco Scott",
    "spider": "spider",
    "hammer": "martillo",
    "goblet": "goblet",
    "pistol": "pistol",
    "sissy": "sissy",
    "hack": "hack",
    "frog": "rana",
    "donkey": "burro",
    "gorilla": "gorila",
    "bear": "oso",
    "crawl": "reptacion",
    "superman": "superman",
    "butterfly": "mariposa",
    "windmill": "molino",
    "windmills": "molinos",
    "scissor": "tijera",
    "scissors": "tijeras",
    "jackknife": "navaja",
    "inchworm": "oruga",
    "cocoons": "capullos",
    "locust": "langosta",
    "child": "del nino",
    "cat": "del gato",
    "dancer": "del bailarin",
    "runner": "del corredor",
    "pyramid": "piramide",
    "star": "estrella",
    "clock": "reloj",
    "figure": "figura",
    "world": "mundo",
    "worlds": "mundo",
    "greatest": "mejor",
    "monster": "monstruo",
    "rocket": "cohete",
    "rocking": "balanceo",
    "crucifix": "crucifijo",
    "guillotine": "guillotina",
    "renegade": "renegado",
    "seesaw": "sube y baja",
    "see-saw": "sube y baja",
    "vacuum": "vacio abdominal",
    "groiners": "groiners",
    "carioca": "carioca",
    "skating": "patinaje",
    "judo": "judo",
    "handstand": "pino",
    "pike": "carpa",
    "straddle": "abierto",
    "plyo": "pliometrico",
    "depth": "de profundidad",
    "bound": "bote",
    "leap": "salto largo",
    "acceleration": "aceleracion",
    "recumbent": "reclinada",
    "stationary": "estatica",
    "air": "al aire",
    "wind": "viento",
    "mill": "molino",
    "sledgehammer": "mazo",
    "shotgun": "escopeta",
    "spell": "deletrear",
    "caster": "caster",
    "fallout": "caida controlada",
    "crosses": "cruces",
    "wipers": "limpiaparabrisas",
    "flip": "volteo",
    "slam": "golpeo",
    "pass": "pase",
    "scoop": "recogida",
    "drop": "caida",
    "return": "retorno",
    "grab": "agarre",
    "pinch": "pinza",
    "iso": "iso",
    "trail": "pierna atrasada",
    "back-leg": "pierna atrasada",
    "cross": "cruzado",
    "chin": "menton",
    "face": "cara",
    "facing": "de frente",
    "circus": "circo",
    "bell": "campana",
    "farmer": "granjero",
    "drivers": "drivers",
    "dead": "muerto",
    "bottoms": "fondo",
    "multiple": "multiple",
    "response": "respuesta",
    "point": "punto",
    "style": "estilo",
    "powerlifting": "powerlifting",
    "strongman": "strongman",
    "db": "mancuerna",
    "smith": "multipower",
    # Nombres propios: se mantienen, solo se normaliza la mayuscula
    "arnold": "Arnold",
    "cuban": "cubana",
    "bradford": "Bradford",
    "svend": "Svend",
    "tate": "Tate",
    "zercher": "Zercher",
    "jefferson": "Jefferson",
    "janda": "Janda",
    "gironda": "Gironda",
    "pallof": "Pallof",
    "turkish": "turca",
    "russian": "ruso",
    "zottman": "Zottman",
    "atlas": "Atlas",
    "conan": "Conan",
    "rocky": "Rocky",
    "london": "London",
    "frankenstein": "Frankenstein",
    "bosu": "bosu",
    "jm": "JM",
    "ez": "Z",
    "it": "IT",
    # Palabras funcionales
    "with": "con",
    "and": "y",
    "or": "o",
    "the": "",
    "a": "",
    "an": "",
    "of": "de",
    "on": "en",
    "in": "en",
    "at": "en",
    "to": "a",
    "from": "desde",
    "into": "hacia",
    "over": "sobre",
    "under": "bajo",
    "above": "por encima",
    "below": "por debajo",
    "between": "entre",
    "against": "contra",
    "apart": "separados",
    "around": "alrededor",
    "across": "a traves",
    "through": "a traves",
    "your": "",
    "no": "sin",
    "off": "fuera",
    "up": "arriba",
    "down": "abajo",
    "all": "todos",
    "fours": "cuatro apoyos",
    "s": "",
    "medicine": "medicinal",
    "touchers": "toques",
    "heel": "talon",
    "smr": "automasaje",
    "tibialis": "tibial",
    "peroneals": "peroneos",
    "quadriceps-smr": "automasaje de cuadriceps",
    "roll": "rodillo",
    "wheel": "rueda",
    "ups": "elevaciones",
    "abdominals": "abdominales",
    "obliques": "oblicuos",
    "hamstring-smr": "automasaje de isquiotibiales",
    "leverage": "de palanca",
    "seesaw": "sube y baja",
    "jack": "tijera",
    "jacks": "tijeras",
    "jumping": "saltando",
    "sitting": "sentado",
    "standing": "de pie",
    "toes": "puntas de los pies",
    "wrists": "munecas",
    "shin": "espinilla",
    "chest-supported": "con apoyo en pecho",
    "behind": "por detras",
    "bent": "flexionado",
    "step": "escalon",
    "one": "una",
    "two": "dos",
    "bug": "bicho",
    "range": "rango",
    "flutter": "aleteo",
    "heaving": "en balanceo",
    "hug": "abrazo",
    "tract": "banda",
    "pirate": "pirata",
    "ships": "barcos",
    "kipping": "kipping",
    "looking": "mirando",
    "ceiling": "techo",
    "military": "militar",
    "mountain": "montana",
    "claw": "garra",
    "para": "para",
    "plie": "plie",
    "sit": "sentado",
    "stiff": "rigida",
    "upright": "al menton",
    "otis": "Otis",
    "isquio": "isquio",
    "muscle": "muscle",
    "body": "cuerpo",
}

_ORDEN = sorted(TERMINOS, key=lambda t: (-len(t.split()), -len(t)))
_PATRONES = [
    (re.compile(r"(?<!\w)" + re.escape(k) + r"(?!\w)", re.I), TERMINOS[k])
    for k in _ORDEN
]

# Prefijos de equipamiento que se retiran del principio del nombre. El dataset
# no es consistente: unos empiezan por el `equipment` exacto y otros por un
# sinonimo ("Cable" cuando el equipment es "cable", "Band" cuando es "bands").
_PREFIJOS = [
    "barbell", "dumbbell", "dumbbells", "cable", "cables", "kettlebell",
    "kettlebells", "machine", "band", "bands", "smith machine",
]


# Nucleos: el movimiento del que habla el ejercicio. Sirven para reordenar la
# frase, que es lo que separa una traduccion de un calco. En ingles los
# modificadores van DELANTE del nucleo ("Alternating Hammer Curl") y en espanol
# detras y en orden inverso ("Curl martillo alterno"). Sin esta pasada salen
# 872 nombres legibles pero que nadie escribiria asi.
NUCLEOS = [
    "bench press", "leg press", "shoulder press", "chest press",
    "military press", "overhead press", "push press", "floor press",
    "leg extension", "leg extensions", "leg curl", "leg curls",
    "leg raise", "leg raises", "calf raise", "calf raises",
    "lateral raise", "lateral raises", "front raise", "front raises",
    "upright row", "good morning", "good mornings", "hip thrust",
    "glute bridge", "russian twist", "wood chop", "skull crusher",
    "skullcrusher", "muscle up", "box jump", "jump squat", "step-up",
    "sit-up", "sit-ups", "situp", "situps", "push-up", "push-ups",
    "pushup", "pushups", "pull-up", "pull-ups", "pullup", "pullups",
    "chin-up", "chin-ups", "chins", "pulldown", "pulldowns", "pushdown",
    "press", "presses", "curl", "curls", "squat", "squats",
    "deadlift", "deadlifts", "row", "rows", "raise", "raises",
    "extension", "extensions", "crunch", "crunches", "plank", "lunge",
    "lunges", "shrug", "shrugs", "dip", "dips", "fly", "flye", "flyes",
    "pullover", "clean", "snatch", "jerk", "thruster", "swing", "swings",
    "twist", "twists", "rotation", "rotations", "stretch", "jump", "jumps",
    "hop", "hops", "sprint", "sprints", "run", "walk", "carry", "throw",
    "drag", "drags", "pull", "pulls", "push", "lift", "bridge", "bridges",
    "rollout", "hyperextension", "hyperextensions", "adduction",
    "abduction", "kickback", "kickbacks", "circles", "shuffle", "climbers", "touchers", "touches",
    "crawl", "climb", "slam", "flip", "kick", "kicks", "bend", "bends",
    "roll", "walk", "carry", "hold", "get-up", "wall slide",
]
_NUCLEOS_RE = [
    (n, re.compile(r"(?<!\w)" + re.escape(n) + r"(?!\w)", re.I))
    for n in sorted(NUCLEOS, key=lambda n: (-len(n.split()), -len(n)))
]


def _partir_por_nucleo(texto: str):
    """Devuelve (modificadores, nucleo, cola) del nombre en ingles.

    Se queda con la ULTIMA aparicion del nucleo mas largo: en ingles el nucleo
    cierra el sintagma ("Cable Seated Row"), asi que lo que va antes son
    modificadores y lo que va detras es casi siempre un complemento que en
    espanol tambien va detras ("Row to Chest").
    """
    mejor = None
    for _, patron in _NUCLEOS_RE:
        for m in patron.finditer(texto):
            if mejor is None or m.start() > mejor.start():
                mejor = m
        if mejor is not None:
            break
    if mejor is None:
        return texto, "", ""
    return texto[:mejor.start()].strip(), mejor.group(0), texto[mejor.end():].strip()


def traducir_nombre(nombre: str, equipment: str) -> str:
    texto = nombre.replace("’", "'").lower()
    _, complemento = EQUIPAMIENTO.get(equipment, ("Otro", ""))

    quitado = False
    if complemento:
        for prefijo in sorted(_PREFIJOS, key=len, reverse=True):
            if texto.startswith(prefijo + " "):
                texto = texto[len(prefijo) + 1:]
                quitado = True
                break

    modificadores, nucleo, cola = _partir_por_nucleo(texto)
    if nucleo:
        # Los modificadores se invierten ANTES de traducir: en ingles se apilan
        # del mas general al mas cercano al nucleo y en espanol al reves.
        # "Incline Dumbbell Bench Press" -> "press de banca con mancuernas
        # inclinado", no "inclinado con mancuernas press de banca".
        invertidos = " ".join(reversed(modificadores.split()))
        texto = " ".join(x for x in (nucleo, cola, invertidos) if x)

    # Se sustituye reservando cada traduccion tras un marcador. Sin esto, una
    # traduccion que contiene una palabra inglesa ("press" -> "press", "band"
    # dentro de "banda elastica") vuelve a entrar en la pasada siguiente y el
    # resultado se corrompe encima de si mismo.
    piezas: list[str] = []

    for patron, destino in _PATRONES:
        def _sub(_m, destino=destino):
            piezas.append(destino)
            return "\x00%d\x00" % (len(piezas) - 1)

        texto = patron.sub(_sub, texto)

    texto = re.sub(r"\x00(\d+)\x00", lambda m: piezas[int(m.group(1))], texto)
    texto = texto.replace("'", "")
    # El dataset separa variantes con " - " ("Back Flyes - With Bands"); una vez
    # traducido y reordenado ese guion ya no separa nada, solo estorba.
    texto = re.sub(r"\s*-\s*", " ", texto)
    texto = re.sub(r"\s+", " ", texto).strip(" -")
    texto = re.sub(r"\s+", " ", texto).strip()

    if quitado and complemento:
        texto = "%s %s" % (texto, complemento)

    texto = acentuar(texto)
    return texto[:1].upper() + texto[1:] if texto else nombre


# -- Tildes -----------------------------------------------------------------
# El diccionario se escribe sin tildes a proposito (una sola forma por palabra,
# sin decidir en cada entrada si lleva acento) y se acentua aqui, al final, por
# palabra suelta. Poner las tildes arriba obligaria a duplicar cada regla para
# que "extension" y "extensiones" no se acentuaran las dos igual.
TILDES = {
    "biceps": u"bíceps", "triceps": u"tríceps",
    "cuadriceps": u"cuádriceps", "gluteo": u"glúteo",
    "gluteos": u"glúteos", "maquina": u"máquina",
    "extension": u"extensión", "elevacion": u"elevación",
    "flexion": u"flexión", "jalon": u"jalón",
    "menton": u"mentón", "cajon": u"cajón", "balon": u"balón",
    "aduccion": u"aducción", "abduccion": u"abducción",
    "rotacion": u"rotación", "traccion": u"tracción",
    "contraccion": u"contracción", "posicion": u"posición",
    "progresion": u"progresión", "version": u"versión",
    "reptacion": u"reptación", "aceleracion": u"aceleración",
    "pronacion": u"pronación", "supinacion": u"supinación",
    "recepcion": u"recepción", "hiperextension": u"hiperextensión",
    "muneca": u"muñeca", "munecas": u"muñecas",
    "nino": u"niño", "lenador": u"leñador",
    "montana": u"montaña", "arnes": u"arnés",
    "soleo": u"sóleo", "piramide": u"pirámide",
    "bailarin": u"bailarín", "esternon": u"esternón",
    "isometrico": u"isométrico", "dinamico": u"dinámico",
    "estatico": u"estático", "estatica": u"estática",
    "eliptica": u"elíptica", "pliometrico": u"pliométrico",
    "olimpico": u"olímpico", "rapido": u"rápido",
    "deficit": u"déficit", "multiple": u"múltiple",
    "tecnica": u"técnica", "pelvica": u"pélvica",
    "bascula": u"báscula", "caida": u"caída",
    "vacio": u"vacío", "dias": u"días",
    "rigidas": u"rígidas", "elastica": u"elástica",
    "elasticas": u"elásticas", "circulos": u"círculos",
    "envion": u"envión", "frances": u"francés",
    "talon": u"talón", "atras": u"atrás",
    "traves": u"través", "plie": u"plié",
    "tambien": u"también", "pierna": "pierna",
    "piramidal": "piramidal",
}


def acentuar(texto: str) -> str:
    return re.sub(
        r"[A-Za-zñ]+",
        lambda m: _mantener_caja(m.group(0), TILDES.get(m.group(0).lower())),
        texto,
    )


def _mantener_caja(original: str, acentuada) -> str:
    if not acentuada:
        return original
    if original[:1].isupper():
        return acentuada[:1].upper() + acentuada[1:]
    return acentuada


def sin_tildes(t: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", t)
        if unicodedata.category(c) != "Mn"
    )


def construir(ruta_dataset: str) -> list:
    datos = json.load(open(ruta_dataset, encoding="utf-8"))
    filas, vistos = [], set()
    for e in datos:
        nombre = traducir_nombre(e["name"], str(e.get("equipment")))[:100]
        clave = sin_tildes(nombre).lower()
        # `nombre` es UNIQUE en la tabla: dos ingleses distintos pueden caer en
        # la misma traduccion ("Barbell Curl" / "Barbell Curls"), y sin este
        # filtro el INSERT entero se cae por la restriccion.
        if clave in vistos:
            continue
        vistos.add(clave)

        principal = (e.get("primaryMuscles") or ["chest"])[0]
        equipo, _ = EQUIPAMIENTO.get(str(e.get("equipment")), ("Otro", ""))
        categoria = CATEGORIA.get(e.get("category", ""), e.get("category", ""))
        nivel = NIVEL.get(e.get("level", ""), "")
        # La descripcion se CONSTRUYE en espanol a partir de los campos
        # estructurados; no se traducen las instrucciones del dataset.
        #
        # Dos motivos. Uno: las instrucciones son prosa inglesa de varias
        # frases, y un diccionario de terminos que sirve para nombres cortos
        # produce con ellas un destrozo — mejor no tenerlas que tenerlas mal.
        # Dos: `GET /exercises-catalog` devuelve la tabla COMPLETA y la app se
        # la traga entera al abrir "Anadir rapido"; con las instrucciones
        # dentro esa carga pasa de ~180 KB a ~740 KB, sobre el plan gratuito de
        # Render y en cada apertura. Lo que se pierde sigue estando en el
        # dataset de origen.
        secundarios = [
            GRUPO.get(m, m) for m in (e.get("secondaryMuscles") or [])
        ]
        partes = ["%s, nivel %s" % (categoria.capitalize(), nivel)]
        partes.append("trabaja %s" % GRUPO.get(principal, "el tren superior").lower())
        if secundarios:
            partes.append("tambien %s" % ", ".join(s.lower() for s in secundarios))
        if equipo not in ("Otro", "Peso corporal"):
            partes.append("con %s" % equipo.lower())
        elif equipo == "Peso corporal":
            partes.append("sin material")
        descripcion = " · ".join(partes) + "."
        imagenes = e.get("images") or []
        url = (
            "https://raw.githubusercontent.com/yuhonas/free-exercise-db/"
            "main/exercises/" + imagenes[0]
        ) if imagenes else None

        filas.append({
            "nombre": nombre,
            "grupo": acentuar(GRUPO.get(principal, "Pecho")),
            "equipo": acentuar(equipo),
            "descripcion": acentuar(descripcion)[:300] or None,
            "imagen": url,
        })
    return filas


def _sql(v) -> str:
    if v is None:
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"


def emitir_sql(filas: list) -> str:
    valores = ",\n      ".join(
        "(%s, %s, %s, %s, %s)" % (
            _sql(f["nombre"]), _sql(f["grupo"]), _sql(f["equipo"]),
            _sql(f["descripcion"]), _sql(f["imagen"]),
        )
        for f in filas
    )
    return valores


def restos_ingles(filas: list) -> list:
    """Nombres que aun contienen palabras que no estan en el diccionario."""
    conocidas = set()
    for destino in TERMINOS.values():
        conocidas.update(sin_tildes(destino).lower().split())
    pendientes = []
    for f in filas:
        sueltas = [
            t for t in re.split(r"[^\w]+", sin_tildes(f["nombre"]).lower())
            if t and not t.isdigit() and t not in conocidas
        ]
        if sueltas:
            pendientes.append((f["nombre"], sueltas))
    return pendientes


if __name__ == "__main__":
    filas = construir(sys.argv[1])
    if "--sql" in sys.argv:
        print(emitir_sql(filas))
    elif "--restos" in sys.argv:
        pendientes = restos_ingles(filas)
        print("%d nombres con palabras sin traducir" % len(pendientes))
        for nombre, sueltas in pendientes:
            print("  %-60s %s" % (nombre, sueltas))
    else:
        print("%d ejercicios" % len(filas))
        for f in filas[:40]:
            print("  %-55s %-15s %s" % (f["nombre"], f["grupo"], f["equipo"]))
