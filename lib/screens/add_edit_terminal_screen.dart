import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
  final TextEditingController _fareController = TextEditingController();
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  List<XFile> _selectedImages = [];
  List<String> _existingBase64Images = [];
  bool _isSaving = false;
  String? _selectedType; // ✅ dropdown value

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _selectedType = data['type'] ?? 'Jeepney';
      _fareController.text = data['fareMetric'] ?? '';
      _scheduleController.text = data['timeSchedule'] ?? '';
      _landmarkController.text = data['nearestLandmark'] ?? '';
      _latitudeController.text = (data['latitude']?.toString() ?? '');
      _longitudeController.text = (data['longitude']?.toString() ?? '');

      if (data['imagesBase64'] != null && data['imagesBase64'] is List) {
        _existingBase64Images =
        List<String>.from(data['imagesBase64'] as List<dynamic>);
      }
    }
  }

  // Pick multiple images
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

  // Compress + convert to Base64
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
        'fareMetric': _fareController.text.trim(),
        'timeSchedule': _scheduleController.text.trim(),
        'nearestLandmark': _landmarkController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text.trim()),
        'longitude': double.tryParse(_longitudeController.text.trim()),
        'imagesBase64': base64Images,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.terminalId != null) {
        await firestore
            .collection('terminals')
            .doc(widget.terminalId)
            .update(terminalData);
      } else {
        await firestore.collection('terminals').add(terminalData);
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
          SnackBar(content: Text('❌ Failed to save terminal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.terminalId != null ? 'Edit Terminal' : 'Add Terminal'),
        actions: [
          if (widget.terminalId != null)
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
            children: [
              // Terminal Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Terminal Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: 10),

              // ✅ Dropdown for Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'Jeepney', child: Text('Jeepney')),
                  DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                  DropdownMenuItem(value: 'Minibus', child: Text('Minibus')),
                ],
                decoration: const InputDecoration(labelText: 'Type'),
                onChanged: (val) => setState(() => _selectedType = val),
              ),

              const SizedBox(height: 10),

              // Multiline fields
              TextFormField(
                controller: _fareController,
                decoration: const InputDecoration(labelText: 'Fare'),
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _scheduleController,
                decoration: const InputDecoration(labelText: 'Schedule'),
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _landmarkController,
                decoration:
                const InputDecoration(labelText: 'Nearest Landmark'),
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
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

              const SizedBox(height: 20),

              // ✅ Updated button text
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.image),
                label: const Text('Select Images'),
              ),

              const SizedBox(height: 10),

              // Image previews
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
                              setState(() => _existingBase64Images.removeAt(index));
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

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTerminal,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Terminal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
