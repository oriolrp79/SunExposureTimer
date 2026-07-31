import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'package:sun_timer/main.dart';

void main() {
  testWidgets('Onboarding and 10s Demo Countdown Test', (WidgetTester tester) async {
    // Configurar el tamaño de la pantalla del test para simular un móvil típico (400x800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'check' || methodCall.method == 'checkConnectivity') {
        return ['wifi'];
      }
      return null;
    });

    const statusChannel = EventChannel('dev.fluttercommunity.plus/connectivity_status');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(statusChannel, MockStreamHandler.inline(
      onListen: (arguments, events) {
        events.success(['wifi']);
      },
      onCancel: (arguments) {},
    ));

    SharedPreferences.setMockInitialValues({
      'app_language': 'es',
      'manual_city': 'Madrid',
      'manual_lat': 40.4167,
      'manual_lon': -3.7037,
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(const SunTimerApp());

    // Esperar a que se carguen las preferencias y se renderice el onboarding.
    await tester.pumpAndSettle();

    // Verificar que aparece el nombre de la app o elementos del onboarding.
    expect(find.text('Sun Exposure Timer'), findsOneWidget);
    expect(find.text('Selecciona tu tipo de piel'), findsOneWidget);

    // Seleccionar tipo de piel (Tipo I)
    await tester.tap(find.text('Tipo I'));
    await tester.pump();

    // Tap "Aceptar"
    await tester.tap(find.text('Aceptar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verificar que se muestra el tiempo seguro estimado automáticamente y el botón de demo
    expect(find.text('Tiempo seguro de exposición solar'), findsOneWidget);
    expect(find.text('Demo 10s'), findsOneWidget);

    // Tap "Demo 10s" para iniciar la cuenta atrás de demo de 10 segundos
    await tester.tap(find.text('Demo 10s'));
    await tester.pump();

    // Verificar que se muestra el contador en 10 s
    expect(find.text('10 s'), findsOneWidget);

    // Avanzar el tiempo 10 segundos (1 segundo a la vez para asegurar que el temporizador periódico se dispare)
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // Esperar a que el diálogo se dibuje por completo
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verificar que aparece el diálogo de límite diario alcanzado
    expect(find.text('¡Límite diario alcanzado!'), findsOneWidget);

    // Cerrar el diálogo pulsando "Entendido"
    await tester.tap(find.text('Entendido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verificar que volvemos al estado inicial y no estamos bloqueados
    expect(find.text('Tiempo seguro de exposición solar'), findsOneWidget);
  });
}
