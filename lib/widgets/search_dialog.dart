import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/terminal.dart';
import '../widgets/terminal_modals.dart'; // ✅ To show terminal info modal

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
    if (kDebugMode) {
      debugPrint('[SearchDialog] categories/types found => ${getCategories()}');
    }

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

    return AlertDialog(
      title: const Text('Search Terminals'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Type to search...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: selectedCategory,
              isExpanded: true,
              items: getCategories()
                  .map((category) => DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => selectedCategory = value);
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No terminals found'))
                  : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final terminal = filtered[index];
                  final displayType =
                  (terminal.type ?? terminal.category ?? 'Unknown');
                  return ListTile(
                    title: Text(terminal.name ?? 'Unnamed Terminal'),
                    subtitle: Text(displayType),
                    onTap: () async {
                      Navigator.pop(context); // close search dialog

                      if (widget.mapController != null && terminal.position != null) {
                        // Move directly to terminal and zoom very close
                        final target = LatLng(
                          terminal.position!.latitude,
                          terminal.position!.longitude,
                        );

                        await widget.mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(target, 20.5), // ✅ higher zoom
                        );

                        // Optional: show terminal modal
                        await Future.delayed(const Duration(milliseconds: 400));
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (_) => TerminalModal(
                              terminalData: {
                                "name": terminal.name,
                                "type": terminal.type,
                                "fareMetric": terminal.fareMetric,
                                "timeSchedule": terminal.timeSchedule,
                                "nearestLandmark": terminal.nearestLandmark,
                                "latitude": terminal.latitude,
                                "longitude": terminal.longitude,
                                "pictures": terminal.imagesBase64 ?? [], // ✅ match modal field name
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
