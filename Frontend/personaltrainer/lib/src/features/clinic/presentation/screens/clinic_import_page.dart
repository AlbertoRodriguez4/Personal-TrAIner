import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';

/// Importador de analítica clínica — réplica de `clinic.import.tsx`.
///
/// 3 modos:
///  - `pdf`   → `file_picker` (PDF / DICOM).
///  - `image` → `image_picker` (foto de la analítica).
///  - `manual`→ formulario de 8 biomarcadores.
class ClinicImportPage extends StatefulWidget {
  const ClinicImportPage({
    super.key,
    this.onBack,
    this.onAnalyze,
    this.onManualSave,
  });

  final VoidCallback? onBack;
  // TODO: conectar a POST /clinical-data/import (NestJS) — subida de archivo + COLMENA IA.
  final void Function(File file, ClinicImportMode mode)? onAnalyze;
  // TODO: conectar a POST /clinical-data/manual (NestJS) — valores manuales.
  final void Function(Map<String, String> values)? onManualSave;

  @override
  State<ClinicImportPage> createState() => _ClinicImportPageState();
}

enum ClinicImportMode { menu, pdf, image, manual }

class _ClinicImportPageState extends State<ClinicImportPage> {
  ClinicImportMode _mode = ClinicImportMode.menu;
  File? _file;

  void _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'dcm', 'dicom'],
    );
    if (res != null && res.files.single.path != null) {
      setState(() => _file = File(res.files.single.path!));
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.camera);
    if (x != null) setState(() => _file = File(x.path));
  }

  void _pickImageGallery() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _file = File(x.path));
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: DesignTokens.surface2of(b),
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                onBack: _mode == ClinicImportMode.menu
                    ? (widget.onBack ?? () => Navigator.maybePop(context))
                    : () => setState(() { _mode = ClinicImportMode.menu; _file = null; }),
              ),
              Expanded(
                child: ColoredBox(
                  color: DesignTokens.background(b),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: switch (_mode) {
                      ClinicImportMode.menu => _Menu(onPick: (m) => setState(() { _mode = m; _file = null; })),
                      ClinicImportMode.pdf => _FileDrop(
                          icon: LucideIcons.fileText,
                          title: 'Subir PDF',
                          hint: 'Informe médico, analítica o DICOM',
                          onPick: _pickPdf,
                          file: _file,
                          ctaLabel: 'Elegir archivo',
                          onAnalyze: (f) => widget.onAnalyze?.call(f, ClinicImportMode.pdf),
                        ),
                      ClinicImportMode.image => _FileDrop(
                          icon: LucideIcons.image,
                          title: 'Subir imagen',
                          hint: 'Foto de la analítica o gráfica',
                          onPickCapture: _pickImage,
                          onPickGallery: _pickImageGallery,
                          file: _file,
                          ctaLabel: 'Tomar / elegir',
                          onAnalyze: (f) => widget.onAnalyze?.call(f, ClinicImportMode.image),
                        ),
                      ClinicImportMode.manual => _ManualForm(onSave: widget.onManualSave),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── Header ─────────────────────── */

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: DesignTokens.background(b).withOpacity(0.7),
        border: Border(bottom: BorderSide(color: DesignTokens.border(b))),
      ),
      child: Row(
        children: [
          _RoundIconButton(icon: LucideIcons.arrowLeft, fillColor: DesignTokens.surface2of(b), onTap: onBack),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CLÍNICA',
                  style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b), fontSize: 11)),
              Text('Importar analítica',
                  style: DesignTokens.titleFont(fontSize: 17, color: DesignTokens.foreground(b), weight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Menu ─────────────────────── */

class _Menu extends StatelessWidget {
  const _Menu({required this.onPick});
  final void Function(ClinicImportMode) onPick;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final opts = [
      (ClinicImportMode.pdf, LucideIcons.fileText, 'Subir PDF', 'Informe médico, analítica, DICOM'),
      (ClinicImportMode.image, LucideIcons.image, 'Subir imagen', 'Foto de la analítica'),
      (ClinicImportMode.manual, LucideIcons.keyboard, 'Introducir a mano', 'Valores clave: colesterol, glucosa…'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Elige cómo quieres añadir tus datos clínicos.',
            style: DesignTokens.bodyFont(fontSize: 13, color: DesignTokens.mutedForeground(b))),
        const SizedBox(height: 16),
        for (final o in opts) ...[
          _MenuOption(icon: o.$2, title: o.$3, sub: o.$4, onTap: () => onPick(o.$1)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(24),
          boxShadow: DesignTokens.shadowSoft(b),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: DesignTokens.aiGradientSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 20, color: DesignTokens.foreground(b)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DesignTokens.titleFont(fontSize: 15, color: DesignTokens.foreground(b), weight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(sub, style: DesignTokens.bodyFont(fontSize: 12, color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: DesignTokens.mutedForeground(b)),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── File drop ─────────────────────── */

class _FileDrop extends StatelessWidget {
  const _FileDrop({
    required this.icon,
    required this.title,
    required this.hint,
    required this.file,
    required this.onAnalyze,
    this.onPick,
    this.onPickCapture,
    this.onPickGallery,
    this.ctaLabel = 'Elegir archivo',
  });
  final IconData icon;
  final String title, hint, ctaLabel;
  final File? file;
  final VoidCallback? onPick, onPickCapture, onPickGallery;
  final void Function(File) onAnalyze;

  void _onTap() {
    if (onPickCapture != null && onPickGallery != null) {
      // Prefer camera if available; fall back to gallery handled by caller separately.
      onPickCapture!();
    } else if (onPick != null) {
      onPick!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _onTap,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
              border: Border.all(color: DesignTokens.border(b), width: 2, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: DesignTokens.aiGradientSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 24, color: DesignTokens.foreground(b)),
                ),
                const SizedBox(height: 12),
                Text(title, style: DesignTokens.titleFont(fontSize: 16, color: DesignTokens.foreground(b), weight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(hint, style: DesignTokens.bodyFont(fontSize: 12, color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: DesignTokens.foreground(b),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.upload, size: 14, color: DesignTokens.background(b)),
                      const SizedBox(width: 8),
                      Text(ctaLabel, style: DesignTokens.bodyFont(fontSize: 12, weight: FontWeight.w600, color: DesignTokens.background(b))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (file != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              boxShadow: DesignTokens.shadowSoft(b),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Archivo seleccionado'.toUpperCase(),
                    style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 4),
                Text(file!.uri.pathSegments.last,
                    style: DesignTokens.bodyFont(fontSize: 14, weight: FontWeight.w600, color: DesignTokens.foreground(b)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${(file!.lengthSync() / 1024).round()} KB',
                    style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => onAnalyze(file!),
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: DesignTokens.aiGradient,
                      borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                      boxShadow: DesignTokens.shadowCard(b),
                    ),
                    child: Text('Analizar con IA',
                        style: DesignTokens.bodyFont(fontSize: 14, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/* ─────────────────────── Manual form ─────────────────────── */

class _ManualFields {
  static const data = [
    ('chol', 'Colesterol total', 'mg/dL', '190'),
    ('hdl', 'HDL', 'mg/dL', '55'),
    ('ldl', 'LDL', 'mg/dL', '110'),
    ('trig', 'Triglicéridos', 'mg/dL', '120'),
    ('glu', 'Glucosa', 'mg/dL', '92'),
    ('hba1c', 'HbA1c', '%', '5.3'),
    ('vitd', 'Vitamina D', 'ng/mL', '32'),
    ('fer', 'Ferritina', 'ng/mL', '80'),
  ];
}

class _ManualForm extends StatefulWidget {
  const _ManualForm({this.onSave});
  final void Function(Map<String, String>)? onSave;
  @override
  State<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<_ManualForm> {
  final _ctrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final f in _ManualFields.data) {
      _ctrls[f.$1] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = {for (final e in _ctrls.entries) e.key: e.value.text.trim()};
    widget.onSave?.call(values);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignTokens.card(b),
            borderRadius: BorderRadius.circular(24),
            boxShadow: DesignTokens.shadowSoft(b),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Valores clave'.toUpperCase(),
                  style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 5.5,
                children: [
                  for (final f in _ManualFields.data)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$2, style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: DesignTokens.surface1(b),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.border(b)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ctrls[f.$1],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: DesignTokens.bodyFont(fontSize: 14, weight: FontWeight.w600, color: DesignTokens.foreground(b)),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    hintText: f.$3.isEmpty ? '' : f.$4,
                                    hintStyle: DesignTokens.bodyFont(fontSize: 14, color: DesignTokens.mutedForeground(b).withOpacity(0.6)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(f.$3, style: DesignTokens.bodyFont(fontSize: 10, color: DesignTokens.mutedForeground(b))),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _submit,
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: DesignTokens.aiGradient,
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              boxShadow: DesignTokens.shadowCard(b),
            ),
            child: Text('Guardar y analizar',
                style: DesignTokens.titleFont(fontSize: 15, color: Colors.white, weight: FontWeight.w600, letterSpacing: 0)),
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────── Shared ─────────────────────── */

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap, this.fillColor});
  final IconData icon;
  final VoidCallback? onTap;
  final Color? fillColor;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor ?? DesignTokens.surface1(b),
          border: Border.all(color: DesignTokens.border(b)),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: DesignTokens.foreground(b)),
      ),
    );
  }
}