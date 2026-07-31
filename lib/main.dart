import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(const SunTimerApp());
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
      'app_title': 'Sun Exposure Timer',
      'select_skin_type': 'Select your skin type',
      'onboarding_desc':
          'Your skin type determines your sensitivity to the sun and the safe dose of UV radiation you can receive before sunburn.',
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
      'shade_umbrella': 'Shade / Umbrella',
      'indoor_deep_shade': 'Indoor / Deep shade',
      'light_sensor_info':
          'The light sensor helps estimate if you are in the shade or in direct sun. Remember that sand and water reflect up to 20% of UV radiation even in the shade.',
      'header_info_p1':
          'It uses the Standard Erythemal Dose (SED) algorithm and the Fitzpatrick skin phototype scale supported by the WHO.',
      'header_info_p2':
          'UV radiation data based on global meteorological models from NOAA / ECMWF.',
      'estimated_safe_time': 'Estimated Safe Sun Exposure Time',
      'start_exposure': 'Start Alarm',
      'daily_limit_reached': 'Daily limit reached',
      'cancel_exposure': 'Cancel Exposure',
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
      'ad_space': 'Reserved Space for Advertising',
      'shadow_warning': 'Seek shade, wear sunscreen, and stay well hydrated.',
      'detecting_location': 'Detecting location...',
      'exposure_timer_title': 'Exposure Timer',
      'remaining': 'remaining',
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
      'no_light_sensor_msg':
          'Device without light sensor. No attenuators are applied in the sun exposure calculation.',
      'manage_gps': 'GPS Management',
      'disclaimer_title': 'Legal & Health Disclaimer',
      'disclaimer_point1':
          '• The app offers indicative estimates and does not replace medical advice.',
      'disclaimer_point2': '• The use of the app is at the user\'s own risk.',
      'disclaimer_point3':
          '• For any doubts or sensitive skin, you must consult a dermatologist.',
    },
    'es': {
      'app_title': 'Temporizador de Exposición Solar',
      'select_skin_type': 'Selecciona tu tipo de piel',
      'onboarding_desc':
          'El tipo de piel determina tu sensibilidad al sol y la dosis de radiación ultravioleta segura que puedes recibir antes de sufrir eritema (quemadura).',
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
      'shade_umbrella': 'Sombra / Sombrilla',
      'indoor_deep_shade': 'Interior / Sombra densa',
      'light_sensor_info':
          'El sensor de luz ayuda a estimar si estás a la sombra o al sol directo. Recuerda que la arena y el agua reflejan hasta un 20% de la radiación UV incluso a la sombra.',
      'header_info_p1':
          'Utiliza el algoritmo de Dosis Eritemática Estándar (SED) y la escala de fototipos cutáneos de Fitzpatrick respaldada por la OMS.',
      'header_info_p2':
          'Datos de radiación UV basados en modelos meteorológicos globales de la NOAA / ECMWF.',
      'estimated_safe_time': 'Tiempo seguro de exposición solar',
      'start_exposure': 'Iniciar Alarma',
      'daily_limit_reached': 'Límite diario alcanzado',
      'cancel_exposure': 'Cancelar Exposición',
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
      'ad_space': 'Espacio reservado para Publicidad',
      'shadow_warning':
          'Busca la sombra, ponte protector solar e hidrátate bien.',
      'detecting_location': 'Detectando ubicación...',
      'exposure_timer_title': 'Temporizador de Exposición',
      'remaining': 'restantes',
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
    },
    'de': {
      'app_title': 'Sonnenschonungs-Timer',
      'select_skin_type': 'Wählen Sie Ihren Hauttyp',
      'onboarding_desc':
          'Ihr Hauttyp bestimmt Ihre Empfindlichkeit gegenüber der Sonne und die sichere UV-Dosis, die Sie vor einem Sonnenbrand erhalten können.',
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
      'shade_umbrella': 'Schatten / Schirm',
      'indoor_deep_shade': 'Innen / Tiefer Schatten',
      'light_sensor_info':
          'Der Lichtsensor hilft abzuschätzen, ob Sie sich im Schatten oder in der direkten Sonne befinden. Denken Sie daran, dass Sand und Wasser selbst im Schatten bis zu 20 % der UV-Strahlung reflektieren.',
      'header_info_p1':
          'Es verwendet den Standard-Erythemdosis-Algorithmus (SED) und die von der WHO unterstützte Fitzpatrick-Hautphototypskala.',
      'header_info_p2':
          'UV-Strahlungsdaten basierend auf globalen meteorologischen Modellen von NOAA / ECMWF.',
      'estimated_safe_time': 'Geschätzte sichere Sonnenexpositionszeit',
      'start_exposure': 'Alarm starten',
      'daily_limit_reached': 'Tageslimit erreicht',
      'cancel_exposure': 'Exposition abbrechen',
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
      'ad_space': 'Reservierter Platz für Werbung',
      'shadow_warning':
          'Suchen Sie Schatten auf, tragen Sie Sonnencreme auf und trinken Sie ausreichend Wasser.',
      'detecting_location': 'Standort wird ermittelt...',
      'exposure_timer_title': 'Expositions-Timer',
      'remaining': 'verbleibend',
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
    },
    'fr': {
      'app_title': 'Minuteur d\'Exposition Solaire',
      'select_skin_type': 'Sélectionnez votre type de peau',
      'onboarding_desc':
          'Votre type de peau détermine votre sensibilité au soleil et la dose sûre de rayonnement ultraviolet que vous pouvez recevoir avant d\'attraper un coup de soleil.',
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
      'shade_umbrella': 'Ombre / Parasol',
      'indoor_deep_shade': 'Intérieur / Ombre dense',
      'light_sensor_info':
          'Le capteur de lumière aide à estimer si vous êtes à l\'ombre ou en plein soleil. N\'oubliez pas que le sable et l\'eau réfléchissent jusqu\'à 20 % des rayons UV, même à l\'ombre.',
      'header_info_p1':
          'Il utilise l\'algorithme de Dose Érythémale Standard (SED) et l\'échelle des phototypes cutanés de Fitzpatrick soutenue par l\'OMS.',
      'header_info_p2':
          'Données de rayonnement UV basées sur les modèles météorologiques mondiaux de la NOAA / CEPMMT.',
      'estimated_safe_time': 'Temps d\'exposition solaire sûr estimé',
      'start_exposure': 'Démarrer l\'alarme',
      'daily_limit_reached': 'Limite quotidienne atteinte',
      'cancel_exposure': 'Annuler l\'exposition',
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
      'ad_space': 'Espace réservé à la publicité',
      'shadow_warning':
          'Recherchez l\'ombre, mettez de la crème solaire et restez bien hydraté.',
      'detecting_location': 'Détection de l\'emplacement...',
      'exposure_timer_title': 'Minuteur d\'exposition',
      'remaining': 'restants',
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
    },
    'it': {
      'app_title': 'Timer di Esposizione Solare',
      'select_skin_type': 'Seleziona il tuo tipo di pelle',
      'onboarding_desc':
          'Il tuo tipo di pelle determina la tua sensibilità al sol e la dose sicura di radiazioni ultraviolette que puoi ricevere prima di scottarti.',
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
      'shade_umbrella': 'Ombra / Ombrellone',
      'indoor_deep_shade': 'Interno / Ombra densa',
      'light_sensor_info':
          'Il sensore di luce aiuta a stimare se sei all\'ombra o al sol directo. Ricorda che la sabbia e l\'acqua riflettono fino al 20% delle radiazioni UV anche all\'ombra.',
      'header_info_p1':
          'Utilizza l\'algoritmo Standard Erythemal Dose (SED) e la scala dei fototipi cutanei di Fitzpatrick supportata dall\'OMS.',
      'header_info_p2':
          'Dati sulla radiazione UV basati sui modelli meteorologici globali di NOAA / ECMWF.',
      'estimated_safe_time': 'Tempo di esposizione solare sicuro stimato',
      'start_exposure': 'Avvia allarme',
      'daily_limit_reached': 'Limite giornaliero raggiunto',
      'cancel_exposure': 'Annulla esposizione',
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
      'ad_space': 'Spazio riservato alla pubblicità',
      'shadow_warning':
          'Cerca l\'ombra, usa la crema solare e rimani ben idratato.',
      'detecting_location': 'Rilevamento della posizione...',
      'exposure_timer_title': 'Timer di esposizione',
      'remaining': 'rimanenti',
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
    },
    'pt': {
      'app_title': 'Temporizador de Exposição Solar',
      'select_skin_type': 'Selecione o seu tipo de pele',
      'onboarding_desc':
          'O seu tipo de pele determina a sua sensibilidade ao sol e a dose segura de radiação ultravioleta que pode receber antes de sofrer eritema (queimadura).',
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
      'shade_umbrella': 'Sombra / Guarda-sol',
      'indoor_deep_shade': 'Interior / Sombra densa',
      'light_sensor_info':
          'O sensor de luz ajuda a estimar se está à sombra ou sob o sol direto. Lembre-se de que a areia e a água refletem até 20% da radiação UV, mesmo à sombra.',
      'header_info_p1':
          'Utiliza o algoritmo de Dose Eritemática Padrão (SED) e a escala de fotótipos cutâneos de Fitzpatrick apoiada pela OMS.',
      'header_info_p2':
          'Dados de radiação UV baseados em modelos meteorológicos globais da NOAA / ECMWF.',
      'estimated_safe_time': 'Tempo seguro estimado de exposição solar',
      'start_exposure': 'Iniciar Alarme',
      'daily_limit_reached': 'Limite diário atingido',
      'cancel_exposure': 'Cancelar exposição',
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
      'ad_space': 'Espaço reservado para publicidade',
      'shadow_warning':
          'Procure a sombra, use protetor solar e mantenha-se bem hidratado.',
      'detecting_location': 'Detectando localização...',
      'exposure_timer_title': 'Temporizador de exposição',
      'remaining': 'restantes',
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
    },
    'ca': {
      'app_title': 'Temporitzador d\'Exposició Solar',
      'select_skin_type': 'Selecciona el teu tipus de pell',
      'onboarding_desc':
          'El tipus de pell determina la teva sensibilitat al sol i la dosi de radiació ultraviolada segura que pots rebre abans de patir eritema (cremada).',
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
      'shade_umbrella': 'Ombra / Parasol',
      'indoor_deep_shade': 'Interior / Sombra densa',
      'light_sensor_info':
          'El sensor de llum ajuda a estimar si estàs a l\'ombra o al sol directe. Recorda que la sorra i l\'aigua reflecteixen fins a un 20% de la radiació UV fins i tot a l\'ombra.',
      'header_info_p1':
          'Utilitza l\'algoritme de Dosi Eritemàtica Estàndard (SED) i l\'escala de fototips cutanis de Fitzpatrick recolzada per l\'OMS.',
      'header_info_p2':
          'Dades de radiació UV basades en models meteorològics globals de la NOAA / ECMWF.',
      'estimated_safe_time': 'Temps segur estimat d\'exposició solar',
      'start_exposure': 'Iniciar Alarma',
      'daily_limit_reached': 'Límit diari assolit',
      'cancel_exposure': 'Cancel·lar exposició',
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
      'ad_space': 'Espai reservat per a publicitat',
      'shadow_warning':
          'Busca l\'ombra, posa\'t protector solar i hidrata\'t bé.',
      'detecting_location': 'Detectant ubicació...',
      'exposure_timer_title': 'Temporitzador d\'Exposició',
      'remaining': 'restants',
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
  const SunTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sun Exposure Timer',
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
          return const InitialRouter();
        },
      ),
    );
  }
}

/// Enrutador inicial que decide si mostrar el Onboarding o el Dashboard principal.
class InitialRouter extends StatefulWidget {
  const InitialRouter({super.key});

  @override
  State<InitialRouter> createState() => _InitialRouterState();
}

class _InitialRouterState extends State<InitialRouter> {
  bool _isLoading = true;
  int? _savedSkinType;
  bool _isEditingSkinType = false;

  @override
  void initState() {
    super.initState();
    _checkPreferences();
  }

  Future<void> _checkPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar preferencia de idioma
    String selectedLang;
    if (prefs.containsKey('app_language')) {
      selectedLang = prefs.getString('app_language')!;
    } else {
      // Auto-detectar idioma
      selectedLang = getSystemLanguageCode();
    }
    appLanguage.value = selectedLang;

    setState(() {
      _savedSkinType = prefs.containsKey('skin_type')
          ? prefs.getInt('skin_type')
          : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7D070)),
          ),
        ),
      );
    }

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
                  "Sun Exposure Timer",
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
    with TickerProviderStateMixin {
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

  // Lógica del Temporizador (0 = Inicial, 1 = Calculado, 2 = Countdown Activo)
  int _buttonState = 1;
  int _calculatedSafeMinutes = 0;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _calculationTimer;
  bool _limitReachedToday = false;
  bool _demoMode = false; // Modo demo de 10 segundos

  // Animaciones de Alerta (Flashes)
  bool _isFlashing = false;
  bool _flashToggle = false;
  Timer? _flashTimer;

  // Formateador de tiempo actual
  late String _currentTimeString;
  late Timer _clockTimer;

  @override
  void initState() {
    super.initState();
    appLanguage.addListener(_onLanguageChanged);
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateClock(),
    );
    _checkDailyLimit();
    _initLightSensor();

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

    _fetchLocationAndUv();
    _initUpdateListener();

    // Calcular inicialmente
    _calculateRecommendedTime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBannerAd();
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

  @override
  void dispose() {
    appLanguage.removeListener(_onLanguageChanged);
    _clockTimer.cancel();
    _calculationTimer?.cancel();
    _lightSubscription?.cancel();
    _updateSubscription?.cancel();
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    _bannerAd?.dispose();
    _connectivitySubscription?.cancel();
    _networkCheckTimer?.cancel();
    super.dispose();
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

  // Verifica si el límite ya fue alcanzado hoy en SharedPreferences
  Future<void> _checkDailyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedLimitDate = prefs.getString('daily_limit_date');
    if (savedLimitDate == today) {
      setState(() {
        _limitReachedToday = true;
      });
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
            if (_buttonState == 1) {
              _calculateRecommendedTime();
            }
          });

          _lightSubscription = sensor.ambientLightStream.listen((lux) {
            setState(() {
              _luxValue = lux.round();
            });
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

    debugPrint("📡 [CONNECTIVITY] Resultats rebuts: $results");
    debugPrint(
      "📡 [CONNECTIVITY] Càlcul Offline: $isCurrentlyOffline | GPS Actiu: $_isGpsActive",
    );

    bool hasInternet = !isCurrentlyOffline;
    if (hasInternet) {
      hasInternet = await _hasRealInternet();
      debugPrint("📡 [CONNECTIVITY] Comprovació de xarxa real: $hasInternet");
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

  // Petición a Open-Meteo API
  Future<void> _fetchUvIndex(double lat, double lon) async {
    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=uv_index&timezone=auto";
    try {
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
          setState(() {
            _uvIndex = (hourlyUv[closestIndex] as num).toDouble();
            _uvAvailable = true;
          });
          _calculateRecommendedTime();
          return;
        }
      }
      throw 'Respuesta inválida de la API.';
    } catch (e) {
      debugPrint("Error obteniendo UV: $e");
      // Asignar un UV por defecto según la hora/luz para que no falle el prototipo
      setState(() {
        _uvIndex = _calculateEstimatedUv();
        _uvAvailable = false;
      });
      _calculateRecommendedTime();
    }
  }

  // Estimación de UV secundaria si la API falla
  double _calculateEstimatedUv() {
    // Estimación básica: máx 7.5 al mediodía, disminuye en extremos
    final hour = DateTime.now().hour;
    if (hour < 8 || hour > 19) return 0.1;
    final diff = (hour - 13).abs(); // Distancia al mediodía (13:00)
    double estimated = 8.0 - (diff * 1.2);
    return estimated < 0.5 ? 0.5 : estimated;
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
      return 0.1;
    } else if (lux < 1000) {
      return 0.1 + 0.4 * (lux / 1000.0);
    } else if (lux < 20000) {
      return 0.5 + 0.5 * ((lux - 1000.0) / 19000.0);
    } else {
      return 1.0;
    }
  }

  String _getEnvironmentName(int lux) {
    if (lux >= 20000) {
      return "Sol Directo";
    } else if (lux >= 1000) {
      return "Sombra / Sombrilla";
    } else {
      return "Interior / Sombra Densa";
    }
  }

  IconData _getEnvironmentIcon(int lux) {
    if (lux >= 20000) {
      return Icons.wb_sunny_rounded;
    } else if (lux >= 1000) {
      return Icons.beach_access_rounded;
    } else {
      return Icons.house_siding_rounded;
    }
  }

  Color _getEnvironmentIconColor(int lux) {
    if (lux >= 20000) {
      return const Color(0xFFF7D070);
    } else {
      return const Color(0xFF73C6B6);
    }
  }

  // Cálculo del tiempo recomendado en minutos
  void _calculateRecommendedTime() {
    final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
    final factorAtenuacion = _hasPhysicalLightSensor
        ? _getAttenuationFactor(_luxValue)
        : 1.0;

    double rawTime;
    if (_uvIndex < 0.5) {
      rawTime = 480.0 / factorAtenuacion;
    } else {
      rawTime = (currentType.dose / _uvIndex) / factorAtenuacion;
    }

    if (rawTime > 480.0) {
      rawTime = 480.0;
    }

    setState(() {
      _calculatedSafeMinutes = rawTime.round();
      if (_calculatedSafeMinutes < 1) _calculatedSafeMinutes = 1;
      if (_buttonState != 2) {
        _buttonState = 1;
      }
    });
  }

  // Iniciar la cuenta atrás
  void _startCountdown() {
    int durationSeconds = _demoMode ? 10 : _calculatedSafeMinutes * 60;
    setState(() {
      _remainingSeconds = durationSeconds;
      _buttonState = 2;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds == 0) {
          _countdownTimer?.cancel();
          _onTimeFinished();
        }
      } else {
        _countdownTimer?.cancel();
        _onTimeFinished();
      }
    });
  }

  // Detener o cancelar la exposición
  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _buttonState = 1;
      _demoMode = false;
    });
  }

  // Acción finalizada
  void _onTimeFinished() {
    // 1. Activar alertas sonoras nativas
    try {
      FlutterRingtonePlayer().playAlarm(asAlarm: true);
    } catch (e) {
      debugPrint("Error con RingtonePlayer: $e");
    }

    // 2. Activar la animación de flash (destellos)
    setState(() {
      _isFlashing = true;
    });
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _flashToggle = !_flashToggle;
      });
    });

    // 3. Mostrar diálogo a pantalla completa
    _showFullscreenAlert();
  }

  // Cierra el diálogo de advertencia, apaga la alarma y los destellos, y persiste el límite
  void _dismissAlert() {
    _flashTimer?.cancel();
    try {
      FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint("Error al parar Ringtone: $e");
    }

    bool wasDemo = _demoMode;

    setState(() {
      _isFlashing = false;
      _demoMode = false;
      if (wasDemo) {
        _buttonState = 1;
      }
    });

    Navigator.of(context).pop(); // Cerrar diálogo
    if (!wasDemo) {
      _saveDailyLimitReached(); // Persistir hoy como completado
    }
  }

  void _showFullscreenAlert() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Límite alcanzado",
      pageBuilder: (context, anim1, anim2) {
        final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
        return Scaffold(
          backgroundColor: const Color(0xFFFBF9F5),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  // Icono animado del Sol / Advertencia
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE599),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wb_sunny_rounded,
                        color: Color(0xFFF7D070),
                        size: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "¡Límite diario alcanzado!",
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Has completado tu dosis máxima recomendada de exposición solar para hoy de acuerdo a tu fototipo (${currentType.name}).",
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
                            "Busca la sombra, ponte protector solar e hidrátate bien.",
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
                    onPressed: _dismissAlert,
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
                      "Entendido",
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
  }

  String _formatSafeTime(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? "${hours}h $mins min" : "${hours}h";
    }
    return "$minutes min";
  }

  String _formatCountdownTime(int totalSeconds) {
    if (totalSeconds >= 60) {
      int minutes = totalSeconds ~/ 60;
      return _formatSafeTime(minutes);
    }
    return "$totalSeconds s";
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
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          // El usuario aceptó la actualización y comenzó a descargarse en segundo plano.
          // El listener registrado _updateSubscription capturará el estado descargado (downloaded).
        } else {
          debugPrint("Flexible update flow result: $result");
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
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // HEADER DE LA APLICACIÓN
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Sun Exposure Timer",
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
                                                color: const Color(
                                                  0xFF2C3E50,
                                                ).withOpacity(0.6),
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
                                              color: const Color(
                                                0xFF2C3E50,
                                              ).withOpacity(0.6),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: _showSettingsDialog,
                                            child: Icon(
                                              Icons.settings_outlined,
                                              size: 22,
                                              color: const Color(
                                                0xFF2C3E50,
                                              ).withOpacity(0.6),
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
                                          _locationError
                                              ? Icons.location_off
                                              : Icons.location_on,
                                          size: 14,
                                          color: _locationError
                                              ? Colors.orange
                                              : const Color(0xFF73C6B6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _locationError
                                              ? AppTranslations.getText(
                                                  lang,
                                                  'simulated',
                                                )
                                              : AppTranslations.getText(
                                                  lang,
                                                  'gps_active',
                                                ),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: const Color(
                                              0xFF2C3E50,
                                            ).withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // FILA DE FOTOTIPO SELECCIONADO
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
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
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: currentType.color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(
                                          0xFF2C3E50,
                                        ).withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${AppTranslations.getText(lang, 'your_skin_type')}: ${AppTranslations.getText(lang, 'skin_type_${widget.selectedSkinTypeIndex + 1}_name')}",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                        ),
                                        Text(
                                          "${AppTranslations.getText(lang, 'safe_dose')}: ${currentType.dose} J/m²",
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
                                  IconButton(
                                    onPressed: widget.onResetSkinType,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                      color: Color(0xFF73C6B6),
                                    ),
                                    tooltip: AppTranslations.getText(
                                      lang,
                                      'change_skin_type',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // COORDINADAS CARD
                            Container(
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
                                  const Icon(
                                    Icons.map_outlined,
                                    color: Color(0xFF73C6B6),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppTranslations.getText(
                                            lang,
                                            'location',
                                          ),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: const Color(
                                              0xFF2C3E50,
                                            ).withOpacity(0.6),
                                          ),
                                        ),
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _locationError
                                                ? Colors.redAccent
                                                : const Color(0xFF2C3E50),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_isGpsActive) ...[
                                        IconButton(
                                          onPressed: _openSearchCityBottomSheet,
                                          icon: const Icon(
                                            Icons.search_rounded,
                                            size: 20,
                                            color: Color(0xFF73C6B6),
                                          ),
                                        ),
                                      ],
                                      if (_isGpsActive ||
                                          (!_isOffline &&
                                              !_gpsPermissionDenied)) ...[
                                        IconButton(
                                          onPressed: () async {
                                            if (!_isGpsActive) {
                                              setState(() {
                                                _isFetchingUv = true;
                                              });
                                              try {
                                                LocationPermission permission =
                                                    await Geolocator.requestPermission();
                                                if (permission ==
                                                        LocationPermission
                                                            .whileInUse ||
                                                    permission ==
                                                        LocationPermission
                                                            .always) {
                                                  setState(() {
                                                    _gpsPermissionDenied =
                                                        false;
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
                                          icon: _isFetchingUv
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation(
                                                          Color(0xFF73C6B6),
                                                        ),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.refresh_rounded,
                                                  size: 20,
                                                  color: Color(0xFF73C6B6),
                                                ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                // SENSOR LUZ AMBIENTAL
                                Expanded(
                                  child: Container(
                                    height: 148,
                                    padding: const EdgeInsets.all(16),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                height: 38,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            AppTranslations.getText(
                                                              lang,
                                                              'real_light',
                                                            ),
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  const Color(
                                                                    0xFF2C3E50,
                                                                  ).withOpacity(
                                                                    0.6,
                                                                  ),
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          GestureDetector(
                                                            onTap:
                                                                _showLightSensorInfoDialog,
                                                            child: Icon(
                                                              Icons
                                                                  .info_outline_rounded,
                                                              size: 14,
                                                              color:
                                                                  const Color(
                                                                    0xFF2C3E50,
                                                                  ).withOpacity(
                                                                    0.5,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      _getEnvironmentIcon(
                                                        _luxValue,
                                                      ),
                                                      size: 20,
                                                      color:
                                                          _getEnvironmentIconColor(
                                                            _luxValue,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text.rich(
                                                      TextSpan(
                                                        text: _formatLux(
                                                          _luxValue,
                                                        ),
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 42,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  const Color(
                                                                    0xFF2C3E50,
                                                                  ),
                                                            ),
                                                        children: [
                                                          TextSpan(
                                                            text: " lx",
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  const Color(
                                                                    0xFF2C3E50,
                                                                  ).withOpacity(
                                                                    0.6,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _getEnvironmentName(
                                                      _luxValue,
                                                    ),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          _getEnvironmentIconColor(
                                                            _luxValue,
                                                          ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      AppTranslations.getText(
                                                        lang,
                                                        'real_light',
                                                      ),
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: const Color(
                                                              0xFF2C3E50,
                                                            ).withOpacity(0.5),
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons
                                                        .lightbulb_outline_rounded,
                                                    color: const Color(
                                                      0xFF2C3E50,
                                                    ).withOpacity(0.3),
                                                    size: 18,
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
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                    height: 148,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          (_locationError ||
                                              _isOffline ||
                                              !_uvAvailable)
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
                                    child:
                                        (_locationError ||
                                            _isOffline ||
                                            !_uvAvailable)
                                        ? Center(
                                            child: Text(
                                              "Índex UV no disponible",
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(
                                                  0xFF2C3E50,
                                                ).withOpacity(0.6),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                height: 38,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        AppTranslations.getText(
                                                          lang,
                                                          'uv_index_title',
                                                        ),
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  const Color(
                                                                    0xFF2C3E50,
                                                                  ).withOpacity(
                                                                    0.6,
                                                                  ),
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    SvgPicture.asset(
                                                      'assets/icons/heat_24.svg',
                                                      width: 20,
                                                      height: 20,
                                                      colorFilter:
                                                          const ColorFilter.mode(
                                                            Color.fromARGB(
                                                              255,
                                                              149,
                                                              62,
                                                              255,
                                                            ),
                                                            BlendMode.srcIn,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      _uvIndex.toStringAsFixed(
                                                        1,
                                                      ),
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 42,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: const Color(
                                                              0xFF2C3E50,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _uvIndex <= 2.9
                                                        ? AppTranslations.getText(
                                                            lang,
                                                            'uv_low',
                                                          )
                                                        : _uvIndex <= 5.9
                                                        ? AppTranslations.getText(
                                                            lang,
                                                            'uv_moderate',
                                                          )
                                                        : _uvIndex <= 7.9
                                                        ? AppTranslations.getText(
                                                            lang,
                                                            'uv_high',
                                                          )
                                                        : _uvIndex <= 10.9
                                                        ? AppTranslations.getText(
                                                            lang,
                                                            'uv_very_high',
                                                          )
                                                        : AppTranslations.getText(
                                                            lang,
                                                            'uv_extreme',
                                                          ),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _getUvColor(
                                                        _uvIndex,
                                                      ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // LÓGICA DE ESTADO DEL BOTÓN PRINCIPAL / DETALLES DE ACCIÓN
                            if (_limitReachedToday)
                              _buildLimitReachedCard()
                            else if (_buttonState == 1)
                              _buildCalculatedButton()
                            else if (_buttonState == 2)
                              _buildCountdownTimerCard(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
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

  // Card que se muestra si el límite fue alcanzado hoy
  Widget _buildLimitReachedCard() {
    final lang = appLanguage.value;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50).withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF2C3E50).withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.done_all_rounded,
            color: Color(0xFF73C6B6),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            AppTranslations.getText(lang, 'daily_limit_reached'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppTranslations.getText(lang, 'sun_limit_reached_card_body'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF2C3E50).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              // Botón secreto de reseteo para permitir probar nuevamente en el mismo día
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('daily_limit_date');
              setState(() {
                _limitReachedToday = false;
                _buttonState = 1;
              });
            },
            child: Text(
              AppTranslations.getText(lang, 'reset_limit_proto'),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF73C6B6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ESTADO 1: Botón de inicio con el tiempo ya calculado
  Widget _buildCalculatedButton() {
    final lang = appLanguage.value;
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF73C6B6),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF73C6B6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sunny, color: Color(0xFFF7D070), size: 30),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppTranslations.getText(lang, 'estimated_safe_time'),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatSafeTime(_calculatedSafeMinutes),
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: (_locationError || _isOffline || !_uvAvailable)
                      ? null
                      : _startCountdown,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF73C6B6),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                  ),
                  child: Text(
                    AppTranslations.getText(lang, 'start_exposure'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
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
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_locationError || _isOffline || !_uvAvailable)
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Demo 10s",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: (_locationError || _isOffline || !_uvAvailable)
                              ? Colors.white.withOpacity(0.4)
                              : Colors.white,
                        ),
                      ),
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

  Color _getCountdownColor(double progress) {
    if (progress >= 0.50) {
      return const Color(0xFF73C6B6);
    } else if (progress >= 0.25) {
      // Verde a amarillo progresivamente (50% al 25%)
      double t = (0.50 - progress) / 0.25;
      return Color.lerp(
        const Color(0xFF73C6B6),
        const Color(0xFFF7D070),
        t.clamp(0.0, 1.0),
      )!;
    } else if (progress >= 0.10) {
      // Amarillo a rojo progresivamente (25% al 10%)
      double t = (0.25 - progress) / 0.15;
      return Color.lerp(
        const Color(0xFFF7D070),
        Colors.redAccent,
        t.clamp(0.0, 1.0),
      )!;
    } else {
      // A partir del 10% solo rojo
      return Colors.redAccent;
    }
  }

  // ESTADO 2: Cronómetro circular animado de cuenta atrás
  Widget _buildCountdownTimerCard() {
    final lang = appLanguage.value;
    int totalDuration = _demoMode ? 10 : _calculatedSafeMinutes * 60;
    double progress = totalDuration > 0
        ? _remainingSeconds / totalDuration
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(28),
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
        children: [
          Text(
            AppTranslations.getText(lang, 'exposure_timer_title'),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C3E50).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          // Círculo de cuenta atrás
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: const Color(0xFFFBF9F5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getCountdownColor(progress),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatCountdownTime(_remainingSeconds),
                            style: GoogleFonts.poppins(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        AppTranslations.getText(lang, 'remaining'),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF2C3E50).withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: _cancelCountdown,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stop_rounded, color: Colors.redAccent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AppTranslations.getText(lang, 'cancel_exposure'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para obtener color según nivel de UV
  Color _getUvColor(double uv) {
    if (uv <= 2.9) return const Color(0xFF2ECC71); // Verde - Bajo
    if (uv <= 5.9) return const Color(0xFFF1C40F); // Amarillo - Moderado
    if (uv <= 7.9) return const Color(0xFFE67E22); // Naranja - Alto
    if (uv <= 10.9) return const Color(0xFFE74C3C); // Rojo - Muy Alto
    return const Color(0xFF9B59B6); // Púrpura - Extremo
  }
}
