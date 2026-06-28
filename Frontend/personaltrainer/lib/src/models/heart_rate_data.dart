/// Modelo de datos para una medición de frecuencia cardíaca.
///
/// Parsea los bytes de la característica BLE Heart Rate Measurement (0x2A37)
/// según la especificación Bluetooth SIG GATT.
class HeartRateData {
  /// Pulsaciones por minuto.
  final int bpm;

  /// Intervalos R-R en milisegundos.
  /// Vacío si el sensor no los reporta (bit 4 de flags = 0).
  final List<double> rrIntervals;

  /// Instante de la lectura.
  final DateTime timestamp;

  /// Indica si el sensor tiene contacto con la piel.
  /// `null` si el sensor no reporta este estado.
  final bool? sensorContact;

  /// Energía gastada acumulada en kJ (si el sensor la reporta).
  final int? energyExpended;

  const HeartRateData({
    required this.bpm,
    this.rrIntervals = const [],
    required this.timestamp,
    this.sensorContact,
    this.energyExpended,
  });

  /// Calcula la variabilidad de la frecuencia cardíaca (RMSSD) a partir
  /// de una ventana de intervalos R-R sucesivos.
  static double? calculateRmssd(List<double> rrValues) {
    if (rrValues.length < 2) return null;
    double sumSquares = 0;
    int count = 0;
    for (int i = 1; i < rrValues.length; i++) {
      final diff = rrValues[i] - rrValues[i - 1];
      sumSquares += diff * diff;
      count++;
    }
    if (count == 0) return null;
    return _sqrt(sumSquares / count);
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }

  /// Parsea los bytes crudos de la característica Heart Rate Measurement
  /// (UUID 0x2A37) según la especificación Bluetooth SIG.
  ///
  /// Referencia: GATT Specification Supplement, Heart Rate Measurement.
  factory HeartRateData.fromBleBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return HeartRateData(bpm: 0, timestamp: DateTime.now());
    }

    final flags = bytes[0];
    int offset = 1;

    // ── Bit 0: Formato del valor de Heart Rate ──
    // 0 = UINT8 (1 byte), 1 = UINT16 (2 bytes Little Endian)
    final bool is16Bit = (flags & 0x01) != 0;
    int bpm;
    if (is16Bit) {
      bpm = (bytes.length > 2)
          ? bytes[1] | (bytes[2] << 8)
          : (bytes.length > 1 ? bytes[1] : 0);
      offset = 3;
    } else {
      bpm = (bytes.length > 1) ? bytes[1] : 0;
      offset = 2;
    }

    // ── Bits 1-2: Estado de contacto del sensor ──
    // Bit 1: Sensor Contact Status supported
    // Bit 2: Sensor Contact Status value (1 = contacto detectado)
    bool? sensorContact;
    if ((flags & 0x02) != 0) {
      sensorContact = (flags & 0x04) != 0;
    }

    // ── Bit 3: Energy Expended presente ──
    int? energyExpended;
    if ((flags & 0x08) != 0) {
      if (offset + 1 < bytes.length) {
        energyExpended = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;
      }
    }

    // ── Bit 4: Intervalos R-R presentes ──
    // Cada intervalo R-R ocupa 2 bytes (UINT16 Little Endian).
    // La unidad es 1/1024 segundos → convertir a milisegundos.
    final List<double> rrIntervals = [];
    if ((flags & 0x10) != 0) {
      while (offset + 1 < bytes.length) {
        final raw = bytes[offset] | (bytes[offset + 1] << 8);
        final rrMs = (raw / 1024.0) * 1000.0;
        rrIntervals.add(rrMs);
        offset += 2;
      }
    }

    return HeartRateData(
      bpm: bpm,
      rrIntervals: rrIntervals,
      timestamp: DateTime.now(),
      sensorContact: sensorContact,
      energyExpended: energyExpended,
    );
  }

  @override
  String toString() =>
      'HeartRateData(bpm: $bpm, rr: $rrIntervals, contact: $sensorContact)';
}
