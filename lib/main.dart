import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'models/trip_calculator.dart';
import 'models/vehicle.dart';
import 'services/route_service.dart';
import 'widgets/place_field.dart';

void main() {
  runApp(const TrajetApp());
}

class TrajetApp extends StatelessWidget {
  const TrajetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Coût de trajet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: const TripCostPage(),
    );
  }
}

/// Regroupe l'itinéraire calculé et son coût.
class TripOutcome {
  const TripOutcome({required this.route, required this.cost});
  final RouteResult route;
  final TripCostResult cost;
}

class TripCostPage extends StatefulWidget {
  const TripCostPage({super.key});

  @override
  State<TripCostPage> createState() => _TripCostPageState();
}

class _TripCostPageState extends State<TripCostPage> {
  final _routeService = RouteService();

  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _fuelPriceCtrl = TextEditingController(text: '1.75');
  final _consumptionCtrl = TextEditingController(
    text: Vehicle.peugeot207.consumptionPer100km.toString(),
  );
  final _tollCtrl = TextEditingController(text: '0');
  final _passengersCtrl = TextEditingController(text: '1');

  GeoPlace? _originPlace;
  GeoPlace? _destPlace;

  bool _roundTrip = false;
  bool _loading = false;
  TripOutcome? _outcome;

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _fuelPriceCtrl.dispose();
    _consumptionCtrl.dispose();
    _tollCtrl.dispose();
    _passengersCtrl.dispose();
    _routeService.dispose();
    super.dispose();
  }

  double _parse(String value, {double fallback = 0}) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  /// Calcule l'itinéraire réel entre les positions choisies puis le coût.
  Future<void> _calculate() async {
    final origin = _originPlace;
    final dest = _destPlace;
    if (origin == null || dest == null) {
      _showMessage(
        'Choisissez une position dans la liste pour le départ ET l\'arrivée.',
        error: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final route = await _routeService.route(origin, dest);

      final vehicle = Vehicle.peugeot207.copyWith(
        consumptionPer100km: _parse(_consumptionCtrl.text, fallback: 4.5),
      );
      final cost = TripCalculator.calculate(
        oneWayDistanceKm: route.distanceKm,
        vehicle: vehicle,
        fuelPricePerLiter: _parse(_fuelPriceCtrl.text, fallback: 1.75),
        tollCost: _parse(_tollCtrl.text),
        passengers: int.tryParse(_passengersCtrl.text.trim()) ?? 1,
        roundTrip: _roundTrip,
      );

      setState(() => _outcome = TripOutcome(route: route, cost: cost));
    } on RouteException catch (e) {
      _showMessage(e.message, error: true);
    } catch (_) {
      _showMessage('Erreur inattendue lors du calcul.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _originCtrl.clear();
    _destCtrl.clear();
    _fuelPriceCtrl.text = '1.75';
    _consumptionCtrl.text = Vehicle.peugeot207.consumptionPer100km.toString();
    _tollCtrl.text = '0';
    _passengersCtrl.text = '1';
    setState(() {
      _originPlace = null;
      _destPlace = null;
      _roundTrip = false;
      _outcome = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coût de trajet'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final maxWidth = isWide ? 1040.0 : 560.0;

          final form = _buildForm(context);
          final resultPanel = _buildResultPanel(context);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: form),
                          const SizedBox(width: 24),
                          Expanded(flex: 6, child: resultPanel),
                        ],
                      )
                    : Column(
                        children: [
                          form,
                          const SizedBox(height: 20),
                          resultPanel,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VehicleHeader(vehicle: Vehicle.peugeot207),
            const SizedBox(height: 20),
            PlaceField(
              controller: _originCtrl,
              label: 'Départ',
              icon: Icons.trip_origin,
              service: _routeService,
              onSelected: (p) => setState(() => _originPlace = p),
            ),
            const SizedBox(height: 12),
            PlaceField(
              controller: _destCtrl,
              label: 'Arrivée',
              icon: Icons.place,
              service: _routeService,
              onSelected: (p) => setState(() => _destPlace = p),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    controller: _consumptionCtrl,
                    label: 'Conso (L/100km)',
                    icon: Icons.local_gas_station,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    controller: _fuelPriceCtrl,
                    label: 'Prix (€/L)',
                    icon: Icons.euro,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    controller: _tollCtrl,
                    label: 'Péages (€)',
                    icon: Icons.toll,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    controller: _passengersCtrl,
                    label: 'Personnes',
                    icon: Icons.people,
                    integer: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aller-retour'),
              value: _roundTrip,
              onChanged: (v) => setState(() => _roundTrip = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _calculate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.calculate),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_loading ? 'Calcul…' : 'Calculer'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool integer = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: integer
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  Widget _buildResultPanel(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = _outcome;

    if (outcome == null) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const SizedBox(
          height: 320,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Choisissez un départ et une arrivée,\npuis appuyez sur « Calculer ».',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final route = outcome.route;
    final cost = outcome.cost;
    final factor = _roundTrip ? 2 : 1;
    final totalMinutes = route.durationMinutes * factor;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 240, child: _RouteMap(route: route)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _endpointRow(Icons.trip_origin, 'Départ',
                    _shortName(route.origin.displayName)),
                const Padding(
                  padding: EdgeInsets.only(left: 11),
                  child: SizedBox(
                    height: 16,
                    child: VerticalDivider(thickness: 1.5),
                  ),
                ),
                _endpointRow(Icons.place, 'Arrivée',
                    _shortName(route.destination.displayName)),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(Icons.route, '${cost.distanceKm.toStringAsFixed(0)} km',
                        'Distance'),
                    _stat(Icons.schedule, _formatDuration(totalMinutes),
                        'Durée'),
                    _stat(
                        Icons.local_gas_station,
                        '${cost.litersUsed.toStringAsFixed(1)} L',
                        'Carburant'),
                  ],
                ),
                const Divider(height: 28),
                _costRow('Carburant', cost.fuelCost),
                if (cost.tollCost > 0) _costRow('Péages', cost.tollCost),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Coût total',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          )),
                      Text('${cost.totalCost.toStringAsFixed(2)} €',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
                if (cost.passengers > 1) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Par personne (${cost.passengers})',
                          style: theme.textTheme.bodyLarge),
                      Text('${cost.costPerPerson.toStringAsFixed(2)} €',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _endpointRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(value,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }

  Widget _costRow(String label, double value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text('${value.toStringAsFixed(2)} €',
              style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  /// Raccourcit un nom complet OpenStreetMap aux 3 premiers segments.
  String _shortName(String full) {
    final parts = full.split(',').map((e) => e.trim()).toList();
    return parts.take(3).join(', ');
  }

  String _formatDuration(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}min';
  }
}

/// Carte affichant le tracé de l'itinéraire avec les points de départ/arrivée.
class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.route});

  final RouteResult route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = LatLng(route.origin.latitude, route.origin.longitude);
    final end = LatLng(route.destination.latitude, route.destination.longitude);
    final points = route.geometry.isNotEmpty ? route.geometry : [start, end];

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(36),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.trajet.trajet',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: 4,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: start,
              width: 36,
              height: 36,
              child: const Icon(Icons.trip_origin,
                  color: Colors.green, size: 28),
            ),
            Marker(
              point: end,
              width: 36,
              height: 36,
              child: Icon(Icons.place,
                  color: theme.colorScheme.error, size: 32),
            ),
          ],
        ),
      ],
    );
  }
}

/// En-tête affichant les caractéristiques du véhicule.
class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Icon(
            Icons.directions_car,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${vehicle.fuelType.label} • Manuelle • 1,4 L • 67 ch',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
