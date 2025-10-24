import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


class AddEditTerminalScreen extends StatefulWidget {
  final Map<String, dynamic>? terminalData;
  final String? docId;


  const AddEditTerminalScreen({super.key, this.terminalData, this.docId});


  @override
  State<AddEditTerminalScreen> createState() => _AddEditTerminalScreenState();
}


class _AddEditTerminalScreenState extends State<AddEditTerminalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;


  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fareController = TextEditingController();
  final TextEditingController _scheduleController = TextEditingController();
  final TextEditingController _tripTimeController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();


  String _type = 'Jeepney';
  bool _isSaving = false;


  List<File> _newImages = [];
  List<String> _existingImages = [];


  @override
  void initState() {
    super.initState();
    if (widget.terminalData != null) {
      final data = widget.terminalData!;
      _nameController.text = data['name'] ?? '';
      _type = data['type'] ?? 'Jeepney';
      _fareController.text = data['fareMetric'] ?? '';
      _scheduleController.text = data['timeSchedule'] ?? '';
      _tripTimeController.text = data['estimatedTripTime'] ?? '';
      _landmarkController.text = data['nearestLandmark'] ?? '';
      _latController.text = (data['latitude']?.toString() ?? '');
      _lonController.text = (data['longitude']?.toString() ?? '');
      if (data['pictures'] != null && data['pictures'] is List) {
        _existingImages = List<String>.from(data['pictures']);
      }
    }
  }


  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty) {
      final List<File> compressedImages = [];
      for (final img in picked) {
        final compressed = await _compressImage(File(img.path));
        if (compressed != null) compressedImages.add(compressed);
      }
      setState(() {
        _newImages.addAll(compressedImages);
      });
    }
  }


  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
    path.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75,
    );
    return compressed != null ? File(compressed.path) : null;
  }


  Future<String> _uploadImage(File file) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('terminal_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putFile(file);
    return await storageRef.getDownloadURL();
  }


  Future<void> _removeExistingImage(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Image?"),
        content: const Text("Do you want to remove this image?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _existingImages.remove(url);
      });
    }
  }


  Future<void> _removeNewImage(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Image?"),
        content: const Text("Do you want to remove this image?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _newImages.remove(file);
      });
    }
  }


  Future<void> _saveTerminal() async {
    if (!_formKey.currentState!.validate()) return;


    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());


    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter valid coordinates')),
      );
      return;
    }


    setState(() => _isSaving = true);


    try {
      List<String> uploadedUrls = List.from(_existingImages);


      for (final file in _newImages) {
        final url = await _uploadImage(file);
        uploadedUrls.add(url);
      }


      final data = {
        'name': _nameController.text.trim(),
        'type': _type,
        'latitude': lat,
        'longitude': lon,
        'fareMetric': _fareController.text.trim(),
        'timeSchedule': _scheduleController.text.trim(),
        'estimatedTripTime': _tripTimeController.text.trim(),
        'nearestLandmark': _landmarkController.text.trim(),
        'pictures': uploadedUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };


      final ref = _firestore.collection('terminals');


      if (widget.docId != null && widget.docId!.isNotEmpty) {
        await ref.doc(widget.docId).update(data);
      } else {
        await ref.add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.docId != null ? '✅ Terminal updated!' : '✅ Terminal added!',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stack) {
      debugPrint('❌ Error saving terminal: $e');
      debugPrint(stack.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save terminal: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }


  Future<void> _deleteTerminal() async {
    if (widget.docId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Terminal?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('terminals').doc(widget.docId).delete();
      if (mounted) Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allImages = [
      ..._existingImages.map((String url) => {'type': 'url', 'data': url}),
      ..._newImages.map((File file) => {'type': 'file', 'data': file}),
    ];




    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId != null ? "Edit Terminal" : "Add Terminal"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text("Add Images"),
                  ),
                ),
                const SizedBox(height: 10),
                if (allImages.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allImages.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemBuilder: (context, index) {
                      final imageItem = allImages[index];
                      final String type = imageItem['type'] as String;
                      final dynamic data = imageItem['data'];


                      return GestureDetector(
                        onTap: () {
                          if (type == 'url') {
                            _removeExistingImage(data as String);
                          } else {
                            _removeNewImage(data as File);
                          }
                        },
                        child: type == 'url'
                            ? Image.network(data as String, fit: BoxFit.cover)
                            : Image.file(data as File, fit: BoxFit.cover),
                      );
                    },


                  ),
                const SizedBox(height: 20),


                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Terminal Name"),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Enter terminal name" : null,
                ),
                const SizedBox(height: 16),


                DropdownButtonFormField<String>(
                  value: _type,
                  items: ['Jeepney', 'Minibus', 'Bus']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                  decoration: const InputDecoration(labelText: "Vehicle Type"),
                ),
                const SizedBox(height: 16),


                TextFormField(
                  controller: _latController,
                  decoration: const InputDecoration(labelText: "Latitude"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),


                TextFormField(
                  controller: _lonController,
                  decoration: const InputDecoration(labelText: "Longitude"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),


                TextFormField(
                  controller: _fareController,
                  decoration: const InputDecoration(labelText: "Fare Metric"),
                ),
                const SizedBox(height: 16),


                TextFormField(
                  controller: _scheduleController,
                  decoration: const InputDecoration(labelText: "Schedule"),
                ),
                const SizedBox(height: 16),


                TextFormField(
                  controller: _tripTimeController,
                  decoration:
                  const InputDecoration(labelText: "Estimated Trip Time"),
                ),
                const SizedBox(height: 16),


                TextFormField(
                  controller: _landmarkController,
                  decoration:
                  const InputDecoration(labelText: "Nearest Landmark"),
                ),
                const SizedBox(height: 30),


                ElevatedButton(
                  onPressed: _isSaving ? null : _saveTerminal,
                  child: Text(_isSaving
                      ? "Saving..."
                      : widget.docId != null
                      ? "Update Terminal"
                      : "Save Terminal"),
                ),
                if (widget.docId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: _deleteTerminal,
                      child: const Text("Delete Terminal"),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

