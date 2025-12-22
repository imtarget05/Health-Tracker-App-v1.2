import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_storage.dart' show AuthStorage;
import 'package:best_flutter_ui_templates/services/event_bus.dart';
import '../camera/services/api_service.dart';
import '../camera/services/db_service.dart';
import '../camera/models/scan_result.dart';
import 'history_screen.dart';
import '../camera/services/suggestion_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/diary_service.dart';
import '../../models/diary.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String _selectedSlot = 'none';
  // small retry helper for transient errors
  Future<T> _retryWithBackoff<T>(Future<T> Function() fn, {int maxAttempts = 3, Duration initialDelay = const Duration(seconds: 1)}) async {
    int attempt = 0;
    Duration delay = initialDelay;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt += 1;
        final isTransient = (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded')) || e is SocketException || e.toString().toLowerCase().contains('unavailable');
        if (!isTransient) rethrow;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }
  // history is read via DBService.getAllResults(); keep local field removed to avoid unused warning

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
    debugPrint('predict: started, _isLoading=$_isLoading _cancelled=$_cancelled');

    // helper to stop loading and ensure setState called when mounted
    void _stopLoading() {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('predict: _stopLoading called');
      }
    }
  setState(() => _cancelled = false);
  debugPrint('predict: started, _isLoading=$_isLoading _cancelled=$_cancelled');

                try {
                  debugPrint('predict: before addMeal (shouldAttempt)');
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
          // include selected slot so backend can tag the returned diary/meal
          request.fields['slot'] = _selectedSlot;
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

            // Attempt to save image locally, but make it optional: if copy fails,
            // proceed to store metadata (meal/ suggestion) without image to avoid
            // permission or file errors causing the whole flow to fail.
                        final docId = response['id'] as String?; 
            String? localPath;
            try {
              final suggested = response['suggestedLocalFilename'] as String? ?? '${docId ?? DateTime.now().millisecondsSinceEpoch}.jpg';
              final appDir = await getApplicationDocumentsDirectory();
              final historyDir = Directory('${appDir.path}/scan_history');
              if (!await historyDir.exists()) await historyDir.create(recursive: true);
              localPath = '${historyDir.path}/$suggested';
              // copy but if copy fails we'll catch and continue without image
              await File(_selectedImage!.path).copy(localPath);

              // save sidecar JSON alongside image when possible
              final sidecarPath = '${historyDir.path}/${docId ?? suggested}.json';
              try {
                final Map<String, dynamic> serverMap = jsonDecode(resp.body) as Map<String, dynamic>;
                serverMap['slot'] = _selectedSlot;
                await File(sidecarPath).writeAsString(jsonEncode(serverMap));
              } catch (e) {
                await File(sidecarPath).writeAsString(resp.body);
              }
            } catch (e) {
              // Ignore image copy/sidecar errors. We'll still continue saving
              // metadata (meal/suggestion) so the user flow is not blocked.
              localPath = null;
            }

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
                _isLoading = false; // stop spinner immediately when prediction available
              });

              final result = ScanResult(
                imagePath: localPath ?? '',
                predictedClass: display['class'],
                confidence: display['confidence'],
                timestamp: DateTime.now(),
                synced: true,
              );
              try {
                await DBService.addResult(result);
              } catch (_) {
                // ignore DBService write errors (keep UI flow smooth)
              }
              await _loadHistory();
              // If user selected a slot and backend returned nutrition, add Meal to today's diary
              try {
                final user = FirebaseAuth.instance.currentUser;
                final hasNutrition = response['totalNutrition'] != null;
                // Normalize detected class into allowed categories
                String normalizeClass(String raw) {
                  final r = raw.toLowerCase();
                  if (r.contains('rice')) return 'Rice';
                  if (r.contains('bread') || r.contains('bun') || r.contains('bagel')) return 'Bread';
                  if (r.contains('egg')) return 'Egg';
                  if (r.contains('meat') || r.contains('beef') || r.contains('pork') || r.contains('chicken')) return 'Meat';
                  if (r.contains('seafood') || r.contains('fish') || r.contains('shrimp') || r.contains('crab')) return 'Seafood';
                  if (r.contains('noodle') || r.contains('pasta')) return 'Noodles-Pasta';
                  if (r.contains('soup')) return 'Soup';
                  if (r.contains('dessert') || r.contains('cake') || r.contains('cookie') || r.contains('sweet')) return 'Dessert';
                  if (r.contains('dairy') || r.contains('milk') || r.contains('cheese') || r.contains('yogurt')) return 'Dairy product';
                  if (r.contains('fried') || r.contains('fries') || r.contains('fry')) return 'Fried food';
                  return 'Vegetable-Fruit';
                }

                if (user != null && _selectedSlot != 'none' && hasNutrition) {
                  final diaryService = DiaryService(FirebaseFirestore.instance, user.uid);
                  final nutrition = Map<String, dynamic>.from(response['totalNutrition'] as Map<String, dynamic>);
                  final mealMap = <String, dynamic>{
                    'id': response['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    'type': _selectedSlot,
                    'name': normalizeClass(display['class'] ?? ''),
                    'kcal': (nutrition['calories'] is num) ? (nutrition['calories'] as num).toInt() : 0,
                    'carbsG': (nutrition['carbs'] is num) ? (nutrition['carbs'] as num).toInt() : 0,
                    'proteinG': (nutrition['protein'] is num) ? (nutrition['protein'] as num).toInt() : 0,
                    'fatG': (nutrition['fat'] is num) ? (nutrition['fat'] as num).toInt() : 0,
                    'items': ((response['detections'] as List<dynamic>?) ?? []).map((d) => d is Map && d['food'] != null ? (d['food'] as String) : d.toString()).toList(),
                    // use a concrete Timestamp for local object construction; server will still store serverTimestamp when using transactions if desired
                    'createdAt': Timestamp.now(),
                  };

                  bool skipAddMeal = false;
                    try {
                        // Defensive: avoid duplicate inserts if backend already created the meal.
                        final existingDiary = await _retryWithBackoff(() => diaryService.getDiary(DateTime.now()));
                        final newMeal = Meal.fromMap(Map<String, dynamic>.from(mealMap));
                        var shouldAdd = true;
                        if (existingDiary != null) {
                          try {
                            shouldAdd = !existingDiary.meals.any((m) => m.id == newMeal.id);
                          } catch (_) {
                            shouldAdd = true;
                          }
                        }
                        if (shouldAdd) {
                          try {
                            // Proactively check access by attempting a lightweight get on the diary doc.
                            // If this read fails with permission-denied, avoid attempting the transaction
                            // which can produce a more verbose error. This makes the handling deterministic.
                            try {
                              await _retryWithBackoff(() => diaryService.getDiary(DateTime.now()));
                            } catch (rErr) {
                              final isPermDeniedRead = (rErr is FirebaseException && rErr.code == 'permission-denied') || rErr.toString().contains('permission-denied');
                              if (isPermDeniedRead) {
                                // Save as suggestion locally and inform user
                                try {
                                  final nutritionLocal = {
                                    'kcal': mealMap['kcal'],
                                    'carbsG': mealMap['carbsG'],
                                    'proteinG': mealMap['proteinG'],
                                    'fatG': mealMap['fatG'],
                                  };
                                  final suggestion = {
                                    'name': mealMap['name'],
                                    'rawName': display['class'],
                                    'nutrition': nutritionLocal,
                                    if (localPath != null) 'imagePath': localPath,
                                    'slot': _selectedSlot,
                                    'ts': DateTime.now().millisecondsSinceEpoch,
                                  };
                                  await SuggestionService.addSuggestion(suggestion);
                                } catch (_) {}
                                EventBus.instance.emitInfo('Meal stored locally (no permission to write to Firestore). It will be synced when permissions are available.');
                                // Skip attempting addMeal
                                skipAddMeal = true;
                              }
                            }
                            // If read passed or didn't detect permission issue, proceed to write
                            if (!skipAddMeal) {
                              await _retryWithBackoff(() => diaryService.addMeal(DateTime.now(), newMeal));
                              debugPrint('predict: addMeal completed');
                            } else {
                              debugPrint('predict: skipAddMeal=true; not calling addMeal');
                            }
                        } catch (e, st) {
                        // Robustly detect permission-denied regardless of exception type
                        final isPermDenied = (e is FirebaseException && e.code == 'permission-denied') || e.toString().contains('permission-denied');
                        if (isPermDenied) {
                          // Persist a local suggestion with slot so user can assign/sync later
                          try {
                            final nutritionLocal = {
                              'kcal': mealMap['kcal'],
                              'carbsG': mealMap['carbsG'],
                              'proteinG': mealMap['proteinG'],
                              'fatG': mealMap['fatG'],
                            };
                            final suggestion = {
                              'name': mealMap['name'],
                              'rawName': display['class'],
                              'nutrition': nutritionLocal,
                              if (localPath != null) 'imagePath': localPath,
                              'slot': _selectedSlot,
                              'ts': DateTime.now().millisecondsSinceEpoch,
                            };
                              await SuggestionService.addSuggestion(suggestion);
                          } catch (_) {
                            // fall back to informing user only
                          }
                          EventBus.instance.emitInfo('Meal stored locally (no permission to write to Firestore). It will be synced when permissions are available.');
                        } else {
                          // If this is a transient error, convert it to an info and queue suggestion instead of error
                          final isTransient = (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded')) || e.toString().toLowerCase().contains('unavailable');
                          if (isTransient) {
                            try {
                              final nutritionLocal = {
                                'kcal': mealMap['kcal'],
                                'carbsG': mealMap['carbsG'],
                                'proteinG': mealMap['proteinG'],
                                'fatG': mealMap['fatG'],
                              };
                              final suggestion = {
                                'name': mealMap['name'],
                                'rawName': display['class'],
                                'nutrition': nutritionLocal,
                                if (localPath != null) 'imagePath': localPath,
                                'slot': _selectedSlot,
                                'ts': DateTime.now().millisecondsSinceEpoch,
                              };
                              await SuggestionService.addSuggestion(suggestion);
                            } catch (_) {}
                            EventBus.instance.emitInfo('Failed to save to server; meal stored locally and will be retried.');
                          } else {
                            // Emit more context so we can debug unknown error domains
                            final user = FirebaseAuth.instance.currentUser;
                            final uid = user?.uid ?? '<no-user>';
                            final typeName = e.runtimeType.toString();
                            String fbCode = '';
                            String fbMessage = '';
                            if (e is FirebaseException) {
                              fbCode = e.code ?? '';
                              fbMessage = e.message ?? '';
                            }
                            debugPrint('addMeal failed: type=$typeName code=$fbCode msg=$fbMessage uid=$uid ex=$e');
                            debugPrintStack(label: 'addMeal stack', stackTrace: st);
                            EventBus.instance.emitError('Unable to add meal. Please try again.');
                          }
                        }
                      }
                    } else {
                      EventBus.instance.emitInfo('Meal already present in today\'s diary; skipping local insert');
                    }
                  } catch (e, st) {
                    // surface an error so we can see why meal wasn't added
                    final isPermDenied = (e is FirebaseException && e.code == 'permission-denied') || e.toString().contains('permission-denied');
                    if (isPermDenied) {
                      // Try to persist as suggestion if possible
                      try {
                        final nutritionLocal = {
                          'kcal': mealMap['kcal'],
                          'carbsG': mealMap['carbsG'],
                          'proteinG': mealMap['proteinG'],
                          'fatG': mealMap['fatG'],
                        };
                        final suggestion = {
                          'name': mealMap['name'],
                          'rawName': display['class'],
                          'nutrition': nutritionLocal,
                          'imagePath': localPath,
                          'slot': _selectedSlot,
                          'ts': DateTime.now().millisecondsSinceEpoch,
                        };
                        await SuggestionService.addSuggestion(suggestion);
                      } catch (_) {}
                      EventBus.instance.emitInfo('Meal stored locally (no permission to write to Firestore). It will be synced when permissions are available.');
                    } else {
                      final isTransient = (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded')) || e.toString().toLowerCase().contains('unavailable');
                      if (isTransient) {
                        try {
                          final nutritionLocal = {
                            'kcal': mealMap['kcal'],
                            'carbsG': mealMap['carbsG'],
                            'proteinG': mealMap['proteinG'],
                            'fatG': mealMap['fatG'],
                          };
                          final suggestion = {
                            'name': mealMap['name'],
                            'rawName': display['class'],
                            'nutrition': nutritionLocal,
                            if (localPath != null) 'imagePath': localPath,
                            'slot': _selectedSlot,
                            'ts': DateTime.now().millisecondsSinceEpoch,
                          };
                          await SuggestionService.addSuggestion(suggestion);
                        } catch (_) {}
                        EventBus.instance.emitInfo('Failed to save to server; meal stored locally and will be retried.');
                      } else {
                        final user = FirebaseAuth.instance.currentUser;
                        final uid = user?.uid ?? '<no-user>';
                        final typeName = e.runtimeType.toString();
                        String fbCode = '';
                        String fbMessage = '';
                        if (e is FirebaseException) {
                          fbCode = e.code ?? '';
                          fbMessage = e.message ?? '';
                        }
                        debugPrint('addMeal outer failed: type=$typeName code=$fbCode msg=$fbMessage uid=$uid ex=$e');
                        debugPrintStack(label: 'addMeal outer stack', stackTrace: st);
                        EventBus.instance.emitError('Không thể thêm bữa ăn. Vui lòng thử lại.');
                      }
                    }
                  }
                } else if (user != null && _selectedSlot == 'none' && hasNutrition) {
                  // save suggestion locally for user to assign later
                  final norm = normalizeClass(display['class'] ?? 'Food');
                  final nutrition = Map<String, dynamic>.from(response['totalNutrition'] as Map<String, dynamic>);
                  final suggestion = {
                    'name': norm,
                    'rawName': display['class'],
                    'nutrition': nutrition,
                    'imagePath': localPath,
                    'ts': DateTime.now().millisecondsSinceEpoch,
                  };
                  await SuggestionService.addSuggestion(suggestion);
                }
              } catch (_) {
                // non-fatal; ignore failures to avoid blocking user flow
              }
              // (meal insertion handled above with normalization)
            } else {
              EventBus.instance.emitInfo('No food detected');
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
            final raw = e.toString();
            debugPrint('Camera: predict error raw: $raw');
            EventBus.instance.emitError('Error processing image. Please try again.');
          }
        }
      } else {
        if (mounted) {
          EventBus.instance.emitInfo('Offline mode: Prediction queued for sync');
        }

        final result = ScanResult(
          imagePath: _selectedImage!.path,
          predictedClass: 'Pending...',
          confidence: 0.0,
          timestamp: DateTime.now(),
          synced: false,
        );
        await DBService.addResult(result);

        // Also save a sidecar JSON for offline queued item so history shows slot and predicted class
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final historyDir = Directory('${appDir.path}/scan_history');
          if (!await historyDir.exists()) await historyDir.create(recursive: true);
          final base = DateTime.now().millisecondsSinceEpoch.toString();
          final localImgName = '$base.jpg';
          final localPath = '${historyDir.path}/$localImgName';
          // copy temp image to persisted history
          await File(_selectedImage!.path).copy(localPath);
          final sidecar = {
            'mainFood': {'food': result.predictedClass},
            'totalNutrition': null,
            'slot': _selectedSlot,
            'queued': true,
            'ts': DateTime.now().millisecondsSinceEpoch,
          };
          final sidecarPath = '${historyDir.path}/$base.json';
          await File(sidecarPath).writeAsString(jsonEncode(sidecar));
          // also update Hive entry to point to persisted image path
          // find last added ScanResult and update path if present
          try {
            final box = Hive.box('scan_history');
            final idx = box.length - 1;
            if (idx >= 0) {
              final item = box.getAt(idx);
              if (item != null) {
                item.imagePath = localPath;
                await item.save();
              }
            }
          } catch (_) {}
        } catch (_) {}

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
        final raw = e.toString();
        debugPrint('Camera: predict outer error raw: $raw');
        EventBus.instance.emitError('Có lỗi khi xử lý hình ảnh. Vui lòng thử lại.');
      }
    } finally {
      debugPrint('predict: finally running, mounted=$mounted _cancelled=$_cancelled');
      if (mounted) {
        // Always clear loading spinner when the flow finishes (success or error).
        setState(() => _isLoading = false);
        debugPrint('predict: setState _isLoading=false');
      }
    }
  }

  Future<void> _loadHistory() async {
  // History is displayed in separate HistoryScreen; call DBService when needed.
  // DBService.getAllResults(); // intentionally not used here
  }

  @override
  void initState() {
    super.initState();
  // no local history load required; HistoryScreen reads DBService directly
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
            // meal slot selector: none, breakfast, lunch, snack, dinner
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSlot,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Slot: None')),
                  DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                  DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'snack', child: Text('Snack')),
                  DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                ],
                onChanged: (v) {
                  setState(() => _selectedSlot = v ?? 'none');
                },
              ),
            ),

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
