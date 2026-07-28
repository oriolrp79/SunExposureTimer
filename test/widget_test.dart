import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'package:sun_timer/main.dart';

void main() {
  testWidgets('Onboarding and 10s Demo Countdown Test', (WidgetTester tester) async {
    // Configurar el tamaño de la pantalla del test para simular un móvil típico (400x800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'app_language': 'es'});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const SunTimerApp());

    // Esperar a que se carguen las preferencias y se renderice el onboarding.
    await tester.pumpAndSettle();

    // Verificar que aparece el nombre de la app o elementos del onboarding.
    expect(find.text('Temporizador de Exposición Solar'), findsOneWidget);
    expect(find.text('Selecciona tu tipo de piel'), findsOneWidget);

    // Seleccionar tipo de piel (Tipo I)
    await tester.tap(find.text('Tipo I'));
    await tester.pump();

    // Tap "Aceptar"
    await tester.tap(find.text('Aceptar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verificar que se muestra el tiempo seguro estimado automáticamente y el botón de demo
    expect(find.text('Tiempo Seguro Estimado'), findsOneWidget);
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
    expect(find.text('Tiempo Seguro Estimado'), findsOneWidget);
  });
}
