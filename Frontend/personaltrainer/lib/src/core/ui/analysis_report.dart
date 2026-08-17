import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/design_tokens.dart';

/// Piezas compartidas por las dos pantallas que muestran un informe de la IA
/// (Clínica y Físico): las dos renderizan el mismo tipo de respuesta — bloques
/// con título, párrafos, viñetas, fuentes citadas — y mantenerlas separadas
/// garantizaba que se separasen también visualmente.

class ReportBlock extends StatelessWidget {
  const ReportBlock({
    super.key,
    required this.title,
    required this.child,
    this.accent,
  });

  final String title;
  final Widget child;

  /// Tiñe título y borde. Se usa para los bloques que piden atención
  /// (banderas rojas), no como decoración.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(20),
        boxShadow: DesignTokens.shadowSoft(b),
        border: accent == null
            ? null
            : Border.all(color: accent!.withOpacity(0.45), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DesignTokens.labelSmall(
              color: accent ?? DesignTokens.mutedForeground(b),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class ReportParagraph extends StatelessWidget {
  const ReportParagraph(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Text(
      stripMarkdown(text),
      style: DesignTokens.bodyFont(
        fontSize: 13,
        height: 1.45,
        color: DesignTokens.foreground(b),
      ),
    );
  }
}

class ReportBullet extends StatelessWidget {
  const ReportBullet(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color ?? DesignTokens.mutedForeground(b),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              stripMarkdown(text),
              style: DesignTokens.bodyFont(
                fontSize: 12.5,
                height: 1.4,
                color: DesignTokens.foreground(b),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de fuentes citadas, deduplicada. Un mismo organismo puede respaldar
/// varios marcadores; al usuario le interesa la lista de referencias, no el
/// cruce completo.
class ReportSources extends StatelessWidget {
  const ReportSources({super.key, required this.sources});
  final List<Map<String, dynamic>> sources;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final nombres = <String>{for (final f in sources) reportText(f['fuente'])}
      ..removeWhere((s) => s.isEmpty);
    if (nombres.isEmpty) return const SizedBox.shrink();

    return ReportBlock(
      title: 'FUENTES CONSULTADAS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in nombres)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $n',
                style: DesignTokens.bodyFont(
                  fontSize: 11.5,
                  color: DesignTokens.mutedForeground(b),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: DesignTokens.aiGradient,
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
            boxShadow: DesignTokens.shadowCard(b),
          ),
          child: Text(
            label,
            style: DesignTokens.bodyFont(
              fontSize: 14,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final color = DesignTokens.destructive(b);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertCircle, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: DesignTokens.bodyFont(
                fontSize: 12.5,
                color: DesignTokens.foreground(b),
              ),
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.x, size: 15, color: color),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de espera de un análisis. Los dos pipelines tardan decenas de
/// segundos (dos pasadas al modelo más consultas externas), así que el texto
/// explica qué está pasando en vez de dejar un spinner mudo.
class AnalyzingView extends StatelessWidget {
  const AnalyzingView({super.key, required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: DesignTokens.titleFont(
              fontSize: 16,
              color: DesignTokens.foreground(b),
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: DesignTokens.bodyFont(
                fontSize: 12.5,
                color: DesignTokens.mutedForeground(b),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: DesignTokens.mutedForeground(b)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DesignTokens.titleFont(
                fontSize: 15,
                color: DesignTokens.foreground(b),
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: DesignTokens.bodyFont(
                fontSize: 12.5,
                color: DesignTokens.mutedForeground(b),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── Helpers de lectura del JSON ─────────────────────── */

String reportText(dynamic v) => v == null ? '' : v.toString();

/// Postgres devuelve las columnas `numeric` como string ("18.0000"), así que
/// no se puede asumir `num` aunque el campo lo sea en la entidad.
String reportNumber(dynamic v) {
  final n = v is num ? v : double.tryParse(reportText(v));
  if (n == null) return reportText(v);
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();
}

List<String> reportList(dynamic v) {
  if (v is List) return v.map(reportText).where((s) => s.isNotEmpty).toList();
  // Red por si un `simple-array` de TypeORM llega sin deserializar (CSV).
  if (v is String && v.trim().isNotEmpty) {
    return v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

List<Map<String, dynamic>> reportMaps(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

/// Las respuestas de la IA vienen en Markdown ligero. En vez de arrastrar un
/// renderizador entero solo por esto, se quitan los marcadores: el texto ya
/// está escrito en frases cortas.
String stripMarkdown(String text) => text
    .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!)
    .replaceAll(RegExp(r'^#{1,4}\s*', multiLine: true), '')
    .trim();

String shortDate(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

String readableDate(dynamic iso) {
  final parsed = DateTime.tryParse(reportText(iso));
  // `.toLocal()` no es cosmético: una columna `date` con 2026-06-12 sale
  // serializada como "2026-06-11T22:00:00.000Z" (medianoche local de Madrid en
  // UTC), y `.day` sobre un DateTime en UTC devolvería 11 — un día menos que el
  // que pone el informe del usuario.
  return parsed == null ? '—' : shortDate(parsed.toLocal());
}

/// Mensaje de error listo para enseñar. El timeout es el caso frecuente y el
/// texto crudo de la excepción no le dice nada al usuario.
String analysisErrorMessage(Object e) {
  final texto = e.toString().replaceFirst('Exception: ', '');
  if (texto.contains('TimeoutException')) {
    return 'El análisis está tardando más de lo normal. Vuelve a intentarlo en un momento.';
  }
  return texto;
}
