import 'dart:convert';
import 'package:http/http.dart' as http;

class IpLocationResult {
  final String city;
  final String countryName;
  final double latitude;
  final double longitude;

  IpLocationResult({
    required this.city,
    required this.countryName,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'city': city,
        'country_name': countryName,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory IpLocationResult.fromJson(Map<String, dynamic> json) {
    return IpLocationResult(
      city: json['city'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class IpLocationService {
  static Future<IpLocationResult?> fetchIpLocation() async {
    try {
      final url = Uri.parse('https://ipapi.co/json/');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Ensure required fields are present and not null
        if (data.containsKey('city') &&
            data.containsKey('country_name') &&
            data.containsKey('latitude') &&
            data.containsKey('longitude')) {
          return IpLocationResult.fromJson(data);
        }
      }
      return null;
    } catch (_) {
      // Catch network error, timeout, or parsing error and return null
      return null;
    }
  }
}
