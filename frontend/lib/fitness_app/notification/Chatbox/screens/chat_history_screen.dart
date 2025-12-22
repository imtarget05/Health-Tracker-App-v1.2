import 'package:flutter/material.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/utility/animated_dialog.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/constants/constants.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/boxes.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/chat_history.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/widgets/chat_history_widget.dart';
import 'package:best_flutter_ui_templates/services/auth_storage.dart';
import 'package:best_flutter_ui_templates/services/backend_api.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/widgets/empty_history_widget.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  Future<List<ChatHistory>>? _serverSummariesFuture;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    // start auto-sync if user is signed in
    _startAutoSync();
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (t) {
      final jwt = AuthStorage.token;
      if (jwt != null && jwt.isNotEmpty) {
        setState(() {
          _serverSummariesFuture = null; // force refresh
        });
      }
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<List<ChatHistory>> _fetchServerSummariesIfAvailable() async {
    final jwt = AuthStorage.token;
    if (jwt == null || jwt.isEmpty) return [];
    try {
      final resp = await BackendApi.getAiHistorySummaries(jwt: jwt, limit: 100);
      final list = (resp['history'] as List? ?? []).cast<Map<String, dynamic>>();
      // Map server docs to local ChatHistory model
      final mapped = list.map((doc) {
        final chatId = doc['chatId']?.toString() ?? (doc['id']?.toString() ?? '');
        final prompt = (doc['prompt'] ?? '') as String;
        final response = (doc['response'] ?? '') as String;
        final images = (doc['imagesUrls'] is List) ? (doc['imagesUrls'] as List).map((e) => e.toString()).toList() : <String>[];
        final updatedAt = doc['updatedAt'];
        DateTime ts;
        try {
          ts = updatedAt is String ? DateTime.parse(updatedAt) : (updatedAt is int ? DateTime.fromMillisecondsSinceEpoch(updatedAt) : (updatedAt is Map ? DateTime.parse(updatedAt['_seconds']?.toString() ?? DateTime.now().toIso8601String()) : DateTime.now()));
        } catch (_) {
          ts = DateTime.now();
        }
        return ChatHistory(chatId: chatId, prompt: prompt, response: response, imagesUrls: images, timestamp: ts);
      }).toList();

      return mapped;
    } catch (e) {
      return [];
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        centerTitle: true,
        title: const Text('Lịch sử chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              setState(() {
                _serverSummariesFuture = null;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Xoá tất cả',
            onPressed: () {
              showMyAnimatedDialog(
                context: context,
                title: 'Xoá tất cả',
                content: 'Bạn có chắc muốn xoá toàn bộ lịch sử chat?',
                actionText: 'Xoá',
                onActionPressed: (value) async {
                  if (value) {
                    final box = Boxes.getChatHistory();
                    final all = box.values.toList().cast();
                    for (var item in all) {
                      try {
                        // also delete messages box for each chat
                        final chatId = item.chatId as String?;
                        if (chatId != null && chatId.isNotEmpty) {
                          if (Hive.isBoxOpen('${Constants.chatMessagesBox}$chatId')) {
                            await Hive.box('${Constants.chatMessagesBox}$chatId').clear();
                            await Hive.box('${Constants.chatMessagesBox}$chatId').close();
                          } else {
                            final b = await Hive.openBox('${Constants.chatMessagesBox}$chatId');
                            await b.clear();
                            await b.close();
                          }
                        }
                      } catch (_) {}
                    }
                    await box.clear();
                  }
                },
              );
            },
          )
        ],
      ),
      body: Builder(builder: (context) {
  // Avoid calling Boxes.getChatHistory() if the box hasn't been opened yet.
        if (!Hive.isBoxOpen(Constants.chatHistoryBox)) {
          // If the box isn't open yet, show the empty history UI so the
          // user can still navigate. Kick off a background open on the
          // next frame so we don't return from a catchError with no value.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
            } catch (_) {}
          });
          return const EmptyHistoryWidget();
        }
        final box = Boxes.getChatHistory();

        // Try server summaries first (if user has a backend JWT). Falls back
        // to local Hive data when server not available or empty.
        _serverSummariesFuture ??= _fetchServerSummariesIfAvailable();

        return FutureBuilder<List<ChatHistory>>(
          future: _serverSummariesFuture,
          builder: (context, snapshot) {
            final serverList = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              // show local cache while waiting
              final localCache = box.values.toList().cast<ChatHistory>();
              if (localCache.isEmpty) return const EmptyHistoryWidget();
              localCache.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  itemCount: localCache.length,
                  itemBuilder: (context, index) => ChatHistoryWidget(chat: localCache[index]),
                ),
              );
            }

            if (serverList.isNotEmpty) {
              serverList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  itemCount: serverList.length,
                  itemBuilder: (context, index) => ChatHistoryWidget(chat: serverList[index]),
                ),
              );
            }

            // If server returned empty or errored, fall back to local Hive box.
            final cached = box.values.toList().cast<ChatHistory>();
            cached.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            return cached.isEmpty
                ? const EmptyHistoryWidget()
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: cached.length,
                      itemBuilder: (context, index) => ChatHistoryWidget(chat: cached[index]),
                    ),
                  );
          },
        );
      }),
    );
  }
}
