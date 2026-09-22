import 'dart:async';

import 'package:flutter/material.dart';

import '../services/geocoding_service.dart';
import '../theme/app_colors.dart';
import 'address_map_picker.dart';

/// Address text field with live OpenStreetMap (Nominatim) suggestions.
class AddressSearchField extends StatefulWidget {
  final String label;
  final IconData icon;
  final ValueChanged<GeocodingResult?> onSelected;

  const AddressSearchField({
    super.key,
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final _controller = TextEditingController();
  final _geocoding = GeocodingService();

  Timer? _debounce;
  List<GeocodingResult> _results = [];
  GeocodingResult? _selected;
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_selected != null) {
      _selected = null;
      widget.onSelected(null);
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _geocoding.search(query);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _select(GeocodingResult result) {
    setState(() {
      _selected = result;
      _controller.text = result.displayName;
      _results = [];
    });
    widget.onSelected(result);
  }

  Future<void> _pickFromMap() async {
    final result = await Navigator.push<GeocodingResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressMapPickerPage(
          title: 'Select ${widget.label}',
          initialLocation: _selected,
        ),
      ),
    );
    if (result != null) _select(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Search address...',
            prefixIcon: Icon(widget.icon),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_selected != null)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                  ),
                IconButton(
                  tooltip: 'Pick on map',
                  onPressed: _pickFromMap,
                  icon: const Icon(
                    Icons.map_outlined,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    result.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => _select(result),
                );
              },
            ),
          ),
      ],
    );
  }
}
