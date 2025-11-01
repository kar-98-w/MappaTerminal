import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/terminal.dart';
import '../widgets/terminal_modals.dart'; // ✅ For terminal info modal

class SearchDialog extends StatefulWidget {
  final List<Terminal> terminals;
  final MaplibreMapController? mapController;

  const SearchDialog({
    super.key,
    required this.terminals,
    required this.mapController,
  });

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  String query = '';
  String selectedCategory = 'All';

  List<String> getCategories() {
    final types = widget.terminals
        .map((t) => (t.type ?? t.category ?? 'Unknown').toString())
        .toSet()
        .toList();
    types.sort();
    return ['All', ...types];
  }

  @override
  Widget build(BuildContext context) {
    final categories = getCategories();

    final filtered = widget.terminals.where((t) {
      final name = (t.name ?? '').toLowerCase().trim();
      final typeOrCategory = (t.type ?? t.category ?? '').toLowerCase().trim();
      final searchQuery = query.toLowerCase().trim();

      final matchesQuery = searchQuery.isEmpty ||
          name.contains(searchQuery) ||
          typeOrCategory.contains(searchQuery);

      final matchesCategory = selectedCategory == 'All'
          ? true
          : typeOrCategory == selectedCategory.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔍 Google-like Search bar
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for terminals or routes...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),

            const SizedBox(height: 10),

            // 🎚 Filter chips row
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = selectedCategory == category;
                  return ChoiceChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent,
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) {
                      setState(() => selectedCategory = category);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // 📋 Results
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'No terminals found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final terminal = filtered[index];
                  final displayType =
                  (terminal.type ?? terminal.category ?? 'Unknown');

                  return ListTile(
                    leading:
                    const Icon(Icons.place, color: Colors.blueAccent),
                    title: Text(
                      terminal.name ?? 'Unnamed Terminal',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(displayType),
                    onTap: () async {
                      Navigator.pop(context); // Close search dialog

                      if (widget.mapController != null &&
                          terminal.position != null) {
                        final target = LatLng(
                          terminal.position!.latitude,
                          terminal.position!.longitude,
                        );

                        await widget.mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(target, 20.5),
                        );

                        // Show terminal modal after zoom
                        await Future.delayed(
                            const Duration(milliseconds: 300));
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (_) => TerminalModal(
                              terminalData: {
                                "name": terminal.name,
                                "type": terminal.type,
                                "fareMetric": terminal.fareMetric,
                                "timeSchedule": terminal.timeSchedule,
                                "nearestLandmark":
                                terminal.nearestLandmark,
                                "latitude": terminal.latitude,
                                "longitude": terminal.longitude,
                                "pictures":
                                terminal.imagesBase64 ?? [],
                              },
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
