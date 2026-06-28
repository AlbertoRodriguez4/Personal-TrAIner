import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  test('Print HealthDataTypes', () {
    print("Health Data Types:");
    for (var type in HealthDataType.values) {
      print(type.toString());
    }
  });
}
