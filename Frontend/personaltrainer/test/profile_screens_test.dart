import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/auth/presentation/screens/register_flow_page.dart';
import 'package:personaltrainer/src/features/profile/presentation/screens/profile_setup_page.dart';
import 'package:personaltrainer/src/features/profile/presentation/widgets/profile_fields.dart';

/// Las dos pantallas de perfil son formularios largos con mucho widget
/// compuesto (anillos y donuts pintados a mano, rejillas, chips). `flutter
/// analyze` no las ejecuta, así que un fallo de layout o un `null` en un campo
/// vacío solo se vería abriendo la app a mano.
///
/// Estos tests las montan de verdad y comprueban que no lanzan. Van sin sesión
/// a propósito: es el caso de un usuario nuevo y el que más `null` atraviesa.
void main() {
  Widget envolver(Widget hijo) => MaterialApp(home: hijo);

  group('Configurador de perfil', () {
    testWidgets('se monta sin sesión y avisa en vez de reventar',
        (tester) async {
      await tester.pumpWidget(envolver(const ProfileSetupPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Configurador de perfil'), findsOneWidget);
      expect(find.textContaining('No hay sesión activa'), findsOneWidget);
    });
  });

  group('Registro por pasos', () {
    testWidgets('abre en el primer paso', (tester) async {
      await tester.pumpWidget(envolver(const RegisterFlowPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('PASO 1 DE 5'), findsOneWidget);
      expect(find.text('Crea tu cuenta'), findsOneWidget);
    });

    testWidgets('no deja pasar del primer paso con el formulario vacío',
        (tester) async {
      await tester.pumpWidget(envolver(const RegisterFlowPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe tu nombre.'), findsOneWidget);
      expect(find.text('PASO 1 DE 5'), findsOneWidget);
    });

    testWidgets('avanza al paso de mínimos con la cuenta rellena',
        (tester) async {
      await tester.pumpWidget(envolver(const RegisterFlowPage()));
      await tester.pumpAndSettle();

      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Ana Pérez');
      await tester.enterText(campos.at(1), 'ana@ejemplo.com');
      await tester.enterText(campos.at(2), 'secreta1');
      await tester.enterText(campos.at(3), 'secreta1');

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('PASO 2 DE 5'), findsOneWidget);
      // Altura y peso son los únicos campos marcados como obligatorios.
      expect(find.text('OBLIGATORIO'), findsNWidgets(3));
    });

    testWidgets('las contraseñas que no coinciden se cazan antes de avanzar',
        (tester) async {
      await tester.pumpWidget(envolver(const RegisterFlowPage()));
      await tester.pumpAndSettle();

      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Ana Pérez');
      await tester.enterText(campos.at(1), 'ana@ejemplo.com');
      await tester.enterText(campos.at(2), 'secreta1');
      await tester.enterText(campos.at(3), 'otracosa');

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Las dos contraseñas no coinciden.'), findsOneWidget);
    });
  });

  group('Donut de macros', () {
    // El aviso de descuadre es la única parte de la pantalla que hace un
    // cálculo, y compara dos campos que se editan por separado: es justo donde
    // un error pasaría desapercibido.
    test('detecta cuando los macros no suman las calorías declaradas', () {
      // 165·4 + 290·4 + 75·9 = 2495 kcal frente a una meta de 2650.
      const descuadrado = MacroDonut(
        kcal: 2650,
        proteinas: 165,
        carbohidratos: 290,
        grasas: 75,
      );
      expect(descuadrado.kcalDeMacros, 2495);
      expect(descuadrado.descuadra, isTrue);
    });

    test('tolera el redondeo de gramos a enteros', () {
      // 165·4 + 330·4 + 74·9 = 2646 kcal: 4 kcal de diferencia sobre 2650 es
      // redondeo, no un error que merezca avisar.
      const cuadrado = MacroDonut(
        kcal: 2650,
        proteinas: 165,
        carbohidratos: 330,
        grasas: 74,
      );
      expect(cuadrado.descuadra, isFalse);
    });

    test('no avisa si falta algún macro por rellenar', () {
      const incompleto = MacroDonut(
        kcal: 2650,
        proteinas: 165,
        carbohidratos: null,
        grasas: 75,
      );
      expect(incompleto.kcalDeMacros, isNull);
      expect(incompleto.descuadra, isFalse);
    });
  });
}
