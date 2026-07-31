import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:sun_timer/main.dart'; // To access appLanguage

class SelectedCity {
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? admin1;
  final String? countryCode;

  SelectedCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.admin1,
    this.countryCode,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'country': country,
        'admin1': admin1,
        'countryCode': countryCode,
      };

  factory SelectedCity.fromJson(Map<String, dynamic> json) {
    return SelectedCity(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      country: json['country'] as String?,
      admin1: json['admin1'] as String?,
      countryCode: json['countryCode'] as String?,
    );
  }
}

class SearchCityBottomSheet extends StatefulWidget {
  const SearchCityBottomSheet({super.key});

  @override
  State<SearchCityBottomSheet> createState() => _SearchCityBottomSheetState();
}

class _SearchCityBottomSheetState extends State<SearchCityBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<SelectedCity> _results = [];
  String _errorMessage = '';
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMessage = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _hasSearched = true;
    });

    try {
      final url = Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=5&format=json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final resultsList = data['results'] as List?;
        if (resultsList != null) {
          final List<SelectedCity> cities = [];
          for (var item in resultsList) {
            final map = item as Map<String, dynamic>;
            cities.add(
              SelectedCity(
                name: map['name'] ?? '',
                latitude: (map['latitude'] as num).toDouble(),
                longitude: (map['longitude'] as num).toDouble(),
                country: map['country'],
                admin1: map['admin1'],
                countryCode: map['country_code'],
              ),
            );
          }
          setState(() {
            _results = cities;
            _isLoading = false;
          });
        } else {
          setState(() {
            _results = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = _getText('error');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getText('error');
        _isLoading = false;
      });
    }
  }

  String _getText(String key) {
    final lang = appLanguage.value;
    final translations = {
      'en': {
        'search_city': 'Search City',
        'search_hint': 'Search for a city...',
        'no_results': 'No cities found',
        'error': 'Error searching cities',
        'type_to_search': 'Type a city name to search',
      },
      'es': {
        'search_city': 'Buscar Ciudad',
        'search_hint': 'Busca una ciudad...',
        'no_results': 'No se encontraron ciudades',
        'error': 'Error al buscar ciudades',
        'type_to_search': 'Escribe el nombre de una ciudad para buscar',
      },
      'ca': {
        'search_city': 'Buscar Ciutat',
        'search_hint': 'Busca una ciutat...',
        'no_results': 'No s\'han trobat ciutats',
        'error': 'Error en buscar ciutats',
        'type_to_search': 'Escriu el nom d\'una ciutat per cercar',
      },
      'de': {
        'search_city': 'Stadt suchen',
        'search_hint': 'Nach einer Stadt suchen...',
        'no_results': 'Keine Städte gefunden',
        'error': 'Fehler bei der Stadtsuche',
        'type_to_search': 'Geben Sie einen Stadtnamen ein',
      },
      'fr': {
        'search_city': 'Rechercher une ville',
        'search_hint': 'Rechercher une ville...',
        'no_results': 'Aucune ville trouvée',
        'error': 'Erreur lors de la recherche',
        'type_to_search': 'Saisissez le nom d\'une ville',
      },
      'it': {
        'search_city': 'Cerca Città',
        'search_hint': 'Cerca una città...',
        'no_results': 'Nessuna città trovata',
        'error': 'Errore nella ricerca',
        'type_to_search': 'Digita il nome di una città',
      },
      'pt': {
        'search_city': 'Buscar Cidade',
        'search_hint': 'Buscar por uma cidade...',
        'no_results': 'Nenhuma cidade encontrada',
        'error': 'Erro ao buscar cidades',
        'type_to_search': 'Digite o nome de uma cidade',
      },
    };
    return translations[lang]?[key] ?? translations['en']?[key] ?? '';
  }

  String _getCountryFlagEmoji(String? countryCode) {
    if (countryCode == null || countryCode.length != 2) return '📍';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF73C6B6);
    final darkColor = const Color(0xFF2C3E50);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFBF9F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: darkColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getText('search_city'),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: darkColor.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: darkColor,
              ),
              decoration: InputDecoration(
                hintText: _getText('search_hint'),
                hintStyle: GoogleFonts.poppins(
                  fontSize: 15,
                  color: darkColor.withOpacity(0.4),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: darkColor.withOpacity(0.4),
                        ),
                        onPressed: () {
                          _controller.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 280,
                minHeight: 80,
              ),
              child: _buildContent(darkColor, primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color darkColor, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _errorMessage,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.redAccent,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          _getText('type_to_search'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: darkColor.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          _getText('no_results'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: darkColor.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      separatorBuilder: (context, index) => Divider(
        color: darkColor.withOpacity(0.08),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final city = _results[index];
        final String flag = _getCountryFlagEmoji(city.countryCode);
        final String locationDetail = [
          if (city.admin1 != null && city.admin1!.isNotEmpty) city.admin1,
          if (city.country != null && city.country!.isNotEmpty) city.country,
        ].join(', ');

        return InkWell(
          onTap: () {
            Navigator.pop(context, city);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Row(
              children: [
                Text(
                  flag,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: darkColor,
                        ),
                      ),
                      if (locationDetail.isNotEmpty)
                        Text(
                          locationDetail,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: darkColor.withOpacity(0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: darkColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
