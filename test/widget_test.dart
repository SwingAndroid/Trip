import 'package:flutter_test/flutter_test.dart';
import 'package:trajet/models/trip_calculator.dart';
import 'package:trajet/models/vehicle.dart';

void main() {
  group('TripCalculator', () {
    test('calcul aller simple', () {
      final r = TripCalculator.calculate(
        oneWayDistanceKm: 100,
        vehicle: Vehicle.peugeot207, // 4.5 L/100km
        fuelPricePerLiter: 1.75,
      );

      expect(r.distanceKm, 100);
      expect(r.litersUsed, closeTo(4.5, 0.0001));
      expect(r.fuelCost, closeTo(7.875, 0.0001));
      expect(r.totalCost, closeTo(7.875, 0.0001));
    });

    test('aller-retour double distance et péages', () {
      final r = TripCalculator.calculate(
        oneWayDistanceKm: 100,
        vehicle: Vehicle.peugeot207,
        fuelPricePerLiter: 1.75,
        tollCost: 10,
        roundTrip: true,
      );

      expect(r.distanceKm, 200);
      expect(r.tollCost, 20);
      expect(r.litersUsed, closeTo(9.0, 0.0001));
      expect(r.totalCost, closeTo(9.0 * 1.75 + 20, 0.0001));
    });

    test('partage des frais par personne', () {
      final r = TripCalculator.calculate(
        oneWayDistanceKm: 100,
        vehicle: Vehicle.peugeot207,
        fuelPricePerLiter: 1.75,
        passengers: 3,
      );

      expect(r.costPerPerson, closeTo(r.totalCost / 3, 0.0001));
    });
  });
}
