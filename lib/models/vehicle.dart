/// Type de carburant supporté par l'application.
enum FuelType {
  diesel('Diesel'),
  essence('Essence');

  const FuelType(this.label);
  final String label;
}

/// Représente un véhicule et ses caractéristiques de consommation.
class Vehicle {
  const Vehicle({
    required this.name,
    required this.fuelType,
    required this.consumptionPer100km,
  });

  /// Nom affiché du véhicule (ex: "Peugeot 207 1.4 HDi").
  final String name;

  /// Type de carburant utilisé.
  final FuelType fuelType;

  /// Consommation moyenne en litres pour 100 km.
  final double consumptionPer100km;

  /// Véhicule par défaut : la Peugeot 207 1.4 Diesel (2009) de l'utilisateur.
  ///
  /// La 207 1.4 HDi (50 kW / 67 ch) consomme en moyenne ~4,5 L/100 km
  /// en cycle mixte.
  static const Vehicle peugeot207 = Vehicle(
    name: 'Peugeot 207 1.4 HDi (2009)',
    fuelType: FuelType.diesel,
    consumptionPer100km: 4.5,
  );

  Vehicle copyWith({
    String? name,
    FuelType? fuelType,
    double? consumptionPer100km,
  }) {
    return Vehicle(
      name: name ?? this.name,
      fuelType: fuelType ?? this.fuelType,
      consumptionPer100km: consumptionPer100km ?? this.consumptionPer100km,
    );
  }
}
