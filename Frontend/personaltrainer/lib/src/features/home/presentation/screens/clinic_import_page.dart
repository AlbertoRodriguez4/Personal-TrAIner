import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/ai_gradient_text.dart';

class ClinicImportPage extends StatefulWidget {
  const ClinicImportPage({super.key});

  @override
  State<ClinicImportPage> createState() => _ClinicImportPageState();
}

class _ClinicImportPageState extends State<ClinicImportPage> {
  bool _isUploading = false;
  bool _isSuccess = false;

  void _simulateUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'dcm'],
    );

    if (result == null) return; // User canceled

    setState(() {
      _isUploading = true;
      _isSuccess = false;
    });

    // Simulate network delay for uploading and processing
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _isSuccess = true;
    });

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Análisis completado: Se han extraído 24 métricas.'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final card = DesignTokens.card(b);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: AiGradientText(
          'CLÍNICA',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Importar Archivo Médico',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Sube tus analíticas de sangre o escaneos DEXA (DICOM). El modelo de IA extraerá los biomarcadores automáticamente.',
                style: TextStyle(fontSize: 15, color: mutedFg, height: 1.5),
              ),
              const SizedBox(height: 32),
              
              // Upload Area
              GestureDetector(
                onTap: _isUploading ? null : _simulateUpload,
                child: Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: DesignTokens.surface1(b),
                    borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
                    border: Border.all(
                      color: _isSuccess ? const Color(0xFF10B981) : DesignTokens.aiVia.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: _isUploading
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: DesignTokens.aiVia),
                              SizedBox(height: 16),
                              Text(
                                'Procesando con IA...',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isSuccess ? const Color(0xFFD1FAE5) : DesignTokens.aiVia.withOpacity(0.1),
                                ),
                                child: Icon(
                                  _isSuccess ? LucideIcons.checkCircle2 : LucideIcons.uploadCloud,
                                  size: 32,
                                  color: _isSuccess ? const Color(0xFF10B981) : DesignTokens.aiVia,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isSuccess ? 'Archivo subido con éxito' : 'Toca para subir archivo',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PDF, JPG, PNG o DICOM',
                                style: TextStyle(fontSize: 13, color: mutedFg),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              if (_isSuccess) ...[
                Text(
                  'RESULTADOS EXTRAÍDOS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: mutedFg),
                ),
                const SizedBox(height: 16),
                _ResultCard(
                  title: 'Composición Corporal',
                  icon: LucideIcons.activity,
                  value: 'DEXA Detectado',
                  b: b,
                ),
                const SizedBox(height: 12),
                _ResultCard(
                  title: 'Grasa Visceral',
                  icon: LucideIcons.flame,
                  value: 'Reducción del 12%',
                  isGood: true,
                  b: b,
                ),
                const SizedBox(height: 12),
                _ResultCard(
                  title: 'Masa Magra',
                  icon: LucideIcons.dumbbell,
                  value: '+1.2 kg',
                  isGood: true,
                  b: b,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.b,
    this.isGood = false,
  });

  final String title;
  final IconData icon;
  final String value;
  final Brightness b;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final fg = DesignTokens.foreground(b);
    final card = DesignTokens.card(b);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGood ? const Color(0xFFECFDF5) : DesignTokens.surface1(b),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: isGood ? const Color(0xFF059669) : fg.withOpacity(0.7)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isGood ? const Color(0xFF059669) : fg,
            ),
          ),
        ],
      ),
    );
  }
}
