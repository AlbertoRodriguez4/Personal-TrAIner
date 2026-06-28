import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/routine/models/routine.dart';
import '../../features/routine/models/routine_day.dart';
import '../../features/routine/models/exercise.dart';
import '../../services/api_service.dart';
import '../../services/ble_service.dart';

enum Phase { idle, inSet, rest, analyzing, finished }

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
  String get currentZone => _zoneFor(_currentBpm);

  String _zoneFor(int bpm) {
    if (fcm <= 0) return '—';
    final pct = bpm / fcm;
    if (pct < 0.60) return 'Reposo';
    if (pct < 0.70) return 'Z1 Recuperación';
    if (pct < 0.80) return 'Z2 Aeróbica';
    if (pct < 0.88) return 'Z3 Tempo';
    if (pct < 0.95) return 'Z4 Umbral';
    return 'Z5 Máxima';
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
    _phase = Phase.idle;
    _workoutDetected = false;
    notifyListeners();
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
      final zona = res['zona']?.toString() ?? _zoneFor(maxBpm);
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
    if (currentExercise == null || _setIndex >= totalSetsForExercise) {
      _exerciseIndex += 1;
      _setIndex = 0;
      if (currentDay == null || _exerciseIndex >= currentDay!.exercises.length) {
        _phase = Phase.finished;
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
    _phase = Phase.finished;
    notifyListeners();
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