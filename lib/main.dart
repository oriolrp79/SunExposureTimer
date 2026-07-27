import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ambient_light/ambient_light.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const InitialRouter(),
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
                  "Selecciona tu tipo de piel",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Compara tu piel del antebrazo con las siguientes tarjetas de la escala Fitzpatrick.",
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
                                      type.name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      type.description,
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
                    "Aceptar",
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

  // Sensor de Luz
  bool _hasPhysicalLightSensor = false;
  int _luxValue = 0;
  double _simulatedSunPower = 15000.0; // Valor simulado inicial (en lux)
  StreamSubscription<double>? _lightSubscription;

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
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateClock(),
    );
    _checkDailyLimit();
    _initLightSensor();
    _fetchLocationAndUv();

    // Calcular inicialmente
    _calculateRecommendedTime();
    // Programar cálculo periódico cada 5 segundos
    _calculationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_buttonState == 1) {
        _calculateRecommendedTime();
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _calculationTimer?.cancel();
    _lightSubscription?.cancel();
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
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
          _lightSubscription = sensor.ambientLightStream.listen((lux) {
            setState(() {
              _luxValue = lux.round();
            });
            _calculateRecommendedTime();
          });
          return;
        }
      } catch (e) {
        debugPrint("Error inicializando sensor de luz: $e");
      }
    }
    // Si no está disponible, el valor se toma de la simulación interactiva
    setState(() {
      _hasPhysicalLightSensor = false;
      _luxValue = _simulatedSunPower.round();
    });
    _calculateRecommendedTime();
  }

  // Obtiene posición GPS y consulta Open-Meteo
  Future<void> _fetchLocationAndUv() async {
    setState(() {
      _isFetchingUv = true;
      _locationError = false;
      _locationName = "Detectando ubicación...";
    });

    try {
      Position position = await _determinePosition();
      setState(() {
        _currentPosition = position;
        _locationName =
            "Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}";
      });
      await _fetchUvIndex(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Error de localización: $e");
      // Fallback a ubicación simulada (Barcelona)
      setState(() {
        _locationError = true;
        _locationName = "Barcelona, ES (Simulada)";
      });
      // Consultamos UV para coordenadas de Barcelona
      await _fetchUvIndex(41.3851, 2.1734);
    } finally {
      setState(() {
        _isFetchingUv = false;
      });
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
    if (lux >= 20000) {
      return 1.0;
    } else if (lux >= 1000) {
      return 0.5;
    } else {
      return 0.1;
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
    final factorAtenuacion = _getAttenuationFactor(_luxValue);

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

  // Genera un texto para el formato de tiempo en MM:SS
  String _formatSeconds(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            "Información",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          content: Text(
            "El sensor de luz ayuda a estimar si estás a la sombra o al sol directo. Recuerda que la arena y el agua reflejan hasta un 20% de la radiación UV incluso a la sombra.",
            style: GoogleFonts.poppins(
              color: const Color(0xFF2C3E50).withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF73C6B6),
              ),
              child: Text(
                "Entendido",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentType = fitzpatrickTypes[widget.selectedSkinTypeIndex];
    final date = DateTime.now();
    final dayString = "${date.day} de ${_getMonthName(date.month)}";
    final season = _getSeason();

    // Determinar color de fondo con destellos si se activa la alarma
    Color backgroundColor = const Color(0xFFF7D070);
    if (_isFlashing) {
      backgroundColor = _flashToggle
          ? const Color(0xFFFFE599)
          : const Color(0xFFA8E6CF);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                Text(
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
                                    _locationError ? "Simulada" : "GPS Activo",
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Tu tipo de piel: ${currentType.name}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                  ),
                                  Text(
                                    "Dosis segura: ${currentType.dose} J/m²",
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
                              tooltip: "Cambiar fototipo",
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Coordenadas",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(
                                        0xFF2C3E50,
                                      ).withOpacity(0.6),
                                    ),
                                  ),
                                  Text(
                                    _locationName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _fetchLocationAndUv,
                              icon: _isFetchingUv
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    height: 38,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _hasPhysicalLightSensor
                                                    ? "Luz real"
                                                    : "Lux Simulado",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF2C3E50,
                                                  ).withOpacity(0.6),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              GestureDetector(
                                                onTap:
                                                    _showLightSensorInfoDialog,
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
                                        const SizedBox(width: 4),
                                        Icon(
                                          _getEnvironmentIcon(_luxValue),
                                          size: 20,
                                          color: _getEnvironmentIconColor(
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
                                        alignment: Alignment.centerLeft,
                                        child: Text.rich(
                                          TextSpan(
                                            text: _formatLux(_luxValue),
                                            style: GoogleFonts.poppins(
                                              fontSize: 42,
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
                                        _getEnvironmentName(_luxValue),
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _getEnvironmentIconColor(
                                            _luxValue,
                                          ),
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
                          const SizedBox(width: 16),

                          // ÍNDICE UV REAL/ESTIMADO
                          Expanded(
                            child: Container(
                              height: 148,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    height: 38,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "UV",
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(
                                                0xFF2C3E50,
                                              ).withOpacity(0.6),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        SvgPicture.asset(
                                          'assets/icons/heat_24.svg',
                                          width: 20,
                                          height: 20,
                                          colorFilter: const ColorFilter.mode(
                                            Color.fromARGB(255, 149, 62, 255),
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
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _uvIndex.toStringAsFixed(1),
                                          style: GoogleFonts.poppins(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _uvIndex <= 2.9
                                            ? "Bajo"
                                            : _uvIndex <= 5.9
                                            ? "Moderado"
                                            : _uvIndex <= 7.9
                                            ? "Alto"
                                            : _uvIndex <= 10.9
                                            ? "Muy Alto"
                                            : "Extremo",
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
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

                      // DESLIZADOR PARA SIMULAR SENSOR SI NO EXISTE FÍSICO
                      if (!_hasPhysicalLightSensor)
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Simular potencia de luz (Deslizador)",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(
                                    0xFF2C3E50,
                                  ).withOpacity(0.7),
                                ),
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF73C6B6),
                                  inactiveTrackColor: const Color(
                                    0xFF73C6B6,
                                  ).withOpacity(0.2),
                                  thumbColor: const Color(0xFF73C6B6),
                                  overlayColor: const Color(
                                    0xFF73C6B6,
                                  ).withOpacity(0.12),
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: 80000.0,
                                  divisions: 80,
                                  value: _simulatedSunPower,
                                  onChanged: (val) {
                                    setState(() {
                                      _simulatedSunPower = val;
                                      _luxValue = val.round();
                                      // Si no tenemos datos GPS, estimar UV proporcional a los luxes del slider
                                      if (_locationError) {
                                        _uvIndex = (val / 8000.0);
                                        if (_uvIndex > 12.0) _uvIndex = 12.0;
                                      }
                                    });
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Sombra (0 lx)",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(
                                        0xFF2C3E50,
                                      ).withOpacity(0.5),
                                    ),
                                  ),
                                  Text(
                                    "Sol Pleno (80K lx)",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(
                                        0xFF2C3E50,
                                      ).withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      // LÓGICA DE ESTADO DEL BOTÓN PRINCIPAL / DETALLES DE ACCIÓN
                      if (_limitReachedToday)
                        _buildLimitReachedCard()
                      else if (_buttonState == 0)
                        _buildInitialButton()
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.ads_click_rounded,
                          color: const Color(0xFF2C3E50).withOpacity(0.6),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Espacio reservado para Publicidad",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2C3E50).withOpacity(0.6),
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
          ],
        ),
      ),
    );
  }

  // Card que se muestra si el límite fue alcanzado hoy
  Widget _buildLimitReachedCard() {
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
            "Límite diario alcanzado",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Ya has completado tu dosis de sol recomendada para el día de hoy. Vuelve mañana para un nuevo monitoreo seguro.",
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
                _buttonState = 0;
              });
            },
            child: Text(
              "Reestablecer límite (Modo Prototipo)",
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

  // ESTADO 0: Botón Inicial para calcular
  Widget _buildInitialButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: _calculateRecommendedTime,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7659),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7659).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Calcular tiempo seguro",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Basado en fototipo y UV actual",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ESTADO 1: Botón de inicio con el tiempo ya calculado
  Widget _buildCalculatedButton() {
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
                Text(
                  "Tiempo Seguro Estimado",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                  ),
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
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _buttonState = 0;
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.replay_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "Volver a calcular",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white70,
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
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _startCountdown,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF73C6B6),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    "Iniciar",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        "Demo 10s",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
            "Temporizador de Exposición",
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
                        "restantes",
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
                    "Cancelar Exposición",
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

  // Método auxiliar para el nombre del mes
  String _getMonthName(int month) {
    const months = [
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
    ];
    return months[month - 1];
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
