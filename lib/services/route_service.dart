import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Un lieu géocodé (résultat d'une recherche d'adresse).
class GeoPlace {
  const GeoPlace({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;
}

/// Résultat d'un calcul d'itinéraire routier.
class RouteResult {
  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.origin,
    required this.destination,
    required this.geometry,
  });

  /// Distance routière réelle en kilomètres.
  final double distanceKm;

  /// Durée estimée du trajet en minutes.
  final double durationMinutes;

  final GeoPlace origin;
  final GeoPlace destination;

  /// Tracé de l'itinéraire (suite de points à afficher sur la carte).
  final List<LatLng> geometry;
}

/// Erreur métier remontée à l'interface (message lisible par l'utilisateur).
class RouteException implements Exception {
  RouteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Service de calcul d'itinéraire basé sur OpenStreetMap.
///
/// - Géocodage via Nominatim (adresse -> coordonnées).
/// - Itinéraire routier via OSRM (distance réelle par la route).
///
/// Ces services publics sont gratuits et sans clé. Ils imposent un usage
/// raisonnable (un appel par calcul) et un en-tête `User-Agent` identifiant
/// l'application pour Nominatim.
class RouteService {
  RouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _osrmBase = 'https://router.project-osrm.org';
  static const _userAgent = 'TrajetApp/1.0 (calcul cout trajet)';

  /// Recherche des lieux correspondant à [query] (ville, adresse...).
  Future<List<GeoPlace>> searchPlaces(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse('$_nominatimBase/search').replace(
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'addressdetails': '0',
        'limit': '$limit',
      },
    );

    final res = await _get(uri);
    final data = jsonDecode(res) as List<dynamic>;
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      return GeoPlace(
        displayName: m['display_name'] as String? ?? '',
        latitude: double.parse(m['lat'] as String),
        longitude: double.parse(m['lon'] as String),
      );
    }).toList();
  }

  /// Géocode [query] et renvoie le meilleur résultat, ou null si aucun.
  Future<GeoPlace?> geocodeFirst(String query) async {
    final results = await searchPlaces(query, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  /// Calcule l'itinéraire routier en voiture entre deux lieux.
  Future<RouteResult> route(GeoPlace origin, GeoPlace destination) async {
    // OSRM attend les coordonnées au format lon,lat.
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$_osrmBase/route/v1/driving/$coords').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'alternatives': 'false',
      },
    );

    final res = await _get(uri);
    final data = jsonDecode(res) as Map<String, dynamic>;

    if (data['code'] != 'Ok') {
      throw RouteException(
          "Itinéraire introuvable entre ces deux points.");
    }

    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw RouteException("Aucun itinéraire routier disponible.");
    }

    final first = routes.first as Map<String, dynamic>;
    final meters = (first['distance'] as num).toDouble();
    final seconds = (first['duration'] as num).toDouble();

    // La géométrie GeoJSON est une liste de couples [lon, lat].
    final geometry = <LatLng>[];
    final geo = first['geometry'] as Map<String, dynamic>?;
    if (geo != null && geo['coordinates'] is List) {
      for (final point in geo['coordinates'] as List) {
        final p = point as List;
        geometry.add(LatLng(
          (p[1] as num).toDouble(),
          (p[0] as num).toDouble(),
        ));
      }
    }

    return RouteResult(
      distanceKm: meters / 1000.0,
      durationMinutes: seconds / 60.0,
      origin: origin,
      destination: destination,
      geometry: geometry,
    );
  }

  /// Calcule l'itinéraire à partir de deux requêtes textuelles
  /// (départ et destination), en géocodant chaque adresse au passage.
  Future<RouteResult> routeFromAddresses(
    String originQuery,
    String destinationQuery,
  ) async {
    final origin = await geocodeFirst(originQuery);
    if (origin == null) {
      throw RouteException('Lieu de départ introuvable : « $originQuery ».');
    }
    final destination = await geocodeFirst(destinationQuery);
    if (destination == null) {
      throw RouteException(
          'Destination introuvable : « $destinationQuery ».');
    }
    return route(origin, destination);
  }

  Future<String> _get(Uri uri) async {
    try {
      final res = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        throw RouteException(
            'Service indisponible (code ${res.statusCode}). Réessayez.');
      }
      return res.body;
    } on RouteException {
      rethrow;
    } catch (_) {
      throw RouteException(
          'Connexion impossible au service de cartographie. Vérifiez votre réseau.');
    }
  }

  void dispose() => _client.close();
}
