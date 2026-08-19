import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/routine/models/routine.dart';
import '../../features/routine/models/routine_day.dart';
import '../../features/routine/models/exercise.dart';
import '../../services/api_service.dart';
import '../../services/ble_service.dart';
import '../theme/design_tokens.dart';

enum Phase { idle, inSet, rest, analyzing, finished }

/// Banda de intensidad para la FC en vivo (equivalente a `bandFor` en
/// `session.tsx`): etiqueta corta, hint explicativo y color asociado.
class IntensityBand {
  final String label;
  final String hint;
  final Color color;
  const IntensityBand(this.label, this.hint, this.color);
}

class SetResult {
  final String exerciseName;
  final int setNumber;
  final int durationSec;
  final int maxBpm;
  final int avgBpm;
  final int rirEstimated;
  final double attackSlope;
  final double plateauIndex;
  final String zone;
  final String feedback;
  final bool reachedFailure;
  final bool sufficientIntensity;

  const SetResult({
    required this.exerciseName,
    required this.setNumber,
    required this.durationSec,
    required this.maxBpm,
    required this.avgBpm,
    required this.rirEstimated,
    required this.attackSlope,
    required this.plateauIndex,
    required this.zone,
    required this.feedback,
    required this.reachedFailure,
    required this.sufficientIntensity,
  });
}

class WorkoutSessionProvider extends ChangeNotifier {
  final BleService _ble = BleService();

  WorkoutSessionProvider() {
    _ble.onStateChanged = _updateBleState;
  }

  void _updateBleState() {
    _hrSource = _ble.currentSource;
    if (_ble.bleState == BleConnectionState.scanning) {
      _connectionLabel = 'Buscando banda HRM...';
    } else if (_ble.bleState == BleConnectionState.connecting) {
      _connectionLabel = 'Conectando a ${_ble.deviceName}...';
    } else if (_ble.currentSource == 'ble') {
      _connectionLabel = '${_ble.deviceName} · BLE conectado';
    } else if (_ble.currentSource == 'simulation') {
      _connectionLabel = '${_ble.deviceName} · modo simulación';
    } else {
      _connectionLabel = 'Desconectado';
    }
    notifyListeners();
  }

  Phase _phase = Phase.idle;
  Phase get phase => _phase;

  String? _connectionLabel;
  String? get connectionLabel => _connectionLabel;

  String? _hrSource;
  String? get hrSource => _hrSource;

  int _currentBpm = 0;
  int get currentBpm => _currentBpm;

  // ── Telemetría R-R / HRV ──
  double? _lastRrMs;
  double? get lastRrMs => _lastRrMs;

  double? get currentRmssd => _ble.currentRmssd;

  BleConnectionState get bleConnectionState => _ble.bleState;

  bool? _sensorContact;
  bool? get sensorContact => _sensorContact;

  int _userAge = 30;
  int get userAge => _userAge;
  int get fcm => 220 - _userAge;
  int get highIntensityThreshold => (fcm * 0.85).round();

  /// % de la FC máx. personalizada (fcm = 220-edad), no el HR_MAX=190 fijo
  /// que usa el mockup — la fórmula por edad ya existente es más precisa.
  int get pctOfMax => fcm <= 0 ? 0 : ((_currentBpm / fcm) * 100).round();

  IntensityBand get currentIntensityBand => _bandFor(pctOfMax);

  IntensityBand _bandFor(int pct) {
    if (pct < 60) {
      return const IntensityBand('Ligero',
          'Muy lejos del fallo · puedes subir carga', DesignTokens.effortLow);
    }
    if (pct < 72) {
      return const IntensityBand('Moderado',
          'Trabajo cómodo · 4+ reps en reserva', DesignTokens.effortModerate);
    }
    if (pct < 82) {
      return const IntensityBand('Intenso',
          'Estímulo óptimo · 2-3 reps en reserva', DesignTokens.effortHigh);
    }
    if (pct < 91) {
      return const IntensityBand('Cerca del fallo',
          '1-2 reps en reserva · mantén la técnica', DesignTokens.effortVeryHigh);
    }
    return const IntensityBand(
        'Fallo muscular', 'Sin reps en reserva · descansa más', DesignTokens.effortMax);
  }

  void setUserAge(int age) {
    if (age > 0 && age < 120) {
      _userAge = age;
      notifyListeners();
    }
  }

  final List<int> _liveGraph = [];
  List<int> get liveGraph => List.unmodifiable(_liveGraph);

  Routine? _routine;
  Routine? get routine => _routine;

  int _dayIndex = 0;
  int get dayIndex => _dayIndex;
  RoutineDay? get currentDay =>
      _routine != null && _dayIndex < _routine!.days.length
          ? _routine!.days[_dayIndex]
          : null;

  int _exerciseIndex = 0;
  int get exerciseIndex => _exerciseIndex;
  Exercise? get currentExercise {
    final day = currentDay;
    if (day == null || _exerciseIndex >= day.exercises.length) return null;
    return day.exercises[_exerciseIndex];
  }

  int _setIndex = 0;
  int get setIndex => _setIndex;
  int get totalSetsForExercise => currentExercise?.sets ?? 0;

  // ── Checklist de ejercicios (overview sobre el flujo de sets existente) ──
  final Set<int> _completedExerciseIndices = {};
  bool isExerciseDone(int index) => _completedExerciseIndices.contains(index);
  int get completedExercisesCount => _completedExerciseIndices.length;
  int get totalExercisesInDay => currentDay?.exercises.length ?? 0;

  /// Marca/desmarca un ejercicio manualmente desde el checklist, independiente
  /// del avance automático por sets analizados (ver `_advanceAfterSet`).
  void toggleExerciseDone(int index) {
    if (currentDay == null || index < 0 || index >= currentDay!.exercises.length) {
      return;
    }
    if (!_completedExerciseIndices.remove(index)) {
      _completedExerciseIndices.add(index);
    }
    notifyListeners();
  }

  final List<int> _setHrBuffer = [];
  final List<SetResult> _results = [];
  List<SetResult> get results => List.unmodifiable(_results);

  DateTime? _setStart;
  Timer? _setTimer;
  int _setElapsed = 0;
  int get setElapsed => _setElapsed;

  Timer? _restTimer;
  int _restRemaining = 0;
  int get restRemaining => _restRemaining;
  static const int _defaultRestSec = 90;

  // ── Timer de sesión + pausa (independiente del timer por set/descanso, que
  // sigue su propio flujo de análisis de IA sin interrupciones) ──
  Timer? _sessionTimer;
  int _sessionElapsedSeconds = 0;
  int get sessionElapsedSeconds => _sessionElapsedSeconds;
  DateTime? _sessionStartAt;

  /// Id de la sesión ya guardada en el backend (para pedir su análisis en el
  /// resumen) y bandera para no duplicarla si `endSession()` se llama más de
  /// una vez (pasa: el botón "Finalizar" y el back de la cabecera llaman a lo
  /// mismo, y nada impide que el usuario toque los dos).
  String? _savedSessionId;
  String? get savedSessionId => _savedSessionId;
  bool _sessionSaved = false;
  bool _saving = false;
  bool get isSavingSession => _saving;
  String get sessionElapsedFormatted {
    final m = (_sessionElapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_sessionElapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _paused = false;
  bool get paused => _paused;

  void pauseSession() {
    if (_paused) return;
    _paused = true;
    _sessionTimer?.cancel();
    notifyListeners();
  }

  void resumeSession() {
    if (!_paused) return;
    _paused = false;
    _startSessionTimer();
    notifyListeners();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionElapsedSeconds += 1;
      notifyListeners();
    });
  }

  /// Estimación gruesa (misma fórmula que el mockup) — no es una medición
  /// científica, solo un valor orientativo para el mini-stat de la sesión.
  int get estimatedKcal =>
      (_sessionElapsedSeconds * 0.13 + completedExercisesCount * 22).round();

  bool _autoDetectEnabled = false;
  bool get autoDetectEnabled => _autoDetectEnabled;
  bool _workoutDetected = false;
  bool get workoutDetected => _workoutDetected;
  int _elevatedSeconds = 0;
  static const int _detectionThreshold = 110;
  static const int _detectionWindowSec = 50;

  StreamSubscription<HrSample>? _hrSub;
  Timer? _detectionTimer;
  String? _error;
  String? get error => _error;

  VoidCallback? onWorkoutDetected;

  @override
  void dispose() {
    _setTimer?.cancel();
    _restTimer?.cancel();
    _sessionTimer?.cancel();
    _detectionTimer?.cancel();
    _hrSub?.cancel();
    _ble.disconnect();
    _ble.dispose();
    super.dispose();
  }

  Future<void> connectWatch() async {
    _connectionLabel = 'Buscando banda HRM...';
    notifyListeners();
    final birth =
        ApiService.getCurrentUserBirthDate();
    if (birth != null && birth.isNotEmpty) {
      final parsed = DateTime.tryParse(birth);
      if (parsed != null) {
        final age = DateTime.now().difference(parsed).inDays ~/ 365;
        if (age > 0) _userAge = age;
      }
    }
    _hrSub?.cancel();
    _hrSub = _ble.hrStream.listen(_onHrSample);

    // Intentar conexión BLE real (fallback automático a simulación).
    await _ble.connectBle();

    _startDetection();
    notifyListeners();
  }

  void _startDetection() {
    if (_phase != Phase.idle && _phase != Phase.finished) return;
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkWorkoutDetection();
    });
  }

  void _onHrSample(HrSample s) {
    _currentBpm = s.bpm;
    _sensorContact = s.sensorContact;
    if (s.rrIntervals.isNotEmpty) {
      _lastRrMs = s.rrIntervals.last;
    }
    final capped = s.bpm > 220 ? 220 : s.bpm;
    _liveGraph.add(capped);
    if (_liveGraph.length > 60) _liveGraph.removeAt(0);
    if (_phase == Phase.inSet) _setHrBuffer.add(capped);
    notifyListeners();
  }


  void _checkWorkoutDetection() {
    if (_phase != Phase.idle && _phase != Phase.finished) {
      _elevatedSeconds = 0;
      return;
    }
    if (_currentBpm >= _detectionThreshold) {
      _elevatedSeconds += 2;
      if (_elevatedSeconds >= _detectionWindowSec && !_workoutDetected) {
        _workoutDetected = true;
        notifyListeners();
        onWorkoutDetected?.call();
      }
    } else {
      _elevatedSeconds = 0;
    }
  }

  void dismissWorkoutDetection() {
    _workoutDetected = false;
    _elevatedSeconds = 0;
    notifyListeners();
  }

  void startSession(Routine routine, {int dayIndex = 0}) {
    _routine = routine;
    _dayIndex = dayIndex.clamp(0, routine.days.length - 1);
    _exerciseIndex = 0;
    _setIndex = 0;
    _results.clear();
    _completedExerciseIndices.clear();
    _phase = Phase.idle;
    _workoutDetected = false;
    _paused = false;
    _sessionElapsedSeconds = 0;
    _sessionStartAt = DateTime.now();
    _sessionSaved = false;
    _startSessionTimer();
    notifyListeners();
  }

  /// Reinicia la sesión actual desde cero (mismo día, misma rutina).
  void restartSession() {
    if (_routine == null) return;
    startSession(_routine!, dayIndex: _dayIndex);
  }

  void startSet() {
    if (currentExercise == null) return;
    _phase = Phase.inSet;
    _setHrBuffer.clear();
    _setStart = DateTime.now();
    _setElapsed = 0;
    _ble.beginSetModel();
    _setTimer?.cancel();
    _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _setElapsed += 1;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> endSetAndAnalyze() async {
    _setTimer?.cancel();
    if (_setStart == null) return;
    final dur = DateTime.now().difference(_setStart!).inSeconds;
    if (_setHrBuffer.isEmpty) {
      _advanceAfterSet(null);
      return;
    }
    _phase = Phase.analyzing;
    notifyListeners();

    try {
      final uid = ApiService.getCurrentUserId() ?? 'guest';
      final eid = currentExercise?.id ?? currentExercise?.name ?? 'ex';
      final res = await ApiService.analyzeHrSet(
        uid: uid,
        eid: eid,
        dur: dur,
        hr: List<int>.from(_setHrBuffer),
      );
      final rir = (res['rir_estimado'] is num)
          ? (res['rir_estimado'] as num).toInt()
          : 3;
      final feedback = res['feedback']?.toString() ?? 'Sin feedback';
      final maxBpm = _setHrBuffer.reduce((a, b) => a > b ? a : b);
      final avgBpm = _setHrBuffer.reduce((a, b) => a + b) ~/ _setHrBuffer.length;
      final reachedFailure = rir == 0;
      final sufficientIntensity = rir <= 2;
      final attackSlope = (res['pendiente_ataque'] is num)
          ? (res['pendiente_ataque'] as num).toDouble()
          : 0.0;
      final plateauIndex = (res['plateau_index'] is num)
          ? (res['plateau_index'] as num).toDouble()
          : 0.0;
      final zona = res['zona']?.toString() ??
          _bandFor(fcm <= 0 ? 0 : ((maxBpm / fcm) * 100).round()).label;
      final result = SetResult(
        exerciseName: currentExercise?.name ?? '',
        setNumber: _setIndex + 1,
        durationSec: dur,
        maxBpm: maxBpm,
        avgBpm: avgBpm,
        rirEstimated: rir,
        attackSlope: attackSlope,
        plateauIndex: plateauIndex,
        zone: zona,
        feedback: feedback,
        reachedFailure: reachedFailure,
        sufficientIntensity: sufficientIntensity,
      );
      _results.add(result);
      _ble.endSetModel();
      _startRest();
    } catch (e) {
      _error = e.toString();
      _advanceAfterSet(null);
    }
  }

  void _startRest() {
    _phase = Phase.rest;
    _restRemaining = _defaultRestSec;
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _restRemaining -= 1;
      if (_restRemaining <= 0) {
        _restTimer?.cancel();
        _advanceAfterSet(null);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void skipRest() {
    _restTimer?.cancel();
    _advanceAfterSet(null);
  }

  void _advanceAfterSet(SetResult? _) {
    _setIndex += 1;
    final finishedExercise = currentExercise;
    if (finishedExercise == null || _setIndex >= totalSetsForExercise) {
      if (finishedExercise != null) {
        _completedExerciseIndices.add(_exerciseIndex);
      }
      _exerciseIndex += 1;
      _setIndex = 0;
      if (currentDay == null || _exerciseIndex >= currentDay!.exercises.length) {
        _phase = Phase.finished;
        _sessionTimer?.cancel();
        notifyListeners();
        return;
      }
    }
    _phase = Phase.idle;
    notifyListeners();
  }

  void nextExercise() {
    if (currentDay == null) return;
    _exerciseIndex += 1;
    _setIndex = 0;
    if (_exerciseIndex >= currentDay!.exercises.length) {
      _exerciseIndex = currentDay!.exercises.length - 1;
    }
    _phase = Phase.idle;
    notifyListeners();
  }

  void selectExercise(int index) {
    if (currentDay == null) return;
    if (index < 0 || index >= currentDay!.exercises.length) return;
    _exerciseIndex = index;
    _setIndex = 0;
    _phase = Phase.idle;
    notifyListeners();
  }

  void endSession() {
    _setTimer?.cancel();
    _restTimer?.cancel();
    _sessionTimer?.cancel();
    _phase = Phase.finished;
    notifyListeners();
    // Fire-and-forget: guardar no puede bloquear al usuario viendo su propio
    // resumen. `_SummaryView` sondea `savedSessionId`/`isSavingSession` para
    // pedir el análisis en cuanto la sesión tenga id.
    unawaited(_persistSession());
  }

  /// gym/calistenia → fuerza (con o sin peso externo, es trabajo de fuerza);
  /// cardio/deportes → cardio; yoga → flexibilidad. `tipo_entrenamiento` está
  /// restringido a solo esos tres valores en toda la app — ver la nota en
  /// `crear_rutina_personalizada` sobre por qué no se puede aflojar ese enum.
  String _tipoSesionDesdeActividad(String? activityType) {
    switch (activityType) {
      case 'cardio':
      case 'deportes':
        return 'cardio';
      case 'yoga':
        return 'flexibilidad';
      default:
        return 'fuerza';
    }
  }

  /// Guarda la sesión que de verdad ocurrió, con las métricas que midió la
  /// banda BLE. Antes de esto, una sesión rastreada en vivo terminaba en la
  /// pantalla de resumen y ahí se quedaba — nada se guardaba en el backend, así
  /// que no había ni historial ni con qué comparar la siguiente.
  Future<void> _persistSession() async {
    if (_sessionSaved || _results.isEmpty) return;
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;

    _sessionSaved = true; // se marca antes del await: un doble tap no duplica
    _saving = true;
    notifyListeners();

    try {
      final fcMedias = _results.map((r) => r.avgBpm).where((v) => v > 0).toList();
      final fcMaxima = _results.map((r) => r.maxBpm).where((v) => v > 0);

      final guardada = await ApiService.createTrainingSession(
        userId: userId,
        fechaProgramada:
            (_sessionStartAt ?? DateTime.now()).toIso8601String(),
        tipoEntrenamiento: _tipoSesionDesdeActividad(_routine?.activityType),
        ejercicios: [
          for (final r in _results)
            {
              'ejercicio': r.exerciseName,
              'serie': r.setNumber,
              'duracion_seg': r.durationSec,
              'fc_media': r.avgBpm,
              'fc_max': r.maxBpm,
              'rir_estimado': r.rirEstimated,
              'zona': r.zone,
              'al_fallo': r.reachedFailure,
            },
        ],
        estado: 'completado',
        duracionMinutos: (_sessionElapsedSeconds / 60).round(),
        caloriasKcal: estimatedKcal,
        frecuenciaCardiacaMedia: fcMedias.isEmpty
            ? null
            : (fcMedias.reduce((a, b) => a + b) / fcMedias.length).round(),
        frecuenciaCardiacaMax: fcMaxima.isEmpty
            ? null
            : fcMaxima.reduce((a, b) => a > b ? a : b),
        origen: 'app',
      );
      _savedSessionId = guardada['id']?.toString();
    } catch (_) {
      // No hay dónde mostrar el error en una pantalla que ya se está cerrando;
      // el usuario ya vio su resumen en pantalla, perder el guardado no puede
      // bloquear el flujo. `_sessionSaved` se queda en true a propósito: un
      // reintento automático aquí podría duplicar si el POST sí llegó a
      // guardarse y solo falló la respuesta.
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  int get totalSets => _routine == null
      ? 0
      : _routine!.days.fold(
          0,
          (s, d) => s + d.exercises.fold(0, (e, ex) => e + (ex.sets ?? 0)),
        );

  int get completedSets => _results.length;

  int get failureSets => _results.where((r) => r.reachedFailure).length;

  int get highIntensitySets =>
      _results.where((r) => r.sufficientIntensity).length;
}