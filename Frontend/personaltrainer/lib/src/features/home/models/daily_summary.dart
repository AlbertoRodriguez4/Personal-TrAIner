class MacroCumplimiento {
  final double objetivo;
  final double consumido;
  final double porcentaje;
  final bool cumplido;

  const MacroCumplimiento({
    required this.objetivo,
    required this.consumido,
    required this.porcentaje,
    required this.cumplido,
  });

  factory MacroCumplimiento.fromJson(Map<String, dynamic> j) => MacroCumplimiento(
        objetivo: (j['objetivo'] as num?)?.toDouble() ?? 0,
        consumido: (j['consumido'] as num?)?.toDouble() ?? 0,
        porcentaje: (j['porcentaje'] as num?)?.toDouble() ?? 0,
        cumplido: j['cumplido'] as bool? ?? false,
      );
}

class MacrosBloque {
  final double kcal;
  final double proteinasG;
  final double carbohidratosG;
  final double grasasG;

  const MacrosBloque({
    required this.kcal,
    required this.proteinasG,
    required this.carbohidratosG,
    required this.grasasG,
  });

  factory MacrosBloque.fromJson(Map<String, dynamic> j) => MacrosBloque(
        kcal: (j['kcal'] as num?)?.toDouble() ?? 0,
        proteinasG: (j['proteinas_g'] as num?)?.toDouble() ?? 0,
        carbohidratosG: (j['carbohidratos_g'] as num?)?.toDouble() ?? 0,
        grasasG: (j['grasas_g'] as num?)?.toDouble() ?? 0,
      );
}

class UltimaSesion {
  final String id;
  final DateTime fechaProgramada;
  final String tipoEntrenamiento;
  final String estado;
  final DateTime? fechaFinalizacion;

  const UltimaSesion({
    required this.id,
    required this.fechaProgramada,
    required this.tipoEntrenamiento,
    required this.estado,
    required this.fechaFinalizacion,
  });

  factory UltimaSesion.fromJson(Map<String, dynamic> j) => UltimaSesion(
        id: j['id']?.toString() ?? '',
        fechaProgramada: DateTime.tryParse(j['fecha_programada']?.toString() ?? '') ?? DateTime.now(),
        tipoEntrenamiento: j['tipo_entrenamiento']?.toString() ?? '',
        estado: j['estado']?.toString() ?? '',
        fechaFinalizacion: j['fecha_finalizacion'] == null
            ? null
            : DateTime.tryParse(j['fecha_finalizacion'].toString()),
      );
}

class DailySummary {
  final String usuarioId;
  final String fecha;
  final MacrosBloque objetivos;
  final MacrosBloque consumidoHoy;
  final MacroCumplimiento cumplKcal;
  final MacroCumplimiento cumplProt;
  final MacroCumplimiento cumplCarbos;
  final MacroCumplimiento cumplGrasas;
  final bool objetivosCumplidos;
  final UltimaSesion? ultimaSesion;
  final int rutinasCount;
  final bool metasCalculadas;

  const DailySummary({
    required this.usuarioId,
    required this.fecha,
    required this.objetivos,
    required this.consumidoHoy,
    required this.cumplKcal,
    required this.cumplProt,
    required this.cumplCarbos,
    required this.cumplGrasas,
    required this.objetivosCumplidos,
    required this.ultimaSesion,
    required this.rutinasCount,
    required this.metasCalculadas,
  });

  factory DailySummary.fromJson(Map<String, dynamic> j) {
    final c = j['cumplimiento'] as Map<String, dynamic>? ?? {};
    return DailySummary(
      usuarioId: j['usuario_id']?.toString() ?? '',
      fecha: j['fecha']?.toString() ?? '',
      objetivos: MacrosBloque.fromJson(j['objetivos'] as Map<String, dynamic>? ?? {}),
      consumidoHoy: MacrosBloque.fromJson(j['consumido_hoy'] as Map<String, dynamic>? ?? {}),
      cumplKcal: MacroCumplimiento.fromJson(c['kcal'] as Map<String, dynamic>? ?? {}),
      cumplProt: MacroCumplimiento.fromJson(c['proteinas_g'] as Map<String, dynamic>? ?? {}),
      cumplCarbos: MacroCumplimiento.fromJson(c['carbohidratos_g'] as Map<String, dynamic>? ?? {}),
      cumplGrasas: MacroCumplimiento.fromJson(c['grasas_g'] as Map<String, dynamic>? ?? {}),
      objetivosCumplidos: j['objetivos_cumplidos'] as bool? ?? false,
      ultimaSesion: j['ultima_sesion'] == null
          ? null
          : UltimaSesion.fromJson(j['ultima_sesion'] as Map<String, dynamic>),
      rutinasCount: (j['rutinas_count'] as num?)?.toInt() ?? 0,
      metasCalculadas: j['metas_calculadas_automaticamente'] as bool? ?? true,
    );
  }
}