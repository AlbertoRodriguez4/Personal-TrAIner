import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/supplement_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../models/supplement.dart';

/// Lista de suplementos del día con toggle, alta inline y borrado.
class SupplementsCard extends StatefulWidget {
  const SupplementsCard({super.key});

  @override
  State<SupplementsCard> createState() => _SupplementsCardState();
}

class _SupplementsCardState extends State<SupplementsCard> {
  bool _adding = false;
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  void _submit(SupplementProvider intake) {
    if (_nameController.text.trim().isEmpty) return;
    intake.addSupplement(_nameController.text, _doseController.text);
    _nameController.clear();
    _doseController.clear();
    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final intake = context.watch<SupplementProvider>();
    final items = intake.supplements;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SUPLEMENTOS DE HOY',
                        style: DesignTokens.labelSmall(
                            color: DesignTokens.mutedForeground(b))),
                    const SizedBox(height: 4),
                    Text(
                      items.isEmpty
                          ? 'Sin suplementos'
                          : '${intake.supplementsTaken}/${items.length} tomados',
                      style: DesignTokens.titleFont(
                          fontSize: 20, color: DesignTokens.foreground(b)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradientSoft,
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                ),
                child: Icon(LucideIcons.pill,
                    size: 18, color: DesignTokens.foreground(b)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aún no has añadido suplementos.',
                  style: DesignTokens.bodyFont(
                      fontSize: 13,
                      color: DesignTokens.mutedForeground(b))),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _SupplementRow(
                supplement: items[i],
                onToggle: () => intake.toggleSupplement(items[i].id),
                onRemove: () => intake.removeSupplement(items[i].id),
              ),
            ],
          const SizedBox(height: 14),
          if (_adding)
            _AddForm(
              nameController: _nameController,
              doseController: _doseController,
              onSave: () => _submit(intake),
              onCancel: () => setState(() => _adding = false),
            )
          else
            Material(
              color: DesignTokens.surface1(b),
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              child: InkWell(
                onTap: () => setState(() => _adding = true),
                borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.plus,
                          size: 16, color: DesignTokens.foreground(b)),
                      const SizedBox(width: 6),
                      Text('Añadir suplemento',
                          style: DesignTokens.bodyFont(
                              fontSize: 13.5,
                              weight: FontWeight.w600,
                              color: DesignTokens.foreground(b))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupplementRow extends StatelessWidget {
  const _SupplementRow({
    required this.supplement,
    required this.onToggle,
    required this.onRemove,
  });

  final Supplement supplement;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final taken = supplement.taken;

    return Row(
      children: [
        Semantics(
          checked: taken,
          label: supplement.name,
          child: InkWell(
            onTap: onToggle,
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: taken ? DesignTokens.aiGradient : null,
                color: taken ? null : DesignTokens.card(b),
                border: taken
                    ? null
                    : Border.all(color: DesignTokens.border(b)),
              ),
              child: Icon(
                LucideIcons.check,
                size: 15,
                color: taken
                    ? Colors.white
                    : DesignTokens.mutedForeground(b).withOpacity(0.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                supplement.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTokens.bodyFont(
                  fontSize: 13.5,
                  weight: FontWeight.w600,
                  color: taken
                      ? DesignTokens.mutedForeground(b)
                      : DesignTokens.foreground(b),
                ).copyWith(
                  decoration: taken ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(supplement.dose,
                  style: DesignTokens.bodyFont(
                      fontSize: 11.5,
                      color: DesignTokens.mutedForeground(b))),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Quitar ${supplement.name}',
          onPressed: onRemove,
          icon: Icon(LucideIcons.x,
              size: 15, color: DesignTokens.mutedForeground(b)),
        ),
      ],
    );
  }
}

class _AddForm extends StatelessWidget {
  const _AddForm({
    required this.nameController,
    required this.doseController,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController nameController;
  final TextEditingController doseController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      children: [
        TextField(
          controller: nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'Nombre (ej. Creatina)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: doseController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSave(),
          decoration: const InputDecoration(hintText: 'Dosis (ej. 5 g)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onSave,
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: DesignTokens.aiGradient,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radius2xl),
                    ),
                    child: Center(
                      child: Text('Guardar',
                          style: DesignTokens.bodyFont(
                              fontSize: 14,
                              weight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Solo el nombre es obligatorio.',
              style: DesignTokens.bodyFont(
                  fontSize: 11, color: DesignTokens.mutedForeground(b))),
        ),
      ],
    );
  }
}

/// Versión compacta para el dashboard: conteo, los dos primeros del día, y un
/// acceso a la pantalla de Nutrición donde se gestionan.
class SupplementsMiniCard extends StatelessWidget {
  const SupplementsMiniCard({super.key, this.onManage});
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final intake = context.watch<SupplementProvider>();
    final items = intake.supplements;

    return Material(
      color: DesignTokens.card(b),
      borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
      child: InkWell(
        onTap: onManage,
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
            boxShadow: DesignTokens.shadowSoft(b),
            color: DesignTokens.card(b),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('SUPLEMENTOS',
                        overflow: TextOverflow.ellipsis,
                        style: DesignTokens.labelSmall(
                            color: DesignTokens.mutedForeground(b))),
                  ),
                  Icon(LucideIcons.pill,
                      size: 15,
                      color: DesignTokens.foreground(b).withOpacity(0.7)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${intake.supplementsTaken}',
                      style: DesignTokens.titleFont(
                          fontSize: 20, color: DesignTokens.foreground(b))),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text('/ ${items.length} hoy',
                        overflow: TextOverflow.ellipsis,
                        style: DesignTokens.bodyFont(
                            fontSize: 11,
                            color: DesignTokens.mutedForeground(b))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final s in items.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${s.taken ? '✓' : '·'} ${s.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignTokens.bodyFont(
                        fontSize: 11,
                        color: DesignTokens.mutedForeground(b)),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        DesignTokens.aiGradient.createShader(bounds),
                    child: Text('Gestionar',
                        style: DesignTokens.bodyFont(
                            fontSize: 11.5,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  Icon(LucideIcons.chevronRight,
                      size: 13, color: DesignTokens.mutedForeground(b)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
