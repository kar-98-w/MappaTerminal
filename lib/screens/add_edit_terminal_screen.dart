import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// --- (RouteModel class is unchanged) ---
class RouteModel {
  String to;
  String type;
  String timeSchedule;
  String? fare;

  RouteModel({
    required this.to,
    this.type = 'Jeepney',
    required this.timeSchedule,
    this.fare,
  });

  Map<String, dynamic> toJson() {
    return {
      'to': to,
      'type': type,
      'timeSchedule': timeSchedule,
      'fare': fare,
    };
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawFare = json['fare'];
    String? finalFare;

    if (rawFare is String) {
      finalFare = rawFare;
    } else if (rawFare is num) {
      finalFare = rawFare.toString();
    } else if (rawFare != null) {
      finalFare = rawFare.toString();
    }

    return RouteModel(
      to: json['to'] ?? '',
      type: json['type'] ?? 'Jeepney',
      timeSchedule: json['timeSchedule'] ?? '',
      fare: finalFare,
    );
  }
}

class AddEditTerminalScreen extends StatefulWidget {
  final String? terminalId;
  final Map<String, dynamic>? existingData;

  const AddEditTerminalScreen({
    super.key,
    this.terminalId,
    this.existingData,
  });

  @override
  State<AddEditTerminalScreen> createState() => _AddEditTerminalScreenState();
}

class _AddEditTerminalScreenState extends State<AddEditTerminalScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  // --- NEW ---
  // Controller for the custom terminal ID
  final TextEditingController _terminalIdController = TextEditingController();


  final ImagePicker _picker = ImagePicker();

  List<XFile> _selectedImages = [];
  List<String> _existingBase64Images = [];
  bool _isSaving = false;
  String? _selectedType;

  List<RouteModel> _routes = [];

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _selectedType = data['type'] ?? 'Jeepney';
      _landmarkController.text = data['nearestLandmark'] ?? '';
      _latitudeController.text = (data['latitude']?.toString() ?? '');
      _longitudeController.text = (data['longitude']?.toString() ?? '');

      if (data['imagesBase64'] != null && data['imagesBase64'] is List) {
        _existingBase64Images =
        List<String>.from(data['imagesBase64'] as List<dynamic>);
      }

      if (data['routes'] != null && data['routes'] is List) {
        _routes = (data['routes'] as List)
            .map((routeData) =>
            RouteModel.fromJson(routeData as Map<String, dynamic>))
            .toList();
      }
    }
  }

  // --- (Image helper functions are unchanged) ---
  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() {
          final remainingSlots = 3 - _existingBase64Images.length;
          _selectedImages = picked.take(remainingSlots.clamp(0, 3)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<String?> _compressAndConvertToBase64(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
          dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 50,
        minWidth: 800,
        minHeight: 600,
      );

      if (result == null) return null;

      final bytes = await result.readAsBytes();
      final base64Str = base64Encode(bytes);

      if (base64Str.length > 350000) {
        debugPrint("⚠️ One image too large (${base64Str.length} bytes)");
        return null;
      }

      return base64Str;
    } catch (e) {
      debugPrint("Error compressing image: $e");
      return null;
    }
  }

  // Save terminal
  Future<void> _saveTerminal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      List<String> base64Images = [..._existingBase64Images];

      for (var image in _selectedImages) {
        final file = File(image.path);
        final base64Str = await _compressAndConvertToBase64(file);
        if (base64Str != null) base64Images.add(base64Str);
      }

      // ... (Image size checks are unchanged) ...
      if (base64Images.length > 3) {
        throw Exception("⚠️ Max 3 images allowed per terminal.");
      }
      final totalSize = base64Images.fold<int>(
        0,
            (sum, b64) => sum + b64.length,
      );
      if (totalSize > 950000) {
        throw Exception(
            "⚠️ Total images exceed Firestore 1MB limit (${totalSize ~/ 1000} KB)");
      }

      final terminalData = {
        'name': _nameController.text.trim(),
        'type': _selectedType ?? 'Jeepney',
        'nearestLandmark': _landmarkController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text.trim()),
        'longitude': double.tryParse(_longitudeController.text.trim()),
        'imagesBase64': base64Images,
        'updatedAt': FieldValue.serverTimestamp(),
        'routes': _routes.map((route) => route.toJson()).toList(),
      };

      // --- MODIFIED ---
      // Updated saving logic to use custom ID
      if (widget.terminalId != null) {
        // We are EDITING an existing terminal
        await firestore
            .collection('terminals')
            .doc(widget.terminalId)
            .update(terminalData);
      } else {
        // We are ADDING a new terminal
        final customId = _terminalIdController.text.trim();
        if (customId.isEmpty) {
          // This should be caught by the validator, but good to double-check
          throw Exception('Terminal ID cannot be empty.');
        }

        // Safety Check: Make sure this ID isn't already taken
        final docRef = firestore.collection('terminals').doc(customId);
        final doc = await docRef.get();

        if (doc.exists) {
          // Stop! This ID is already in use.
          throw Exception('Error: A terminal with the ID "$customId" already exists.');
        } else {
          // This ID is free. Use .set() to create the document with our custom ID.
          await docRef.set(terminalData);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Terminal saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Failed to save terminal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e')), // Show the specific error
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- (Delete terminal function is unchanged) ---
  Future<void> _deleteTerminal() async {
    if (widget.terminalId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this terminal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('terminals')
            .doc(widget.terminalId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Terminal deleted successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('❌ Failed to delete terminal: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Failed to delete terminal: $e')),
          );
        }
      }
    }
  }

  // --- (Route Dialog function is unchanged) ---
  Future<void> _showRouteDialog({int? index}) async {
    final bool isEditing = index != null;
    final _routeFormKey = GlobalKey<FormState>();
    RouteModel route =
    isEditing ? _routes[index ?? 0] : RouteModel(to: '', timeSchedule: '');
    final toController = TextEditingController(text: route.to);
    final scheduleController = TextEditingController(text: route.timeSchedule);
    final fareController = TextEditingController(text: route.fare ?? '');
    String routeType = route.type;

    final result = await showDialog<RouteModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Route' : 'Add Route'),
              content: Form(
                key: _routeFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: toController,
                        decoration:
                        const InputDecoration(labelText: 'Destination (To)'),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: routeType,
                        items: const [
                          DropdownMenuItem(
                              value: 'Jeepney', child: Text('Jeepney')),
                          DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                          DropdownMenuItem(
                              value: 'Minibus', child: Text('Minibus')),
                        ],
                        decoration: const InputDecoration(labelText: 'Type'),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => routeType = val);
                          }
                        },
                      ),
                      TextFormField(
                        controller: scheduleController,
                        decoration: const InputDecoration(labelText: 'Schedule'),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: fareController,
                        decoration: const InputDecoration(
                            labelText: 'Fare (e.g., ₱29 or Contact Driver)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_routeFormKey.currentState!.validate()) {
                      final newRoute = RouteModel(
                        to: toController.text.trim(),
                        type: routeType,
                        timeSchedule: scheduleController.text.trim(),
                        fare: fareController.text.trim().isEmpty
                            ? null
                            : fareController.text.trim(),
                      );
                      Navigator.pop(context, newRoute);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (isEditing) {
          _routes[index!] = result;
        } else {
          _routes.add(result);
        }
      });
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    // --- NEW ---
    // Check if we are in "Add" mode
    final bool isAdding = widget.terminalId == null;

    return Scaffold(
      appBar: AppBar(
        title:
        Text(isAdding ? 'Add Terminal' : 'Edit Terminal'),
        actions: [
          if (!isAdding)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteTerminal,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- NEW ---
              // Show this field ONLY when adding a new terminal
              if (isAdding)
                TextFormField(
                  controller: _terminalIdController,
                  decoration: const InputDecoration(
                      labelText: 'Terminal ID *',
                      hintText: 'e.g., pampanga_main_terminal',
                      helperText: 'Cannot be changed later. Use letters, numbers, _'
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'A custom ID is required';
                    }
                    if (v.contains(' ')) {
                      return 'ID cannot contain spaces';
                    }
                    return null;
                  },
                ),
              if (isAdding) const SizedBox(height: 10),

              // Terminal Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Terminal Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),

              const SizedBox(height: 10),

              // Dropdown for Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'Jeepney', child: Text('Jeepney')),
                  DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                  DropdownMenuItem(
                      value: 'Minibus', child: Text('Minibus')),
                ],
                decoration:
                const InputDecoration(labelText: 'Terminal Main Type'),
                onChanged: (val) => setState(() => _selectedType = val),
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _landmarkController,
                decoration:
                const InputDecoration(labelText: 'Nearest Landmark'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _latitudeController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _longitudeController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
              ),

              const Divider(height: 40),

              // --- (Routes section is unchanged) ---
              Text(
                'Routes from this Terminal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _routes.length,
                itemBuilder: (context, index) {
                  final route = _routes[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(route.to,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${route.type} | ${route.timeSchedule} | ${route.fare ?? 'N/A'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.blueAccent),
                            onPressed: () => _showRouteDialog(index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () {
                              setState(() => _routes.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showRouteDialog(),
                  icon: const Icon(Icons.add_road),
                  label: const Text('Add Route'),
                ),
              ),

              const Divider(height: 40),

              // --- (Image picker UI is unchanged) ---
              Center(
                child: ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.image),
                  label: const Text('Select Images'),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._existingBase64Images.asMap().entries.map((entry) {
                    final index = entry.key;
                    final b64 = entry.value;
                    return Stack(
                      children: [
                        Image.memory(
                          base64Decode(b64),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(
                                      () => _existingBase64Images.removeAt(index));
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  ..._selectedImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return Stack(
                      children: [
                        Image.file(
                          File(file.path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedImages.removeAt(index));
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                  ),
                  onPressed: _isSaving ? null : _saveTerminal,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Terminal'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}