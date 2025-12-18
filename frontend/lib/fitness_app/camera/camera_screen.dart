import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_storage.dart' show AuthStorage;
import '../camera/services/api_service.dart';
import '../camera/services/db_service.dart';
import '../camera/models/scan_result.dart';
import 'history_screen.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _cancelled = false;
  List<ScanResult> _history = [];

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
  setState(() => _cancelled = false);

    try {
  final dynamic conn = await Connectivity().checkConnectivity();
  final isOnline = conn != ConnectivityResult.none;

      if (isOnline) {
        // New flow: POST the file directly to backend /upload (multipart). Backend will store only JSON
        // in Firestore and return the document id + suggestedLocalFilename. We persist the image locally
        // and a sidecar JSON file for later history viewing.
        try {
          final uri = Uri.parse('${ApiService.baseUrl}/upload');
          final jwt = AuthStorage.token;

          final request = http.MultipartRequest('POST', uri);
          if (jwt != null && jwt.isNotEmpty) {
            request.headers['Authorization'] = 'Bearer $jwt';
          }
          request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path, filename: _selectedImage!.name));

          final streamed = await request.send();
          final resp = await http.Response.fromStream(streamed);

          if (_cancelled) return;

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            final response = jsonDecode(resp.body) as Map<String, dynamic>;

            // determine display values
            Map<String, dynamic>? display;
            if (response['mainFood'] != null) {
              final mf = response['mainFood'] as Map<String, dynamic>;
              display = {
                'class': mf['food'] ?? 'Unknown',
                'confidence': (mf['confidence'] is num) ? (mf['confidence'] as num).toDouble() : 0.0,
              };
            } else if (response['detections'] is List && (response['detections'] as List).isNotEmpty) {
              final first = (response['detections'] as List).first as Map<String, dynamic>;
              display = {
                'class': first['food'] ?? 'Unknown',
                'confidence': (first['confidence'] is num) ? (first['confidence'] as num).toDouble() : 0.0,
              };
            }

            // Save image locally under documents/scan_history/<suggestedLocalFilename>
            final docId = response['id'] as String?;
            final suggested = response['suggestedLocalFilename'] as String? ?? '${docId ?? DateTime.now().millisecondsSinceEpoch}.jpg';
            final appDir = await getApplicationDocumentsDirectory();
            final historyDir = Directory('${appDir.path}/scan_history');
            if (!await historyDir.exists()) await historyDir.create(recursive: true);
            final localPath = '${historyDir.path}/$suggested';
            await File(_selectedImage!.path).copy(localPath);

            // save sidecar JSON
            final sidecarPath = '${historyDir.path}/${docId ?? suggested}.json';
            await File(sidecarPath).writeAsString(resp.body);

            if (display != null) {
              // augment display with nutrition info when present so camera UI shows it immediately
              if (response['totalNutrition'] != null) {
                display['nutrition'] = response['totalNutrition'];
              }
              if (response['mainFood'] != null && response['mainFood']['portion_g'] != null) {
                display['portion_g'] = response['mainFood']['portion_g'];
              }
              setState(() {
                _prediction = display;
              });

              final result = ScanResult(
                imagePath: localPath,
                predictedClass: display['class'],
                confidence: display['confidence'],
                timestamp: DateTime.now(),
                synced: true,
              );
              await DBService.addResult(result);
              await _loadHistory();
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No food detected')));
            }
          } else {
            String bodyText = resp.body;
            try {
              final parsed = jsonDecode(resp.body);
              if (parsed is Map && parsed['message'] != null) bodyText = parsed['message'];
            } catch (_) {}
            throw Exception('upload failed: ${resp.statusCode} - $bodyText');
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
      if (mounted && !_cancelled) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    final list = DBService.getAllResults();
    setState(() {
      _history = list;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () async {
              // open history screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
            _isLoading
                ? Column(
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Processing image, this may take up to 30 seconds. You can cancel if you wish.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _cancelled = true;
                            _isLoading = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            _prediction != null
                ? Column(
                    children: [
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
                              const SizedBox(height: 8),
                              // show nutrition if available in sidecar JSON
                              if (_prediction!['nutrition'] != null)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Chip(label: Text('Cal: ${_prediction!['nutrition']['calories']}')),
                                    Chip(label: Text('Protein: ${_prediction!['nutrition']['protein']}g')),
                                    Chip(label: Text('Fat: ${_prediction!['nutrition']['fat']}g')),
                                    Chip(label: Text('Carbs: ${_prediction!['nutrition']['carbs']}g')),
                                  ],
                                ),
                              if (_prediction!['portion_g'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('Portion: ${_prediction!['portion_g']} g'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          const SizedBox.shrink(),
                ],
              ),
            ),
          ),
          // single history container is shown above inside the scrollable area
        ],
      ),
    );
  }
}
