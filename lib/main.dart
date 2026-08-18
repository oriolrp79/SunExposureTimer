import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ambient_light/ambient_light.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'search_city_bottom_sheet.dart';
import 'services/ip_location_service.dart';
import 'services/notification_service.dart';

// --- CONFIGURACIÓN DE MODO DEMO ---
// Cambiar a 'true' para visualizar el botón "Demo 30s" o 'false' para ocultarlo.
const bool showDemoButton = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();

  // Pre-carrega de SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Carregar preferència d'idioma i establir-la immediatament en el ValueNotifier global
  final String selectedLang =
      prefs.getString('app_language') ?? getSystemLanguageCode();
  appLanguage.value = selectedLang;

  // Carregar preferència de fototipus de pell
  final int? savedSkinType = prefs.containsKey('skin_type')
      ? prefs.getInt('skin_type')
      : null;

  MobileAds.instance.initialize();

  // Permet que l'aplicació es dibuixi sota les barres del sistema (edge-to-edge) per permetre transparències reals
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black, // Barra de navegació en negre
      systemNavigationBarContrastEnforced:
          false, // OBLIGATORI per a Android 10+
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness
          .light, // Icons de la barra de navegació en blanc (contrastats)
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(SunTimerApp(initialSkinType: savedSkinType));
}

/// Clase que define los fototipos de la escala de Fitzpatrick.
class FitzpatrickType {
  final int index;
  final String name;
  final String description;
  final Color color;
  final int dose; // Dosis de tolerancia en J/m² (simplificada)

  const FitzpatrickType({
    required this.index,
    required this.name,
    required this.description,
    required this.color,
    required this.dose,
  });
}

/// Lista oficial de fototipos de Fitzpatrick con sus colores y dosis recomendadas.
const List<FitzpatrickType> fitzpatrickTypes = [
  FitzpatrickType(
    index: 0,
    name: "Tipo I",
    description: "Muy clara. Siempre se quema, nunca se broncea.",
    color: Color(0xFFFDF0ED),
    dose: 200,
  ),
  FitzpatrickType(
    index: 1,
    name: "Tipo II",
    description: "Clara. Se quema fácilmente, se broncea mínimamente.",
    color: Color(0xFFFFDDC7),
    dose: 250,
  ),
  FitzpatrickType(
    index: 2,
    name: "Tipo III",
    description: "Media. Se quema moderadamente, se broncea gradualmente.",
    color: Color(0xFFE5C298),
    dose: 350,
  ),
  FitzpatrickType(
    index: 3,
    name: "Tipo IV",
    description: "Oscura. Se quema mínimamente, se broncea bien.",
    color: Color(0xFFC59B73),
    dose: 450,
  ),
  FitzpatrickType(
    index: 4,
    name: "Tipo V",
    description: "Muy oscura. Raramente se quema, se broncea intensamente.",
    color: Color(0xFF8F5D38),
    dose: 600,
  ),
  FitzpatrickType(
    index: 5,
    name: "Tipo VI",
    description: "Negra. Nunca se quema, se broncea profundamente.",
    color: Color(0xFF4A2E1D),
    dose: 1000,
  ),
];

String getSystemLanguageCode() {
  if (kIsWeb) return 'en';
  try {
    final locale = Platform.localeName;
    if (locale.length >= 2) {
      final code = locale.substring(0, 2).toLowerCase();
      final supported = ['en', 'es', 'de', 'fr', 'it', 'pt', 'ca'];
      if (supported.contains(code)) {
        return code;
      }
    }
  } catch (e) {
    debugPrint("Error detecting locale: $e");
  }
  return 'en';
}

final ValueNotifier<String> appLanguage = ValueNotifier<String>(
  getSystemLanguageCode(),
);

class AppTranslations {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title':
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      'select_skin_type': 'Select your skin type',
      'silence_alarm': 'Mute Alarm',
      'onboarding_desc':
          'Your skin type (Fitzpatrick scale) determines your sun sensitivity and the safe UV radiation dose you can receive before suffering skin burns.',
      'accept': 'Accept',
      'skin_type_1_name': 'Type I',
      'skin_type_1_desc': 'Very fair. Always burns, never tans.',
      'skin_type_2_name': 'Type II',
      'skin_type_2_desc': 'Fair. Burns easily, tans minimally.',
      'skin_type_3_name': 'Type III',
      'skin_type_3_desc': 'Medium. Burns moderately, tans gradually.',
      'skin_type_4_name': 'Type IV',
      'skin_type_4_desc': 'Dark. Burns minimally, tans well.',
      'skin_type_5_name': 'Type V',
      'skin_type_5_desc': 'Very dark. Rarely burns, tans intensely.',
      'skin_type_6_name': 'Type VI',
      'skin_type_6_desc': 'Black. Never burns, tans deeply.',
      'your_skin_type': 'Your skin',
      'safe_dose': 'Safe dose',
      'change_skin_type': 'Change skin type',
      'gps_active': 'GPS Active',
      'simulated': 'GPS Inactive',
      'location_unavailable': 'Location unavailable',
      'search_your_city': 'Search your city',
      'location': 'Location',
      'real_light': 'Real light',
      'simulated_lux': 'Simulated Lux',
      'direct_sun': 'Direct sun',
      'shade_umbrella': 'Shade',
      'indoor_deep_shade': 'Indoor',
      'light_sensor_info':
          'The light sensor helps estimate if you are in the shade or in direct sun. Remember that sand and water reflect up to 20% of UV radiation even in the shade.',
      'header_info_p1':
          'It uses the Standard Erythemal Dose (SED) algorithm and the Fitzpatrick skin phototype scale supported by the WHO.',
      'header_info_p2':
          'UV radiation data based on global meteorological models from NOAA / ECMWF.',
      'estimated_safe_time': 'Estimated Safe Sun Exposure Time',
      'solar_dose_pct': 'Max Solar Dose',
      'vitamin_d': 'Vitamin D',
      'start_exposure': 'Start Exposure',
      'safe_exposure_btn': 'Safe exposure',
      'daily_limit_reached': 'Daily limit reached',
      'cancel_exposure': 'Pause Exposure',
      'safe_exposure_finished_title': 'Daily limit reached!',
      'safe_exposure_finished_body':
          'You have reached your recommended sun limit!',
      'understood': 'Understood',
      'settings_title': 'Settings',
      'select_language': 'Select language',
      'close': 'Close',
      'info_dialog_title': 'Information',
      'ambient_light_title': 'Real light level',
      'uv_index_title': 'UV Index',
      'uv_index_desc': 'Based on coordinates & Open-Meteo',
      'simulating_light_slider': 'Simulate light power (Slider)',
      'sun_limit_reached_card_body':
          'You have already reached your recommended safe sun dose for today. Return tomorrow for new monitoring.',
      'reset_limit_proto': 'Reset limit (Prototype Mode)',
      'reset': 'Reset',
      'ad_space': 'Reserved Space for Advertising',
      'shadow_warning': 'Seek shade, wear sunscreen, and stay well hydrated.',
      'detecting_location': 'Detecting location...',
      'exposure_timer_title': 'Exposure Timer',
      'accumulated': 'Accumulated',
      'uv_low': 'Low',
      'uv_moderate': 'Moderate',
      'uv_high': 'High',
      'uv_very_high': 'Very High',
      'uv_extreme': 'Extreme',
      'shade_slider_label': 'Shade (0 lx)',
      'sun_slider_label': 'Full Sun (80K lx)',
      'check_for_updates': 'Check for updates',
      'checking_for_updates': 'Checking for updates...',
      'app_up_to_date': 'App is up to date',
      'update_downloaded': 'Update downloaded. Restart the app to apply it.',
      'install_now': 'Install',
      'update_error_title': 'Update Check Failed',
      'update_error_msg':
          'We could not check for updates. Would you like to visit the Google Play Store to check manually?',
      'open_play_store': 'Open Play Store',
      'cancel': 'Cancel',
      'update_available_title': 'Update Available',
      'update_available_msg':
          'A new version of the app is available. Would you like to update now?',
      'update_button_later': 'Later',
      'update_button_now': 'Update',
      'no_light_sensor_msg':
          'Device without light sensor. No attenuators are applied in the sun exposure calculation.',
      'manage_gps': 'GPS Management',
      'disclaimer_title': 'Legal & Health Disclaimer',
      'disclaimer_point1':
          '• The app offers indicative estimates and does not replace medical advice.',
      'disclaimer_point2': '• The use of the app is at the user\'s own risk.',
      'disclaimer_point3':
          '• For any doubts or sensitive skin, you must consult a dermatologist.',
      'vit_d_100_percent': '100% of daily Vitamin D achieved!',
      'solar_intensity': 'Impact on your skin',
      'fullscreen_alert_body':
          'You have completed your recommended maximum daily sun exposure for today according to your skin type ({phototype}).',
      'accumulated_exposure_time': 'Accumulated\nExposure Time',
      'safe_exposure_banner_title': '🛡️ Safe exposure',
      'safe_exposure_banner_desc':
          'Under current conditions, there is no need to track exposure time.',
      'uv_forecast_title': 'Hourly UV Forecast',
      'uv_forecast_btn_label': 'Hourly UV Forecast →',
      'current_hour_label': 'Now',
      'paused_exposure_banner_title': '⏸️ Exposure Paused',
      'paused_exposure_banner_desc': 'Current conditions are safe',
    },
    'es': {
      'app_title':
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      'select_skin_type': 'Selecciona tu tipo de piel',
      'silence_alarm': 'Silenciar Alarma',
      'onboarding_desc':
          'El tipo de piel (escala Fitzpatrick) determina tu sensibilidad al sol y la dosis de radiación ultravioleta segura que puedes recibir antes de sufrir quemaduras en la piel.',
      'accept': 'Aceptar',
      'skin_type_1_name': 'Tipo I',
      'skin_type_1_desc': 'Muy clara. Siempre se quema, nunca se broncea.',
      'skin_type_2_name': 'Tipo II',
      'skin_type_2_desc': 'Clara. Se quema fácilmente, se broncea mínimamente.',
      'skin_type_3_name': 'Tipo III',
      'skin_type_3_desc':
          'Media. Se quema moderadamente, se broncea gradualmente.',
      'skin_type_4_name': 'Tipo IV',
      'skin_type_4_desc': 'Oscura. Se quema mínimamente, se broncea bien.',
      'skin_type_5_name': 'Tipo V',
      'skin_type_5_desc':
          'Muy oscura. Raramente se quema, se broncea intensamente.',
      'skin_type_6_name': 'Tipo VI',
      'skin_type_6_desc': 'Negra. Nunca se quema, se broncea profundamente.',
      'your_skin_type': 'Tu piel',
      'safe_dose': 'Dosis segura',
      'change_skin_type': 'Cambiar fototipo',
      'gps_active': 'GPS Activo',
      'simulated': 'GPS Inactivo',
      'location_unavailable': 'Ubicación no disponible',
      'search_your_city': 'Busca tu ciudad',
      'location': 'Ubicación',
      'real_light': 'Luz real',
      'simulated_lux': 'Lux Simulado',
      'direct_sun': 'Sol directo',
      'shade_umbrella': 'Sombra',
      'indoor_deep_shade': 'Interior',
      'light_sensor_info':
          'El sensor de luz ayuda a estimar si estás a la sombra o al sol directo. Recuerda que la arena y el agua reflejan hasta un 20% de la radiación UV incluso a la sombra.',
      'header_info_p1':
          'Utiliza el algoritmo de Dosis Eritemática Estándar (SED) y la escala de fototipos cutáneos de Fitzpatrick respaldada por la OMS.',
      'header_info_p2':
          'Datos de radiación UV basados en modelos meteorológicos globales de la NOAA / ECMWF.',
      'estimated_safe_time': 'Tiempo seguro de exposición solar',
      'solar_dose_pct': 'Dosis Solar Máxima',
      'vitamin_d': 'Vitamina D',
      'start_exposure': 'Iniciar Exposición',
      'safe_exposure_btn': 'Exposición segura',
      'daily_limit_reached': 'Límite diario alcanzado',
      'cancel_exposure': 'Pausar Exposición',
      'safe_exposure_finished_title': '¡Límite diario alcanzado!',
      'safe_exposure_finished_body':
          '¡Has alcanzado tu límite de sol recomendado!',
      'understood': 'Entendido',
      'settings_title': 'Configuración',
      'select_language': 'Seleccionar idioma',
      'close': 'Cerrar',
      'info_dialog_title': 'Información',
      'ambient_light_title': 'Nivel de lux real',
      'uv_index_title': 'Índice UV',
      'uv_index_desc': 'Basado en coordenadas y Open-Meteo',
      'simulating_light_slider': 'Simular potencia de luz (Deslizador)',
      'sun_limit_reached_card_body':
          'Ya has completado tu dosis de sol recomendada para el día de hoy. Vuelve mañana para un nuevo monitoreo seguro.',
      'reset_limit_proto': 'Reestablecer límite (Modo Prototipo)',
      'reset': 'Reiniciar',
      'ad_space': 'Espacio reservado para Publicidad',
      'shadow_warning':
          'Busca la sombra, ponte protector solar e hidrátate bien.',
      'detecting_location': 'Detectando ubicación...',
      'exposure_timer_title': 'Temporizador de Exposición',
      'accumulated': 'Acumulado',
      'uv_low': 'Bajo',
      'uv_moderate': 'Moderado',
      'uv_high': 'Alto',
      'uv_very_high': 'Muy Alto',
      'uv_extreme': 'Extremo',
      'shade_slider_label': 'Sombra (0 lx)',
      'sun_slider_label': 'Sol Pleno (80K lx)',
      'check_for_updates': 'Buscar actualizaciones',
      'checking_for_updates': 'Buscando actualizaciones...',
      'app_up_to_date': 'La aplicación ya está actualizada',
      'update_downloaded':
          'Actualización descargada. Reinicia la aplicación para aplicarla.',
      'install_now': 'Instalar',
      'update_error_title': 'Error de actualización',
      'update_error_msg':
          'No se pudo buscar actualizaciones. ¿Deseas visitar Google Play Store para comprobarlo manualmente?',
      'open_play_store': 'Abrir Play Store',
      'cancel': 'Cancelar',
      'update_available_title': 'Actualización disponible',
      'update_available_msg':
          'Hay una nueva versión de la aplicación disponible. ¿Quieres actualizar ahora?',
      'update_button_later': 'Más tarde',
      'update_button_now': 'Actualizar',
      'no_light_sensor_msg':
          'Dispositivo sin sensor de luz. No se aplican atenuadores en el cálculo de exposición solar.',
      'manage_gps': 'Gestión de GPS',
      'disclaimer_title': 'Aviso Legal y de Salud',
      'disclaimer_point1':
          '• La aplicación ofrece estimaciones orientativas y no reemplaza el consejo médico.',
      'disclaimer_point2':
          '• El uso de la aplicación es bajo la propia responsabilidad del usuario.',
      'disclaimer_point3':
          '• Ante dudas o pieles sensibles, se debe consultar con un dermatólogo.',
      'vit_d_100_percent': '¡100% de Vitamina D diaria conseguida!',
      'solar_intensity': 'Impacto en tu piel',
      'fullscreen_alert_body':
          'Has completado tu dosis máxima recomendada de exposición solar para hoy de acuerdo a tu fototipo ({phototype}).',
      'accumulated_exposure_time': 'Tiempo Acumulado\nde Exposición',
      'safe_exposure_banner_title': '🛡️ Exposición segura',
      'safe_exposure_banner_desc':
          'En las condiciones actuales no es necesario controlar el tiempo de exposición.',
      'uv_forecast_title': 'Previsión UV por horas',
      'uv_forecast_btn_label': 'Previsión UV por horas →',
      'current_hour_label': 'Ahora',
      'paused_exposure_banner_title': '⏸️ Exposición Pausada',
      'paused_exposure_banner_desc': 'Las condiciones actuales son seguras',
    },
    'de': {
      'app_title':
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      'select_skin_type': 'Wählen Sie Ihren Hauttyp',
      'silence_alarm': 'Alarm stummschalten',
      'onboarding_desc':
          'Ihr Hauttyp (Fitzpatrick-Skala) bestimmt Ihre Empfindlichkeit gegenüber der Sonne und die sichere UV-Dosis, die Sie vor Hautverbrennungen erhalten können.',
      'accept': 'Akzeptieren',
      'skin_type_1_name': 'Typ I',
      'skin_type_1_desc': 'Sehr hell. Verbrennt immer, bräunt nie.',
      'skin_type_2_name': 'Typ II',
      'skin_type_2_desc': 'Hell. Verbrennt leicht, bräunt minimal.',
      'skin_type_3_name': 'Typ III',
      'skin_type_3_desc': 'Mittel. Verbrennt mäßig, bräunt allmählich.',
      'skin_type_4_name': 'Typ IV',
      'skin_type_4_desc': 'Dunkel. Verbrennt minimal, bräunt gut.',
      'skin_type_5_name': 'Typ V',
      'skin_type_5_desc': 'Sehr dunkel. Verbrennt selten, bräunt intensiv.',
      'skin_type_6_name': 'Typ VI',
      'skin_type_6_desc': 'Schwarz. Verbrennt nie, bräunt tief.',
      'your_skin_type': 'Deine Haut',
      'safe_dose': 'Sichere Dosis',
      'change_skin_type': 'Hauttyp ändern',
      'gps_active': 'GPS Aktiv',
      'simulated': 'GPS Inaktiv',
      'location_unavailable': 'Standort nicht verfügbar',
      'search_your_city': 'Suche deine Stadt',
      'location': 'Standort',
      'real_light': 'Echtes Licht',
      'simulated_lux': 'Simulierter Lux',
      'direct_sun': 'Direkte Sonne',
      'shade_umbrella': 'Schatten',
      'indoor_deep_shade': 'Innen',
      'light_sensor_info':
          'Der Lichtsensor hilft abzuschätzen, ob Sie sich im Schatten oder in der direkten Sonne befinden. Denken Sie daran, dass Sand und Wasser selbst im Schatten bis zu 20 % der UV-Strahlung reflektieren.',
      'header_info_p1':
          'Es verwendet den Standard-Erythemdosis-Algorithmus (SED) und die von der WHO unterstützte Fitzpatrick-Hautphototypskala.',
      'header_info_p2':
          'UV-Strahlungsdaten basierend auf globalen meteorologischen Modellen von NOAA / ECMWF.',
      'estimated_safe_time': 'Geschätzte sichere Sonnenexpositionszeit',
      'solar_dose_pct': 'Maximale Sonnendosis',
      'vitamin_d': 'Vitamin D',
      'start_exposure': 'Exposition starten',
      'safe_exposure_btn': 'Sichere Exposition',
      'daily_limit_reached': 'Tageslimit erreicht',
      'cancel_exposure': 'Belichtung pausieren',
      'safe_exposure_finished_title': 'Sichere Exposition beendet',
      'safe_exposure_finished_body':
          'Sie haben Ihr empfohlenes Sonnenlimit erreicht!',
      'understood': 'Verstanden',
      'settings_title': 'Einstellungen',
      'select_language': 'Sprache auswählen',
      'close': 'Schließen',
      'info_dialog_title': 'Information',
      'ambient_light_title': 'Echter Lichtpegel',
      'uv_index_title': 'UV-Index',
      'uv_index_desc': 'Basierend auf Koordinaten & Open-Meteo',
      'simulating_light_slider': 'Lichtstärke simulieren (Schieberegler)',
      'sun_limit_reached_card_body':
          'Sie haben Ihre empfohlene sichere Sonnendosis für heute bereits erreicht. Kommen Sie morgen für eine neue Überwachung wieder.',
      'reset_limit_proto': 'Limit zurücksetzen (Prototyp-Modus)',
      'reset': 'Zurücksetzen',
      'ad_space': 'Reservierter Platz für Werbung',
      'shadow_warning':
          'Suchen Sie Schatten auf, tragen Sie Sonnencreme auf und trinken Sie ausreichend Wasser.',
      'detecting_location': 'Standort wird ermittelt...',
      'exposure_timer_title': 'Expositions-Timer',
      'accumulated': 'Akkumuliert',
      'uv_low': 'Niedrig',
      'uv_moderate': 'Mäßig',
      'uv_high': 'Hoch',
      'uv_very_high': 'Sehr hoch',
      'uv_extreme': 'Extrem',
      'shade_slider_label': 'Schatten (0 lx)',
      'sun_slider_label': 'Volle Sonne (80K lx)',
      'check_for_updates': 'Auf Updates prüfen',
      'checking_for_updates': 'Auf Updates wird geprüft...',
      'app_up_to_date': 'Die App ist auf dem neuesten Stand',
      'update_downloaded':
          'Update heruntergeladen. Starten Sie die App neu, um es anzuwenden.',
      'install_now': 'Installieren',
      'update_error_title': 'Update-Prüfung fehlgeschlagen',
      'update_error_msg':
          'Es konnte nicht nach Updates gesucht werden. Möchten Sie den Google Play Store besuchen, um manuell zu suchen?',
      'open_play_store': 'Play Store öffnen',
      'cancel': 'Abbrechen',
      'update_available_title': 'Update verfügbar',
      'update_available_msg':
          'Eine neue Version der App ist verfügbar. Möchten Sie jetzt aktualisieren?',
      'update_button_later': 'Später',
      'update_button_now': 'Aktualisieren',
      'no_light_sensor_msg':
          'Gerät ohne Lichtsensor. Für die Berechnung der Sonnenexposition werden keine Abschwächer angewendet.',
      'manage_gps': 'GPS-Verwaltung',
      'disclaimer_title': 'Rechtlicher & gesundheitlicher Haftungsausschluss',
      'disclaimer_point1':
          '• Die App bietet Richtwerte und ersetzt keine ärztliche Beratung.',
      'disclaimer_point2':
          '• Die Nutzung der App erfolgt auf eigene Verantwortung des Nutzers.',
      'disclaimer_point3':
          '• Bei Fragen oder empfindlicher Haut wenden Sie sich an einen Dermatologen.',
      'vit_d_100_percent': '100% des täglichen Vitamin D erreicht!',
      'solar_intensity': 'Belastung deiner Haut',
      'fullscreen_alert_body':
          'Sie haben Ihre empfohlene maximale tägliche Sonnenexposition für heute entsprechend Ihrem Hauttyp ({phototype}) erreicht.',
      'accumulated_exposure_time': 'Akkumulierte\nExpositionszeit',
      'safe_exposure_banner_title': '🛡️ Sichere Exposition',
      'safe_exposure_banner_desc':
          'Unter den aktuellen Bedingungen muss die Expositionszeit nicht überwacht werden.',
      'uv_forecast_title': 'Stündliche UV-Vorhersage',
      'uv_forecast_btn_label': 'Stündliche UV-Prognose →',
      'current_hour_label': 'Jetzt',
      'paused_exposure_banner_title': '⏸️ Exposition pausiert',
      'paused_exposure_banner_desc': 'Die aktuellen Bedingungen sind sicher',
    },
    'fr': {
      'app_title':
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      'select_skin_type': 'Sélectionnez votre type de peau',
      'silence_alarm': 'Couper l\'alarme',
      'onboarding_desc':
          'Votre type de peau (échelle de Fitzpatrick) détermine votre sensibilité au soleil et la dose sûre de rayonnement ultraviolet que vous pouvez recevoir avant de subir des brûlures cutanées.',
      'accept': 'Accepter',
      'skin_type_1_name': 'Type I',
      'skin_type_1_desc': 'Très claire. Brûle toujours, ne bronze jamais.',
      'skin_type_2_name': 'Type II',
      'skin_type_2_desc': 'Claire. Brûle facilement, bronze peu.',
      'skin_type_3_name': 'Type III',
      'skin_type_3_desc': 'Moyenne. Brûle modérément, bronze progressivement.',
      'skin_type_4_name': 'Type IV',
      'skin_type_4_desc': 'Mate. Brûle peu, bronze bien.',
      'skin_type_5_name': 'Type V',
      'skin_type_5_desc': 'Très mate. Brûle rarement, bronze intensément.',
      'skin_type_6_name': 'Type VI',
      'skin_type_6_desc': 'Noire. Ne brûle jamais, bronze intensément.',
      'your_skin_type': 'Votre peau',
      'safe_dose': 'Dose sûre',
      'change_skin_type': 'Modifier le type de peau',
      'gps_active': 'GPS Actif',
      'simulated': 'GPS Inactif',
      'location_unavailable': 'Localisation indisponible',
      'search_your_city': 'Recherchez votre ville',
      'location': 'Localisation',
      'real_light': 'Lumière réelle',
      'simulated_lux': 'Lux simulé',
      'direct_sun': 'Soleil direct',
      'shade_umbrella': 'Ombre',
      'indoor_deep_shade': 'Intérieur',
      'light_sensor_info':
          'Le capteur de lumière aide à estimer si vous êtes à l\'ombre ou en plein soleil. N\'oubliez pas que le sable et l\'eau réfléchissent jusqu\'à 20 % des rayons UV, même à l\'ombre.',
      'header_info_p1':
          'Il utilise l\'algorithme de Dose Érythémale Standard (SED) et l\'échelle des phototypes cutanés de Fitzpatrick soutenue par l\'OMS.',
      'header_info_p2':
          'Données de rayonnement UV basées sur les modèles météorologiques mondiaux de la NOAA / CEPMMT.',
      'estimated_safe_time': 'Temps d\'exposition solaire sûr estimé',
      'solar_dose_pct': 'Dose solaire maximale',
      'vitamin_d': 'Vitamine D',
      'start_exposure': 'Démarrer l\'exposition',
      'safe_exposure_btn': 'Exposition sûre',
      'daily_limit_reached': 'Limite quotidienne atteinte',
      'cancel_exposure': 'Pause de l\'exposition',
      'safe_exposure_finished_title': 'Exposition sûre terminée',
      'safe_exposure_finished_body':
          'Vous avez atteint votre limite d\'exposition recommandée !',
      'understood': 'Compris',
      'settings_title': 'Paramètres',
      'select_language': 'Sélectionner la langue',
      'close': 'Fermer',
      'info_dialog_title': 'Information',
      'ambient_light_title': 'Niveau de lux réel',
      'uv_index_title': 'Indice UV',
      'uv_index_desc': 'Basé sur les coordonnées et Open-Meteo',
      'simulating_light_slider': 'Simuler la puissance de la lumière (Curseur)',
      'sun_limit_reached_card_body':
          'Vous avez déjà atteint votre dose de soleil sûre recommandée pour aujourd\'hui. Revenez demain pour un nouveau suivi.',
      'reset_limit_proto': 'Réinitialiser la limite (Mode Prototype)',
      'reset': 'Réinitialiser',
      'ad_space': 'Espace réservé à la publicité',
      'shadow_warning':
          'Recherchez l\'ombre, mettez de la crème solaire et restez bien hydraté.',
      'detecting_location': 'Détection de l\'emplacement...',
      'exposure_timer_title': 'Minuteur d\'exposition',
      'remaining': 'restants',
      'accumulated': 'Accumulé',
      'uv_low': 'Faible',
      'uv_moderate': 'Modéré',
      'uv_high': 'Élevé',
      'uv_very_high': 'Très élevé',
      'uv_extreme': 'Extrême',
      'shade_slider_label': 'Ombre (0 lx)',
      'sun_slider_label': 'Plein Soleil (80K lx)',
      'check_for_updates': 'Vérifier les mises à jour',
      'checking_for_updates': 'Vérification des mises à jour...',
      'app_up_to_date': 'L\'application est à jour',
      'update_downloaded':
          'Mise à jour téléchargée. Redémarrez l\'application pour l\'appliquer.',
      'install_now': 'Installer',
      'update_error_title': 'Échec de la vérification',
      'update_error_msg':
          'Impossible de vérifier les mises à jour. Souhaitez-vous visiter le Google Play Store pour vérifier manuellement ?',
      'open_play_store': 'Ouvrir le Play Store',
      'cancel': 'Annuler',
      'update_available_title': 'Mise à jour disponible',
      'update_available_msg':
          'Une nouvelle version de l\'application est disponible. Voulez-vous mettre à jour maintenant?',
      'update_button_later': 'Plus tard',
      'update_button_now': 'Mettre à jour',
      'no_light_sensor_msg':
          'Appareil sans capteur de lumière. Aucun atténuateur n\'est appliqué dans le calcul de l\'exposition solaire.',
      'manage_gps': 'Gestion du GPS',
      'disclaimer_title': 'Clause de Non-Responsabilité Légale et Médicale',
      'disclaimer_point1':
          '• L\'application fournit des estimations indicatives et ne remplace pas un avis médical.',
      'disclaimer_point2':
          '• L\'utilisation de l\'application est sous la seule responsabilité de l\'utilisateur.',
      'disclaimer_point3':
          '• En cas de doute ou de peau sensible, veuillez consulter un dermatologue.',
      'vit_d_100_percent': '100% de la vitamine D quotidienne atteinte!',
      'solar_intensity': 'Impact sur votre peau',
      'fullscreen_alert_body':
          'Vous avez atteint votre exposition solaire maximale quotidienne recommandée pour aujourd\'hui selon votre phototype ({phototype}).',
      'accumulated_exposure_time': 'Temps d\'Exposition\nAccumulé',
      'safe_exposure_banner_title': '🛡️ Exposition sûre',
      'safe_exposure_banner_desc':
          'Dans les conditions actuelles, il n\'est pas nécessaire de contrôler le temps d\'exposition.',
      'uv_forecast_title': 'Prévisions UV par heure',
      'uv_forecast_btn_label': 'Prévisions UV horaires →',
      'current_hour_label': 'Maint.',
      'paused_exposure_banner_title': '⏸️ Exposition en pause',
      'paused_exposure_banner_desc': 'Les conditions actuelles sont sûres',
    },
    'it': {
      'app_title':
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      'select_skin_type': 'Seleziona il tuo tipo di pelle',
      'silence_alarm': 'Silenzia sveglia',
      'onboarding_desc':
          'Il tuo tipo di pelle (scala Fitzpatrick) determina la tua sensibilità al sole e la dose sicura di radiazioni ultraviolette che puoi ricevere prima di subire ustioni cutanee.',
      'accept': 'Accetta',
      'skin_type_1_name': 'Tipo I',
      'skin_type_1_desc':
          'Molto chiara. Si scotta sempre, non si abbronza mai.',
      'skin_type_2_name': 'Tipo II',
      'skin_type_2_desc':
          'Chiara. Si scotta facilmente, si abbronza minimamente.',
      'skin_type_3_name': 'Tipo III',
      'skin_type_3_desc':
          'Media. Si scotta moderatamente, si abbronza gradualmente.',
      'skin_type_4_name': 'Tipo IV',
      'skin_type_4_desc': 'Scura. Si scotta minimamente, si abbronza bene.',
      'skin_type_5_name': 'Tipo V',
      'skin_type_5_desc':
          'Molto scura. Raramente si scotta, si abbronza intensamente.',
      'skin_type_6_name': 'Tipo VI',
      'skin_type_6_desc': 'Nera. Non si scotta mai, si abbronza intensamente.',
      'your_skin_type': 'La tua pelle',
      'safe_dose': 'Dose sicura',
      'change_skin_type': 'Cambia fototipo',
      'gps_active': 'GPS Attivo',
      'simulated': 'GPS Inattivo',
      'location_unavailable': 'Posizione non disponibile',
      'search_your_city': 'Cerca la tua città',
      'location': 'Posizione',
      'real_light': 'Luce reale',
      'simulated_lux': 'Lux simulato',
      'direct_sun': 'Sole directo',
      'shade_umbrella': 'Ombra',
      'indoor_deep_shade': 'Interno',
      'light_sensor_info':
          'Il sensore di luce aiuta a stimare se sei all\'ombra o al sol directo. Ricorda che la sabbia e l\'acqua riflettono fino al 20% delle radiazioni UV anche all\'ombra.',
      'header_info_p1':
          'Utilizza l\'algoritmo Standard Erythemal Dose (SED) e la scala dei fototipi cutanei di Fitzpatrick supportata dall\'OMS.',
      'header_info_p2':
          'Dati sulla radiazione UV basati sui modelli meteorologici globali di NOAA / ECMWF.',
      'estimated_safe_time': 'Tempo di esposizione solare sicuro stimato',
      'solar_dose_pct': 'Dose Solare Massima',
      'vitamin_d': 'Vitamina D',
      'start_exposure': 'Avvia Esposizione',
      'safe_exposure_btn': 'Esposizione sicura',
      'daily_limit_reached': 'Limite giornaliero raggiunto',
      'cancel_exposure': 'Pausa esposizione',
      'safe_exposure_finished_title': 'Esposizione sicura terminata',
      'safe_exposure_finished_body':
          'Hai raggiunto il tuo limite di sole consigliato!',
      'understood': 'Capito',
      'settings_title': 'Impostazioni',
      'select_language': 'Seleziona lingua',
      'close': 'Chiudi',
      'info_dialog_title': 'Informazione',
      'ambient_light_title': 'Livello di lux reale',
      'uv_index_title': 'Indice UV',
      'uv_index_desc': 'Basato su coordinate e Open-Meteo',
      'simulating_light_slider': 'Simula potenza luce (Cursore)',
      'sun_limit_reached_card_body':
          'Hai già completato la tua dose di sole sicura consigliata per oggi. Torna domani per un nuovo monitoraggio.',
      'reset_limit_proto': 'Reimposta limite (Modalità Prototipo)',
      'reset': 'Reimposta',
      'ad_space': 'Spazio riservato alla pubblicità',
      'shadow_warning':
          'Cerca l\'ombra, usa la crema solare e rimani ben idratato.',
      'detecting_location': 'Rilevamento della posizione...',
      'exposure_timer_title': 'Timer di esposizione',
      'accumulated': 'Accumulato',
      'uv_low': 'Basso',
      'uv_moderate': 'Moderato',
      'uv_high': 'Alto',
      'uv_very_high': 'Molto alto',
      'uv_extreme': 'Estremo',
      'shade_slider_label': 'Ombra (0 lx)',
      'sun_slider_label': 'Sole Pieno (80K lx)',
      'check_for_updates': 'Controlla aggiornamenti',
      'checking_for_updates': 'Verifica aggiornamenti in corso...',
      'app_up_to_date': 'L\'applicazione è aggiornata',
      'update_downloaded':
          'Aggiornamento scaricato. Riavvia l\'applicazione per applicarlo.',
      'install_now': 'Installa',
      'update_error_title': 'Verifica aggiornamenti fallita',
      'update_error_msg':
          'Impossibile verificare gli aggiornamenti. Vuoi visitare Google Play Store per verificare manualmente?',
      'open_play_store': 'Apri Play Store',
      'cancel': 'Annulla',
      'update_available_title': 'Aggiornamento disponibile',
      'update_available_msg':
          'È disponibile una nova versione dell\'applicazione. Vuoi aggiornare ora?',
      'update_button_later': 'Più tardi',
      'update_button_now': 'Aggiorna',
      'no_light_sensor_msg':
          'Dispositivo senza sensore di luce. Non vengono applicati attenuatori nel calcolo dell\'esposizione solare.',
      'manage_gps': 'Gestione GPS',
      'disclaimer_title': 'Avviso Legale e della Salute',
      'disclaimer_point1':
          '• L\'applicazione offre stime indicative e non sostituisce il parere medico.',
      'disclaimer_point2':
          '• L\'uso dell\'applicazione è a proprio rischio e pericolo dell\'utente.',
      'disclaimer_point3':
          '• In caso di dubbi o pelle sensibile, consultare un dermatologo.',
      'vit_d_100_percent': '100% di vitamina D giornaliera raggiunta!',
      'solar_intensity': 'Impatto sulla tua pelle',
      'fullscreen_alert_body':
          'Hai completato la tua esposizione solare massima giornaliera raccomandata per oggi in base al tuo fototipo ({phototype}).',
      'accumulated_exposure_time': 'Tempo di Esposizione\nAccumulato',
      'safe_exposure_banner_title': '🛡️ Esposizione sicura',
      'safe_exposure_banner_desc':
          'Nelle condizioni attuali non è necessario controllare il tempo di esposizione.',
      'uv_forecast_title': 'Previsioni UV orarie',
      'uv_forecast_btn_label': 'Previsioni UV orarie →',
      'current_hour_label': 'Ora',
      'paused_exposure_banner_title': '⏸️ Esposizione in pausa',
      'paused_exposure_banner_desc': 'Le condizioni attuali sono sicure',
    },
    'pt': {
      'app_title':
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      'select_skin_type': 'Selecione o seu tipo de pele',
      'silence_alarm': 'Silenciar Alarme',
      'onboarding_desc':
          'O seu tipo de pele (escala de Fitzpatrick) determina a sua sensibilidade ao sol e a dose segura de radiação ultravioleta que pode receber antes de sofrer queimaduras na pele.',
      'accept': 'Aceitar',
      'skin_type_1_name': 'Tipo I',
      'skin_type_1_desc': 'Muito clara. Sempre se queima, nunca se bronzeia.',
      'skin_type_2_name': 'Tipo II',
      'skin_type_2_desc':
          'Clara. Queima-se facilmente, bronzeia-se minimamente.',
      'skin_type_3_name': 'Tipo III',
      'skin_type_3_desc':
          'Média. Queima-se moderadamente, bronzeia-se gradualmente.',
      'skin_type_4_name': 'Tipo IV',
      'skin_type_4_desc': 'Escura. Queima-se minimamente, bronzeia-se bem.',
      'skin_type_5_name': 'Tipo V',
      'skin_type_5_desc':
          'Muito escura. Raramente se queima, bronzeia-se intensamente.',
      'skin_type_6_name': 'Tipo VI',
      'skin_type_6_desc': 'Negra. Nunca se queima, bronzeia-se profundamente.',
      'your_skin_type': 'Sua pele',
      'safe_dose': 'Dose segura',
      'change_skin_type': 'Alterar fototipo',
      'gps_active': 'GPS Activo',
      'simulated': 'GPS Inativo',
      'location_unavailable': 'Localização indisponível',
      'search_your_city': 'Pesquise sua cidade',
      'location': 'Localização',
      'real_light': 'Luz real',
      'simulated_lux': 'Lux simulado',
      'direct_sun': 'Sol direto',
      'shade_umbrella': 'Sombra',
      'indoor_deep_shade': 'Interior',
      'light_sensor_info':
          'O sensor de luz ajuda a estimar se está à sombra ou sob o sol direto. Lembre-se de que a areia e a água refletem até 20% da radiação UV, mesmo à sombra.',
      'header_info_p1':
          'Utiliza o algoritmo de Dose Eritemática Padrão (SED) e a escala de fotótipos cutâneos de Fitzpatrick apoiada pela OMS.',
      'header_info_p2':
          'Dados de radiação UV baseados em modelos meteorológicos globais da NOAA / ECMWF.',
      'estimated_safe_time': 'Tempo seguro estimado de exposição solar',
      'solar_dose_pct': 'Dose Solar Máxima',
      'vitamin_d': 'Vitamina D',
      'start_exposure': 'Iniciar Exposição',
      'safe_exposure_btn': 'Exposição segura',
      'daily_limit_reached': 'Limite diário atingido',
      'cancel_exposure': 'Pausar Exposição',
      'safe_exposure_finished_title': 'Exposição segura concluída',
      'safe_exposure_finished_body':
          'Você atingiu o seu limite de sol recomendado!',
      'understood': 'Entendido',
      'settings_title': 'Configurações',
      'select_language': 'Selecionar idioma',
      'close': 'Fechar',
      'info_dialog_title': 'Informação',
      'ambient_light_title': 'Nível de lux real',
      'uv_index_title': 'Indice UV',
      'uv_index_desc': 'Baseado em coordenadas e Open-Meteo',
      'simulating_light_slider': 'Simular potência de luz (Deslizador)',
      'sun_limit_reached_card_body':
          'Já atingiu a sua dose de sol segura recomendada para hoje. Volte amanhã para uma nova monitorização.',
      'reset_limit_proto': 'Redefinir limite (Modo Protótipo)',
      'reset': 'Reiniciar',
      'ad_space': 'Espaço reservado para publicidade',
      'shadow_warning':
          'Procure a sombra, use protetor solar e mantenha-se bem hidratado.',
      'detecting_location': 'Detectando localização...',
      'exposure_timer_title': 'Temporizador de exposição',
      'accumulated': 'Acumulado',
      'uv_low': 'Baixo',
      'uv_moderate': 'Moderado',
      'uv_high': 'Alto',
      'uv_very_high': 'Muito alto',
      'uv_extreme': 'Extremo',
      'shade_slider_label': 'Sombra (0 lx)',
      'sun_slider_label': 'Sol Pleno (80K lx)',
      'check_for_updates': 'Verificar atualizações',
      'checking_for_updates': 'Verificando atualizações...',
      'app_up_to_date': 'O aplicativo está atualizado',
      'update_downloaded':
          'Atualização baixada. Reinicie o aplicativo para aplicá-la.',
      'install_now': 'Instalar',
      'update_error_title': 'Falha na verificação',
      'update_error_msg':
          'Não foi possível verificar atualizações. Deseja visitar a Google Play Store para verificar manualmente?',
      'open_play_store': 'Abrir Play Store',
      'cancel': 'Cancelar',
      'update_available_title': 'Atualização disponível',
      'update_available_msg':
          'Uma nova versão do aplicativo está disponível. Deseja atualizar agora?',
      'update_button_later': 'Mais tarde',
      'update_button_now': 'Atualizar',
      'no_light_sensor_msg':
          'Dispositivo sem sensor de luz. Não são aplicados atenuadores no cálculo da exposição solar.',
      'manage_gps': 'Gestão de GPS',
      'disclaimer_title': 'Aviso Legal e de Saúde',
      'disclaimer_point1':
          '• O aplicativo fornece estimativas orientativas e não substitui o conselho médico.',
      'disclaimer_point2':
          '• O uso do aplicativo é de inteira responsabilidade do usuário.',
      'disclaimer_point3':
          '• Em caso de dúvidas ou pele sensível, consulte um dermatologista.',
      'vit_d_100_percent': '100% de vitamina D diária alcançada!',
      'solar_intensity': 'Impacto na sua pele',
      'fullscreen_alert_body':
          'Você completou a sua exposição solar máxima diária recomendada para hoje de acordo com o seu fototipo ({phototype}).',
      'accumulated_exposure_time': 'Tempo de Exposição\nAcumulado',
      'safe_exposure_banner_title': '🛡️ Exposição segura',
      'safe_exposure_banner_desc':
          'Nas condições actuais não é necessário controlar o tempo de exposição.',
      'uv_forecast_title': 'Previsão UV por hora',
      'uv_forecast_btn_label': 'Previsão UV por horas →',
      'current_hour_label': 'Agora',
      'paused_exposure_banner_title': '⏸️ Exposição em pausa',
      'paused_exposure_banner_desc': 'As condições actuais são seguras',
    },
    'ca': {
      'app_title':
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      'select_skin_type': 'Selecciona el teu tipus de pell',
      'silence_alarm': 'Silenciar Alarma',
      'onboarding_desc':
          'El tipus de pell (escala Fitzpatrick) determina la teva sensibilitat al sol i la dosi de radiació ultraviolada segura que pots rebre abans de patir cremades a la pell.',
      'accept': 'Acceptar',
      'skin_type_1_name': 'Tipus I',
      'skin_type_1_desc': 'Molt clara. Sempre es crema, mai es bronzeja.',
      'skin_type_2_name': 'Tipus II',
      'skin_type_2_desc': 'Clara. Es crema fàcilment, es bronzeja mínimament.',
      'skin_type_3_name': 'Tipus III',
      'skin_type_3_desc':
          'Mitjana. Es crema moderadament, es bronzeja gradualment.',
      'skin_type_4_name': 'Tipus IV',
      'skin_type_4_desc': 'Fosca. Es crema mínimament, es bronzeja bé.',
      'skin_type_5_name': 'Tipus V',
      'skin_type_5_desc':
          'Molt fosca. Rarament es crema, es bronzeja intensivament.',
      'skin_type_6_name': 'Tipus VI',
      'skin_type_6_desc': 'Negra. Mai es crema, es bronzeja profundament.',
      'your_skin_type': 'La teva pell',
      'safe_dose': 'Dosi segura',
      'change_skin_type': 'Canviar fototip',
      'gps_active': 'GPS Actiu',
      'simulated': 'GPS Inactiu',
      'location_unavailable': 'Ubicació no disponible',
      'search_your_city': 'Cerca la teva ciutat',
      'location': 'Ubicació',
      'real_light': 'Llum real',
      'simulated_lux': 'Lux simulat',
      'direct_sun': 'Sol directe',
      'shade_umbrella': 'Ombra',
      'indoor_deep_shade': 'Interior',
      'light_sensor_info':
          'El sensor de llum ajuda a estimar si estàs a l\'ombra o al sol directe. Recorda que la sorra i l\'aigua reflecteixen fins a un 20% de la radiació UV fins i tot a l\'ombra.',
      'header_info_p1':
          'Utilitza l\'algoritme de Dosi Eritemàtica Estàndard (SED) i l\'escala de fototips cutanis de Fitzpatrick recolzada per l\'OMS.',
      'header_info_p2':
          'Dades de radiació UV basades en models meteorològics globals de la NOAA / ECMWF.',
      'estimated_safe_time': 'Temps segur estimat d\'exposició solar',
      'solar_dose_pct': 'Dosi Solar Màxima',
      'vitamin_d': 'Vitamina D',
      'start_exposure': 'Iniciar Exposició',
      'safe_exposure_btn': 'Exposició segura',
      'daily_limit_reached': 'Límit diari assolit',
      'cancel_exposure': 'Pausar Exposició',
      'safe_exposure_finished_title': 'Exposició segura finalitzada',
      'safe_exposure_finished_body':
          '¡Has assolit el teu límit de sol recomanat!',
      'understood': 'Entès',
      'settings_title': 'Configuració',
      'select_language': 'Seleccionar idioma',
      'close': 'Tancar',
      'info_dialog_title': 'Informació',
      'ambient_light_title': 'Nivel de lux real',
      'uv_index_title': 'Índex UV',
      'uv_index_desc': 'Basat en coordenades i Open-Meteo',
      'simulating_light_slider': 'Simular potència de llum (Lliscador)',
      'sun_limit_reached_card_body':
          'Ja has completat la teva dosi de sol recomanada per a avui. Torna demà per a un nou monitoratge segur.',
      'reset_limit_proto': 'Restablir límit (Mode Prototip)',
      'reset': 'Restablir',
      'ad_space': 'Espai reservat per a publicitat',
      'shadow_warning':
          'Busca l\'ombra, posa\'t protector solar i hidrata\'t bé.',
      'detecting_location': 'Detectant ubicació...',
      'exposure_timer_title': 'Temporitzador d\'Exposició',
      'remaining': 'restants',
      'accumulated': 'Acumulat',
      'uv_low': 'Baix',
      'uv_moderate': 'Moderat',
      'uv_high': 'Alt',
      'uv_very_high': 'Molt Alt',
      'uv_extreme': 'Extrem',
      'shade_slider_label': 'Ombra (0 lx)',
      'sun_slider_label': 'Sol Ple (80K lx)',
      'check_for_updates': 'Comprovar actualitzacions',
      'checking_for_updates': 'Comprovant actualitzacions...',
      'app_up_to_date': 'L\'aplicació ja està actualitzada',
      'update_downloaded':
          'Actualització descarregada. Reinicia l\'aplicació per aplicar-la.',
      'install_now': 'Instal·lar',
      'update_error_title': 'Error d\'actualització',
      'update_error_msg':
          'No s\'ha pogut buscar actualitzacions. Vols visitar Google Play Store per comprovar-ho manualment?',
      'open_play_store': 'Obrir Play Store',
      'cancel': 'Cancel·lar',
      'update_available_title': 'Actualització disponible',
      'update_available_msg':
          'Hi ha una nova versió de l\'aplicació disponible. Vols actualitzar-la ara?',
      'update_button_later': 'Més tard',
      'update_button_now': 'Actualitzar',
      'no_light_sensor_msg':
          'Dispositiu sense sensor de llum. No s\'apliquen atenuadors en el càlcul d\'exposició solar.',
      'manage_gps': 'Gestió de GPS',
      'disclaimer_title': 'Avís Legal i de Salut',
      'disclaimer_point1':
          '• L\'aplicació ofereix estimacions orientatives i no substitueix consells mèdics.',
      'disclaimer_point2':
          '• L\'ús de l\'aplicació és sota la pròpia responsabilitat de l\'usuari.',
      'disclaimer_point3':
          '• Davant de dubtes o pells sensibles, cal consultar un dermatóleg.',
      'vit_d_100_percent': '100% de Vitamina D diària aconseguida!',
      'solar_intensity': 'Impacte a la teva pell',
      'fullscreen_alert_body':
          'Has completat la teva dosi màxima recomanada d\'exposició solar per a avui d\'acord amb el teu fototip ({phototype}).',
      'accumulated_exposure_time': 'Temps Acumulat\nd\'Exposició',
      'safe_exposure_banner_title': '🛡️ Exposició segura',
      'safe_exposure_banner_desc':
          'En les condicions actuals no cal controlar el temps d\'exposició.',
      'uv_forecast_title': 'Previsió UV per hores',
      'uv_forecast_btn_label': 'Previsió UV per hores →',
      'current_hour_label': 'Ara',
      'paused_exposure_banner_title': '⏸️ Exposició Pausada',
      'paused_exposure_banner_desc': 'Les condicions actuals són segures',
    },
  };

  static String getText(String lang, String key) {
    return _translations[lang]?[key] ?? _translations['en']?[key] ?? '';
  }

  static String getMonthName(int month, String lang) {
    final months = {
      'en': [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
      ],
      'es': [
        "Enero",
        "Febrero",
        "Marzo",
        "Abril",
        "Mayo",
        "Junio",
        "Julio",
        "Agosto",
        "Septiembre",
        "Octubre",
        "Noviembre",
        "Diciembre",
      ],
      'ca': [
        "Gener",
        "Febrer",
        "Març",
        "Abril",
        "Maig",
        "Juny",
        "Juliol",
        "Agost",
        "Setembre",
        "Octubre",
        "Novembre",
        "Desembre",
      ],
      'de': [
        "Januar",
        "Februar",
        "März",
        "April",
        "Mai",
        "Juni",
        "Juli",
        "August",
        "September",
        "Oktober",
        "November",
        "Dezember",
      ],
      'fr': [
        "Janvier",
        "Février",
        "Mars",
        "Avril",
        "Mai",
        "Juin",
        "Juillet",
        "Août",
        "Septembre",
        "Octobre",
        "Novembre",
        "Décembre",
      ],
      'it': [
        "Gennaio",
        "Febbraio",
        "Marzo",
        "Aprile",
        "Maggio",
        "Giugno",
        "Luglio",
        "Agosto",
        "Settembre",
        "Ottobre",
        "Novembre",
        "Dicembre",
      ],
      'pt': [
        "Janeiro",
        "Fevereiro",
        "Março",
        "Abril",
        "Maio",
        "Junho",
        "Julho",
        "Agosto",
        "Setembro",
        "Outubro",
        "Novembro",
        "Dezembro",
      ],
    };
    return (months[lang] ?? months['en']!)[month - 1];
  }

  static String getSeasonName(String seasonKey, String lang) {
    final seasons = {
      'Primavera': {
        'en': 'Spring',
        'es': 'Primavera',
        'ca': 'Primavera',
        'de': 'Frühling',
        'fr': 'Printemps',
        'it': 'Primavera',
        'pt': 'Primavera',
      },
      'Verano': {
        'en': 'Summer',
        'es': 'Verano',
        'ca': 'Estiu',
        'de': 'Sommer',
        'fr': 'Été',
        'it': 'Estate',
        'pt': 'Verão',
      },
      'Otoño': {
        'en': 'Autumn',
        'es': 'Otoño',
        'ca': 'Tardor',
        'de': 'Herbst',
        'fr': 'Automne',
        'it': 'Autunno',
        'pt': 'Outono',
      },
      'Invierno': {
        'en': 'Winter',
        'es': 'Invierno',
        'ca': 'Hivern',
        'de': 'Winter',
        'fr': 'Hiver',
        'it': 'Inverno',
        'pt': 'Inverno',
      },
    };
    return seasons[seasonKey]?[lang] ?? seasons[seasonKey]?['en'] ?? seasonKey;
  }

  static String formatDate(DateTime date, String lang) {
    final monthName = getMonthName(date.month, lang);
    switch (lang) {
      case 'en':
        return "$monthName ${date.day}";
      case 'de':
        return "${date.day}. $monthName";
      case 'fr':
        return "${date.day} $monthName";
      case 'it':
        return "${date.day} $monthName";
      case 'pt':
        return "${date.day} de $monthName";
      case 'ca':
        final firstChar = monthName.substring(0, 1).toLowerCase();
        final isVowel = ['a', 'e', 'i', 'o', 'u'].contains(firstChar);
        return "${date.day} ${isVowel ? "d'" : "de "}$monthName";
      case 'es':
      default:
        return "${date.day} de $monthName";
    }
  }
}

class SunTimerApp extends StatelessWidget {
  final int? initialSkinType;

  const SunTimerApp({super.key, this.initialSkinType});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:
          'Sun Exposure Timer', // NOTRANSLATE: The app title must always remain in English ("Sun Exposure Timer")
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBF9F5),
        primaryColor: const Color(0xFFF7D070),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
            .apply(
              bodyColor: const Color(0xFF2C3E50),
              displayColor: const Color(0xFF2C3E50),
            ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF7D070),
          surface: const Color(0xFFFBF9F5),
        ),
        useMaterial3: true,
      ),
      home: ValueListenableBuilder<String>(
        valueListenable: appLanguage,
        builder: (context, lang, child) {
          return InitialRouter(initialSkinType: initialSkinType);
        },
      ),
    );
  }
}

/// Enrutador inicial que decide si mostrar el Onboarding o el Dashboard principal.
class InitialRouter extends StatefulWidget {
  final int? initialSkinType;

  const InitialRouter({super.key, this.initialSkinType});

  @override
  State<InitialRouter> createState() => _InitialRouterState();
}

class _InitialRouterState extends State<InitialRouter> {
  int? _savedSkinType;
  bool _isEditingSkinType = false;

  @override
  void initState() {
    super.initState();
    _savedSkinType = widget.initialSkinType;
  }

  @override
  Widget build(BuildContext context) {
    if (_savedSkinType == null || _isEditingSkinType) {
      return OnboardingScreen(
        initialSelectedIndex: _savedSkinType,
        showCloseButton: _savedSkinType != null,
        onCompleted: (selectedType) {
          setState(() {
            _savedSkinType = selectedType;
            _isEditingSkinType = false;
          });
        },
        onClose: () {
          setState(() {
            _isEditingSkinType = false;
          });
        },
      );
    }

    return DashboardScreen(
      selectedSkinTypeIndex: _savedSkinType!,
      onResetSkinType: () {
        setState(() {
          _isEditingSkinType = true;
        });
      },
    );
  }
}

/// PANTALLA 1: ONBOARDING - Comparador Visual Interactivo de Piel
class OnboardingScreen extends StatefulWidget {
  final int? initialSelectedIndex;
  final bool showCloseButton;
  final Function(int) onCompleted;
  final VoidCallback? onClose;

  const OnboardingScreen({
    super.key,
    this.initialSelectedIndex,
    this.showCloseButton = false,
    required this.onCompleted,
    this.onClose,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
  }

  Future<void> _saveSkinType(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('skin_type', index);
    widget.onCompleted(index);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appLanguage.value;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (widget.showCloseButton && widget.onClose != null) {
          widget.onClose!();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showCloseButton)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF2C3E50),
                        size: 24,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
                Text(
                  "Sun Exposure Timer", // NOTRANSLATE: The app title in the header must always remain in English ("Sun Exposure Timer")
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF73C6B6),
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.getText(lang, 'select_skin_type'),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  AppTranslations.getText(lang, 'onboarding_desc'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF2C3E50).withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: fitzpatrickTypes.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final type = fitzpatrickTypes[index];
                      final isSelected = _selectedIndex == index;

                      // Determinar el color del texto sobre el color de piel
                      final textColor = type.index >= 4
                          ? Colors.white
                          : const Color(0xFF2C3E50);
                      final subTextColor = type.index >= 4
                          ? Colors.white70
                          : const Color(0xFF2C3E50).withOpacity(0.6);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: type.color,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF73C6B6)
                                  : Colors.transparent,
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? const Color(0xFF73C6B6).withOpacity(0.15)
                                    : const Color(0x0A000000),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF73C6B6)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : textColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppTranslations.getText(
                                        lang,
                                        'skin_type_${index + 1}_name',
                                      ),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppTranslations.getText(
                                        lang,
                                        'skin_type_${index + 1}_desc',
                                      ),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: subTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _selectedIndex == null
                      ? null
                      : () => _saveSkinType(_selectedIndex!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF73C6B6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(
                      0xFF2C3E50,
                    ).withOpacity(0.1),
                    disabledForegroundColor: const Color(
                      0xFF2C3E50,
                    ).withOpacity(0.3),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    AppTranslations.getText(lang, 'accept'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PANTALLA 2: DASHBOARD PRINCIPAL
class DashboardScreen extends StatefulWidget {
  final int selectedSkinTypeIndex;
  final VoidCallback onResetSkinType;

  const DashboardScreen({
    super.key,
    required this.selectedSkinTypeIndex,
    required this.onResetSkinType,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int notificationReprogramIntervalMinutes = 3;
  static const int maxExposureSeconds = 6 * 3600; // 21600 segons (6 hores)
  static const double maxSafeMinutesThreshold = 360.0; // 6 hores
  Timer? _reprogramTimer;

  // Ubicación y API
  Position? _currentPosition;
  String _locationName = "Detectando ubicación...";
  bool _locationError = false;
  double _uvIndex = 0.0;
  bool _isFetchingUv = false;
  bool _isGpsActive = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;
  Timer? _networkCheckTimer;
  bool _uvAvailable = true;
  bool _gpsPermissionDenied = false;

  // Sensor de Luz
  bool _hasPhysicalLightSensor = false;
  int _luxValue = 0;
  StreamSubscription<double>? _lightSubscription;
  StreamSubscription<InstallStatus>? _updateSubscription;

  // Banner publicitario (Google AdMob)
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  double? _adWidth;
  bool _firstFrameRendered = false;
  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;

  // Lógica del Temporizador (0 = Inicial, 1 = Calculado, 2 = Countdown Activo)
  int _buttonState = 1;
  int _calculatedSafeMinutes = 0;
  int _remainingSeconds = 0;
  double _accumulatedDosePercentage = 0.0;
  double _accumulatedVitDPercentage = 0.0;
  int _elapsedExposureSeconds = 0;
  Timer? _countdownTimer;
  Timer? _calculationTimer;
  Timer? _stateSavingTimer;
  bool _limitReachedToday = false;
  bool _demoMode = false; // Modo demo de 30 segundos
  bool _vitDCelebrated = false;
  double _lastReprogrammedDosePct = 0.0;
  double _lastReprogrammedVitDPct = 0.0;

  bool _isAutoPaused = false;
  bool _exposureSessionActive = false;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  bool _showVitDRipple = false;
  late AnimationController _vitDRippleController;
  late AnimationController _orbitalEchoController;

  // Animaciones de Alerta (Flashes)
  bool _isFlashing = false;
  bool _flashToggle = false;
  Timer? _flashTimer;

  // Formateador de tiempo actual
  late String _currentTimeString;
  late Timer _clockTimer;

  List<Map<String, dynamic>> _hourlyForecast = [];
  PageController? _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    final today = DateTime.now();
    _hourlyForecast = List.generate(
      24,
      (i) => {
        'hour': DateTime(today.year, today.month, today.day, i),
        'uv': _calculateEstimatedUvForHour(i),
      },
    );
    WidgetsBinding.instance.addObserver(this);

    _vitDRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _orbitalEchoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _blinkAnimation = CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    );
    _vitDRippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showVitDRipple = false;
        });
        _vitDRippleController.reset();
      }
    });
    appLanguage.addListener(_onLanguageChanged);
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateClock(),
    );

    // Detecció de connectivitat inicial i subscripció reactiva en temps real
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _updateConnectivityState(results);
    });

    // Heartbeat periòdic cada 3 segons per a una comprovació de connectivitat robusta
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      try {
        final List<ConnectivityResult> results = await Connectivity()
            .checkConnectivity();
        _updateConnectivityState(results);
      } catch (e) {
        debugPrint("Error checking connectivity heartbeat: $e");
      }
    });

    _initUpdateListener();

    // Calcular inicialmente
    _calculateRecommendedTime();

    // Optimización de arranque rápido: Diferir tareas pesadas para después del renderizado del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUpdateOnStartup();
        setState(() {
          _firstFrameRendered = true;
        });
        _loadSavedSessionState();
        _loadBannerAd();
        _loadInterstitialAd();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_firstFrameRendered) {
      _loadBannerAd();
    }
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSkinTypeIndex != widget.selectedSkinTypeIndex) {
      _calculateRecommendedTime();
    }
  }

  void _loadBannerAd() async {
    final double width = MediaQuery.of(context).size.width;
    if (_adWidth == width) {
      return;
    }

    if (_bannerAd != null) {
      await _bannerAd!.dispose();
      _bannerAd = null;
      setState(() {
        _isBannerAdReady = false;
      });
    }

    _adWidth = width;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width.truncate(),
    );

    if (size == null) {
      debugPrint('Unable to get adaptive banner size.');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd loaded successfully.');
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          setState(() {
            _isBannerAdReady = false;
          });
        },
      ),
    );

    _bannerAd!.load();
  }

  void _loadInterstitialAd() {
    if (_isAdLoading || _interstitialAd != null) return;
    _isAdLoading = true;

    final String adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('InterstitialAd loaded successfully.');
          _interstitialAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    appLanguage.removeListener(_onLanguageChanged);
    _clockTimer.cancel();
    _calculationTimer?.cancel();
    _lightSubscription?.cancel();
    _updateSubscription?.cancel();
    _countdownTimer?.cancel();
    _stateSavingTimer?.cancel();
    _flashTimer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _connectivitySubscription?.cancel();
    _networkCheckTimer?.cancel();
    _vitDRippleController.dispose();
    _orbitalEchoController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _saveSessionState() async {
    final double currentIntensity = _demoMode
        ? (100.0 / 30.0)
        : _getCurrentPercentagePerSecond();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('timer_active', true);
      await prefs.setBool('is_auto_paused', _isAutoPaused);
      await prefs.setInt(
        'last_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setDouble('accumulated_dose_pct', _accumulatedDosePercentage);
      await prefs.setDouble(
        'accumulated_vit_d_pct',
        _accumulatedVitDPercentage,
      );
      await prefs.setDouble('last_skin_intensity', currentIntensity);
      await prefs.setBool('demo_mode', _demoMode);
      await prefs.setInt('elapsed_exposure_seconds', _elapsedExposureSeconds);
    } catch (e) {
      debugPrint("Error saving session state: $e");
    }
  }

  Future<void> _clearSavedSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('timer_active', false);
      await prefs.remove('is_auto_paused');
      await prefs.remove('last_timestamp');
      await prefs.remove('accumulated_dose_pct');
      await prefs.remove('accumulated_vit_d_pct');
      await prefs.remove('last_skin_intensity');
      await prefs.remove('demo_mode');
      await prefs.remove('elapsed_exposure_seconds');
    } catch (e) {
      debugPrint("Error clearing saved session state: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_buttonState == 2) {
        await _saveSessionState();
        await _reprogramNotifications();
        _countdownTimer?.cancel();
        _stateSavingTimer?.cancel();
        _reprogramTimer?.cancel();
        _orbitalEchoController.stop();
        if (mounted) {
          setState(() {
            _buttonState = 1;
          });
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    if (_buttonState == 2) return;
    try {
      // 1. Recuperació de SharedPreferences (Dades Històriques):
      final prefs = await SharedPreferences.getInstance();
      final bool active = prefs.getBool('timer_active') ?? false;
      if (!active) return;

      final int? lastTimestamp = prefs.getInt('last_timestamp');
      final double? savedDosePct = prefs.getDouble('accumulated_dose_pct');
      final double? savedVitDPct = prefs.getDouble('accumulated_vit_d_pct');
      final double? lastSkinIntensity = prefs.getDouble('last_skin_intensity');
      final bool? savedDemoMode = prefs.getBool('demo_mode');
      final int? savedElapsed = prefs.getInt('elapsed_exposure_seconds');
      final bool savedAutoPaused = prefs.getBool('is_auto_paused') ?? false;

      if (lastTimestamp == null ||
          savedDosePct == null ||
          lastSkinIntensity == null) {
        return;
      }

      // Check if already 100% or more
      if (savedDosePct >= 100.0) {
        return;
      }

      // 2. Càlcul d'Acumulació en Segon Pla ( Catch-up ):
      final double elapsedSeconds =
          (DateTime.now().millisecondsSinceEpoch - lastTimestamp) / 1000.0;

      int savedElapsedSecs = savedElapsed ?? 0;
      bool limitReachedInBackground = false;
      double activeElapsedSeconds = savedAutoPaused ? 0.0 : elapsedSeconds;

      if (!savedAutoPaused && savedElapsedSecs + elapsedSeconds >= maxExposureSeconds) {
        activeElapsedSeconds = (maxExposureSeconds - savedElapsedSecs)
            .toDouble();
        limitReachedInBackground = true;
      }

      double newDosePct = savedDosePct;
      double newVitDPct = savedVitDPct ?? 0.0;

      if (activeElapsedSeconds > 0) {
        final double doseIncrement = activeElapsedSeconds * lastSkinIntensity;
        final double vitDIncrement =
            activeElapsedSeconds * lastSkinIntensity * 4.0;

        newDosePct = savedDosePct + doseIncrement;
        newVitDPct = (savedVitDPct ?? 0.0) + vitDIncrement;

        if (newDosePct > 100.0) {
          newDosePct = 100.0;
        }
        if (newVitDPct > 100.0) {
          newVitDPct = 100.0;
        }
      }

      int remainingSeconds = 0;
      if (lastSkinIntensity > 0) {
        remainingSeconds = ((100.0 - newDosePct) / lastSkinIntensity).round();
      }
      int newElapsed = savedElapsedSecs;
      if (elapsedSeconds > 0 && !savedAutoPaused) {
        if (limitReachedInBackground) {
          newElapsed = maxExposureSeconds;
        } else {
          newElapsed += elapsedSeconds.round();
        }
      }

      setState(() {
        _demoMode = savedDemoMode ?? false;
        _accumulatedDosePercentage = newDosePct;
        _accumulatedVitDPercentage = newVitDPct;
        _remainingSeconds = remainingSeconds;
        _elapsedExposureSeconds = newElapsed;
        _exposureSessionActive = true;
        _isAutoPaused = savedAutoPaused;
        if (_accumulatedVitDPercentage >= 100.0) {
          if (!_vitDCelebrated) {
            _vitDCelebrated = true;
            // No trigger celebration here because it was reached in the background
          }
        }
      });

      if (limitReachedInBackground) {
        _countdownTimer?.cancel();
        _stateSavingTimer?.cancel();
        _reprogramTimer?.cancel();
        _orbitalEchoController.stop();
        _orbitalEchoController.reset();
        await _clearSavedSessionState();
        try {
          await NotificationService().cancelAllExposureNotifications();
        } catch (e) {
          debugPrint("Error cancelling notifications: $e");
        }
        setState(() {
          _buttonState = 1;
          _exposureSessionActive = false;
          _isAutoPaused = false;
        });
        return;
      }

      if (newDosePct >= 100.0 || remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _stateSavingTimer?.cancel();
        _orbitalEchoController.stop();
        _orbitalEchoController.reset();
        _onTimeFinished();
        return;
      }

      // 3. Consulta de dades actuals (API Índex UV):
      await _fetchLocationAndUv();

      // 4. Activació de lectors de sensors i procés regular:
      await _initLightSensor();
      await _startCountdown(resuming: true);

      // 5. Re-activació del timer de guardat a LocalStorage:
      // (La gestió dels 10 segons de durada del timer s'aplica directament a _startCountdown)
    } catch (e) {
      debugPrint("Error handling app resumed: $e");
    }
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        if (_isFetchingUv) {
          _locationName = AppTranslations.getText(
            appLanguage.value,
            'detecting_location',
          );
        } else if (_locationError) {
          _locationName = AppTranslations.getText(
            appLanguage.value,
            'location_unavailable',
          );
        }
      });
      if (_buttonState == 2) {
        _reprogramNotifications();
      }
    }
  }

  Future<void> _reprogramNotifications() async {
    final double startingDosePct = _accumulatedDosePercentage;
    final double startingVitDPct = _accumulatedVitDPercentage;
    final double pctPerSec = _demoMode
        ? (100.0 / 30.0)
        : _getCurrentPercentagePerSecond();

    final double dosePctRemaining = (100.0 - startingDosePct).clamp(0.0, 100.0);
    final double vitDPctRemaining = (100.0 - startingVitDPct).clamp(0.0, 100.0);

    final int secondsToMaxDose = pctPerSec > 0
        ? (dosePctRemaining / pctPerSec).round()
        : 0;
    final int secondsToVitD = pctPerSec > 0
        ? (vitDPctRemaining / (pctPerSec * 4.0)).round()
        : 0;

    try {
      await NotificationService().scheduleExposureNotifications(
        vitDSeconds: secondsToVitD,
        maxDoseSeconds: secondsToMaxDose,
        lang: appLanguage.value,
        textGetter: AppTranslations.getText,
      );
      _lastReprogrammedDosePct = startingDosePct;
      _lastReprogrammedVitDPct = startingVitDPct;
    } catch (e) {
      debugPrint("Error rescheduling notifications: $e");
    }
  }

  void _updateClock() {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    if (mounted) {
      setState(() {
        _currentTimeString = timeStr;
      });
    }
  }

  void _startNormalSensorsAndUv() {
    if (mounted) {
      _initLightSensor();
      _fetchLocationAndUv();
    }
  }

  // Carga el estado guardado de la sesión y maneja límites diarios
  Future<void> _loadSavedSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final savedLimitDate = prefs.getString('daily_limit_date');
      if (savedLimitDate == today) {
        setState(() {
          _limitReachedToday = true;
          _accumulatedDosePercentage = 100.0;
          _accumulatedVitDPercentage = 100.0;
        });
        _startNormalSensorsAndUv();
        return;
      }

      final double? savedDosePct = prefs.getDouble('accumulated_dose_pct');
      final double? savedVitDPct = prefs.getDouble('accumulated_vit_d_pct');
      final bool active = prefs.getBool('timer_active') ?? false;
      final int? savedElapsed = prefs.getInt('elapsed_exposure_seconds');

      if (savedDosePct != null) {
        setState(() {
          _accumulatedDosePercentage = savedDosePct;
          _accumulatedVitDPercentage = savedVitDPct ?? 0.0;
          _elapsedExposureSeconds = savedElapsed ?? 0;
        });
      }

      if (active && savedDosePct != null && savedDosePct < 100.0) {
        await _handleAppResumed();
      } else {
        _startNormalSensorsAndUv();
      }
    } catch (e) {
      debugPrint("Error loading saved session state: $e");
      _startNormalSensorsAndUv();
    }
  }

  // Registra que hoy se alcanzó el límite
  Future<void> _saveDailyLimitReached() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('daily_limit_date', today);
    setState(() {
      _limitReachedToday = true;
      _buttonState = 1;
    });
  }

  // Inicializa el sensor de luz física o fallback simulado
  Future<void> _initLightSensor() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final sensor = AmbientLight();
        final initialLux = await sensor.currentAmbientLight();
        if (initialLux != null) {
          setState(() {
            _hasPhysicalLightSensor = true;
            _luxValue = initialLux.round();
          });
          _calculateRecommendedTime();

          // Programar càlcul periòdic cada 2 segons
          _calculationTimer?.cancel();
           _calculationTimer = Timer.periodic(const Duration(seconds: 2), (
            timer,
          ) {
            if (_buttonState == 1 || _exposureSessionActive) {
              _calculateRecommendedTime();
            }
          });

          await _lightSubscription?.cancel();
          _lightSubscription = sensor.ambientLightStream.listen((lux) {
            setState(() {
              _luxValue = lux.round();
            });
            if (_buttonState == 1 || _exposureSessionActive) {
              _calculateRecommendedTime();
            }
          });
          return;
        }
      } catch (e) {
        debugPrint("Error inicializando sensor de luz: $e");
      }
    }
    // Si no está disponible
    setState(() {
      _hasPhysicalLightSensor = false;
      _luxValue = 0;
    });
    _calculateRecommendedTime();
  }

  // Obtiene posición GPS y consulta Open-Meteo
  Future<void> _fetchLocationAndUv() async {
    try {
      final List<ConnectivityResult> connectivityResults = await Connectivity()
          .checkConnectivity();
      final bool isCurrentlyOffline =
          connectivityResults.isEmpty ||
          connectivityResults.contains(ConnectivityResult.none) ||
          (!connectivityResults.contains(ConnectivityResult.mobile) &&
              !connectivityResults.contains(ConnectivityResult.wifi) &&
              !connectivityResults.contains(ConnectivityResult.ethernet));
      bool hasInternet = !isCurrentlyOffline;
      if (hasInternet) {
        hasInternet = await _hasRealInternet();
      }
      setState(() {
        _isOffline = !hasInternet;
      });
    } catch (e) {
      debugPrint("Error checking connectivity: $e");
    }

    setState(() {
      _isFetchingUv = true;
      _locationError = false;
      _uvAvailable = !_isOffline;
      _locationName = AppTranslations.getText(
        appLanguage.value,
        'detecting_location',
      );
    });

    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        throw 'Test mode: skip GPS';
      }
      Position position = await _determinePosition();
      setState(() {
        _currentPosition = position;
        _isGpsActive = true;
        _locationError = false;
        _locationName =
            "Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}";
      });
      if (_isOffline) {
        setState(() {
          _uvAvailable = false;
        });
      } else {
        await _fetchUvIndex(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Error de localización GPS: $e");
      setState(() {
        _isGpsActive = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final String? manualCity = prefs.getString('manual_city');
      final double? manualLat = prefs.getDouble('manual_lat');
      final double? manualLon = prefs.getDouble('manual_lon');

      if (manualCity != null && manualLat != null && manualLon != null) {
        setState(() {
          _locationError = false;
          _locationName = "$manualCity (manual)";
          _currentPosition = Position(
            latitude: manualLat,
            longitude: manualLon,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });
        if (_isOffline) {
          setState(() {
            _uvAvailable = false;
          });
        } else {
          await _fetchUvIndex(manualLat, manualLon);
        }
      } else {
        if (_isOffline) {
          setState(() {
            _locationError = true;
            _uvAvailable = false;
            _locationName = AppTranslations.getText(
              appLanguage.value,
              'location_unavailable',
            );
          });
          return;
        }

        final ipLoc = await IpLocationService.fetchIpLocation();
        if (ipLoc != null) {
          String networkSuffix;
          switch (appLanguage.value) {
            case 'ca':
              networkSuffix = '(xarxa)';
              break;
            case 'es':
              networkSuffix = '(red)';
              break;
            case 'en':
            default:
              networkSuffix = '(network)';
              break;
          }
          setState(() {
            _locationError = false;
            _locationName = "${ipLoc.city} $networkSuffix";
            _currentPosition = Position(
              latitude: ipLoc.latitude,
              longitude: ipLoc.longitude,
              timestamp: DateTime.now(),
              accuracy: 0.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
          });
          await _fetchUvIndex(ipLoc.latitude, ipLoc.longitude);
        } else {
          setState(() {
            _locationError = true;
            _uvAvailable = false;
            _locationName = AppTranslations.getText(
              appLanguage.value,
              'location_unavailable',
            );
          });
        }
      }
    } finally {
      setState(() {
        _isFetchingUv = false;
      });
    }
  }

  void _updateConnectivityState(List<ConnectivityResult> results) async {
    final bool isCurrentlyOffline =
        results.isEmpty ||
        results.contains(ConnectivityResult.none) ||
        (!results.contains(ConnectivityResult.mobile) &&
            !results.contains(ConnectivityResult.wifi) &&
            !results.contains(ConnectivityResult.ethernet));

    bool hasInternet = !isCurrentlyOffline;
    if (hasInternet) {
      hasInternet = await _hasRealInternet();
    }

    final bool finalOfflineState = !hasInternet;

    if (mounted) {
      final bool wasOffline = _isOffline;
      setState(() {
        _isOffline = finalOfflineState;
        if (_isOffline) {
          _uvAvailable = false;
        } else {
          _uvAvailable = true;
        }
      });

      if (_isOffline && !_isGpsActive) {
        final prefs = await SharedPreferences.getInstance();
        final String? manualCity = prefs.getString('manual_city');
        if (manualCity != null && mounted) {
          setState(() {
            _locationError = false;
            _locationName = "$manualCity (manual)";
          });
        } else if (mounted) {
          setState(() {
            _locationError = true;
            _locationName = AppTranslations.getText(
              appLanguage.value,
              'location_unavailable',
            );
          });
        }
      }

      // Si tornem a estar online, recarreguem automàticament
      if (wasOffline && !_isOffline) {
        _fetchLocationAndUv();
      }
    }
  }

  Future<bool> _hasRealInternet() async {
    if (kDebugMode && Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Determinar posición usando geolocator
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Servicio de ubicación desactivado.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Permisos de ubicación denegados.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Permisos denegados permanentemente.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 5),
    );
  }

  Future<void> _openSearchCityBottomSheet() async {
    final SelectedCity? result = await showModalBottomSheet<SelectedCity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchCityBottomSheet(),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('manual_city', result.name);
      await prefs.setDouble('manual_lat', result.latitude);
      await prefs.setDouble('manual_lon', result.longitude);

      setState(() {
        _locationError = false;
        _isGpsActive = false;
        _locationName = "${result.name} (manual)";
        _currentPosition = Position(
          latitude: result.latitude,
          longitude: result.longitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
      });
      await _fetchUvIndex(result.latitude, result.longitude);
    }
  }

  // Estimación de UV por hora para el gráfico
  double _calculateEstimatedUvForHour(int hour) {
    if (hour < 8 || hour > 19) return 0.1;
    final diff = (hour - 13).abs(); // Distancia al mediodía (13:00)
    double estimated = 8.0 - (diff * 1.2);
    return estimated < 0.5 ? 0.5 : estimated;
  }

  // Estimación de UV secundaria si la API falla
  double _calculateEstimatedUv() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return 5.0; // Moderate UV index for stable tests at any time of day
    }
    return _calculateEstimatedUvForHour(DateTime.now().hour);
  }

  // Petición a Open-Meteo API
  Future<void> _fetchUvIndex(double lat, double lon) async {
    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=uv_index&timezone=auto";
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        throw 'Test mode: skip HTTP';
      }
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hourlyTimes = data['hourly']?['time'] as List?;
        final hourlyUv = data['hourly']?['uv_index'] as List?;
        if (hourlyTimes != null && hourlyUv != null && hourlyTimes.isNotEmpty) {
          final now = DateTime.now();
          int closestIndex = 0;
          Duration minDifference = const Duration(days: 365);
          for (int i = 0; i < hourlyTimes.length; i++) {
            final time = DateTime.parse(hourlyTimes[i] as String);
            final diff = time.difference(now).abs();
            if (diff < minDifference) {
              minDifference = diff;
              closestIndex = i;
            }
          }

          // Extraer previsión de las 24 horas del día actual
          final List<Map<String, dynamic>> forecast = [];
          final today = DateTime.now();
          for (int i = 0; i < hourlyTimes.length; i++) {
            final time = DateTime.parse(hourlyTimes[i] as String);
            if (time.year == today.year &&
                time.month == today.month &&
                time.day == today.day) {
              forecast.add({
                'hour': time,
                'uv': (hourlyUv[i] as num).toDouble(),
              });
            }
          }

          // Si por zona horaria no hay coincidencias exactas para "hoy", cogemos las primeras 24 horas de la respuesta
          if (forecast.isEmpty) {
            for (int i = 0; i < math.min(24, hourlyTimes.length); i++) {
              forecast.add({
                'hour': DateTime.parse(hourlyTimes[i] as String),
                'uv': (hourlyUv[i] as num).toDouble(),
              });
            }
          }

          setState(() {
            _uvIndex = (hourlyUv[closestIndex] as num).toDouble();
            _uvAvailable = true;
            _hourlyForecast = forecast;
          });
          _calculateRecommendedTime();
          return;
        }
      }
      throw 'Respuesta inválida de la API.';
    } catch (e) {
      debugPrint("Error obteniendo UV: $e");
      // Asignar un UV por defecto según la hora/luz para que no falle el prototipo y rellenar gráfica
      final List<Map<String, dynamic>> fallbackForecast = [];
      final today = DateTime.now();
      for (int i = 0; i < 24; i++) {
        final time = DateTime(today.year, today.month, today.day, i);
        fallbackForecast.add({
          'hour': time,
          'uv': _calculateEstimatedUvForHour(i),
        });
      }
      setState(() {
        _uvIndex = _calculateEstimatedUv();
        _uvAvailable = false;
        _hourlyForecast = fallbackForecast;
      });
      _calculateRecommendedTime();
    }
  }

  // Obtiene la estación del año basada en coordenadas e históricas
  String _getSeason() {
    final now = DateTime.now();
    final month = now.month;
    final lat =
        _currentPosition?.latitude ?? 41.3851; // Por defecto norte (Barcelona)
    final isNorthern = lat >= 0;

    if (month >= 3 && month <= 5) {
      return isNorthern ? "Primavera" : "Otoño";
    } else if (month >= 6 && month <= 8) {
      return isNorthern ? "Verano" : "Invierno";
    } else if (month >= 9 && month <= 11) {
      return isNorthern ? "Otoño" : "Primavera";
    } else {
      return isNorthern ? "Invierno" : "Verano";
    }
  }

  double _getAttenuationFactor(int lux) {
    if (lux <= 0) {
      return 0.0;
    } else if (lux <= 400) {
      return 0.5 * (lux / 400.0);
    } else if (lux <= 6000) {
      return 0.5 + 0.5 * ((lux - 400.0) / 5600.0);
    } else {
      return 1.0;
    }
  }

  String _getEnvironmentName(int lux, String lang) {
    if (lux >= 6001) {
      return AppTranslations.getText(lang, 'direct_sun');
    } else if (lux >= 401) {
      return AppTranslations.getText(lang, 'shade_umbrella');
    } else {
      return AppTranslations.getText(lang, 'indoor_deep_shade');
    }
  }

  IconData _getEnvironmentIcon(int lux) {
    if (lux >= 6001) {
      return Icons.wb_sunny_rounded;
    } else if (lux >= 401) {
      return Icons.beach_access_rounded;
    } else {
      return Icons.house_siding_rounded;
    }
  }

  Color _getEnvironmentIconColor(int lux) {
    if (lux >= 6001) {
      return const Color(0xFFF7D070);
    } else {
      return const Color(0xFF73C6B6);
    }
  }

  Future<void> _saveAutoPausedState(bool paused) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_auto_paused', paused);
    } catch (e) {
      debugPrint("Error saving auto-paused state: $e");
    }
  }

  void _checkSafeExposureLimits() {
    if (!_exposureSessionActive) return;

    final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
    final double doseTolerance = currentType.dose.toDouble();
    
    final double theoreticalSafeMinutesSun = _uvIndex <= 0.0
        ? double.infinity
        : (doseTolerance / (60.0 * _uvIndex));

    if (_calculatedSafeMinutes > 360.0) {
      // CAS 1 (Causant: Índex UV Baix)
      if (theoreticalSafeMinutesSun > 360.0 || _uvIndex < 0.1) {
        _resetCountdown();
        return;
      }

      // CAS 2 (Causant: Poca Llum / Ombra)
      if (theoreticalSafeMinutesSun <= 360.0) {
        if (!_isAutoPaused) {
          setState(() {
            _isAutoPaused = true;
          });
          
          _countdownTimer?.cancel();
          _stateSavingTimer?.cancel();
          _reprogramTimer?.cancel();
          _orbitalEchoController.stop();

          _saveAutoPausedState(true);

          try {
            NotificationService().cancelAllExposureNotifications();
          } catch (e) {
            debugPrint("Error cancelling notifications during auto-pause: $e");
          }

          _blinkController.repeat(reverse: true);
        }
      }
    } else {
      // Represa Automàtica
      if (_isAutoPaused) {
        setState(() {
          _isAutoPaused = false;
        });
        _blinkController.stop();
        _blinkController.value = 1.0;

        _saveAutoPausedState(false);
        _startCountdown(resuming: true);
      }
    }
  }

  // Cálculo del tiempo recomendado en minutos
  void _calculateRecommendedTime() {
    final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
    final factorAtenuacion = _hasPhysicalLightSensor
        ? _getAttenuationFactor(_luxValue)
        : 1.0;

    final skinImpact = _uvIndex * factorAtenuacion;
    double rawTime;
    if (skinImpact <= 0.0) {
      rawTime = 480.0;
    } else {
      rawTime = currentType.dose / skinImpact;
      if (rawTime > 480.0) {
        rawTime = 480.0;
      }
    }

    setState(() {
      _calculatedSafeMinutes = rawTime.round();
      if (_calculatedSafeMinutes < 1) _calculatedSafeMinutes = 1;
      if (_buttonState != 2) {
        _buttonState = 1;
      }
    });

    _checkSafeExposureLimits();
  }

  // Iniciar la cuenta atrás
  Future<void> _startCountdown({bool resuming = false}) async {
    _loadInterstitialAd();
    final bool isPausedResume =
        _accumulatedDosePercentage > 0.0 && _accumulatedDosePercentage < 100.0;
    final bool shouldResume = resuming || isPausedResume;

    if (!shouldResume) {
      int durationSeconds = _demoMode ? 30 : _calculatedSafeMinutes * 60;
      setState(() {
        _remainingSeconds = durationSeconds;
        _accumulatedDosePercentage = 0.0;
        _accumulatedVitDPercentage = 0.0;
        _elapsedExposureSeconds = 0;
        _vitDCelebrated = false;
        _buttonState = 2;
        _lastReprogrammedDosePct = 0.0;
        _lastReprogrammedVitDPct = 0.0;
        _exposureSessionActive = true;
        _isAutoPaused = false;
      });
    } else {
      double percentagePerSecond = _demoMode
          ? (100.0 / 30.0)
          : _getCurrentPercentagePerSecond();
      double remainingPercentage = 100.0 - _accumulatedDosePercentage;
      int durationSeconds = percentagePerSecond > 0.0
          ? (remainingPercentage / percentagePerSecond).round()
          : 480 * 60;
      if (durationSeconds < 0) durationSeconds = 0;

      setState(() {
        _remainingSeconds = durationSeconds;
        _buttonState = 2;
        _exposureSessionActive = true;
      });
    }

    _countdownTimer?.cancel();
    if (!_isAutoPaused) {
      _orbitalEchoController.repeat();
    } else {
      _orbitalEchoController.stop();
      _blinkController.repeat(reverse: true);
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isAutoPaused) {
        return; // Congela l'acumulació i el compte enrere
      }

      if (_elapsedExposureSeconds >= maxExposureSeconds) {
        _countdownTimer?.cancel();
        _stateSavingTimer?.cancel();
        _reprogramTimer?.cancel();
        _orbitalEchoController.stop();
        _orbitalEchoController.reset();
        try {
          NotificationService().cancelAllExposureNotifications();
        } catch (e) {
          debugPrint("Error cancelling notifications: $e");
        }
        setState(() {
          _buttonState = 1;
          _exposureSessionActive = false;
          _isAutoPaused = false;
        });
        return;
      }

      if (_accumulatedDosePercentage < 100.0) {
        double percentagePerSecond;
        if (_demoMode) {
          percentagePerSecond = 100.0 / 30.0;
        } else {
          percentagePerSecond = _getCurrentPercentagePerSecond();
        }

        setState(() {
          _elapsedExposureSeconds++;
          _accumulatedDosePercentage += percentagePerSecond;
          if (_accumulatedDosePercentage > 100.0) {
            _accumulatedDosePercentage = 100.0;
          }
          _accumulatedVitDPercentage += percentagePerSecond * 4.0;
          if (_accumulatedVitDPercentage >= 100.0) {
            _accumulatedVitDPercentage = 100.0;
            if (!_vitDCelebrated) {
              _vitDCelebrated = true;
              if (WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) {
                _triggerVitDCelebration();
              }
            }
          }
          double remainingPercentage = 100.0 - _accumulatedDosePercentage;
          if (percentagePerSecond > 0.0) {
            _remainingSeconds = (remainingPercentage / percentagePerSecond)
                .round();
          } else {
            _remainingSeconds = 480 * 60;
          }
          if (_remainingSeconds < 0) {
            _remainingSeconds = 0;
          }
        });

        if (_accumulatedDosePercentage >= 100.0 || _remainingSeconds <= 0) {
          _countdownTimer?.cancel();
          _stateSavingTimer?.cancel();
          _reprogramTimer?.cancel();
          _orbitalEchoController.stop();
          _orbitalEchoController.reset();
          _onTimeFinished();
        } else {
          final double doseDelta =
              (_accumulatedDosePercentage - _lastReprogrammedDosePct).abs();
          final double vitDDelta =
              (_accumulatedVitDPercentage - _lastReprogrammedVitDPct).abs();
          if (doseDelta >= 5.0 || vitDDelta >= 5.0) {
            _lastReprogrammedDosePct = _accumulatedDosePercentage;
            _lastReprogrammedVitDPct = _accumulatedVitDPercentage;
            _saveSessionState();
            _reprogramNotifications();
          }
        }
      } else {
        _countdownTimer?.cancel();
        _stateSavingTimer?.cancel();
        _reprogramTimer?.cancel();
        _orbitalEchoController.stop();
        _orbitalEchoController.reset();
        _onTimeFinished();
      }
    });

    _saveSessionState();
    _stateSavingTimer?.cancel();
    _stateSavingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveSessionState();
    });

    try {
      final notificationService = NotificationService();
      await notificationService.requestNotificationPermission();
      await notificationService.requestExactAlarmsPermission();
      await _reprogramNotifications();
    } catch (e) {
      debugPrint("Error scheduling exposure notifications: $e");
    }

    _reprogramTimer?.cancel();
    _reprogramTimer = Timer.periodic(
      const Duration(minutes: notificationReprogramIntervalMinutes),
      (timer) async {
        await _saveSessionState();
        await _reprogramNotifications();
      },
    );
  }

  // Pausar la exposición manteniendo los valores acumulados intactos
  Future<void> _pauseCountdown() async {
    _countdownTimer?.cancel();
    _stateSavingTimer?.cancel();
    _reprogramTimer?.cancel();
    _orbitalEchoController.stop();
    _blinkController.stop();

    try {
      await NotificationService().cancelAllExposureNotifications();
    } catch (e) {
      debugPrint("Error cancelling notifications: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_active', false);
    await prefs.remove('is_auto_paused');
    await prefs.setDouble('accumulated_dose_pct', _accumulatedDosePercentage);
    await prefs.setDouble('accumulated_vit_d_pct', _accumulatedVitDPercentage);

    setState(() {
      _buttonState = 1;
      _demoMode = false;
      _exposureSessionActive = false;
      _isAutoPaused = false;
    });
  }

  // Resetear la exposición a 0%
  Future<void> _resetCountdown() async {
    _countdownTimer?.cancel();
    _stateSavingTimer?.cancel();
    _reprogramTimer?.cancel();
    _orbitalEchoController.stop();
    _orbitalEchoController.reset();
    _blinkController.stop();

    try {
      await NotificationService().cancelAllExposureNotifications();
    } catch (e) {
      debugPrint("Error cancelling notifications: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_active', false);
    await prefs.remove('is_auto_paused');
    await prefs.remove('last_timestamp');
    await prefs.setDouble('accumulated_dose_pct', 0.0);
    await prefs.setDouble('accumulated_vit_d_pct', 0.0);
    await prefs.setInt('elapsed_exposure_seconds', 0);
    await prefs.remove('last_skin_intensity');
    await prefs.remove('demo_mode');
    await prefs.remove('daily_limit_date');

    setState(() {
      _buttonState = 1;
      _demoMode = false;
      _accumulatedDosePercentage = 0.0;
      _accumulatedVitDPercentage = 0.0;
      _elapsedExposureSeconds = 0;
      _vitDCelebrated = false;
      _limitReachedToday = false;
      _locationError = false;
      _isOffline = false;
      _uvAvailable = true;
      _lastReprogrammedDosePct = 0.0;
      _lastReprogrammedVitDPct = 0.0;
      _exposureSessionActive = false;
      _isAutoPaused = false;
    });
  }

  void _triggerVitDCelebration() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint("Error al realitzar feedback hàptic: $e");
    }

    setState(() {
      _showVitDRipple = true;
    });
    _vitDRippleController.forward(from: 0.0);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.getText(appLanguage.value, 'vit_d_100_percent'),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF0023FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    try {
      final player = AudioPlayer();
      player.play(AssetSource('sounds/seeds.mp3'));
    } catch (e) {
      debugPrint("Error en reproduir l'àudio de celebració: $e");
    }
  }

  // Acción finalizada
  void _onTimeFinished({bool playAlarmSound = true}) {
    _stateSavingTimer?.cancel();
    _reprogramTimer?.cancel();
    _clearSavedSessionState();

    try {
      NotificationService().cancelAllExposureNotifications();
    } catch (e) {
      debugPrint("Error al cancel·lar les notificacions: $e");
    }

    if (playAlarmSound) {
      // 1. Activar alertas sonoras nativas
      try {
        FlutterRingtonePlayer().playAlarm(asAlarm: true);
      } catch (e) {
        debugPrint("Error con RingtonePlayer: $e");
      }
    }

    // 2. Activar la animación de flash (destellos)
    setState(() {
      _isFlashing = true;
    });
    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _flashToggle = !_flashToggle;
      });
    });

    // 3. Mostrar diálogo a pantalla completa
    _showFullscreenAlert();
  }

  // Apaga la alarma sonora y los destellos
  void _stopAlarmSoundAndFlashing() {
    _flashTimer?.cancel();
    try {
      FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint("Error al parar Ringtone: $e");
    }
    setState(() {
      _isFlashing = false;
    });
  }

  // Cierra el diálogo de advertencia, apaga la alarma y los destellos, y persiste el límite
  void _dismissAlert() {
    _stopAlarmSoundAndFlashing();

    setState(() {
      _demoMode = false;
      _accumulatedDosePercentage = 100.0;
      _accumulatedVitDPercentage = 100.0;
    });

    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _loadInterstitialAd();
          Navigator.of(context).pop(); // Cerrar diálogo
          _saveDailyLimitReached(); // Persistir hoy como completado
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _loadInterstitialAd();
          Navigator.of(context).pop(); // Cerrar diálogo
          _saveDailyLimitReached(); // Persistir hoy como completado
        },
      );
      _interstitialAd!.show();
    } else {
      Navigator.of(context).pop(); // Cerrar diálogo
      _saveDailyLimitReached(); // Persistir hoy como completado
    }
  }

  void _showFullscreenAlert() {
    bool localAlarmSoundStopped = false;
    final lang = appLanguage.value;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: AppTranslations.getText(
        lang,
        'safe_exposure_finished_title',
      ),
      pageBuilder: (context, anim1, anim2) {
        final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: const Color(0xFFFFFFFF),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/icon512.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        AppTranslations.getText(
                          lang,
                          'safe_exposure_finished_title',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppTranslations.getText(
                          lang,
                          'fullscreen_alert_body',
                        ).replaceAll('{phototype}', currentType.name),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2C3E50).withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA8E6CF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: Color(0xFF73C6B6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppTranslations.getText(lang, 'shadow_warning'),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (!localAlarmSoundStopped) {
                            _stopAlarmSoundAndFlashing();
                            setDialogState(() {
                              localAlarmSoundStopped = true;
                            });
                          } else {
                            _dismissAlert();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF73C6B6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          localAlarmSoundStopped
                              ? AppTranslations.getText(lang, 'understood')
                              : AppTranslations.getText(lang, 'silence_alarm'),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatLux(int lux) {
    final valueStr = lux.toString();
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return valueStr.replaceAllMapped(regExp, (Match match) => ',');
  }

  void _showLightSensorInfoDialog() {
    final lang = appLanguage.value;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            AppTranslations.getText(lang, 'info_dialog_title'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.getText(lang, 'light_sensor_info'),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2C3E50).withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF73C6B6),
              ),
              child: Text(
                AppTranslations.getText(lang, 'understood'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHeaderInfoDialog() {
    final lang = appLanguage.value;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            AppTranslations.getText(lang, 'info_dialog_title'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.getText(lang, 'header_info_p1'),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2C3E50).withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppTranslations.getText(lang, 'header_info_p2'),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2C3E50).withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE74C3C).withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.health_and_safety_outlined,
                          color: Color(0xFFE74C3C),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppTranslations.getText(lang, 'disclaimer_title'),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFC0392B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppTranslations.getText(lang, 'disclaimer_point1'),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF2C3E50).withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTranslations.getText(lang, 'disclaimer_point2'),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF2C3E50).withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTranslations.getText(lang, 'disclaimer_point3'),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF2C3E50).withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF73C6B6),
              ),
              child: Text(
                AppTranslations.getText(lang, 'understood'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    final lang = appLanguage.value;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            AppTranslations.getText(lang, 'settings_title'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.contrast, color: Color(0xFF73C6B6)),
                title: Text(
                  AppTranslations.getText(lang, 'change_skin_type'),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2C3E50),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onResetSkinType();
                },
              ),
              const Divider(color: Color(0xFFE5E8E8), height: 1, thickness: 1),
              ListTile(
                titleAlignment: ListTileTitleAlignment.top,
                leading: const Icon(
                  Icons.language_outlined,
                  color: Color(0xFF73C6B6),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppTranslations.getText(lang, 'select_language'),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2C3E50),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      value: lang,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF73C6B6),
                      ),
                      dropdownColor: const Color(0xFFFBF9F5),
                      borderRadius: BorderRadius.circular(16),
                      onChanged: (String? newLang) async {
                        if (newLang != null) {
                          appLanguage.value = newLang;
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('app_language', newLang);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'es', child: Text('Español')),
                        DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'it', child: Text('Italiano')),
                        DropdownMenuItem(value: 'pt', child: Text('Português')),
                        DropdownMenuItem(value: 'ca', child: Text('Català')),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isGpsActive) ...[
                const Divider(
                  color: Color(0xFFE5E8E8),
                  height: 1,
                  thickness: 1,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.gps_fixed,
                    color: Color(0xFF73C6B6),
                  ),
                  title: Text(
                    AppTranslations.getText(lang, 'manage_gps'),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2C3E50),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    try {
                      // 1. Comprovar si el servei de GPS del dispositiu està encès
                      bool serviceEnabled =
                          await Geolocator.isLocationServiceEnabled();
                      if (!serviceEnabled) {
                        await Geolocator.openLocationSettings();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        return;
                      }

                      // 2. Executar la petició del diàleg del sistema
                      LocationPermission permission =
                          await Geolocator.requestPermission();

                      // 3. Si l'estat és deniedForever, obrir ajustos de l'app
                      if (permission == LocationPermission.deniedForever) {
                        await Geolocator.openAppSettings();
                      } else if (permission == LocationPermission.whileInUse ||
                          permission == LocationPermission.always) {
                        setState(() {
                          _gpsPermissionDenied = false;
                        });
                        _fetchLocationAndUv();
                      } else {
                        setState(() {
                          _gpsPermissionDenied = true;
                        });
                      }

                      // 4. Després de fer l'acció corresponent, tancar el menú de Settings
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      debugPrint("Error requesting GPS permission: $e");
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                      setState(() {
                        _gpsPermissionDenied = true;
                      });
                    }
                  },
                ),
              ],
              const Divider(color: Color(0xFFE5E8E8), height: 1, thickness: 1),
              ListTile(
                leading: const Icon(
                  Icons.system_update_outlined,
                  color: Color(0xFF73C6B6),
                ),
                title: Text(
                  AppTranslations.getText(lang, 'check_for_updates'),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2C3E50),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _checkForUpdates(lang);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF73C6B6),
              ),
              child: Text(
                AppTranslations.getText(lang, 'close'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkUpdateOnStartup() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final lastCheck = prefs.getString('last_update_check_date');

      if (lastCheck != todayStr) {
        // Save date first to avoid repeating check attempt today in case of errors
        await prefs.setString('last_update_check_date', todayStr);

        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable &&
            mounted) {
          final lang = appLanguage.value;
          _showUpdateDialog(lang);
        }
      }
    } catch (e) {
      debugPrint("Silent startup update check failed: $e");
    }
  }

  void _showUpdateDialog(String lang) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppTranslations.getText(lang, 'update_available_title'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppTranslations.getText(lang, 'update_available_msg'),
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppTranslations.getText(lang, 'update_button_later'),
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Tanca el diàleg immediatament
                Navigator.of(context).pop();
                // Inicia la descàrrega en segon pla que gestiona Google Play
                try {
                  final result = await InAppUpdate.startFlexibleUpdate();
                  if (result != AppUpdateResult.success) {
                    debugPrint(
                      "Flexible update download started result: $result",
                    );
                  }
                } catch (e) {
                  debugPrint(
                    "Flexible update failed, redirecting to store: $e",
                  );
                  // Fallback per obrir la Play Store manualment
                  final Uri playStoreUri = Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.suntimer.app',
                  );
                  try {
                    if (await canLaunchUrl(playStoreUri)) {
                      await launchUrl(
                        playStoreUri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  } catch (launchError) {
                    debugPrint("Could not launch Play Store URL: $launchError");
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF73C6B6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppTranslations.getText(lang, 'update_button_now'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _initUpdateListener() {
    _updateSubscription = InAppUpdate.installUpdateListener.listen(
      (status) {
        if (status == InstallStatus.downloaded) {
          _showUpdateDownloadedSnackBar();
        }
      },
      onError: (e) {
        debugPrint("Error in update listener: $e");
      },
    );
  }

  void _showUpdateDownloadedSnackBar() {
    if (!mounted) return;
    final lang = appLanguage.value;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.getText(lang, 'update_downloaded'),
          style: GoogleFonts.poppins(),
        ),
        duration: const Duration(days: 365),
        action: SnackBarAction(
          label: AppTranslations.getText(lang, 'install_now'),
          textColor: const Color(0xFF73C6B6),
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint("Error completing flexible update: $e");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to complete update installation.',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _checkForUpdates(String lang) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.getText(lang, 'checking_for_updates'),
          style: GoogleFonts.poppins(),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.installStatus == InstallStatus.downloaded) {
        _showUpdateDownloadedSnackBar();
        return;
      }

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (mounted) {
          _showUpdateDialog(lang);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppTranslations.getText(lang, 'app_up_to_date'),
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("InAppUpdate failed, redirecting to Google Play Store: $e");
      final Uri playStoreUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.suntimer.app',
      );
      try {
        if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not open Google Play Store',
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
        }
      } catch (launchError) {
        debugPrint("Could not launch Play Store URL: $launchError");
      }
    }
  }

  Widget _buildHeader(String lang, String dayString, String season) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sun Exposure Timer", // NOTRANSLATE: The app title in the header must always remain in English ("Sun Exposure Timer")
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      "$dayString • $season",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF2C3E50).withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showHeaderInfoDialog,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 22,
                      color: const Color(0xFF2C3E50).withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showSettingsDialog,
                    child: Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: const Color(0xFF2C3E50).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Indicador de Hora e Info GPS
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currentTimeString,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  _locationError ? Icons.location_off : Icons.location_on,
                  size: 14,
                  color: _locationError
                      ? Colors.orange
                      : const Color(0xFF73C6B6),
                ),
                const SizedBox(width: 4),
                Text(
                  _locationError
                      ? AppTranslations.getText(lang, 'simulated')
                      : AppTranslations.getText(lang, 'gps_active'),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF2C3E50).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkinTypeCard(FitzpatrickType currentType, String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: currentType.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2C3E50).withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${AppTranslations.getText(lang, 'your_skin_type')}: ${AppTranslations.getText(lang, 'skin_type_${widget.selectedSkinTypeIndex + 1}_name')}",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 2),
                Text(
                  "${currentType.dose} J/m²",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: const Color(0xFF2C3E50).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.onResetSkinType,
            child: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: Color(0xFF73C6B6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, color: Color(0xFF73C6B6), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTranslations.getText(lang, 'location'),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _locationError
                      ? AppTranslations.getText(
                          lang,
                          _isOffline
                              ? 'location_unavailable'
                              : 'search_your_city',
                        )
                      : _locationName,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: _locationError
                        ? Colors.redAccent
                        : const Color(0xFF2C3E50).withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (!_isGpsActive) ...[
            GestureDetector(
              onTap: _openSearchCityBottomSheet,
              child: const Icon(
                Icons.search_rounded,
                size: 16,
                color: Color(0xFF73C6B6),
              ),
            ),
          ],
          if (_isGpsActive || (!_isOffline && !_gpsPermissionDenied)) ...[
            GestureDetector(
              onTap: () async {
                if (!_isGpsActive) {
                  setState(() {
                    _isFetchingUv = true;
                  });
                  try {
                    LocationPermission permission =
                        await Geolocator.requestPermission();
                    if (permission == LocationPermission.whileInUse ||
                        permission == LocationPermission.always) {
                      setState(() {
                        _gpsPermissionDenied = false;
                      });
                      await _fetchLocationAndUv();
                    } else {
                      setState(() {
                        _gpsPermissionDenied = true;
                      });
                    }
                  } catch (e) {
                    debugPrint(
                      "Error requesting GPS permission on refresh: $e",
                    );
                    setState(() {
                      _gpsPermissionDenied = true;
                    });
                  } finally {
                    setState(() {
                      _isFetchingUv = false;
                    });
                  }
                } else {
                  _fetchLocationAndUv();
                }
              },
              child: _isFetchingUv
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF73C6B6)),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Color(0xFF73C6B6),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF2C3E50).withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Home Segment
          GestureDetector(
            onTap: () {
              _pageController?.animateToPage(
                0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: _currentPage == 0
                    ? const Color(0xFF73C6B6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _currentPage == 0
                    ? [
                        BoxShadow(
                          color: const Color(0xFF73C6B6).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.data_saver_on_rounded,
                size: 20,
                color: _currentPage == 0
                    ? Colors.white
                    : const Color(0xFF2C3E50).withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Chart Segment
          GestureDetector(
            onTap: () {
              _pageController?.animateToPage(
                1,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: _currentPage == 1
                    ? const Color(0xFF73C6B6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _currentPage == 1
                    ? [
                        BoxShadow(
                          color: const Color(0xFF73C6B6).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.show_chart_rounded,
                size: 20,
                color: _currentPage == 1
                    ? Colors.white
                    : const Color(0xFF2C3E50).withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDashboardLowerSection(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // SENSOR LUZ AMBIENTAL
            Expanded(
              child: Container(
                height: 120,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _hasPhysicalLightSensor
                      ? Colors.white
                      : const Color(
                          0xFFEAEDED,
                        ), // Grisáceo / disabled background
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _hasPhysicalLightSensor
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 22,
                            child: Row(
                              children: [
                                Icon(
                                  _getEnvironmentIcon(_luxValue),
                                  size: 22,
                                  color: _getEnvironmentIconColor(_luxValue),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          AppTranslations.getText(
                                            lang,
                                            'real_light',
                                          ),
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: _showLightSensorInfoDialog,
                                        child: Icon(
                                          Icons.info_outline_rounded,
                                          size: 14,
                                          color: const Color(
                                            0xFF2C3E50,
                                          ).withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text.rich(
                                  TextSpan(
                                    text: _formatLux(_luxValue),
                                    style: GoogleFonts.poppins(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: " lx",
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(
                                            0xFF2C3E50,
                                          ).withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                _getEnvironmentName(_luxValue, lang),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _getEnvironmentIconColor(_luxValue),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: const Color(0xFF2C3E50).withOpacity(0.3),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppTranslations.getText(lang, 'real_light'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                AppTranslations.getText(
                                  lang,
                                  'no_light_sensor_msg',
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(
                                    0xFF2C3E50,
                                  ).withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // ÍNDICE UV REAL/ESTIMADO
            Expanded(
              child: Container(
                height: 120,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (_locationError || _isOffline || !_uvAvailable)
                      ? const Color(0xFFEAEDED)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: (_locationError || _isOffline || !_uvAvailable)
                    ? Center(
                        child: Text(
                          "Índex UV no disponible",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C3E50).withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 22,
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/heat_24.svg',
                                  width: 22,
                                  height: 22,
                                  colorFilter: const ColorFilter.mode(
                                    Color.fromARGB(255, 149, 62, 255),
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppTranslations.getText(
                                      lang,
                                      'uv_index_title',
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  _uvIndex.toStringAsFixed(1),
                                  style: GoogleFonts.poppins(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              Text(
                                _uvIndex <= 2.9
                                    ? AppTranslations.getText(lang, 'uv_low')
                                    : _uvIndex <= 5.9
                                    ? AppTranslations.getText(
                                        lang,
                                        'uv_moderate',
                                      )
                                    : _uvIndex <= 7.9
                                    ? AppTranslations.getText(lang, 'uv_high')
                                    : _uvIndex <= 10.9
                                    ? AppTranslations.getText(
                                        lang,
                                        'uv_very_high',
                                      )
                                    : AppTranslations.getText(
                                        lang,
                                        'uv_extreme',
                                      ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _getUvColor(_uvIndex),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSolarIntensityCard(),
        const SizedBox(height: 16),
        _buildCombinedExposureCard(),
      ],
    );
  }

  Widget _buildUvForecastCard(String lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: Color(0xFF73C6B6),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                AppTranslations.getText(lang, 'uv_forecast_title'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Builder(
              builder: (context) {
                final today = DateTime.now();
                final day = today.day.toString().padLeft(2, '0');
                final month = today.month.toString().padLeft(2, '0');
                final year = today.year.toString();
                return Text(
                  "$day/$month/$year",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2C3E50).withOpacity(0.6),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          UvForecastGraph(
            forecast: _hourlyForecast,
            currentHourLabel: AppTranslations.getText(
              lang,
              'current_hour_label',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appLanguage.value;
    final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
    final date = DateTime.now();
    final dayString = AppTranslations.formatDate(date, lang);
    final season = AppTranslations.getSeasonName(_getSeason(), lang);

    // Determinar color de fondo con destellos si se activa la alarma
    Color backgroundColor = const Color(0xFFF7D070);
    if (_isFlashing) {
      backgroundColor = _flashToggle
          ? const Color(0xFFFFE599)
          : const Color(0xFFA8E6CF);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black, // Barra de navegació en negre
        systemNavigationBarContrastEnforced:
            false, // OBLIGATORI per a Android 10+
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            Brightness.light, // Icons contrastats (blancs)
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/sand.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [backgroundColor, backgroundColor.withOpacity(0.0)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(lang, dayString, season),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildSkinTypeCard(currentType, lang),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _buildLocationCard(lang)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(child: _buildSegmentedControl()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
                        // Pàgina 0: Main Screen lower section
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildMainDashboardLowerSection(lang),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                        // Pàgina 1: UV Forecast Screen lower section
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildUvForecastCard(lang),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ESPACIO RESERVADO PARA ADS EN LA PARTE INFERIOR
                  Container(
                    color: Colors.black.withOpacity(
                      0.7,
                    ), // Capa negra translúcida que va de l'espai d'ads fins al final de la pantalla
                    child: SafeArea(
                      top: false,
                      bottom: true,
                      child: _isBannerAdReady && _bannerAd != null
                          ? Container(
                              alignment: Alignment.center,
                              width: _bannerAd!.size.width.toDouble(),
                              height: _bannerAd!.size.height.toDouble(),
                              child: AdWidget(ad: _bannerAd!),
                            )
                          : Container(
                              height: 65,
                              width: double.infinity,
                              color: Colors.transparent,
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.ads_click_rounded,
                                          color: Colors.white.withOpacity(0.6),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            AppTranslations.getText(
                                              lang,
                                              'ad_space',
                                            ),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withOpacity(
                                                0.6,
                                              ),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getCurrentPercentagePerSecond() {
    final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
    final factorAtenuacion = _hasPhysicalLightSensor
        ? _getAttenuationFactor(_luxValue)
        : 1.0;

    final skinImpact = _uvIndex * factorAtenuacion;
    if (skinImpact <= 0.0) {
      return 0.0;
    }
    return (100.0 * skinImpact) / (60.0 * currentType.dose);
  }

  double get _solarRadiationWm2 {
    final factorAtenuacion = _hasPhysicalLightSensor
        ? _getAttenuationFactor(_luxValue)
        : 1.0;
    return _uvIndex * factorAtenuacion * 90.9;
  }

  double get _solarIntensityRatio {
    final currentPercentagePerSecond = _getCurrentPercentagePerSecond();
    return (currentPercentagePerSecond / 0.0917).clamp(0.0, 1.0);
  }

  Widget _buildSolarIntensityCard() {
    final lang = appLanguage.value;
    final double linearRatio = _solarIntensityRatio;

    // Transformación logarítmica para la representación visual (curvatura k = 9.0)
    const double k = 9.0;
    final double logarithmicRatio =
        math.log(1.0 + k * linearRatio) / math.log(1.0 + k);

    final int radiationValue = _solarRadiationWm2.round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.speed_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppTranslations.getText(lang, 'solar_intensity'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$radiationValue W/m²",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF2C3E50).withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 12,
                    width: double.infinity,
                    color: const Color(0xFF2C3E50).withOpacity(0.08),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: logarithmicRatio,
                                child: ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.centerLeft,
                                    maxWidth: constraints.maxWidth,
                                    minWidth: constraints.maxWidth,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF2ECC71), // Verde
                                            Color(0xFFF1C40F), // Groc
                                            Color(0xFFE67E22), // Taronja
                                            Color(0xFFE74C3C), // Vermell
                                            Color(0xFF9B59B6), // Morat
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cálculo de la cantidad de exposición solar recibida en % (100% inicialmente, decreciendo según tiempo transcurrido)
  double get _receivedSolarDosePercentage {
    return _accumulatedDosePercentage.clamp(0.0, 100.0);
  }

  double get _receivedVitDPercentage {
    return _accumulatedVitDPercentage.clamp(0.0, 100.0);
  }

  // CONTENEDOR UNIFICADO: Dosis Solar % + Countdown circular con porcentaje reseteado/activo + Botón Iniciar alarma
  Widget _buildCombinedExposureCard() {
    final lang = appLanguage.value;
    final bool isRunning = _buttonState == 2;
    final double dosePercentage = _receivedSolarDosePercentage;
    final double progress = dosePercentage / 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COLUMNA IZQUIERDA: Título "Dosi Solar Màxima" y countdown circular mostrando la cantidad de exposición en %
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sunny, color: Color(0xFFF7D070), size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppTranslations.getText(lang, 'solar_dose_pct'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Cuenta atrás circular mostrando el porcentaje % en medio
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_orbitalEchoController, _blinkController]),
                            builder: (context, child) {
                              return OrbitalCircularProgressIndicator(
                                value: progress,
                                strokeWidth: 8,
                                backgroundColor: const Color(0xFFFBF9F5),
                                valueColor: _getCountdownColor(progress),
                                isRunning: isRunning && !_isAutoPaused,
                                animationValue: _orbitalEchoController.value,
                                opacity: _isAutoPaused ? _blinkAnimation.value : 1.0,
                              );
                            },
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "${dosePercentage.round()}%",
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                AppTranslations.getText(lang, 'accumulated'),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(
                                    0xFF2C3E50,
                                  ).withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/pill.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF0023FF),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppTranslations.getText(lang, 'vitamin_d'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_orbitalEchoController, _blinkController]),
                            builder: (context, child) {
                              return OrbitalCircularProgressIndicator(
                                value: _receivedVitDPercentage / 100.0,
                                strokeWidth: 8,
                                backgroundColor: const Color(0xFFFBF9F5),
                                valueColor: const Color(0xFF0023FF),
                                isRunning: isRunning && !_isAutoPaused,
                                animationValue: _orbitalEchoController.value,
                                opacity: _isAutoPaused ? _blinkAnimation.value : 1.0,
                              );
                            },
                          ),
                        ),
                        if (_showVitDRipple)
                          AnimatedBuilder(
                            animation: _vitDRippleController,
                            builder: (context, child) {
                              final value = _vitDRippleController.value;
                              final size = value * 120.0;
                              final opacity = 1.0 - value;
                              return Center(
                                child: Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFF0023FF,
                                    ).withOpacity(opacity),
                                  ),
                                ),
                              );
                            },
                          ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "${_receivedVitDPercentage.round()}%",
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                AppTranslations.getText(lang, 'accumulated'),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(
                                    0xFF2C3E50,
                                  ).withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // COLUMNA DERECHA: Botón Iniciar alarma (para iniciar countdown) y Demo
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: Color(0xFF73C6B6), size: 20),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        AppTranslations.getText(
                          lang,
                          'accumulated_exposure_time',
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _formatElapsedSeconds(_elapsedExposureSeconds),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 64),
                if (_isAutoPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2ECC71).withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppTranslations.getText(
                            lang,
                            'paused_exposure_banner_title',
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppTranslations.getText(
                            lang,
                            'paused_exposure_banner_desc',
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2C3E50).withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (!isRunning &&
                    (_calculatedSafeMinutes > 360.0 ||
                        _elapsedExposureSeconds >= maxExposureSeconds))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF73C6B6).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF73C6B6).withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppTranslations.getText(
                            lang,
                            'safe_exposure_banner_title',
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppTranslations.getText(
                            lang,
                            'safe_exposure_banner_desc',
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2C3E50).withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  ElevatedButton(
                    onPressed:
                        (_locationError ||
                            _isOffline ||
                            !_uvAvailable ||
                            (_limitReachedToday && !isRunning) ||
                            (_calculatedSafeMinutes >
                                maxSafeMinutesThreshold) ||
                            (_elapsedExposureSeconds >= maxExposureSeconds))
                        ? null
                        : (isRunning ? _pauseCountdown : _startCountdown),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunning
                          ? Colors.redAccent
                          : (((_limitReachedToday && !isRunning) ||
                                    (_calculatedSafeMinutes >
                                        maxSafeMinutesThreshold) ||
                                    (_elapsedExposureSeconds >=
                                        maxExposureSeconds))
                                ? Colors.grey.shade400
                                : const Color(0xFF73C6B6)),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                    ),
                    child: Text(
                      isRunning
                          ? AppTranslations.getText(lang, 'cancel_exposure')
                          : ((_limitReachedToday && !isRunning)
                                ? AppTranslations.getText(
                                    lang,
                                    'daily_limit_reached',
                                  )
                                : ((_calculatedSafeMinutes >
                                              maxSafeMinutesThreshold ||
                                          _elapsedExposureSeconds >=
                                              maxExposureSeconds)
                                      ? AppTranslations.getText(
                                          lang,
                                          'safe_exposure_btn',
                                        )
                                      : AppTranslations.getText(
                                          lang,
                                          'start_exposure',
                                        ))),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: (_limitReachedToday && !isRunning)
                            ? Colors.redAccent
                            : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _resetCountdown,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF73C6B6),
                      side: const BorderSide(
                        color: Color(0xFF73C6B6),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      AppTranslations.getText(lang, 'reset'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isRunning && (showDemoButton || Platform.environment.containsKey('FLUTTER_TEST'))) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: (_locationError || _isOffline || !_uvAvailable)
                          ? null
                          : () {
                              setState(() {
                                _demoMode = true;
                              });
                              _startCountdown();
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (_locationError || _isOffline || !_uvAvailable)
                              ? const Color(0xFF2C3E50).withOpacity(0.05)
                              : const Color(0xFF73C6B6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                (_locationError || _isOffline || !_uvAvailable)
                                ? const Color(0xFF2C3E50).withOpacity(0.1)
                                : const Color(0xFF73C6B6).withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Demo 30s",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  (_locationError ||
                                      _isOffline ||
                                      !_uvAvailable)
                                  ? const Color(0xFF2C3E50).withOpacity(0.4)
                                  : const Color(0xFF73C6B6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCountdownColor(double progress) {
    if (progress <= 0.50) {
      return const Color(0xFF73C6B6);
    } else if (progress <= 0.75) {
      // Verde a amarillo progresivamente (50% al 75%)
      double t = (progress - 0.50) / 0.25;
      return Color.lerp(
        const Color(0xFF73C6B6),
        const Color(0xFFF7D070),
        t.clamp(0.0, 1.0),
      )!;
    } else if (progress <= 0.90) {
      // Amarillo a rojo progresivamente (75% al 90%)
      double t = (progress - 0.75) / 0.15;
      return Color.lerp(
        const Color(0xFFF7D070),
        Colors.redAccent,
        t.clamp(0.0, 1.0),
      )!;
    } else {
      // A partir del 90% solo rojo
      return Colors.redAccent;
    }
  }

  // Método auxiliar para obtener color según nivel de UV
  Color _getUvColor(double uv) {
    if (uv <= 2.9) return const Color(0xFF2ECC71); // Verde - Bajo
    if (uv <= 5.9) return const Color(0xFFF1C40F); // Amarillo - Moderado
    if (uv <= 7.9) return const Color(0xFFE67E22); // Naranja - Alto
    if (uv <= 10.9) return const Color(0xFFE74C3C); // Rojo - Muy Alto
    return const Color(0xFF9B59B6); // Púrpura - Extremo
  }

  String _formatElapsedSeconds(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    if (minutes < 60) {
      return "$minutes min";
    } else {
      final int hours = minutes ~/ 60;
      final int remainingMinutes = minutes % 60;
      return "$hours h $remainingMinutes min";
    }
  }
}

class OrbitalCircularProgressIndicator extends StatelessWidget {
  final double value;
  final double strokeWidth;
  final Color backgroundColor;
  final Color valueColor;
  final bool isRunning;
  final double animationValue;
  final double opacity;

  const OrbitalCircularProgressIndicator({
    super.key,
    required this.value,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.valueColor,
    required this.isRunning,
    required this.animationValue,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _OrbitalCircularProgressPainter(
          value: value,
          strokeWidth: strokeWidth,
          backgroundColor: backgroundColor,
          valueColor: valueColor,
          isRunning: isRunning,
          animationValue: animationValue,
          opacity: opacity,
        ),
      ),
    );
  }
}

class _OrbitalCircularProgressPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Color backgroundColor;
  final Color valueColor;
  final bool isRunning;
  final double animationValue;
  final double opacity;

  _OrbitalCircularProgressPainter({
    required this.value,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.valueColor,
    required this.isRunning,
    required this.animationValue,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Dibuixa el cercle de fons (canal)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Dibuixa l'arc de progrés
    final double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * value.clamp(0.0, 1.0);

    if (sweepAngle > 0) {
      final progressPaint = Paint()
        ..color = valueColor.withOpacity(opacity)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    // 3. Dibuixa l'Eco Orbital (cometa) si la sessió està activa
    if (isRunning) {
      // El centre de l'arc gira 360 graus sincronitzat amb animationValue (de 0 a 1)
      final double rotationCenter = 2 * math.pi * animationValue;
      // Arc de ~45 graus (pi/4 radiants)
      final double arcLength = math.pi / 4;
      // L'inici de l'arc de manera que rotationCenter en sigui el centre:
      final double echoStartAngle = rotationCenter - arcLength / 2;

      final echoPaint = Paint()
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap
            .round; // Capçals arrodonits per a un efecte visual més suau i premium

      final Rect rect = Rect.fromCircle(center: center, radius: radius);

      // Aclarim el color de l'animació cap al blanc per millorar la visibilitat
      final Color animationColor = Color.lerp(valueColor, Colors.white, 0.45)!;

      // Definim el SweepGradient de manera que comenci en transparent (opacitat 0.0),
      // arribi al punt màxim (opacitat 0.8) al mig de l'arc (0.0625 de volta, és a dir, 22.5 graus)
      // i torni a desdibuixar-se fins a transparent (opacitat 0.0) al final de l'arc (0.125 de volta, és a dir, 45 graus).
      echoPaint.shader = SweepGradient(
        colors: [
          animationColor.withOpacity(0.0),
          animationColor.withOpacity(0.8),
          animationColor.withOpacity(0.0),
          animationColor.withOpacity(0.0),
        ],
        stops: const [
          0.0,
          0.0625, // pi/8 és 1/16 (0.0625) d'una volta completa (mig arc, màxim a 22.5 graus)
          0.125, // pi/4 és 1/8 (0.125) d'una volta completa (final de l'arc a 45 graus)
          1.0,
        ],
        transform: GradientRotation(echoStartAngle),
      ).createShader(rect);

      canvas.drawArc(rect, echoStartAngle, arcLength, false, echoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalCircularProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.valueColor != valueColor ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.opacity != opacity;
  }
}

class UvForecastGraph extends StatelessWidget {
  final List<Map<String, dynamic>> forecast;
  final String currentHourLabel;

  const UvForecastGraph({
    super.key,
    required this.forecast,
    required this.currentHourLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(
        painter: UvForecastPainter(
          forecast: forecast,
          currentHourLabel: currentHourLabel,
        ),
      ),
    );
  }
}

class UvForecastPainter extends CustomPainter {
  final List<Map<String, dynamic>> forecast;
  final String currentHourLabel;

  UvForecastPainter({required this.forecast, required this.currentHourLabel});

  Color _getUvColor(double uv) {
    if (uv <= 2.9) return const Color(0xFF2ECC71); // Verde - Bajo
    if (uv <= 5.9) return const Color(0xFFF1C40F); // Amarillo - Moderado
    if (uv <= 7.9) return const Color(0xFFE67E22); // Naranja - Alto
    if (uv <= 10.9) return const Color(0xFFE74C3C); // Rojo - Muy Alto
    return const Color(0xFF9B59B6); // Púrpura - Extremo
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (forecast.isEmpty) return;

    final double paddingLeft = 24.0;
    final double paddingRight = 24.0;
    final double paddingTop = 24.0;
    final double paddingBottom = 24.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Find max UV
    double maxUv = 12.0;
    for (var item in forecast) {
      final uv = (item['uv'] as num).toDouble();
      if (uv > maxUv) {
        maxUv = uv;
      }
    }

    // Convert forecast data to points
    final List<Offset> points = [];
    for (int i = 0; i < forecast.length; i++) {
      final uv = (forecast[i]['uv'] as num).toDouble();
      final double x = paddingLeft + (i / 23.0) * chartWidth;
      final double y = size.height - paddingBottom - (uv / maxUv) * chartHeight;
      points.add(Offset(x, y));
    }

    final currentHour = DateTime.now().hour;

    // 1. Draw background grid/horizontal helper lines
    final gridPaint = Paint()
      ..color = const Color(0xFF2C3E50).withOpacity(0.05)
      ..strokeWidth = 1.0;

    // Draw 3 horizontal lines (low, medium, high)
    for (int j = 1; j <= 3; j++) {
      final double y = paddingTop + (j / 4.0) * chartHeight;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );
    }

    // 2. Draw current hour vertical highlight line
    if (currentHour >= 0 && currentHour < points.length) {
      final currentPoint = points[currentHour];
      final linePaint = Paint()
        ..color = const Color(0xFF73C6B6).withOpacity(0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Draw a dashed vertical line
      double startY = paddingTop;
      final double endY = size.height - paddingBottom;
      while (startY < endY) {
        canvas.drawLine(
          Offset(currentPoint.dx, startY),
          Offset(currentPoint.dx, math.min(startY + 4, endY)),
          linePaint,
        );
        startY += 8;
      }
    }

    // 3. Draw smooth Bezier curve line
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    final colors = forecast
        .map((e) => _getUvColor((e['uv'] as num).toDouble()))
        .toList();
    final stops = List.generate(24, (index) => index / 23.0);
    final shader = LinearGradient(
      colors: colors,
      stops: stops,
    ).createShader(Rect.fromLTWH(paddingLeft, 0, chartWidth, size.height));

    final linePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // 4. Draw key points, values, and horizontal labels
    for (int i = 0; i < forecast.length; i++) {
      final uv = (forecast[i]['uv'] as num).toDouble();
      final point = points[i];
      final isKeyPoint = (i % 3 == 0) || (i == 23);

      if (isKeyPoint) {
        // Draw small dot
        final dotPaint = Paint()
          ..color = _getUvColor(uv)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 4.0, dotPaint);

        final whiteBorder = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(point, 4.0, whiteBorder);

        // Draw UV value label above the curve
        _drawText(
          canvas,
          uv.toStringAsFixed(1),
          Offset(point.dx, point.dy - 12),
          bold: true,
          fontSize: 9,
          color: const Color(0xFF2C3E50),
        );
      }

      // Draw bottom hour labels
      if (isKeyPoint) {
        String label;
        if (i == currentHour) {
          label = currentHourLabel;
        } else {
          label = "${i.toString().padLeft(2, '0')}:00";
        }

        final isCurrent = i == currentHour;
        _drawText(
          canvas,
          label,
          Offset(point.dx, size.height - paddingBottom + 12),
          bold: isCurrent,
          fontSize: 9,
          color: isCurrent
              ? const Color(0xFF73C6B6)
              : const Color(0xFF2C3E50).withOpacity(0.6),
        );
      }
    }

    // 5. Draw current hour glow point (if not already handled)
    if (currentHour >= 0 && currentHour < points.length) {
      final currentPoint = points[currentHour];
      final currentUv = (forecast[currentHour]['uv'] as num).toDouble();

      final glowPaint = Paint()
        ..color = const Color(0xFF73C6B6).withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPoint, 10.0, glowPaint);

      final centerPaint = Paint()
        ..color = _getUvColor(currentUv)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPoint, 5.5, centerPaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(currentPoint, 5.5, borderPaint);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    bool bold = false,
    double fontSize = 10,
    Color color = const Color(0xFF2C3E50),
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant UvForecastPainter oldDelegate) {
    return oldDelegate.forecast != forecast ||
        oldDelegate.currentHourLabel != currentHourLabel;
  }
}
