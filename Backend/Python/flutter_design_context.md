# Personal TrAIner — Flutter Design Context
# Inyecta este archivo cuando generes widgets/pantallas Dart para Flutter.
# Los tokens están extraídos DIRECTAMENTE del código real del proyecto.

## Stack y dependencias clave
- Flutter + Dart, Material 3 (`useMaterial3: true`)
- Fuentes: `google_fonts` → `GoogleFonts.outfit()` (display/títulos) + `GoogleFonts.manrope()` (body/labels)
- Iconos: `lucide_icons` (LucideIcons.xxx) y `phosphor_flutter` (PhosphorIcons.xxx())
- Clases del proyecto: `DesignTokens`, `GlassCard`, `MetricRing`, `AiGradientText`, `AiPulseEffect`, `AiRingEffect`
- Layout: `SingleChildScrollView` + `Column` con padding `fromLTRB(20, 12, 20, 32)`
- Siempre adaptable a modo claro/oscuro via `Theme.of(context).brightness`

---

## Colores — usar DesignTokens, nunca hardcoded

### Light mode
```dart
DesignTokens.lightBackground    = Color(0xFFFFFFFF)
DesignTokens.lightForeground    = Color(0xFF1B1B20)
DesignTokens.lightCard          = Color(0xFFFFFFFF)
DesignTokens.lightMuted         = Color(0xFFF1F1F4)
DesignTokens.lightMutedForeground = Color(0xFF7E7E89)
DesignTokens.lightBorder        = Color(0xFFE9E9EC)
DesignTokens.lightSurface1      = Color(0xFFFAFAFB)
DesignTokens.lightSurface2      = Color(0xFFF3F3F6)
DesignTokens.lightDestructive   = Color(0xFFE5484D)
```

### Dark mode
```dart
DesignTokens.darkBackground     = Color(0xFF111318)
DesignTokens.darkForeground     = Color(0xFFF9F9FC)
DesignTokens.darkCard           = Color(0xFF23262F)
DesignTokens.darkMuted          = Color(0xFF3A3D49)
DesignTokens.darkMutedForeground = Color(0xFF9DA0AE)
DesignTokens.darkBorder         = Color(0x1AFFFFFF)
DesignTokens.darkSurface1       = Color(0xFF1B1D24)
DesignTokens.darkSurface2       = Color(0xFF1A1C22)
```

### Acceder correctamente (brightness-aware)
```dart
final b = Theme.of(context).brightness;
final fg = DesignTokens.foreground(b);
final mutedFg = DesignTokens.mutedForeground(b);
final card = DesignTokens.card(b);
final muted = DesignTokens.muted(b);
final border = DesignTokens.border(b);
final surface1 = DesignTokens.surface1(b);
final bg = DesignTokens.background(b);
```

---

## Gradiente AI (identidad visual principal)

```dart
// Colores individuales
DesignTokens.aiFrom = Color(0xFFB054F0)   // púrpura
DesignTokens.aiVia  = Color(0xFF6A5CF0)   // azul/violeta
DesignTokens.aiTo   = Color(0xFF46B5E8)   // cian

// Gradiente completo (uso en botones, anillos, texto)
DesignTokens.aiGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFB054F0), Color(0xFF6A5CF0), Color(0xFF46B5E8)],
  stops: [0.0, 0.55, 1.0],
)

// Versión soft (fondos de cards, contenedores de icono)
DesignTokens.aiGradientSoft = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEEDBFC), Color(0xFFDCEBFB)],
)

// Alerta/warning
DesignTokens.warnSoft = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFBE8B0), Color(0xFFF4D785)],
)
```

---

## Border Radius — escala real del proyecto

```dart
DesignTokens.cardRadius   = 28.0   // ← contenedores principales, siempre
DesignTokens.radius2xl    = 18.0   // cards secundarias, botones
DesignTokens.radiusXl     = 14.0   // elementos internos
DesignTokens.radiusLg     = 10.0
DesignTokens.radiusMd     = 8.0
DesignTokens.radiusSm     = 6.0
```

---

## Sombras — usar siempre DesignTokens

```dart
// Card principal (el más prominente)
boxShadow: DesignTokens.shadowCard(b)

// Elementos secundarios, pills, chips
boxShadow: DesignTokens.shadowSoft(b)
```

---

## Tipografía — escala real del AppTheme

```dart
// EYEBROW / LABEL (uppercase con tracking)
TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 1.4, color: mutedFg)

// TÍTULO PRINCIPAL
GoogleFonts.outfit(fontSize: 22-26, fontWeight: FontWeight.w800,
                   letterSpacing: -0.5, color: fg)

// SUBTÍTULO H3
GoogleFonts.outfit(fontSize: 18-20, fontWeight: FontWeight.w700, color: fg)

// TEXTO BODY PRINCIPAL
GoogleFonts.manrope(fontSize: 14-15, fontWeight: FontWeight.w500, color: fg)

// TEXTO SECUNDARIO / DESCRIPCIÓN
GoogleFonts.manrope(fontSize: 12-13, color: mutedFg)

// NÚMERO GRANDE (métricas)
TextStyle(fontSize: 15-18, fontWeight: FontWeight.w800, color: fg)

// CAPTION / MICRO-LABEL
TextStyle(fontSize: 10-11, fontWeight: FontWeight.w600,
          letterSpacing: 0.5, color: mutedFg)
```

---

## Componentes disponibles — usar directamente

### GlassCard
```dart
GlassCard(
  radius: 28,                          // default cardRadius
  padding: const EdgeInsets.all(16),   // o fromLTRB(20,16,20,14)
  shadow: true,
  child: ...,
)
// → blur 20px, fondo translúcido, borde translúcido, sombra
```

### MetricRing (anillo de progreso con gradiente AI)
```dart
MetricRing(
  value: '72',          // texto central grande
  unit: '%',            // texto pequeño junto al valor
  pct: 0.72,            // 0.0 → 1.0
  diameter: 72,         // tamaño del anillo
  stroke: 6,
  sub: 'óptima',        // segunda línea (opcional)
)
```

### AiGradientText
```dart
AiGradientText(
  'texto con gradiente',
  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
)
```

### AiPulseEffect / AiRingEffect (indicadores live)
```dart
// Punto verde pulsante + aro expansivo (live BPM, estado sync)
Stack(
  alignment: Alignment.center,
  children: [
    AiPulseEffect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF10B981),
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: 8, height: 8),
      ),
    ),
    AiRingEffect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x6610B981),
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: 8, height: 8),
      ),
    ),
  ],
)
```

---

## Patrones de Widget — copiar exactamente

### Card principal estándar
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
    boxShadow: DesignTokens.shadowCard(b),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('LABEL · SUBTÍTULO',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                           letterSpacing: 1.4, color: mutedFg)),
      const SizedBox(height: 4),
      Text('Título principal',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                           letterSpacing: -0.5, color: fg)),
      // contenido...
    ],
  ),
)
```

### Card con gradiente AI soft (hero card)
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    gradient: DesignTokens.aiGradientSoft,
    borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
    boxShadow: DesignTokens.shadowCard(b),
  ),
  child: ...,
)
```

### Botón primario con gradiente AI
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  decoration: BoxDecoration(
    gradient: DesignTokens.aiGradient,
    borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
    boxShadow: DesignTokens.shadowCard(b),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
      SizedBox(width: 8),
      Text('Acción principal',
          style: TextStyle(color: Colors.white,
                           fontWeight: FontWeight.w600, fontSize: 15)),
    ],
  ),
)
```

### Action tile (quick action 3 cols)
```dart
Material(
  color: card,
  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
  clipBehavior: Clip.antiAlias,
  child: InkWell(
    borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: DesignTokens.aiGradientSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: fg)),
          Text(sub, style: TextStyle(fontSize: 11, color: mutedFg)),
        ],
      ),
    ),
  ),
)
```

### Chip / badge de estado
```dart
// Verde positivo
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: const Color(0xFFECFDF5),
    borderRadius: BorderRadius.circular(999),
  ),
  child: Text('Estado positivo',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                       color: Color(0xFF047857))),
)

// Badge oscuro (estilo Xiaomi/device)
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: const Color(0xFF1E1E1E),
    borderRadius: BorderRadius.circular(999),
  ),
  child: Row(children: [
    Container(width: 6, height: 6,
        decoration: BoxDecoration(color: Color(0xFFFF6900),
                                  shape: BoxShape.circle)),
    SizedBox(width: 4),
    Text('DEVICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 0.5)),
  ]),
)
```

### Alerta predictiva (warnSoft)
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    gradient: DesignTokens.warnSoft,
    borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
    boxShadow: DesignTokens.shadowCard(b),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.70),
          shape: BoxShape.circle,
          boxShadow: DesignTokens.shadowSoft(b),
        ),
        child: Icon(LucideIcons.alertTriangle,
            size: 16, color: Color(0xFFC2410C)),
      ),
      SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ALERTA · TIPO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                               letterSpacing: 1.4,
                               color: Color(0xFF9A3412))),
          SizedBox(height: 4),
          RichText(text: TextSpan(
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                             color: fg, height: 1.35),
            children: [
              TextSpan(text: 'Mensaje con '),
              TextSpan(text: 'énfasis', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          )),
        ],
      )),
    ],
  ),
)
```

### Live sync pill (BPM en tiempo real)
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: surface1,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: border),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 16, height: 16,
        child: Stack(alignment: Alignment.center, children: [
          AiPulseEffect(child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF10B981),
                                      shape: BoxShape.circle),
            child: SizedBox(width: 8, height: 8))),
          AiRingEffect(child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x6610B981),
                                      shape: BoxShape.circle),
            child: SizedBox(width: 8, height: 8))),
        ]),
      ),
      SizedBox(width: 8),
      Icon(LucideIcons.heart, size: 14, color: fg.withOpacity(0.7)),
      SizedBox(width: 4),
      RichText(text: TextSpan(
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
        children: [
          TextSpan(text: '64'),
          TextSpan(text: 'bpm',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                               color: mutedFg)),
        ],
      )),
    ],
  ),
)
```

### Barra de progreso con gradiente AI
```dart
Container(
  height: 8,
  decoration: BoxDecoration(color: DesignTokens.muted(b),
                            borderRadius: BorderRadius.circular(999)),
  alignment: Alignment.centerLeft,
  child: FractionallySizedBox(
    widthFactor: pct,  // 0.0 → 1.0
    child: Container(
      decoration: BoxDecoration(
        gradient: DesignTokens.aiGradient,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  ),
)
```

### Stat pill (métricas en fila)
```dart
Container(
  padding: const EdgeInsets.symmetric(vertical: 12),
  decoration: BoxDecoration(color: surface1,
                            borderRadius: BorderRadius.circular(16)),
  child: Column(children: [
    Text(value, style: TextStyle(fontSize: 13,
        fontWeight: FontWeight.w800, color: fg)),
    SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                 letterSpacing: 0.5, color: mutedFg)),
  ]),
)
```

### Macro box (proteína/carbos/grasas)
```dart
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: surface1,
                            borderRadius: BorderRadius.circular(16)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('PROTEÍNA', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, letterSpacing: 0.5, color: mutedFg)),
      SizedBox(height: 4),
      RichText(text: TextSpan(
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
        children: [
          TextSpan(text: '92'),
          TextSpan(text: '/160g', style: TextStyle(fontSize: 11,
              color: mutedFg, fontWeight: FontWeight.w600)),
        ],
      )),
      SizedBox(height: 8),
      // Barra de color del macro
      Container(
        height: 4, width: double.infinity,
        decoration: BoxDecoration(color: DesignTokens.muted(b),
                                  borderRadius: BorderRadius.circular(999)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: pct,
          child: Container(decoration: BoxDecoration(
              color: const Color(0xFF9D7BFF),   // violeta proteína
              borderRadius: BorderRadius.circular(999))),
        ),
      ),
    ],
  ),
)
// Colores de macro: proteína=0xFF9D7BFF, carbos=0xFF06B6D4, grasas=0xFFF87171
```

### Contenedor de icono AI soft
```dart
Container(
  width: 36, height: 36,   // o 48x48
  alignment: Alignment.center,
  decoration: BoxDecoration(
    gradient: DesignTokens.aiGradientSoft,
    borderRadius: BorderRadius.circular(12),   // o shape: BoxShape.circle
  ),
  child: Icon(LucideIcons.sparkles, size: 16, color: fg),
)
```

---

## Focus Mode / Workout Session — sistema dark independiente

Implementado en `workout_session_page.dart`. Esta pantalla es **dark-only** y NO usa `DesignTokens`
ni el gradiente AI del resto de la app. Tiene su propio set de colores fijo (no brightness-aware).
Úsalo tal cual cuando generes o modifiques esta pantalla — no lo mezcles con el sistema claro.

### Paleta fija de Focus Mode
```dart
// Fondo del header de frecuencia cardíaca
LinearGradient(
  colors: [Color(0xFF0B1220), Color(0xFF1A2B4B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)

// Acentos
Color(0xFFEF4444)  // rojo — icono heartbeat, alta intensidad
Color(0xFF059669)  // verde — estado BLE conectado, completado
Color(0xFFFBBF24)  // ámbar — "Entreno detectado"
Color(0xFF2563EB)  // azul — acciones secundarias
Color(0xFF00F0FF)  // cyan — gráfica HR en vivo, métrica R-R (HRV)
Color(0xFFA78BFA)  // violeta — métrica RMSSD (HRV)
Colors.white            // BPM number, texto principal
Colors.white54          // labels secundarios (BPM caption)
Colors.white.withOpacity(0.7)   // texto sobre el gradiente oscuro
Colors.white.withOpacity(0.4)   // micro-labels (R-R, RMSSD)
```

### Header de frecuencia cardíaca en vivo
```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF0B1220), Color(0xFF1A2B4B)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(PhosphorIcons.heartbeat(), color: Color(0xFFEF4444), size: 20),
        SizedBox(width: 8),
        Text('Frecuencia cardíaca', style: TextStyle(
            color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600)),
        Spacer(),
        // Badge BLE si hay conexión directa al sensor
        if (hrSource == 'ble')
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Color(0xFF059669).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8)),
            child: Text('BLE', style: TextStyle(color: Color(0xFF059669),
                fontSize: 10, fontWeight: FontWeight.w800)),
          ),
      ]),
      SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$currentBpm', style: TextStyle(color: Colors.white,
            fontSize: 52, fontWeight: FontWeight.w800, height: 1)),
        Padding(padding: EdgeInsets.only(bottom: 8, left: 6),
          child: Text('BPM', style: TextStyle(color: Colors.white54,
              fontSize: 14, fontWeight: FontWeight.w600))),
        Spacer(),
        // Columna R-R (cyan) + RMSSD (violeta) — métricas HRV en vivo
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$lastRrMs ms', style: TextStyle(
              color: Color(0xFF00F0FF).withOpacity(0.9),
              fontSize: 16, fontWeight: FontWeight.w700)),
          Text('R-R', style: TextStyle(color: Colors.white.withOpacity(0.4),
              fontSize: 10, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('$currentRmssd', style: TextStyle(
              color: Color(0xFFA78BFA).withOpacity(0.9),
              fontSize: 16, fontWeight: FontWeight.w700)),
          Text('RMSSD', style: TextStyle(color: Colors.white.withOpacity(0.4),
              fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ]),
      SizedBox(height: 14),
      // Gráfica HR en vivo — CustomPaint con stroke Color(0xFF00F0FF)
      // y glow mediante segundo Paint con .withOpacity(0.15) + mayor strokeWidth
      SizedBox(height: 64, child: CustomPaint(painter: _HrGraphPainter(liveGraph))),
    ],
  ),
)
```

### Estados de zona/resultado (chips de la sesión)
```dart
// Completado
Color(0xFFD1FAE5) fondo, Color(0xFF059669) texto

// Estados de set (completado/en curso/pendiente) — Row de chips
completado:  bg=Color(0xFF059669), fg=Colors.white
en_curso:    bg=Color(0xFFFEF3C7), fg=Color(0xFF92400E)
pendiente:   bg=Color(0xFFF3F4F6), fg=Color(0xFF9CA3AF)
```

### Cuándo usar este sistema vs el sistema claro
- Workout Session / Focus Mode activo (serie en curso, HR en vivo) → paleta dark fija de arriba
- Cualquier otra pantalla (dashboard, coach, nutrición, clínica) → `DesignTokens` brightness-aware
- No traduzcas el cyan/violeta de Focus Mode al gradiente AI — son paletas deliberadamente distintas

---

## Reglas invariables

1. NUNCA uses colores hex directamente — siempre `DesignTokens.xxx(b)` o constantes del proyecto
   (excepción: la paleta fija de Focus Mode arriba, que es intencionalmente independiente)
2. SIEMPRE adapta al brightness con `final b = Theme.of(context).brightness`
3. El gradiente AI es el único acento de color — no uses azules, verdes, ni rojos como acento primario
4. `BorderRadius.circular(DesignTokens.cardRadius)` en todos los contenedores principales
5. Padding interno de cards: `EdgeInsets.all(20)` o `EdgeInsets.all(16)` — nunca menos
6. Labels/eyebrows: SIEMPRE uppercase, `fontSize: 11`, `letterSpacing: 1.4`, `mutedFg`
7. Títulos: `FontWeight.w800` + `letterSpacing: -0.5`
8. Iconos: `lucide_icons` por defecto, `size: 16-20` en contenedores, `size: 22` en nav
9. Fuentes: `GoogleFonts.outfit` solo para display/títulos — body usa `GoogleFonts.manrope`
10. Animaciones solo en: indicadores live (AiPulseEffect/AiRingEffect), estados de carga, voz activa
11. Los `StatPill` y `MacroBox` usan `surface1`, no `card`
12. Bottom nav siempre dentro de `GlassCard` con `radius: DesignTokens.cardRadius`