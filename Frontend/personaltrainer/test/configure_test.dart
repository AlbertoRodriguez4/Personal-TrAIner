import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  test('Check configure', () {
    Health().configure();
    print("Configure executed");
  });
}
