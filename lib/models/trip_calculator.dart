import 'vehicle.dart';

/// Résultat détaillé d'un calcul de coût de trajet.
class TripCostResult {
  const TripCostResult({
    required this.distanceKm,
    required this.litersUsed,
    required this.fuelCost,
    required this.tollCost,
    required this.passengers,
    required this.roundTrip,
  });

  /// Distance totale prise en compte (aller, ou aller-retour si applicable).
  final double distanceKm;

  /// Quantité de carburant consommée en litres.
  final double litersUsed;

  /// Coût du carburant en euros.
  final double fuelCost;

  /// Coût des péages en euros.
  final double tollCost;

  /// Nombre de passagers pour le partage des frais (conducteur inclus).
  final int passengers;

  /// Indique si le trajet est un aller-retour.
  final bool roundTrip;

  /// Coût total du trajet (carburant + péages).
  double get totalCost => fuelCost + tollCost;

  /// Coût par personne si les frais sont partagés.
  double get costPerPerson => passengers > 0 ? totalCost / passengers : totalCost;
}

/// Calcule le coût d'un trajet en voiture.
class TripCalculator {
  /// Calcule le coût d'un trajet.
  ///
  /// - [oneWayDistanceKm] : distance d'un aller en km.
  /// - [vehicle] : véhicule utilisé (pour la consommation).
  /// - [fuelPricePerLiter] : prix du carburant en €/L.
  /// - [tollCost] : coût des péages pour un aller (doublé si aller-retour).
  /// - [passengers] : nombre de personnes partageant les frais.
  /// - [roundTrip] : si vrai, la distance et les péages sont doublés.
  static TripCostResult calculate({
    required double oneWayDistanceKm,
    required Vehicle vehicle,
    required double fuelPricePerLiter,
    double tollCost = 0,
    int passengers = 1,
    bool roundTrip = false,
  }) {
    final factor = roundTrip ? 2 : 1;
    final distance = oneWayDistanceKm * factor;
    final tolls = tollCost * factor;

    final liters = distance * vehicle.consumptionPer100km / 100.0;
    final fuelCost = liters * fuelPricePerLiter;

    return TripCostResult(
      distanceKm: distance,
      litersUsed: liters,
      fuelCost: fuelCost,
      tollCost: tolls,
      passengers: passengers < 1 ? 1 : passengers,
      roundTrip: roundTrip,
    );
  }
}
