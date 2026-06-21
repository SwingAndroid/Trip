import 'dart:async';

import 'package:flutter/material.dart';

import '../services/route_service.dart';

/// Champ de saisie d'un lieu avec autocomplétion.
///
/// L'utilisateur tape une ville/adresse, choisit une suggestion réelle
/// (issue d'OpenStreetMap) ; la position sélectionnée est remontée via
/// [onSelected].
class PlaceField extends StatefulWidget {
  const PlaceField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.service,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final RouteService service;

  /// Appelé quand l'utilisateur sélectionne une position (ou null si le texte
  /// est modifié après coup, invalidant la sélection précédente).
  final ValueChanged<GeoPlace?> onSelected;

  @override
  State<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<PlaceField> {
  Timer? _debounce;
  List<GeoPlace> _suggestions = const [];
  bool _loading = false;
  bool _justSelected = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    // Toute modification du texte annule la position précédemment choisie.
    widget.onSelected(null);

    if (_justSelected) {
      _justSelected = false;
      return;
    }

    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() => _suggestions = const []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _loading = true);
      try {
        final results = await widget.service.searchPlaces(query);
        if (mounted) setState(() => _suggestions = results);
      } catch (_) {
        if (mounted) setState(() => _suggestions = const []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  void _select(GeoPlace place) {
    _justSelected = true;
    widget.controller.text = place.displayName;
    widget.onSelected(place);
    setState(() => _suggestions = const []);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surface,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, i) {
                final place = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    place.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _select(place),
                );
              },
            ),
          ),
      ],
    );
  }
}
