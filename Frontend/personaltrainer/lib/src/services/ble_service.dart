import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/heart_rate_data.dart';

/// UUIDs estándar Bluetooth SIG para Heart Rate Service.
final Guid _hrServiceUuid = Guid('180D');
final Guid _hrMeasurementUuid = Guid('2A37');

/// UUID estándar Bluetooth SIG para Battery Level (BAS).
final Guid _batteryServiceUuid = Guid('180F');
final Guid _batteryLevelUuid = Guid('2A19');

/// Clase legacy mantenida para compatibilidad con WorkoutSessionProvider.
class HrSample {
  final int bpm;
  final DateTime at;
  final List<double> rrIntervals;
  final bool? sensorContact;
  const HrSample(this.bpm, this.at, {this.rrIntervals = const [], this.sensorContact});
}

/// Servicio aislado de telemetría cardíaca por Bluetooth Low Energy.
///
/// Opera en dos modos:
///   1. **BLE real** — escanea, conecta y parsea datos de una banda HRM
///      estándar (Service 0x180D, Characteristic 0x2A37).
///   2. **Simulación** — fallback automático cuando BLE no está disponible
///      (escritorio, emulador, o si el usuario no tiene banda).
///
/// Expone un stream unificado (`hrStream`) independientemente del modo.
class BleService {
  // ─────────── Stream público ───────────
  final StreamController<HrSample> _hrController =
      StreamController<HrSample>.broadcast();
  Stream<HrSample> get hrStream => _hrController.stream;

  // ─────────── Estado público ───────────
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _deviceName;
  String? get deviceName => _deviceName;

  String _source = 'none';
  String get currentSource => _source;

  BleConnectionState _bleState = BleConnectionState.disconnected;
  BleConnectionState get bleState => _bleState;

  VoidCallback? onStateChanged;

  void _notifyState() {
    onStateChanged?.call();
  }

  // ─────────── Internos BLE ───────────
  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _characteristicSub;
  bool _intentionalDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // ─────────── Internos Simulación ───────────
  Timer? _simTimer;
  final Random _rng = Random();
  bool _simRunning = false;
  double _currentBpm = 80;
  final List<double> _window = [];
  static const int _windowSize = 4;
  String _simPhase = 'idle';
  int _simPhaseT = 0;
  double _simBase = 80;
  double _simCeiling = 165;

  // ─────────── R-R buffer para HRV ───────────
  final List<double> _rrBuffer = [];
  static const int _rrBufferMaxSize = 30;
  List<double> get rrBuffer => List.unmodifiable(_rrBuffer);

  double? get currentRmssd => HeartRateData.calculateRmssd(_rrBuffer);

  // ═══════════════════════════════════════════════════════════════════
  //  CONEXIÓN BLE REAL
  // ═══════════════════════════════════════════════════════════════════

  /// Inicia el escaneo BLE filtrando exclusivamente por el Service UUID
  /// 0x180D (Heart Rate). Al encontrar el primer dispositivo, se conecta
  /// automáticamente.
  Future<void> connectBle() async {
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;

    // Verificar si BLE está disponible y encendido.
    try {
      final isAvailable = await FlutterBluePlus.isSupported;
      if (!isAvailable) {
        debugPrint('[BLE] Bluetooth no soportado en este dispositivo.');
        _fallbackToSimulation();
        return;
      }

      final adapterState = FlutterBluePlus.adapterStateNow;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('[BLE] Bluetooth apagado. Esperando encendido...');
        // Esperar hasta 5s a que se encienda.
        bool turnedOn = false;
        await for (final state in FlutterBluePlus.adapterState.timeout(
          const Duration(seconds: 5),
          onTimeout: (sink) => sink.close(),
        )) {
          if (state == BluetoothAdapterState.on) {
            turnedOn = true;
            break;
          }
        }
        if (!turnedOn) {
          debugPrint('[BLE] Bluetooth no se encendió. Fallback a simulación.');
          _fallbackToSimulation();
          return;
        }
      }
    } catch (e) {
      debugPrint('[BLE] Error verificando BLE: $e. Fallback a simulación.');
      _fallbackToSimulation();
      return;
    }

    _bleState = BleConnectionState.scanning;
    _notifyState();
    debugPrint('[BLE] Iniciando escaneo por Service UUID 180D...');

    // Cancelar escaneo previo si existe.
    await _scanSub?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    // Escanear filtrando EXCLUSIVAMENTE por el Heart Rate Service.
    try {
      await FlutterBluePlus.startScan(
        withServices: [_hrServiceUuid],
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('[BLE] Error iniciando escaneo: $e');
      _fallbackToSimulation();
      return;
    }

    _scanSub = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isEmpty) return;

        // Tomar el primer dispositivo encontrado.
        final result = results.first;
        debugPrint(
          '[BLE] Dispositivo encontrado: ${result.device.platformName} '
          '(${result.device.remoteId})',
        );

        // Detener escaneo y conectar.
        FlutterBluePlus.stopScan();
        _scanSub?.cancel();
        _connectToDevice(result.device);
      },
      onError: (e) {
        debugPrint('[BLE] Error en escaneo: $e');
        _fallbackToSimulation();
      },
      onDone: () {
        // Si el escaneo termina sin encontrar nada.
        if (!_isConnected && _bleState == BleConnectionState.scanning) {
          debugPrint('[BLE] Escaneo finalizado sin resultados.');
          _fallbackToSimulation();
        }
      },
    );
  }

  /// Conecta a un dispositivo BLE específico y suscribe a la característica HR.
  Future<void> _connectToDevice(BluetoothDevice device) async {
    _device = device;
    _bleState = BleConnectionState.connecting;
    _deviceName = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.toString();
    _notifyState();

    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[BLE] Error conectando: $e');
      _attemptReconnect();
      return;
    }

    // Escuchar cambios de estado de conexión para reconexiones.
    _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _onDeviceDisconnected();
      }
    });

    // Descubrir servicios.
    try {
      final services = await device.discoverServices();
      final hrService = services.firstWhere(
        (s) => s.serviceUuid == _hrServiceUuid,
        orElse: () => throw Exception('Heart Rate Service no encontrado'),
      );

      final hrChar = hrService.characteristics.firstWhere(
        (c) => c.characteristicUuid == _hrMeasurementUuid,
        orElse: () => throw Exception('HR Measurement Characteristic no encontrada'),
      );

      // Suscribirse a notificaciones.
      await hrChar.setNotifyValue(true);
      _characteristicSub?.cancel();
      _characteristicSub = hrChar.onValueReceived.listen(
        _onHrBytes,
        onError: (e) => debugPrint('[BLE] Error en notificación HR: $e'),
      );

      _isConnected = true;
      _bleState = BleConnectionState.connected;
      _source = 'ble';
      _reconnectAttempts = 0;
      _notifyState();
      debugPrint('[BLE] ✓ Conectado a $_deviceName — escuchando HR');
    } catch (e) {
      debugPrint('[BLE] Error descubriendo servicios: $e');
      await device.disconnect();
      _attemptReconnect();
    }
  }

  /// Parsea los bytes crudos de la característica 0x2A37 y emite al stream.
  void _onHrBytes(List<int> bytes) {
    final data = HeartRateData.fromBleBytes(bytes);

    // Alimentar buffer R-R para cálculos de HRV.
    for (final rr in data.rrIntervals) {
      _rrBuffer.add(rr);
      if (_rrBuffer.length > _rrBufferMaxSize) _rrBuffer.removeAt(0);
    }

    _hrController.add(HrSample(
      data.bpm,
      data.timestamp,
      rrIntervals: data.rrIntervals,
      sensorContact: data.sensorContact,
    ));
  }

  /// Maneja desconexiones inesperadas del dispositivo BLE.
  void _onDeviceDisconnected() {
    _isConnected = false;
    _bleState = BleConnectionState.disconnected;
    _characteristicSub?.cancel();
    _notifyState();

    if (!_intentionalDisconnect) {
      debugPrint('[BLE] Desconexión inesperada de $_deviceName');
      _attemptReconnect();
    }
  }

  /// Intenta reconectar con backoff exponencial.
  void _attemptReconnect() {
    if (_intentionalDisconnect || _device == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[BLE] Máx. intentos de reconexión alcanzados. Fallback.');
      _fallbackToSimulation();
      return;
    }

    _reconnectAttempts++;
    _bleState = BleConnectionState.reconnecting;
    _notifyState();
    final delay = Duration(seconds: min(2 * _reconnectAttempts, 10));
    debugPrint('[BLE] Reintentando conexión en ${delay.inSeconds}s '
        '(intento $_reconnectAttempts/$_maxReconnectAttempts)');

    Future.delayed(delay, () {
      if (!_intentionalDisconnect && _device != null) {
        _connectToDevice(_device!);
      }
    });
  }

  /// Fallback automático al modo simulación cuando BLE no está disponible.
  void _fallbackToSimulation() {
    _bleState = BleConnectionState.disconnected;
    _isConnected = true; // Simulación siempre "conectada"
    _source = 'simulation';
    _deviceName = 'Simulador HRM';
    _notifyState();
    startSimulation();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MODO SIMULACIÓN (Fallback)
  // ═══════════════════════════════════════════════════════════════════

  /// Alias para compatibilidad.
  void connect() => connectBle();

  void startSimulation() {
    if (_simRunning) return;
    _simRunning = true;
    _simTimer?.cancel();
    _simBase = (80 + _rng.nextInt(14)).toDouble();
    _currentBpm = _simBase;
    _window.clear();
    _simPhase = 'idle';
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) => _step());
  }

  void beginSetModel({int durationSec = 35}) {
    _simPhase = 'rise';
    _simPhaseT = 0;
    _simCeiling = (155 + _rng.nextInt(20)).toDouble();
    _simBase = _currentBpm;
  }

  void endSetModel() {
    _simPhase = 'recovery';
    _simPhaseT = 0;
  }

  void _step() {
    double next;
    switch (_simPhase) {
      case 'idle':
        next = _simBase + (_rng.nextDouble() * 4 - 2);
        break;
      case 'rise':
        final slope = _simPhaseT < 10 ? 2.5 : 1.1;
        next = _currentBpm + slope + (_rng.nextDouble() * 2 - 1);
        if (_simPhaseT >= 12) {
          _simPhase = 'plateau';
          _simPhaseT = 0;
        }
        break;
      case 'plateau':
        next = _currentBpm +
            (0.7 + _rng.nextDouble() * 1.2) +
            (_rng.nextDouble() * 2 - 1);
        if (_currentBpm >= _simCeiling) {
          _simPhase = 'failure';
          _simPhaseT = 0;
        }
        break;
      case 'failure':
        next = _simCeiling + (_rng.nextDouble() * 3 - 1.5);
        _simPhaseT++;
        break;
      case 'recovery':
        next = _currentBpm - 3.2 + (_rng.nextDouble() * 2 - 1);
        if (next < _simBase) {
          next = _simBase;
          _simPhase = 'idle';
        }
        break;
      default:
        next = _simBase;
    }
    _simPhaseT++;

    next = next.clamp(50.0, 210.0);
    final filtered = _movingAverage(next);
    _currentBpm = filtered;

    final bpm = filtered.round();
    // Generar R-R simulado a partir del BPM.
    final simulatedRr = bpm > 0 ? (60000.0 / bpm) : 0.0;
    // Añadir variabilidad al R-R simulado (±15ms).
    final rrWithNoise = simulatedRr + (_rng.nextDouble() * 30 - 15);

    _rrBuffer.add(rrWithNoise);
    if (_rrBuffer.length > _rrBufferMaxSize) _rrBuffer.removeAt(0);

    _hrController.add(HrSample(
      bpm,
      DateTime.now(),
      rrIntervals: [rrWithNoise],
    ));
  }

  double _movingAverage(double value) {
    _window.add(value);
    if (_window.length > _windowSize) _window.removeAt(0);
    return _window.reduce((a, b) => a + b) / _window.length;
  }

  void injectBpm(int bpm) {
    _hrController.add(HrSample(bpm, DateTime.now()));
  }

  void stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    _simRunning = false;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BATERÍA Y DISPOSITIVOS DETECTADOS (para la pantalla Device Sync)
  // ═══════════════════════════════════════════════════════════════════

  /// Escanea dispositivos BLE cercanos (**sin** filtrar por servicio) para
  /// detectar smartwatches/wearables que no anuncian UUIDs estándar en sus
  /// paquetes de publicidad. Devuelve todos los dispositivos con nombre
  /// visible dentro del timeout indicado.
  Future<List<BleScannedDevice>> scanNearbyDevices({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) return const [];
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        return const [];
      }
    } catch (_) {
      return const [];
    }

    final found = <String, BleScannedDevice>{};
    final completer = Completer<List<BleScannedDevice>>();
    StreamSubscription<List<ScanResult>>? sub;

    sub = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final r in results) {
          final name = r.device.platformName;
          final id = r.device.remoteId.toString();
          if (name.isEmpty) continue;
          final key = id;
          if (found.containsKey(key)) continue;
          final serviceUuids = r.advertisementData.serviceUuids;
          found[key] = BleScannedDevice(
            name: name,
            remoteId: id,
            rssi: r.rssi,
            offersHeartRate: serviceUuids.any((u) => u == _hrServiceUuid),
            offersBattery:
                serviceUuids.any((u) => u == _batteryServiceUuid),
          );
          debugPrint('[BLE] Detectado: $name ($id) RSSI=${r.rssi}');
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(found.values.toList());
      },
    );

    try {
      // Sin withServices → escaneo amplio de todos los dispositivos BLE.
      await FlutterBluePlus.startScan(
        timeout: timeout,
      );
    } catch (e) {
      debugPrint('[BLE] Error iniciando escaneo amplio: $e');
      sub?.cancel();
      return found.values.toList();
    }

    final list = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => found.values.toList(),
    );
    await sub.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    debugPrint('[BLE] Escaneo amplio finalizado: ${list.length} dispositivos');
    return list;
  }

  /// Lee el nivel de batería (0–100) del wearable actualmente conectado.
  /// Si no hay dispositivo conectado o el servicio BAS no está expuesto,
  /// retorna null.
  Future<int?> readBatteryLevel() async {
    final device = _device;
    if (device == null || !device.isConnected) return null;
    try {
      final services = await device.discoverServices();
      final bas = services.firstWhere(
        (s) => s.serviceUuid == _batteryServiceUuid,
        orElse: () => throw Exception('Battery Service no encontrado'),
      );
      final char = bas.characteristics.firstWhere(
        (c) => c.characteristicUuid == _batteryLevelUuid,
        orElse: () => throw Exception('Battery Level char no encontrado'),
      );
      final value = await char.read();
      if (value.isNotEmpty) return value.first.clamp(0, 100);
      return null;
    } catch (e) {
      debugPrint('[BLE] readBatteryLevel error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DESCONEXIÓN Y LIMPIEZA
  // ═══════════════════════════════════════════════════════════════════

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _characteristicSub?.cancel();
    stopSimulation();

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (e) {
        debugPrint('[BLE] Error desconectando: $e');
      }
    }

    _isConnected = false;
    _bleState = BleConnectionState.disconnected;
    _deviceName = null;
    _source = 'none';
    _notifyState();
  }

  void dispose() {
    _intentionalDisconnect = true;
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _characteristicSub?.cancel();
    stopSimulation();
    _hrController.close();
  }
}

/// Estados de conexión BLE para la UI.
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
}

/// Dispositivo BLE detectado durante un escaneo (sin conexión).
class BleScannedDevice {
  const BleScannedDevice({
    required this.name,
    required this.remoteId,
    required this.rssi,
    required this.offersHeartRate,
    required this.offersBattery,
  });
  final String name;
  final String remoteId;
  final int rssi;
  final bool offersHeartRate;
  final bool offersBattery;
}