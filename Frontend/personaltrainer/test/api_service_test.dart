import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltrainer/src/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JWT con el `exp` pedido. La firma da igual: la app nunca la valida, solo
/// lee el `exp` para no restaurar una sesión que ya caducó.
String _jwt({required DateTime exp}) {
  String b64(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.'
      '${b64({'sub': 'u1', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.firma';
}

final _tokenVigente = _jwt(exp: DateTime.now().add(const Duration(days: 30)));

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Ejecuta [cuerpo] con todas las llamadas de `package:http` servidas por
/// [manejador], sin red.
Future<T> _conServidor<T>(
  Future<http.Response> Function(http.Request) manejador,
  Future<T> Function() cuerpo,
) => http.runWithClient(cuerpo, () => MockClient(manejador));

Future<void> _iniciarSesion() => _conServidor(
  (_) async => _json({
    'id': 'u1',
    'nombre_completo': 'Ana',
    'access_token': _tokenVigente,
  }, 200),
  () => ApiService.login('ana@x.dev', 'secret123'),
);

Future<Map<String, dynamic>> _sesionGuardada() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString('pt_session_user')!)
      as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService.logout();
    ApiService.onSesionCaducada = null;
  });

  group('errores de petición', () {
    test('el mensaje del backend llega sin el prefijo "Exception:"', () async {
      await _iniciarSesion();
      final error = await _conServidor(
        (_) async => _json({
          'message': ['El peso debe ser un número', 'Falta la fecha'],
        }, 400),
        () => ApiService.getDailySummary('u1'),
      ).then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<ApiException>());
      expect(
        '$error',
        'El peso debe ser un número, Falta la fecha',
      );
      expect((error as ApiException).statusCode, 400);
    });

    test('un timeout se traduce a un mensaje que invita a reintentar',
        () async {
      await _iniciarSesion();
      await expectLater(
        _conServidor(
          (_) => Future.error(TimeoutException('lento')),
          () => ApiService.getDailySummary('u1'),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.esTimeout, 'esTimeout', isTrue)
              .having((e) => '$e', 'texto', contains('vuelve a intentarlo')),
        ),
      );
    });

    test('sin red: mensaje de conexión, no el volcado de ClientException',
        () async {
      await _iniciarSesion();
      await expectLater(
        _conServidor(
          (_) => Future.error(http.ClientException('Connection refused')),
          () => ApiService.getDailySummary('u1'),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.sinConexion, 'sinConexion', isTrue)
              .having((e) => '$e', 'texto', isNot(contains('ClientException'))),
        ),
      );
    });
  });

  group('login', () {
    test('contraseña incorrecta: el motivo real, sin echar a nadie', () async {
      var avisos = 0;
      ApiService.onSesionCaducada = () => avisos++;

      await expectLater(
        _conServidor(
          (_) async => _json({
            'message': 'Credenciales incorrectas (Contraseña inválida).',
          }, 401),
          () => ApiService.login('ana@x.dev', 'mal'),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => '$e',
            'texto',
            'Credenciales incorrectas (Contraseña inválida).',
          ),
        ),
      );
      expect(avisos, 0);
      expect(ApiService.isAuthenticated(), isFalse);
    });

    test('servidor dormido: no se confunde con credenciales incorrectas',
        () async {
      await expectLater(
        _conServidor(
          (_) => Future.error(TimeoutException('cold start')),
          () => ApiService.login('ana@x.dev', 'secret123'),
        ),
        throwsA(isA<ApiException>().having((e) => e.esTimeout, 'esTimeout', isTrue)),
      );
    });

    test('el registro deja la sesión abierta con el token de la respuesta',
        () async {
      await _conServidor(
        (_) async => _json({
          'id': 'u2',
          'nombre_completo': 'Leo',
          'access_token': _tokenVigente,
        }, 201),
        () => ApiService.register(
          nombreCompleto: 'Leo',
          email: 'leo@x.dev',
          password: 'secret123',
          fechaNacimiento: '1990-01-01',
          estatura: 180,
          peso: 80,
        ),
      );
      expect(ApiService.isAuthenticated(), isTrue);
      expect(ApiService.getCurrentUserId(), 'u2');
    });
  });

  group('sesión caducada', () {
    test('un 401 con sesión la cierra y avisa una sola vez', () async {
      await _iniciarSesion();
      var avisos = 0;
      ApiService.onSesionCaducada = () => avisos++;

      Future<Object?> peticion() => _conServidor(
        (_) async => _json({'message': 'Sesión caducada o token inválido.'}, 401),
        () => ApiService.getDailySummary('u1'),
      ).then<Object?>((_) => null, onError: (Object e) => e);

      // Dos pantallas cargando a la vez: las dos fallan, pero el login se abre
      // una vez.
      final errores = await Future.wait([peticion(), peticion()]);

      expect(errores, everyElement(isA<ApiException>()));
      expect(avisos, 1);
      expect(ApiService.isAuthenticated(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pt_session_user'), isNull);
    });
  });

  group('persistencia de la sesión', () {
    test('editar el perfil no pierde el token guardado', () async {
      await _iniciarSesion();

      // `PUT /users/:id` devuelve el usuario sin `access_token`.
      final ok = await _conServidor(
        (_) async => _json({'id': 'u1', 'nombre_completo': 'Ana B.'}, 200),
        () => ApiService.updateUser('u1', {'nombre_completo': 'Ana B.'}),
      );
      expect(ok, isTrue);

      final guardada = await _sesionGuardada();
      expect(guardada['nombre_completo'], 'Ana B.');
      expect(guardada['access_token'], _tokenVigente);

      // "Siguiente arranque": la sesión se reconstruye desde lo guardado.
      await ApiService.restoreSession();
      expect(ApiService.isAuthenticated(), isTrue);
      expect(ApiService.authToken, _tokenVigente);
    });

    test('un token caducado no se restaura: se abre el login', () async {
      SharedPreferences.setMockInitialValues({
        'pt_session_user': jsonEncode({
          'id': 'u1',
          'access_token': _jwt(
            exp: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        }),
      });

      await ApiService.restoreSession();

      expect(ApiService.isAuthenticated(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pt_session_user'), isNull);
    });

    test('tokenCaducado lee el exp y no bloquea con tokens ilegibles', () {
      final ahora = DateTime(2026, 9, 24, 12);
      expect(
        ApiService.tokenCaducado(
          _jwt(exp: ahora.add(const Duration(hours: 1))),
          ahora: ahora,
        ),
        isFalse,
      );
      expect(
        ApiService.tokenCaducado(
          _jwt(exp: ahora.subtract(const Duration(seconds: 1))),
          ahora: ahora,
        ),
        isTrue,
      );
      // Sin poder leerlo, que decida el backend.
      expect(ApiService.tokenCaducado('no-es-un-jwt', ahora: ahora), isFalse);
    });
  });
}
