import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/analysis_report.dart';
import '../../../../core/ui/round_icon_button.dart';
import '../../../../services/api_service.dart';
import '../../../../services/health_service.dart';
import '../../../../services/notification_service.dart';
import '../../../onboarding/presentation/screens/tour_page.dart';
import '../../../profile/presentation/widgets/profile_fields.dart';

/// Alta de usuario por pasos.
///
/// El orden separa lo que hace falta de lo que ayuda:
///
///   1. **Cuenta** — nombre, correo y contraseña.
///   2. **Lo mínimo** — fecha de nacimiento, altura y peso. Sin altura y peso
///      no hay gasto calórico ni macros que calcular, así que es el único paso
///      que bloquea.
///   3. **Lo recomendado** — sexo, nivel, objetivos… Todo saltable.
///   4. **Health Connect** — permisos del móvil.
///   5. **Tour** — qué hace la app.
///   6. **Crear cuenta** — hasta aquí no se ha escrito nada en el servidor.
///
/// Que la cuenta se cree al FINAL es lo que hace que abandonar a mitad no deje
/// usuarios a medias en la base de datos. El precio es que el correo duplicado
/// no se detecta hasta el último paso; a cambio, quien llega al final llega con
/// el perfil entero en vez de con una fila vacía que ya no vuelve a tocar.
class RegisterFlowPage extends StatefulWidget {
  const RegisterFlowPage({super.key, this.onRegistered});

  /// Se llama cuando la cuenta ya está creada y la sesión iniciada.
  final VoidCallback? onRegistered;

  @override
  State<RegisterFlowPage> createState() => _RegisterFlowPageState();
}

enum _Paso { cuenta, minimos, recomendados, permisos, confirmar }

class _RegisterFlowPageState extends State<RegisterFlowPage> {
  _Paso _paso = _Paso.cuenta;
  bool _procesando = false;
  String? _error;

  // Paso 1 — cuenta
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  // Paso 2 — mínimos
  DateTime? _fechaNacimiento;
  final _altura = TextEditingController();
  final _peso = TextEditingController();

  // Paso 3 — recomendados
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
  final _grasa = TextEditingController();
  final _musculo = TextEditingController();

  // Paso 4 — permisos
  bool _permisosConcedidos = false;
  bool _permisosIntentados = false;

  static const _titulos = {
    _Paso.cuenta: 'Crea tu cuenta',
    _Paso.minimos: 'Tus datos básicos',
    _Paso.recomendados: 'Afina tu perfil',
    _Paso.permisos: 'Conecta tu salud',
    _Paso.confirmar: 'Todo listo',
  };

  static const _subtitulos = {
    _Paso.cuenta: 'Solo el correo y una contraseña. Nada más por ahora.',
    _Paso.minimos:
        'Altura y peso son lo único imprescindible: sin ellos no se puede calcular ni una caloría.',
    _Paso.recomendados:
        'Nada de esto es obligatorio, pero cuanto más rellenes mejor te entiende Pulso. Puedes saltarlo y hacerlo luego.',
    _Paso.permisos:
        'Health Connect le da a Pulso tus pasos, entrenamientos y sueño reales.',
    _Paso.confirmar: 'Revisa y crea tu cuenta.',
  };

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _email,
      _password,
      _password2,
      _altura,
      _peso,
      _fcReposo,
      _condiciones,
      _grasa,
      _musculo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  /* ─────────────── Navegación ─────────────── */

  /// Valida el paso actual. Cada uno comprueba solo lo suyo: así el usuario ve
  /// el fallo donde lo puede arreglar, no un listado al final.
  String? _validarPasoActual() {
    switch (_paso) {
      case _Paso.cuenta:
        if (_nombre.text.trim().isEmpty) return 'Escribe tu nombre.';
        final email = _email.text.trim();
        if (email.isEmpty) return 'Escribe tu correo.';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
          return 'Ese correo no parece válido.';
        }
        if (_password.text.length < 6) {
          return 'La contraseña debe tener al menos 6 caracteres.';
        }
        if (_password.text != _password2.text) {
          return 'Las dos contraseñas no coinciden.';
        }
        return null;
      case _Paso.minimos:
        if (_fechaNacimiento == null) {
          return 'Selecciona tu fecha de nacimiento.';
        }
        final altura = _num(_altura.text);
        final peso = _num(_peso.text);
        if (altura == null || altura < 50 || altura > 300) {
          return 'La altura tiene que estar entre 50 y 300 cm.';
        }
        if (peso == null || peso < 20 || peso > 500) {
          return 'El peso tiene que estar entre 20 y 500 kg.';
        }
        return null;
      case _Paso.recomendados:
      case _Paso.permisos:
      case _Paso.confirmar:
        return null;
    }
  }

  Future<void> _avanzar() async {
    final fallo = _validarPasoActual();
    if (fallo != null) {
      setState(() => _error = fallo);
      return;
    }
    setState(() => _error = null);

    // El tour va entre los permisos y la creación de la cuenta. Se abre como
    // pantalla completa propia en vez de meterlo dentro del formulario: tiene
    // su propio fondo ilustrado y encajarlo aquí lo dejaría descolocado.
    if (_paso == _Paso.permisos) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TourPage(
            onFinish: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _paso = _Paso.confirmar);
      return;
    }

    setState(() => _paso = _Paso.values[_paso.index + 1]);
  }

  void _retroceder() {
    if (_paso.index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _error = null;
      _paso = _Paso.values[_paso.index - 1];
    });
  }

  /* ─────────────── Permisos ─────────────── */

  Future<void> _pedirPermisos() async {
    setState(() => _procesando = true);
    try {
      // Las notificaciones se piden AQUI, junto a Health Connect, y no solo
      // desde el perfil como hasta ahora: este es el unico punto del registro
      // donde se piden permisos, y quien no volviese luego a Ajustes no veia
      // jamas un recordatorio ni la notificacion de entrenamiento en curso,
      // sin que nada se lo explicara. Va antes que Health Connect para que los
      // dos dialogos del sistema no se pisen.
      //
      // No condiciona nada: `_permisosConcedidos` sigue siendo el de Health
      // Connect, que es el que este paso enseña y el que da sentido al resto
      // de la app. Decir que no a las notificaciones no puede frenar el alta.
      await NotificationService.pedirPermiso().catchError((_) => false);
      if (!mounted) return;

      final ok = await HealthService.requestPermissions();
      if (!mounted) return;
      setState(() {
        _permisosConcedidos = ok;
        _permisosIntentados = true;
      });
    } catch (_) {
      if (!mounted) return;
      // Health Connect no está en todas las plataformas ni en todos los
      // móviles. No poder pedirlos no puede impedir crear la cuenta.
      setState(() {
        _permisosConcedidos = false;
        _permisosIntentados = true;
      });
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /* ─────────────── Alta ─────────────── */

  Future<void> _crearCuenta() async {
    setState(() {
      _procesando = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final alta = await ApiService.register(
        nombreCompleto: _nombre.text.trim(),
        email: email,
        password: _password.text,
        fechaNacimiento:
            _fechaNacimiento!.toIso8601String().substring(0, 10),
        estatura: _num(_altura.text)!,
        peso: _num(_peso.text)!,
      );
      if (!mounted) return;
      if (alta == null) {
        setState(() => _error =
            'No se pudo crear la cuenta. Puede que ese correo ya esté '
            'registrado: prueba a iniciar sesión.');
        return;
      }

      final sesion = await ApiService.login(email, _password.text);
      if (!mounted) return;
      if (sesion == null) {
        setState(() => _error =
            'La cuenta se creó pero no se pudo iniciar sesión. Entra desde la '
            'pantalla de acceso.');
        return;
      }

      final userId = ApiService.getCurrentUserId();
      if (userId != null) {
        // El perfil y la medición no bloquean: la cuenta ya existe y el usuario
        // puede completar esto después desde el configurador. Fallar aquí y
        // dejarle fuera sería el peor de los dos males.
        try {
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
          );
        } catch (_) {/* se completa luego en el configurador */}

        final grasa = _num(_grasa.text);
        final musculo = _num(_musculo.text);
        if (grasa != null || musculo != null) {
          try {
            await ApiService.registerBodyComposition(
              userId: userId,
              metodo: 'otro',
              pesoKg: _num(_peso.text),
              porcentajeGrasa: grasa,
              masaMuscularKg: musculo,
              notas: 'Introducido al crear la cuenta.',
            );
          } catch (_) {/* se puede registrar luego en Clínica */}
        }
      }

      if (!mounted) return;
      widget.onRegistered?.call();
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = analysisErrorMessage(e));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /* ─────────────── UI ─────────────── */

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
                  paso: _paso.index,
                  total: _Paso.values.length,
                  titulo: _titulos[_paso]!,
                  subtitulo: _subtitulos[_paso]!,
                  onBack: _retroceder,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                    children: [
                      if (_error != null) ...[
                        ErrorBanner(
                          message: _error!,
                          onClose: () => setState(() => _error = null),
                        ),
                        const SizedBox(height: 12),
                      ],
                      switch (_paso) {
                        _Paso.cuenta => _pasoCuenta(),
                        _Paso.minimos => _pasoMinimos(),
                        _Paso.recomendados => _pasoRecomendados(),
                        _Paso.permisos => _pasoPermisos(b),
                        _Paso.confirmar => _pasoConfirmar(b),
                      },
                    ],
                  ),
                ),
                _Pie(
                  paso: _paso,
                  procesando: _procesando,
                  onContinuar: _paso == _Paso.confirmar
                      ? _crearCuenta
                      : _avanzar,
                  onSaltar: _paso == _Paso.recomendados ||
                          (_paso == _Paso.permisos && !_permisosConcedidos)
                      ? _avanzar
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pasoCuenta() {
    return ProfileSection(
      icon: LucideIcons.userPlus,
      title: 'Cuenta',
      children: [
        const FieldLabel('Nombre completo', obligatorio: true),
        ProfileTextField(
          controller: _nombre,
          hint: 'Tu nombre',
          autofillHints: const [AutofillHints.name],
        ),
        const SizedBox(height: 16),
        const FieldLabel('Correo electrónico', obligatorio: true),
        ProfileTextField(
          controller: _email,
          hint: 'correo@email.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        const FieldLabel('Contraseña', obligatorio: true),
        ProfileTextField(
          controller: _password,
          hint: 'Mínimo 6 caracteres',
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 16),
        const FieldLabel('Repite la contraseña', obligatorio: true),
        ProfileTextField(
          controller: _password2,
          hint: 'Otra vez',
          obscure: true,
        ),
      ],
    );
  }

  Widget _pasoMinimos() {
    return ProfileSection(
      icon: LucideIcons.ruler,
      title: 'Datos básicos',
      children: [
        const FieldLabel('Fecha de nacimiento', obligatorio: true),
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
                  const FieldLabel('Peso (kg)', obligatorio: true),
                  ProfileTextField(
                      controller: _peso, numerico: true, hint: '76'),
                ],
              ),
            ),
          ],
        ),
        const FieldHint(
          'Este peso es tu punto de partida. Después lo irás actualizando '
          'registrando mediciones en Clínica.',
        ),
      ],
    );
  }

  Widget _pasoRecomendados() {
    return Column(
      children: [
        ProfileSection(
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
                valor: _dias, onChanged: (v) => setState(() => _dias = v)),
            const SizedBox(height: 16),
            FieldLabel('Objetivos', nota: '${_objetivos.length} seleccionados'),
            ChipGroup(
              multiple: true,
              opciones: ProfileOptions.objetivos,
              seleccion: _objetivos,
              onToggle: (v) => setState(() => _objetivos.contains(v)
                  ? _objetivos.remove(v)
                  : _objetivos.add(v)),
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
                          'Sueño · ${_horasSueno.toStringAsFixed(_horasSueno % 1 == 0 ? 0 : 1)} h'),
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
          ],
        ),
        ProfileSection(
          icon: LucideIcons.scale,
          title: 'Composición corporal',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Grasa corporal (%)'),
                      ProfileTextField(
                          controller: _grasa, numerico: true, hint: '17.6'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Masa muscular (kg)'),
                      ProfileTextField(
                          controller: _musculo, numerico: true, hint: '49.5'),
                    ],
                  ),
                ),
              ],
            ),
            const FieldHint(
              'Si tienes un DEXA o una báscula de bioimpedancia, estos dos '
              'valores son los que más cambian lo que Pulso te recomienda. Se '
              'guardan como tu primera medición y luego puedes subir el informe '
              'entero en Clínica.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _pasoPermisos(Brightness b) {
    return ProfileSection(
      icon: LucideIcons.heartPulse,
      title: 'Health Connect',
      children: [
        Text(
          'Pulso lee de Health Connect tus pasos, entrenamientos, calorías y '
          'fases de sueño. Con esos datos ajusta cargas y detecta cuándo te '
          'estás pasando de la raya.',
          style: DesignTokens.bodyFont(
              fontSize: 12.5,
              height: 1.45,
              color: DesignTokens.mutedForeground(b)),
        ),
        const SizedBox(height: 14),
        for (final linea in const [
          (LucideIcons.footprints, 'Pasos, distancia y entrenamientos'),
          (LucideIcons.flame, 'Calorías activas y basales'),
          (LucideIcons.moon, 'Fases y calidad del sueño'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(linea.$1, size: 15, color: DesignTokens.foreground(b)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(linea.$2,
                      style: DesignTokens.bodyFont(
                          fontSize: 12.5,
                          color: DesignTokens.foreground(b))),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (_permisosConcedidos)
          _Estado(
            icono: LucideIcons.checkCircle2,
            color: DesignTokens.success(b),
            texto: 'Permisos concedidos. Ya podemos leer tus datos.',
          )
        else if (_permisosIntentados)
          _Estado(
            icono: LucideIcons.alertTriangle,
            color: DesignTokens.warning(b),
            texto:
                'No se han concedido. Puedes seguir sin ellos y activarlos '
                'más tarde desde Dispositivos.',
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _procesando ? null : _pedirPermisos,
              icon: const Icon(LucideIcons.shieldCheck, size: 17),
              label: const Text('Conceder permisos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.foreground(b),
                side: BorderSide(color: DesignTokens.border(b)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                ),
              ),
            ),
          ),
        const FieldHint(
          'Health Connect es de Android. Si tu móvil no lo tiene, puedes seguir '
          'sin ello: la app funciona igual, solo que sin los datos del reloj.',
        ),
      ],
    );
  }

  Widget _pasoConfirmar(Brightness b) {
    final resumen = <(String, String)>[
      ('Nombre', _nombre.text.trim()),
      ('Correo', _email.text.trim()),
      (
        'Nacimiento',
        _fechaNacimiento == null
            ? '—'
            : '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/'
                '${_fechaNacimiento!.month.toString().padLeft(2, '0')}/'
                '${_fechaNacimiento!.year}'
      ),
      ('Altura', '${_altura.text.trim()} cm'),
      ('Peso', '${_peso.text.trim()} kg'),
      if (_sexo != null) ('Sexo', _sexo!),
      if (_nivel != null) ('Nivel', _nivel!),
      if (_objetivos.isNotEmpty) ('Objetivos', _objetivos.join(', ')),
      (
        'Health Connect',
        _permisosConcedidos ? 'Concedido' : 'Sin conceder'
      ),
    ];

    return ProfileSection(
      icon: LucideIcons.checkCircle2,
      title: 'Resumen',
      children: [
        for (final fila in resumen)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(fila.$1,
                      style: DesignTokens.bodyFont(
                          fontSize: 12,
                          color: DesignTokens.mutedForeground(b))),
                ),
                Expanded(
                  child: Text(fila.$2.isEmpty ? '—' : fila.$2,
                      style: DesignTokens.bodyFont(
                          fontSize: 12.5,
                          weight: FontWeight.w600,
                          color: DesignTokens.foreground(b))),
                ),
              ],
            ),
          ),
        const FieldHint(
          'Al crear la cuenta se guarda todo esto. Lo que hayas dejado en '
          'blanco lo puedes rellenar luego desde el configurador de perfil.',
        ),
      ],
    );
  }
}

/* ─────────────────────── Piezas ─────────────────────── */

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.paso,
    required this.total,
    required this.titulo,
    required this.subtitulo,
    required this.onBack,
  });
  final int paso, total;
  final String titulo, subtitulo;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: DesignTokens.background(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RoundIconButton(icon: LucideIcons.arrowLeft, onTap: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PASO ${paso + 1} DE $total',
                        style: DesignTokens.labelSmall(
                            color: DesignTokens.mutedForeground(b))),
                    const SizedBox(height: 2),
                    Text(titulo,
                        style: DesignTokens.titleFont(
                            fontSize: 19,
                            color: DesignTokens.foreground(b))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra de progreso por tramos: se ve cuántos pasos quedan, que es lo
          // que decide si alguien abandona un formulario largo.
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: i <= paso ? DesignTokens.aiGradient : null,
                      color: i <= paso ? null : DesignTokens.border(b),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitulo,
              style: DesignTokens.bodyFont(
                  fontSize: 11.5,
                  height: 1.35,
                  color: DesignTokens.mutedForeground(b))),
        ],
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({
    required this.paso,
    required this.procesando,
    required this.onContinuar,
    this.onSaltar,
  });
  final _Paso paso;
  final bool procesando;
  final VoidCallback onContinuar;
  final VoidCallback? onSaltar;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final esUltimo = paso == _Paso.confirmar;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: DesignTokens.background(b),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Row(
        children: [
          if (onSaltar != null) ...[
            TextButton(
              onPressed: procesando ? null : onSaltar,
              style: TextButton.styleFrom(
                  foregroundColor: DesignTokens.mutedForeground(b)),
              child: const Text('Saltar'),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: procesando ? null : onContinuar,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: DesignTokens.shadowCard(b),
                ),
                child: procesando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(esUltimo ? 'Crear cuenta' : 'Continuar',
                              style: DesignTokens.titleFont(
                                  fontSize: 15,
                                  color: Colors.white,
                                  weight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Icon(
                              esUltimo
                                  ? LucideIcons.check
                                  : LucideIcons.arrowRight,
                              size: 17,
                              color: Colors.white),
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

class _Estado extends StatelessWidget {
  const _Estado({
    required this.icono,
    required this.color,
    required this.texto,
  });
  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: DesignTokens.bodyFont(
                    fontSize: 12,
                    height: 1.35,
                    color: DesignTokens.foreground(b))),
          ),
        ],
      ),
    );
  }
}
