import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/round_icon_button.dart';
import '../../../../services/health_service.dart';

/// Pantalla de gestión de wearables — réplica de `devices.tsx`.
///
/// Escanea dispositivos BLE reales (emparejados + conectados + cercanos) y
/// carga pasos/FC de hoy desde Health Connect al abrir la pantalla.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, this.onBack, this.onForceSync});

  final VoidCallback? onBack;
  final VoidCallback? onForceSync;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  bool _loading = true;          // scan BLE en curso
  bool _metricsLoading = true;   // pasos/HR en curso
  List<BluetoothDevice> _found = [];
  Set<DeviceIdentifier> _connectedOrBondedIds = {};
  int _stepsToday = 0;
  int? _lastHr;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _scanBLE();
    _loadMetrics();
  }

  Future<void> _scanBLE() async {
    if (mounted) setState(() => _loading = true);
    try {
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      // 1. Dispositivos ya emparejados (Android)
      List<BluetoothDevice> bonded = [];
      try { bonded = await FlutterBluePlus.bondedDevices; } catch (_) {}

      // 2. Dispositivos actualmente conectados por GATT
      final connected = FlutterBluePlus.connectedDevices;

      // 3. Scan activo 5 s
      final scanned = <BluetoothDevice>[];
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (!scanned.any((d) => d.remoteId == r.device.remoteId)) {
            scanned.add(r.device);
          }
        }
      });
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
        await Future.delayed(const Duration(seconds: 5));
      } catch (_) {}
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();

      // Combinar + deduplicar
      final all = [...bonded, ...connected, ...scanned];
      final seen = <DeviceIdentifier>{};
      final unique = all.where((d) => seen.add(d.remoteId)).toList();

      // Trackear IDs de dispositivos realmente conectados/emparejados
      final bondedAndConnectedIds = <DeviceIdentifier>{};
      for (final d in bonded) bondedAndConnectedIds.add(d.remoteId);
      for (final d in connected) bondedAndConnectedIds.add(d.remoteId);

      if (mounted) setState(() {
        _found = unique;
        _connectedOrBondedIds = bondedAndConnectedIds;
        _loading = false;
      });
    } catch (e) {
      print('[BLE] scan error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMetrics() async {
    if (mounted) setState(() => _metricsLoading = true);
    try {
      final steps = await HealthService.fetchTodaySteps();
      final hr    = await HealthService.fetchLatestHeartRate();
      if (mounted) setState(() {
        _stepsToday     = steps;
        _lastHr         = hr;
        _metricsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _metricsLoading = false);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  bool _isXiaomi(BluetoothDevice d) {
    final n = d.platformName.toLowerCase();
    return n.contains('redmi') || n.contains('xiaomi') ||
        n.contains('mi watch') || n.contains('mi band') ||
        n.contains('watch') || n.contains('band');
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    final primary = _found.where(_isXiaomi).firstOrNull;
    final others  = _found.where((d) => !_isXiaomi(d)).toList();

    final primaryDevice = PrimaryDevice(
      name: (primary?.platformName.isNotEmpty ?? false)
          ? primary!.platformName
          : 'Redmi Watch 5',
      sub: primary != null
          ? 'Emparejado · Bluetooth activo'
          : 'No detectado — abre Mi Fitness y activa BT',
    );

    final syncState = DeviceSyncState(
      badgeLabel: primary != null ? 'XIAOMI' : 'SIN SEÑAL',
      liveLabel: primary != null
          ? 'BLE activo · sincronizando'
          : 'Sin conexión BLE',
      syncing: primary != null,
    );

    final stepsStr = _metricsLoading ? '…' : _stepsToday.toString();
    final hrStr    = _metricsLoading ? '…'
        : (_lastHr != null ? _lastHr!.toString() : '--');

    final metrics = [
      DeviceMetric(label: 'Pasos hoy',   value: stepsStr, suffix: 'steps'),
      DeviceMetric(label: 'FC reciente', value: hrStr,    suffix: 'bpm'),
    ];

    final otherDevices = <OtherDevice>[
      // Solo mostrar dispositivos realmente conectados/emparejados, no los detectados por scan
      ...others
        .where((d) => _connectedOrBondedIds.contains(d.remoteId))
        .map((d) => OtherDevice(
          icon: LucideIcons.bluetooth,
          name: d.platformName.isNotEmpty ? d.platformName : 'Dispositivo BLE',
          sub: d.remoteId.str,
          status: 'Conectado',
        )),
      const OtherDevice(
        icon: LucideIcons.smartphone,
        name: 'Mi Fitness App',
        sub: 'Android · fuente de datos',
        status: 'Activo',
      ),
      const OtherDevice(
        icon: LucideIcons.database,
        name: 'Health Connect',
        sub: 'Google API · sincronización pasiva',
        status: 'Conectado',
      ),
    ];

    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(title: 'Device Sync Center', onBack: widget.onBack),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 20),
                _PrimaryDeviceCard(
                  device: primaryDevice,
                  metrics: metrics,
                  syncState: syncState,
                ),
                const SizedBox(height: 20),
                _OtherDevicesCard(devices: otherDevices),
                const SizedBox(height: 20),
                _PrimarySyncButton(onTap: () {
                  _scanBLE();
                  _loadMetrics();
                  widget.onForceSync?.call();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── Top bar ─────────────────────── */

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Row(
        children: [
          RoundIconButton(icon: LucideIcons.arrowLeft, onTap: onBack ?? () => Navigator.maybePop(context)),
          const SizedBox(width: 12),
          Text(title.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
        ],
      ),
    );
  }
}

/* ─────────────────────── Badge "Device" (XIAOMI-like) ─────────────────────── */

/// Réplica visual del badge "XIAOMI" / "SINCRONIZANDO" de home_page.dart.
/// El texto proviene de `DeviceSyncState` (inyectado), igual que en home.
class _DeviceBadge extends StatelessWidget {
  const _DeviceBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
      decoration: BoxDecoration(
        color: DesignTokens.deviceBadgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: DesignTokens.deviceBadgeDot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.foreground(Brightness.dark), fontSize: 9)),
        ],
      ),
    );
  }
}

/* ─────────────────────── Live sync pill ─────────────────────── */

class _LiveSyncPill extends StatelessWidget {
  const _LiveSyncPill({required this.state});
  final DeviceSyncState state;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: DesignTokens.deviceLive.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesignTokens.deviceLive.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: DesignTokens.deviceLive),
          const SizedBox(width: 8),
          Text(state.liveLabel,
              style: DesignTokens.bodyFont(fontSize: 11, weight: FontWeight.w600, color: DesignTokens.deviceLive)),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.7, end: 0.0).animate(_c),
            child: ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.6).animate(_c),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color.withOpacity(0.4), shape: BoxShape.circle)),
            ),
          ),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

/* ─────────────────────── Primary device ─────────────────────── */

class _PrimaryDeviceCard extends StatelessWidget {
  const _PrimaryDeviceCard({required this.device, required this.metrics, required this.syncState});
  final PrimaryDevice device;
  final List<DeviceMetric> metrics;
  final DeviceSyncState syncState;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DeviceBadge(label: 'Device'),
                    const SizedBox(height: 12),
                    Text(
                      device.name, 
                      style: DesignTokens.titleFont(fontSize: 22, color: DesignTokens.foreground(b), height: 1.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.sub, 
                      style: DesignTokens.bodyFont(fontSize: 12, color: DesignTokens.mutedForeground(b)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _LiveSyncPill(state: syncState),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final m in metrics) ...[
                if (m != metrics.first) const SizedBox(width: 10),
                Expanded(child: _DeviceMetricTile(metric: m)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceMetricTile extends StatelessWidget {
  const _DeviceMetricTile({required this.metric});
  final DeviceMetric metric;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: DesignTokens.bodyFont(fontSize: 13, weight: FontWeight.w700, color: DesignTokens.foreground(b), height: 1.1),
              children: [
                TextSpan(text: metric.value),
                if (metric.suffix != null)
                  TextSpan(
                    text: ' ${metric.suffix}',
                    style: DesignTokens.bodyFont(fontSize: 10, color: DesignTokens.mutedForeground(b), weight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Other devices ─────────────────────── */

class _OtherDevicesCard extends StatelessWidget {
  const _OtherDevicesCard({required this.devices});
  final List<OtherDevice> devices;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Otros dispositivos'.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
          const SizedBox(height: 12),
          for (final d in devices) ...[
            _OtherDeviceTile(device: d),
            if (d != devices.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _OtherDeviceTile extends StatelessWidget {
  const _OtherDeviceTile({required this.device});
  final OtherDevice device;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Opacity(
      opacity: device.muted ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignTokens.surface1(b),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(device.icon, size: 16, color: DesignTokens.foreground(b)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: DesignTokens.bodyFont(fontSize: 13, weight: FontWeight.w600, color: DesignTokens.foreground(b), height: 1.1)),
                  const SizedBox(height: 2),
                  Text(device.sub, style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
                ],
              ),
            ),
            Text(device.status.toUpperCase(),
                style: DesignTokens.labelSmall(color: device.muted ? DesignTokens.mutedForeground(b) : DesignTokens.deviceLive, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── Force sync CTA ─────────────────────── */

class _PrimarySyncButton extends StatelessWidget {
  const _PrimarySyncButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          gradient: DesignTokens.aiGradient,
          borderRadius: BorderRadius.all(Radius.circular(18)),
          boxShadow: [BoxShadow(color: Color(0x8C6A5CF0), blurRadius: 28, spreadRadius: -12, offset: Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.sparkles, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text('Forzar Sincronización AI', style: DesignTokens.titleFont(fontSize: 15, letterSpacing: 0, color: Colors.white, weight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(LucideIcons.refreshCw, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────── Models ─────────────────────── */

@immutable
class PrimaryDevice {
  const PrimaryDevice({required this.name, required this.sub});
  final String name;
  final String sub;
}

@immutable
class DeviceMetric {
  const DeviceMetric({required this.label, required this.value, this.suffix});
  final String label;
  final String value;
  final String? suffix;
}

/// Estado de sincronización compartido con el badge de `home_page.dart`.
/// `liveLabel` se renderiza tal cual dentro del pill verde (ej.
/// "Syncing data from Health Connect…"), y `badgeLabel` en el badge negro
/// "Device" (ej. "XIAOMI" / "SINCRONIZANDO").
@immutable
class DeviceSyncState {
  const DeviceSyncState({required this.badgeLabel, required this.liveLabel, this.syncing = true});
  final String badgeLabel;
  final String liveLabel;
  final bool syncing;
}

@immutable
class OtherDevice {
  const OtherDevice({
    required this.icon,
    required this.name,
    required this.sub,
    required this.status,
    this.muted = false,
  });
  final IconData icon;
  final String name;
  final String sub;
  final String status;
  final bool muted;
}
