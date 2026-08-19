import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/analysis_report.dart';
import '../../../../core/ui/round_icon_button.dart';
import '../../../../services/api_service.dart';
import '../../../../services/notification_service.dart';
import '../widgets/profile_fields.dart';

/// Configurador de perfil. Se entra tocando la foto de perfil en Inicio.
///
/// Es el único sitio donde se edita todo lo que Pulso sabe del usuario y que no
/// sale de una medición: identidad, perfil deportivo y metas de macros. Lo que
/// sí sale de una medición —la composición corporal— se enseña **solo lectura**
/// con un enlace a Clínica: duplicar aquí el formulario de registrar una
/// medición daría dos sitios donde crear la misma fila y dos historiales que
/// no cuadran.
///
/// El bloque de progreso no es decorativo: sale de `GET /ai-context/:userId`,
/// el mismo `completitud` que decide si la IA puede personalizar o tiene que
/// pedir datos. Así lo que ve el usuario aquí es literalmente lo que le falta
/// al coach, no una lista paralela que se desincroniza.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, this.onBack, this.onLogout});

  final VoidCallback? onBack;
  final Future<void> Function(BuildContext)? onLogout;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String? _aviso;

  // Identidad
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _altura = TextEditingController();
  final _peso = TextEditingController();
  DateTime? _fechaNacimiento;

  // Perfil deportivo
  String? _sexo;
  String? _nivel;
  String? _intensidad;
  int _dias = 4;
  final Set<String> _objetivos = {};
  final Set<String> _actividades = {};
  String? _tipoCuerpo;
  final _fcReposo = TextEditingController();
  double _horasSueno = 7;
  final _condiciones = TextEditingController();
  final _notas = TextEditingController();

  // Metas
  final _kcal = TextEditingController();
  final _proteinas = TextEditingController();
  final _carbohidratos = TextEditingController();
  final _grasas = TextEditingController();

  // Notificaciones (preferencia del dispositivo, no del perfil)
  NotificationPreferences _notis = const NotificationPreferences();

  /// Días (1=lunes … 7=domingo) en los que la rutina activa tiene sesión, para
  /// que el recordatorio de entrenar no suene los días de descanso.
  List<int> _diasRutina = const [];

  // Solo lectura
  Map<String, dynamic>? _composicion;
  List<String> _recomendadosPendientes = const [];
  bool _tieneMinimos = false;

  String? get _userId => ApiService.getCurrentUserId();

  /// Los seis recomendados, en el mismo orden que los devuelve el backend. La
  /// clave es el texto exacto de `completitud.recomendados`: si allí cambia una
  /// cadena, aquí deja de marcarse y hay que actualizarlo en los dos sitios.
  static const _recomendados = <({String clave, String etiqueta})>[
    (
      clave: 'composición corporal (% de grasa, masa muscular…)',
      etiqueta: 'Composición corporal'
    ),
    (clave: 'sexo', etiqueta: 'Sexo'),
    (clave: 'fecha de nacimiento', etiqueta: 'Fecha de nacimiento'),
    (clave: 'nivel de experiencia', etiqueta: 'Nivel de experiencia'),
    (clave: 'análisis del físico con fotos', etiqueta: 'Análisis de físico con fotos'),
    (clave: 'analítica de sangre', etiqueta: 'Analítica de sangre'),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _email,
      _altura,
      _peso,
      _fcReposo,
      _condiciones,
      _notas,
      _kcal,
      _proteinas,
      _carbohidratos,
      _grasas,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _cargar() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _cargando = false;
        _error = 'No hay sesión activa.';
      });
      return;
    }

    try {
      // Las tres a la vez: el perfil y el contexto son endpoints distintos y en
      // serie la pantalla tarda el doble en dejar de parpadear.
      final resultados = await Future.wait([
        ApiService.getUserProfile(userId),
        ApiService.getAiContext(userId),
        ApiService.getLatestBodyComposition(userId),
      ]);
      if (!mounted) return;

      final perfil = resultados[0];
      final contexto = resultados[1] ?? const <String, dynamic>{};
      final composicion = resultados[2];

      final completitud =
          (contexto['completitud'] as Map?)?.cast<String, dynamic>() ?? {};
      final notis = await NotificationService.cargarPreferencias();
      final diasRutina = await _cargarDiasRutina(userId);
      if (!mounted) return;

      setState(() {
        _nombre.text = ApiService.getCurrentUserName() ?? '';
        _email.text = ApiService.getCurrentUserEmail() ?? '';
        _altura.text = _textoNumero(ApiService.getCurrentUserHeight());
        _peso.text = _textoNumero(ApiService.getCurrentUserWeight());
        _fechaNacimiento =
            DateTime.tryParse(ApiService.getCurrentUserBirthDate() ?? '');

        if (perfil != null) {
          _sexo = reportText(perfil['sexo']).isEmpty ? null : perfil['sexo'];
          _nivel = reportText(perfil['nivel_experiencia']).isEmpty
              ? null
              : perfil['nivel_experiencia'];
          _intensidad = reportText(perfil['intensidad']).isEmpty
              ? null
              : perfil['intensidad'];
          _dias = (perfil['dias_entrenamiento_semana'] as num?)?.toInt() ?? 4;
          _objetivos
            ..clear()
            ..addAll(reportList(perfil['objetivos']));
          _actividades
            ..clear()
            ..addAll(reportList(perfil['actividades']));
          _tipoCuerpo = reportText(perfil['tipo_cuerpo']).isEmpty
              ? null
              : perfil['tipo_cuerpo'];
          _fcReposo.text = _textoNumero(perfil['fc_reposo']);
          _horasSueno =
              double.tryParse(reportText(perfil['horas_sueno_habitual'])) ?? 7;
          _condiciones.text = reportText(perfil['condiciones_medicas']);
          _notas.text = reportText(perfil['notas_adicionales']);
          _kcal.text = _textoNumero(perfil['meta_kcal']);
          _proteinas.text = _textoNumero(perfil['meta_proteinas_g']);
          _carbohidratos.text = _textoNumero(perfil['meta_carbohidratos_g']);
          _grasas.text = _textoNumero(perfil['meta_grasas_g']);
        }

        _composicion = composicion;
        _notis = notis;
        _diasRutina = diasRutina;
        _recomendadosPendientes = reportList(completitud['recomendados']);
        _tieneMinimos = completitud['tiene_minimos'] == true;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = analysisErrorMessage(e);
      });
    }
  }

  String _textoNumero(dynamic valor) {
    if (valor == null) return '';
    final n = valor is num ? valor : double.tryParse(valor.toString());
    if (n == null) return '';
    return n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toString();
  }

  Future<void> _guardar() async {
    final userId = _userId;
    if (userId == null) return;

    final altura = _num(_altura.text);
    final peso = _num(_peso.text);
    if (altura == null || peso == null) {
      setState(() => _error =
          'La altura y el peso de referencia son obligatorios: sin ellos no se '
          'puede calcular ni una caloría.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
      _aviso = null;
    });

    try {
      await ApiService.updateUser(userId, {
        'nombre_completo': _nombre.text.trim(),
        if (_fechaNacimiento != null)
          'fecha_nacimiento':
              _fechaNacimiento!.toIso8601String().substring(0, 10),
        'estatura_base_cm': altura,
        'peso_base_kg': peso,
      });

      // `createUserProfile` hace upsert en el backend, así que sirve tanto para
      // el perfil que ya existe como para el que aún no.
      await ApiService.createUserProfile(
        userId: userId,
        sexo: _sexo,
        nivelExperiencia: _nivel,
        intensidad: _intensidad,
        diasEntrenamientoSemana: _dias,
        objetivos: _objetivos.toList(),
        actividades: _actividades.toList(),
        tipoCuerpo: _tipoCuerpo,
        fcReposo: _num(_fcReposo.text)?.round(),
        horasSuenoHabitual: _horasSueno,
        condicionesMedicas: _condiciones.text.trim().isEmpty
            ? null
            : _condiciones.text.trim(),
        notasAdicionales:
            _notas.text.trim().isEmpty ? null : _notas.text.trim(),
        metaKcal: _num(_kcal.text),
        metaProteinasG: _num(_proteinas.text),
        metaCarbohidratosG: _num(_carbohidratos.text),
        metaGrasasG: _num(_grasas.text),
      );

      if (!mounted) return;
      setState(() => _aviso = 'Perfil guardado.');
      // Se relee el contexto para que el progreso refleje lo que se acaba de
      // rellenar sin tener que salir y volver a entrar.
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = analysisErrorMessage(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// 0 = vacío (sin peso/altura), 1 = parcial, 2 = completo.
  int get _estado {
    if (!_tieneMinimos) return 0;
    return _recomendadosPendientes.isEmpty ? 2 : 1;
  }

  int get _hechos => _recomendados.length - _recomendadosPendientes.length;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: DesignTokens.surface2of(b),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _Cabecera(
                  onBack: widget.onBack ?? () => Navigator.maybePop(context),
                  onLogout: widget.onLogout,
                ),
                Expanded(
                  child: _cargando
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : _cuerpo(b),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(Brightness b) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 96),
          children: [
            if (_error != null) ...[
              ErrorBanner(
                  message: _error!, onClose: () => setState(() => _error = null)),
              const SizedBox(height: 12),
            ],
            if (_aviso != null) ...[
              _Aviso(texto: _aviso!),
              const SizedBox(height: 12),
            ],
            StatusSegmented(estado: _estado),
            const SizedBox(height: 14),
            _TarjetaProgreso(
              hechos: _hechos,
              total: _recomendados.length,
              items: [
                for (final r in _recomendados)
                  (
                    etiqueta: r.etiqueta,
                    hecho: !_recomendadosPendientes.contains(r.clave)
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _seccionIdentidad(b),
            _seccionDeportiva(b),
            _seccionMetas(b),
            _seccionNotificaciones(b),
            _seccionComposicion(b),
          ],
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 14,
          child: _BotonGuardar(
            cargando: _guardando,
            onTap: _guardando ? null : _guardar,
          ),
        ),
      ],
    );
  }

  /* ─────────────── Identidad ─────────────── */

  Widget _seccionIdentidad(Brightness b) {
    return ProfileSection(
      icon: LucideIcons.user,
      title: 'Identidad',
      children: [
        const FieldLabel('Nombre completo'),
        ProfileTextField(controller: _nombre, hint: 'Tu nombre'),
        const SizedBox(height: 16),
        const FieldLabel('Email'),
        ProfileTextField(
          controller: _email,
          readOnly: true,
          hint: 'correo@email.com',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Se gestiona en ajustes de cuenta',
            style: DesignTokens.bodyFont(
                fontSize: 10.5, color: DesignTokens.mutedForeground(b)),
          ),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Fecha de nacimiento'),
        ProfileDateField(
          valor: _fechaNacimiento,
          onChanged: (f) => setState(() => _fechaNacimiento = f),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Altura (cm)', obligatorio: true),
                  ProfileTextField(
                      controller: _altura, numerico: true, hint: '178'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Peso de referencia (kg)', obligatorio: true),
                  ProfileTextField(
                      controller: _peso, numerico: true, hint: '76'),
                ],
              ),
            ),
          ],
        ),
        const FieldHint(
          'El peso de referencia es tu punto de partida. El peso vigente se '
          'actualiza registrando mediciones en Clínica.',
        ),
      ],
    );
  }

  /* ─────────────── Perfil deportivo ─────────────── */

  Widget _seccionDeportiva(Brightness b) {
    return ProfileSection(
      icon: LucideIcons.activity,
      title: 'Perfil deportivo',
      children: [
        const FieldLabel('Sexo'),
        ChipGroup(
          opciones: ProfileOptions.sexos,
          seleccion: {if (_sexo != null) _sexo!},
          onToggle: (v) => setState(() => _sexo = _sexo == v ? null : v),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Nivel de experiencia'),
        ChipGroup(
          opciones: ProfileOptions.niveles,
          seleccion: {if (_nivel != null) _nivel!},
          onToggle: (v) => setState(() => _nivel = _nivel == v ? null : v),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Intensidad'),
        ChipGroup(
          opciones: ProfileOptions.intensidades,
          seleccion: {if (_intensidad != null) _intensidad!},
          onToggle: (v) =>
              setState(() => _intensidad = _intensidad == v ? null : v),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Días de entrenamiento / semana'),
        CounterField(
          valor: _dias,
          onChanged: (v) => setState(() => _dias = v),
        ),
        const SizedBox(height: 16),
        FieldLabel('Objetivos',
            nota: '${_objetivos.length} seleccionados'),
        ChipGroup(
          multiple: true,
          opciones: ProfileOptions.objetivos,
          seleccion: _objetivos,
          onToggle: (v) => setState(() =>
              _objetivos.contains(v) ? _objetivos.remove(v) : _objetivos.add(v)),
        ),
        const SizedBox(height: 16),
        FieldLabel('Actividades',
            nota: '${_actividades.length} seleccionadas'),
        ChipGroup(
          multiple: true,
          opciones: ProfileOptions.actividades,
          seleccion: _actividades,
          onToggle: (v) => setState(() => _actividades.contains(v)
              ? _actividades.remove(v)
              : _actividades.add(v)),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Tipo de cuerpo'),
        BodyTypeGrid(
          seleccionado: _tipoCuerpo,
          onSelect: (v) =>
              setState(() => _tipoCuerpo = _tipoCuerpo == v ? null : v),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('FC en reposo (bpm)'),
                  ProfileTextField(
                    controller: _fcReposo,
                    numerico: true,
                    decimal: false,
                    hint: '58',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(
                      'Sueño habitual · ${_horasSueno.toStringAsFixed(_horasSueno % 1 == 0 ? 0 : 1)} h'),
                  SliderField(
                    valor: _horasSueno,
                    onChanged: (v) => setState(() => _horasSueno = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const FieldLabel('Condiciones médicas'),
        ProfileTextField(
          controller: _condiciones,
          lineas: 3,
          hint: 'Lesiones, alergias, limitaciones…',
        ),
        const SizedBox(height: 16),
        const FieldLabel('Notas adicionales'),
        ProfileTextField(
          controller: _notas,
          lineas: 3,
          hint: 'Horarios, preferencias, material disponible…',
        ),
      ],
    );
  }

  /* ─────────────── Metas ─────────────── */

  Widget _seccionMetas(Brightness b) {
    return ProfileSection(
      icon: LucideIcons.utensils,
      title: 'Metas nutricionales',
      children: [
        MacroDonut(
          kcal: _num(_kcal.text),
          proteinas: _num(_proteinas.text),
          carbohidratos: _num(_carbohidratos.text),
          grasas: _num(_grasas.text),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _campoMeta('Calorías (kcal)', _kcal, '2650')),
            const SizedBox(width: 12),
            Expanded(child: _campoMeta('Proteínas (g)', _proteinas, '165')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _campoMeta('Carbohidratos (g)', _carbohidratos, '290')),
            const SizedBox(width: 12),
            Expanded(child: _campoMeta('Grasas (g)', _grasas, '75')),
          ],
        ),
      ],
    );
  }

  Widget _campoMeta(
      String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        ProfileTextField(
          controller: controller,
          numerico: true,
          hint: hint,
          // El donut y el aviso de descuadre se recalculan al teclear; sin esto
          // habría que guardar para ver si los macros cuadran con las kcal.
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  /// `day_of_week` se guarda como nombre en español ("Lunes", "Miércoles"),
  /// no como número, así que hay que traducirlo. Se normalizan los acentos
  /// porque un "Miercoles" sin tilde escrito por la IA no debería perder el
  /// recordatorio de ese día.
  static const _numeroPorDia = {
    'lunes': DateTime.monday,
    'martes': DateTime.tuesday,
    'miercoles': DateTime.wednesday,
    'jueves': DateTime.thursday,
    'viernes': DateTime.friday,
    'sabado': DateTime.saturday,
    'domingo': DateTime.sunday,
  };

  Future<List<int>> _cargarDiasRutina(String userId) async {
    try {
      final rutinas = await ApiService.getRoutines(userId);
      final activa = rutinas.firstWhere(
        (r) => r['activa'] == true,
        orElse: () => rutinas.isNotEmpty ? rutinas.first : <String, dynamic>{},
      );
      final dias = (activa['days'] as List?) ?? const [];
      final numeros = <int>{};
      for (final d in dias) {
        if (d is! Map) continue;
        final clave = reportText(d['day_of_week'])
            .toLowerCase()
            .replaceAll(RegExp('[áà]'), 'a')
            .replaceAll(RegExp('[éè]'), 'e')
            .replaceAll(RegExp('[íì]'), 'i')
            .replaceAll(RegExp('[óò]'), 'o')
            .replaceAll(RegExp('[úù]'), 'u')
            .trim();
        final n = _numeroPorDia[clave];
        if (n != null) numeros.add(n);
      }
      return numeros.toList()..sort();
    } catch (_) {
      // Sin rutina no se bloquea nada: el servicio avisa a diario.
      return const [];
    }
  }

  /* ─────────────── Notificaciones ─────────────── */

  /// Aplica un cambio de preferencias: guarda, reprograma y refresca.
  ///
  /// Se reprograma en cada cambio en vez de solo al pulsar "Guardar cambios"
  /// porque estas preferencias viven en el móvil, no en el perfil del servidor:
  /// si esperaran al botón, un usuario que active un aviso y salga de la
  /// pantalla se quedaría sin él sin entender por qué.
  Future<void> _aplicarNotis(NotificationPreferences nuevas) async {
    // Al encender el interruptor general hay que pedir permiso ANTES de
    // programar nada: en Android 13+, sin POST_NOTIFICATIONS el sistema
    // descarta los avisos en silencio y la app parecería estar rota.
    if (nuevas.activadas && !_notis.activadas) {
      final concedido = await NotificationService.pedirPermiso();
      if (!concedido) {
        if (!mounted) return;
        setState(() => _error =
            'Android no ha concedido el permiso de notificaciones. Actívalo en '
            'los ajustes del sistema para esta app.');
        return;
      }
    }

    setState(() => _notis = nuevas);
    await NotificationService.guardarPreferencias(nuevas);
    // Los días de la rutina activa: así el recordatorio de entrenar solo suena
    // los días que de verdad toca. Si no hay rutina, el servicio avisa a diario.
    await NotificationService.reprogramar(
      nuevas,
      diasEntrenamiento: _diasRutina,
    );
  }

  Widget _seccionNotificaciones(Brightness b) {
    return ProfileSection(
      icon: LucideIcons.bell,
      title: 'Recordatorios',
      children: [
        _FilaInterruptor(
          titulo: 'Activar recordatorios',
          sub: 'Avisos locales del móvil. No sale ningún dato del dispositivo.',
          valor: _notis.activadas,
          onChanged: (v) => _aplicarNotis(_notis.copyWith(activadas: v)),
        ),
        if (_notis.activadas) ...[
          const SizedBox(height: 6),
          Divider(color: DesignTokens.border(b)),
          const SizedBox(height: 6),
          _FilaInterruptor(
            titulo: 'Entrenamiento',
            sub: _diasRutina.isEmpty
                ? 'Todos los días (aún no tienes rutina activa)'
                : 'Solo los días que tu rutina tiene sesión',
            valor: _notis.entrenamiento,
            onChanged: (v) => _aplicarNotis(_notis.copyWith(entrenamiento: v)),
          ),
          if (_notis.entrenamiento)
            _SelectorHora(
              etiqueta: 'A las',
              hora: _notis.horaEntrenamiento,
              onChanged: (h) =>
                  _aplicarNotis(_notis.copyWith(horaEntrenamiento: h)),
            ),
          const SizedBox(height: 10),
          _FilaInterruptor(
            titulo: 'Pesarte',
            sub: 'De tu composición salen las calorías y los macros: si se '
                'queda vieja, el plan también.',
            valor: _notis.composicion,
            onChanged: (v) => _aplicarNotis(_notis.copyWith(composicion: v)),
          ),
          if (_notis.composicion) ...[
            _SelectorDia(
              dia: _notis.diaComposicion,
              onChanged: (d) =>
                  _aplicarNotis(_notis.copyWith(diaComposicion: d)),
            ),
            _SelectorHora(
              etiqueta: 'A las',
              hora: _notis.horaComposicion,
              onChanged: (h) =>
                  _aplicarNotis(_notis.copyWith(horaComposicion: h)),
            ),
          ],
          const SizedBox(height: 10),
          _FilaInterruptor(
            titulo: 'Cerrar el diario de comidas',
            sub: 'Un aviso por la noche por si te falta algo por anotar',
            valor: _notis.nutricion,
            onChanged: (v) => _aplicarNotis(_notis.copyWith(nutricion: v)),
          ),
          if (_notis.nutricion)
            _SelectorHora(
              etiqueta: 'A las',
              hora: _notis.horaNutricion,
              onChanged: (h) =>
                  _aplicarNotis(_notis.copyWith(horaNutricion: h)),
            ),
        ],
      ],
    );
  }

  /* ─────────────── Composición (solo lectura) ─────────────── */

  Widget _seccionComposicion(Brightness b) {
    final m = _composicion;
    return ProfileSection(
      icon: LucideIcons.scale,
      title: 'Composición corporal',
      trailing: Text('SOLO LECTURA',
          style: DesignTokens.labelSmall(
              color: DesignTokens.mutedForeground(b), fontSize: 9)),
      children: [
        if (m == null)
          Text(
            'Todavía no has registrado ninguna medición. Es el dato que más usa '
            'Pulso para calcular tus calorías y tus macros.',
            style: DesignTokens.bodyFont(
                fontSize: 12.5,
                height: 1.4,
                color: DesignTokens.mutedForeground(b)),
          )
        else ...[
          Row(
            children: [
              Text('Última medición',
                  style: DesignTokens.bodyFont(
                      fontSize: 11.5,
                      weight: FontWeight.w600,
                      color: DesignTokens.foreground(b))),
              const Spacer(),
              Text(
                '${_nombreMetodo(m['metodo'])} · ${readableDate(m['fecha_escaneo'])}',
                style: DesignTokens.bodyFont(
                    fontSize: 10.5, color: DesignTokens.mutedForeground(b)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final celda in <(String, String)>[
                ('PESO', _conUnidad(m['peso_kg'], 'kg')),
                ('IMC', _conUnidad(m['imc'], '')),
                ('% GRASA', _conUnidad(m['porcentaje_grasa'], '%')),
                ('M. MUSCULAR', _conUnidad(m['masa_muscular_kg'], 'kg')),
              ])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: DesignTokens.surface1(b),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusXl),
                    ),
                    child: Column(
                      children: [
                        Text(celda.$1,
                            style: DesignTokens.labelSmall(
                                color: DesignTokens.mutedForeground(b),
                                fontSize: 8.5)),
                        const SizedBox(height: 4),
                        Text(celda.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTokens.titleFont(
                                fontSize: 13,
                                color: DesignTokens.foreground(b),
                                weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _EnlaceAccion(
          icono: LucideIcons.history,
          titulo: 'Ver historial completo',
          sub: 'Evolución de todas tus mediciones',
          onTap: () => Navigator.of(context).pushNamed('/clinic/import'),
        ),
        const SizedBox(height: 10),
        _EnlaceAccion(
          icono: LucideIcons.plus,
          titulo: 'Registrar nueva medición',
          sub: 'Se registra en la sección Clínica',
          onTap: () => Navigator.of(context).pushNamed('/clinic/import'),
        ),
      ],
    );
  }

  String _conUnidad(dynamic valor, String unidad) {
    if (valor == null) return '—';
    final texto = reportNumber(valor);
    return unidad.isEmpty ? texto : '$texto $unidad';
  }

  String _nombreMetodo(dynamic metodo) => switch (reportText(metodo)) {
        'dexa' => 'DEXA',
        'bioimpedancia' => 'Bioimpedancia',
        'plicometria' => 'Plicometría',
        'bascula' => 'Báscula',
        _ => 'Medición',
      };
}

/* ─────────────────────── Piezas de la pantalla ─────────────────────── */

/// Fila de interruptor con título y explicación debajo.
class _FilaInterruptor extends StatelessWidget {
  const _FilaInterruptor({
    required this.titulo,
    required this.sub,
    required this.valor,
    required this.onChanged,
  });
  final String titulo, sub;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: DesignTokens.bodyFont(
                        fontSize: 13.5,
                        weight: FontWeight.w700,
                        color: DesignTokens.foreground(b))),
                const SizedBox(height: 2),
                Text(sub,
                    style: DesignTokens.bodyFont(
                        fontSize: 11.5,
                        height: 1.35,
                        color: DesignTokens.mutedForeground(b))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Selector de hora en punto. Solo horas, sin minutos: es un recordatorio, y
/// las alarmas son inexactas por diseño — ofrecer "18:37" prometería una
/// precisión que el sistema no garantiza.
class _SelectorHora extends StatelessWidget {
  const _SelectorHora({
    required this.etiqueta,
    required this.hora,
    required this.onChanged,
  });
  final String etiqueta;
  final int hora;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
      child: Row(
        children: [
          Text(etiqueta,
              style: DesignTokens.bodyFont(
                  fontSize: 12, color: DesignTokens.mutedForeground(b))),
          const SizedBox(width: 10),
          DropdownButton<int>(
            value: hora,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: DesignTokens.bodyFont(
                fontSize: 13,
                weight: FontWeight.w700,
                color: DesignTokens.foreground(b)),
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(
                  value: h,
                  child: Text('${h.toString().padLeft(2, '0')}:00'),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _SelectorDia extends StatelessWidget {
  const _SelectorDia({required this.dia, required this.onChanged});
  final int dia;
  final ValueChanged<int> onChanged;

  static const _nombres = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        children: [
          Text('El día',
              style: DesignTokens.bodyFont(
                  fontSize: 12, color: DesignTokens.mutedForeground(b))),
          const SizedBox(width: 10),
          DropdownButton<int>(
            value: dia,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: DesignTokens.bodyFont(
                fontSize: 13,
                weight: FontWeight.w700,
                color: DesignTokens.foreground(b)),
            items: [
              for (var d = 1; d <= 7; d++)
                DropdownMenuItem(value: d, child: Text(_nombres[d - 1])),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.onBack, this.onLogout});
  final VoidCallback onBack;
  final Future<void> Function(BuildContext)? onLogout;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: DesignTokens.background(b),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoundIconButton(icon: LucideIcons.arrowLeft, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERFIL',
                    style: DesignTokens.labelSmall(
                        color: DesignTokens.mutedForeground(b))),
                const SizedBox(height: 2),
                Text('Configurador de perfil',
                    style: DesignTokens.titleFont(
                        fontSize: 18, color: DesignTokens.foreground(b))),
                const SizedBox(height: 6),
                Text(
                  'Estos datos alimentan a Pulso, tu coach de IA, para '
                  'personalizar rutinas, cargas y nutrición.',
                  style: DesignTokens.bodyFont(
                      fontSize: 11.5,
                      height: 1.35,
                      color: DesignTokens.mutedForeground(b)),
                ),
              ],
            ),
          ),
          if (onLogout != null)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => onLogout!(context),
              icon: Icon(LucideIcons.logOut,
                  size: 18, color: DesignTokens.mutedForeground(b)),
            ),
        ],
      ),
    );
  }
}

class _TarjetaProgreso extends StatelessWidget {
  const _TarjetaProgreso({
    required this.hechos,
    required this.total,
    required this.items,
  });
  final int hechos, total;
  final List<({String etiqueta, bool hecho})> items;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CompletionRing(hechos: hechos, total: total),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROGRESO DE PERFIL',
                        style: DesignTokens.labelSmall(
                            color: DesignTokens.mutedForeground(b),
                            fontSize: 9.5)),
                    const SizedBox(height: 4),
                    Text('$hechos de $total recomendados completados',
                        style: DesignTokens.titleFont(
                            fontSize: 14,
                            color: DesignTokens.foreground(b),
                            weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Cuantos más completes, mejor te entiende Pulso.',
                        style: DesignTokens.bodyFont(
                            fontSize: 11,
                            color: DesignTokens.mutedForeground(b))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i += 2)
            Padding(
              padding:
                  EdgeInsets.only(bottom: i + 2 < items.length ? 8 : 0),
              child: Row(
                children: [
                  Expanded(
                      child: CompletionItem(
                          texto: items[i].etiqueta, hecho: items[i].hecho)),
                  const SizedBox(width: 8),
                  if (i + 1 < items.length)
                    Expanded(
                        child: CompletionItem(
                            texto: items[i + 1].etiqueta,
                            hecho: items[i + 1].hecho))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EnlaceAccion extends StatelessWidget {
  const _EnlaceAccion({
    required this.icono,
    required this.titulo,
    required this.sub,
    required this.onTap,
  });
  final IconData icono;
  final String titulo, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignTokens.surface1(b),
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: DesignTokens.aiGradientSoft,
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              ),
              child:
                  Icon(icono, size: 15, color: DesignTokens.foreground(b)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: DesignTokens.bodyFont(
                          fontSize: 12.5,
                          weight: FontWeight.w700,
                          color: DesignTokens.foreground(b))),
                  Text(sub,
                      style: DesignTokens.bodyFont(
                          fontSize: 10.5,
                          color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 17, color: DesignTokens.mutedForeground(b)),
          ],
        ),
      ),
    );
  }
}

class _BotonGuardar extends StatelessWidget {
  const _BotonGuardar({required this.cargando, this.onTap});
  final bool cargando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: DesignTokens.aiGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: DesignTokens.shadowCard(Theme.of(context).brightness),
        ),
        child: cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.save, size: 17, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('Guardar cambios',
                      style: DesignTokens.titleFont(
                          fontSize: 15,
                          color: Colors.white,
                          weight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DesignTokens.success(b).withOpacity(0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: Border.all(color: DesignTokens.success(b).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2,
              size: 16, color: DesignTokens.success(b)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: DesignTokens.bodyFont(
                    fontSize: 12.5, color: DesignTokens.foreground(b))),
          ),
        ],
      ),
    );
  }
}
