import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../camera/services/api_service.dart';
import '../camera/services/db_service.dart';
import '../camera/models/scan_result.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _prediction;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _prediction = null;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
        _prediction = null;
      });
    }
  }


  Future<void> _predict() async {
    if (_selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        final response = await ApiService.predict(_selectedImage!.path);

        if (response != null) {
          setState(() {
            _prediction = response;
          });

          final result = ScanResult(
            imagePath: _selectedImage!.path,
            predictedClass: response['class'],
            confidence: response['confidence'],
            timestamp: DateTime.now(),
            synced: true,
          );
          await DBService.addResult(result);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline mode: Prediction queued for sync'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        final result = ScanResult(
          imagePath: _selectedImage!.path,
          predictedClass: 'Pending...',
          confidence: 0.0,
          timestamp: DateTime.now(),
          synced: false,
        );
        await DBService.addResult(result);

        setState(() {
          _prediction = {
            'class': 'Queued for sync',
            'confidence': 0.0,
          };
        });
      }
    } catch (e) {
      final result = ScanResult(
        imagePath: _selectedImage!.path,
        predictedClass: 'Error: $e',
        confidence: 0.0,
        timestamp: DateTime.now(),
        synced: false,
      );
      await DBService.addResult(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_selectedImage!.path),
                  height: 300,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera),
              label: const Text('Take Photo'),
            ),

            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _pickImageFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery'),
            ),


            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _selectedImage != null && !_isLoading ? _predict : null,
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Submit'),
            ),
            if (_prediction != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prediction',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _prediction!['class'],
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confidence: ${(_prediction!['confidence'] * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
