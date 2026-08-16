import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  // `Health().configure()` habla con plugins nativos por MethodChannel. En un
  // test unitario no hay plataforma detrás, así que hay que (1) inicializar el
  // binding y (2) simular el canal de device_info: sin lo primero falla con
  // "Binding has not yet been initialized" y sin lo segundo con
  // MissingPluginException.
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceInfoChannel =
      MethodChannel('dev.fluttercommunity.plus/device_info');

  // El host de test resuelve por la rama iOS de device_info_plus, así que el
  // mock tiene que devolver el mapa completo que espera `IosDeviceInfo.fromMap`
  // (sus campos no son nullable y revienta con un mapa parcial).
  final fakeIosDeviceInfo = <String, dynamic>{
    'name': 'test-device',
    'systemName': 'iOS',
    'systemVersion': '17.0',
    'model': 'iPhone',
    'modelName': 'iPhone 15',
    'localizedModel': 'iPhone',
    'identifierForVendor': '00000000-0000-0000-0000-000000000000',
    'freeDiskSize': 0,
    'totalDiskSize': 0,
    'isPhysicalDevice': false,
    'physicalRamSize': 0,
    'availableRamSize': 0,
    'isiOSAppOnMac': false,
    'isiOSAppOnVision': false,
    'utsname': <String, dynamic>{
      'sysname': 'Darwin',
      'nodename': 'test',
      'release': '23.0.0',
      'version': 'test',
      'machine': 'x86_64',
    },
  };

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, (call) async {
      if (call.method == 'getDeviceInfo') return fakeIosDeviceInfo;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, null);
  });

  test('configure() no lanza con los canales nativos simulados', () async {
    await Health().configure();
  });
}
