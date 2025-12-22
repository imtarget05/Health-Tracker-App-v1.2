import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/apis/api_service.dart';
import 'package:best_flutter_ui_templates/services/backend_api.dart';
import 'package:best_flutter_ui_templates/services/auth_storage.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/constants/constants.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/boxes.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/chat_history.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/settings.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/user_model.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/models/message.dart';
import 'package:best_flutter_ui_templates/services/event_bus.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  // list of messages
  final List<Message> _inChatMessages = [];

  // page controller
  final PageController _pageController = PageController();

  // images file list
  List<XFile>? _imagesFileList = [];

  // index of the current screen
  int _currentIndex = 0;

  // cuttent chatId
  String _currentChatId = '';

  // initialize generative model
  GenerativeModel? _model;

  // itialize text model
  GenerativeModel? _textModel;

  // initialize vision model
  GenerativeModel? _visionModel;

  // current mode
  String _modelType = 'gemini-pro';

  // loading bool
  bool _isLoading = false;

  // getters
  List<Message> get inChatMessages => _inChatMessages;

  PageController get pageController => _pageController;

  List<XFile>? get imagesFileList => _imagesFileList;

  int get currentIndex => _currentIndex;

  String get currentChatId => _currentChatId;

  GenerativeModel? get model => _model;

  GenerativeModel? get textModel => _textModel;

  GenerativeModel? get visionModel => _visionModel;

  String get modelType => _modelType;

  bool get isLoading => _isLoading;

  // cache recently deleted conversations for undo
  final Map<String, Map<String, dynamic>> _recentlyDeletedConversations = {};

  // setters

  // set inChatMessages
  Future<void> setInChatMessages({required String chatId}) async {
    // Load full per-message history from the per-chat messages box.
    _inChatMessages.clear();
    try {
      final boxName = '${Constants.chatMessagesBox}$chatId';
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      final messagesBox = Hive.box(boxName);
      for (var k in messagesBox.keys) {
        final stored = messagesBox.get(k);
        try {
          if (stored != null && stored is Map) {
            final msg = Message.fromMap(Map<String, dynamic>.from(stored));
            _inChatMessages.add(msg);
          }
        } catch (_) {
          // ignore malformed entries
        }
      }
      // close the box to avoid leaving it open
      try {
        await messagesBox.close();
      } catch (_) {}
    } catch (e) {
      log('[ChatProvider] setInChatMessages load failed: $e');
    }
    notifyListeners();
  }

  // load the messages from db
  Future<List<Message>> loadMessagesFromDB({required String chatId}) async {
    final result = <Message>[];
    try {
      final boxName = '${Constants.chatMessagesBox}$chatId';
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      final messagesBox = Hive.box(boxName);
      for (var k in messagesBox.keys) {
        final stored = messagesBox.get(k);
        try {
          if (stored != null && stored is Map) {
            result.add(Message.fromMap(Map<String, dynamic>.from(stored)));
          }
        } catch (_) {}
      }
      try {
        await messagesBox.close();
      } catch (_) {}
    } catch (e) {
      log('[ChatProvider] loadMessagesFromDB failed: $e');
    }
    return result;
  }

  // set file list
  void setImagesFileList({required List<XFile> listValue}) {
    _imagesFileList = listValue;
    notifyListeners();
  }

  // set the current model
  String setCurrentModel({required String newModel}) {
    _modelType = newModel;
    notifyListeners();
    return newModel;
  }

  // function to set the model based on bool - isTextOnly
  Future<void> setModel({required bool isTextOnly}) async {
    if (isTextOnly) {
      _model = _textModel ??
          GenerativeModel(
            model: setCurrentModel(newModel: 'gemini-pro'),
            apiKey: ApiService.apiKey,
          );
    } else {
      _model = _visionModel ??
          GenerativeModel(
            model: setCurrentModel(newModel: 'gemini-pro-vision'),
            apiKey: ApiService.apiKey,
          );
    }
    notifyListeners();
  }

  // set current page index
  void setCurrentIndex({required int newIndex}) {
    _currentIndex = newIndex;
    notifyListeners();
  }

  // set current chat id
  void setCurrentChatId({required String newChatId}) {
    _currentChatId = newChatId;
    notifyListeners();
  }

  // set loading
  void setLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

//?Yeha bata copy

  // delete caht
  Future<void> deleteChatMessages({required String chatId}) async {
    // 1. check if the box is open
    if (!Hive.isBoxOpen('${Constants.chatMessagesBox}$chatId')) {
      // open the box
      await Hive.openBox('${Constants.chatMessagesBox}$chatId');

      // delete all messages in the box
      await Hive.box('${Constants.chatMessagesBox}$chatId').clear();

      // close the box
      await Hive.box('${Constants.chatMessagesBox}$chatId').close();
    } else {
      // delete all messages in the box
      await Hive.box('${Constants.chatMessagesBox}$chatId').clear();

      // close the box
      await Hive.box('${Constants.chatMessagesBox}$chatId').close();
    }

    // get the current chatId, its its not empty
    // we check if its the same as the chatId
    // if its the same we set it to empty
    if (currentChatId.isNotEmpty) {
      if (currentChatId == chatId) {
        setCurrentChatId(newChatId: '');
        _inChatMessages.clear();
        notifyListeners();
      }
    }
  }

  // edit a single message (user message) both in memory and in Hive
  Future<void> editMessage({required String chatId, required String messageId, required String newText}) async {
    // find in memory
    try {
      final target = _inChatMessages.firstWhere((m) => m.messageId == messageId && m.role == Role.user);
      target.message = StringBuffer(newText);
      notifyListeners();

      // persist: open messages box and update the map entry
      final messagesBox = await Hive.openBox('${Constants.chatMessagesBox}$chatId');
      // find the entry index by matching stored map 'messageId'
      final keys = messagesBox.keys.toList();
      for (var k in keys) {
        final stored = messagesBox.get(k);
        try {
          final storedId = stored != null && (stored is Map && stored.containsKey('messageId')) ? stored['messageId']?.toString() : null;
          if (storedId != null && storedId == messageId) {
            final updated = Map<String, dynamic>.from(stored as Map)
              ..['message'] = newText;
            await messagesBox.put(k, updated);
            break;
          }
        } catch (e) {
          // ignore malformed entries
        }
      }
      await messagesBox.close();
      // if this edited message is the last in the in-memory messages, update chat history summary
      try {
        if (_inChatMessages.isNotEmpty) {
          final last = _inChatMessages.last;
          if (last.messageId == messageId) {
            final historyBox = Boxes.getChatHistory();
            final histKeys = historyBox.keys.toList();
            for (var hk in histKeys) {
              final val = historyBox.get(hk);
              try {
                if (val != null && val.chatId == chatId) {
                  final updatedHistory = ChatHistory(
                    chatId: val.chatId,
                    prompt: val.prompt,
                    response: newText,
                    imagesUrls: val.imagesUrls,
                    timestamp: DateTime.now(),
                  );
                  await historyBox.put(hk, updatedHistory);
                  break;
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      log('[ChatProvider] editMessage failed: $e');
    }
  }

  // Edit message and optionally ask backend AI to re-analyze and return a new assistant reply
  Future<void> editMessageAndRefetchAi({required String chatId, required String messageId, required String newText, required String jwt}) async {
    // first update the message locally
    await editMessage(chatId: chatId, messageId: messageId, newText: newText);

    // prepare history for backend call
    try {
      final historyPayload = inChatMessages
          .where((m) => m.role == Role.user || m.role == Role.assistant)
          .map((m) => {
                'role': m.role == Role.user ? 'user' : 'assistant',
                'content': m.message.toString(),
              })
          .toList();

      final resp = await BackendApi.postAiChat(jwt: jwt, message: newText, history: historyPayload);
      final reply = (resp['reply'] ?? '') as String;
  final finalReply = (reply.trim().isEmpty) ? 'Sorry, I did not receive a response. Please try again.' : reply;

      // find the assistant message that follows the edited user message
      for (var i = 0; i < _inChatMessages.length; i++) {
        final m = _inChatMessages[i];
        if (m.role == Role.user && m.messageId == messageId) {
          // open messages box for persistence
          final messagesBox = await Hive.openBox('${Constants.chatMessagesBox}$chatId');

          // if there's an assistant message immediately after, update it
          if (i + 1 < _inChatMessages.length && _inChatMessages[i + 1].role == Role.assistant) {
            final assistant = _inChatMessages[i + 1];
            assistant.message = StringBuffer(finalReply);
            notifyListeners();

            // find assistant entry in box and update by messageId
            final keys = messagesBox.keys.toList();
            for (var k in keys) {
              final stored = messagesBox.get(k);
              try {
                final storedId = stored != null && (stored is Map && stored.containsKey('messageId')) ? stored['messageId']?.toString() : null;
                if (storedId != null && storedId == assistant.messageId) {
                  final updated = Map<String, dynamic>.from(stored as Map)
                    ..['message'] = finalReply;
                  await messagesBox.put(k, updated);
                  break;
                }
              } catch (_) {}
            }

            // update chat history summary
            try {
              final historyBox = Boxes.getChatHistory();
              final val = historyBox.get(chatId);
              if (val != null) {
                final updatedHistory = ChatHistory(
                  chatId: val.chatId,
                  prompt: val.prompt,
                  response: finalReply,
                  imagesUrls: val.imagesUrls,
                  timestamp: DateTime.now(),
                );
                await historyBox.put(chatId, updatedHistory);
              }
            } catch (_) {}

            await messagesBox.close();
          } else {
            // No assistant present after edited user message — create one and persist
            final newAssistantId = const Uuid().v4();
            final assistant = Message(
              messageId: newAssistantId,
              chatId: chatId,
              role: Role.assistant,
              message: StringBuffer(finalReply),
              imagesUrls: [],
              timeSent: DateTime.now(),
            );

            // insert assistant into in-memory messages right after the edited user message
            final insertIndex = (i + 1 <= _inChatMessages.length) ? i + 1 : _inChatMessages.length;
            _inChatMessages.insert(insertIndex, assistant);
            notifyListeners();

            // persist the new assistant message
            try {
              await messagesBox.add(assistant.toMap());
              // update chat history
              final historyBox = Boxes.getChatHistory();
              final val = historyBox.get(chatId);
              if (val != null) {
                final updatedHistory = ChatHistory(
                  chatId: val.chatId,
                  prompt: val.prompt,
                  response: finalReply,
                  imagesUrls: val.imagesUrls,
                  timestamp: DateTime.now(),
                );
                await historyBox.put(chatId, updatedHistory);
              } else {
                // create a new history entry
                final chatHistory = ChatHistory(
                  chatId: chatId,
                  prompt: newText,
                  response: finalReply,
                  imagesUrls: [],
                  timestamp: DateTime.now(),
                );
                await historyBox.put(chatId, chatHistory);
              }
            } catch (_) {}

            await messagesBox.close();
          }

          break;
        }
      }
    } catch (e) {
      log('[ChatProvider] editMessageAndRefetchAi failed: $e');
    }
  }

  // delete entire conversation: messages box + chat history entry
  Future<void> deleteConversation({required String chatId}) async {
    try {
      // delete messages box
      if (Hive.isBoxOpen('${Constants.chatMessagesBox}$chatId')) {
        await Hive.box('${Constants.chatMessagesBox}$chatId').clear();
        await Hive.box('${Constants.chatMessagesBox}$chatId').close();
      } else {
        final b = await Hive.openBox('${Constants.chatMessagesBox}$chatId');
        await b.clear();
        await b.close();
      }

      // remove from chat history
      final historyBox = Boxes.getChatHistory();
      final keys = historyBox.keys.toList();
      for (var k in keys) {
        final val = historyBox.get(k);
        try {
          if (val != null && val.chatId == chatId) {
            await historyBox.delete(k);
            break;
          }
        } catch (_) {}
      }

      // clear in-memory messages if current
      if (_currentChatId == chatId) {
        _inChatMessages.clear();
        _currentChatId = '';
        notifyListeners();
      }
    } catch (e) {
      log('[ChatProvider] deleteConversation failed: $e');
    }
  }

  // Delete conversation with undo support. It caches the messages and history in memory for a short time.
  Future<void> deleteConversationWithUndo({required String chatId, Duration undoDuration = const Duration(seconds: 6)}) async {
    try {
      // open messages box and read all entries
      final messagesBox = await Hive.openBox('${Constants.chatMessagesBox}$chatId');
      final cached = <dynamic>[];
      for (var k in messagesBox.keys) {
        cached.add(messagesBox.get(k));
      }

      // cache chat history
      final historyBox = Boxes.getChatHistory();
      final historyVal = historyBox.get(chatId);

      // store in the local map
      _recentlyDeletedConversations[chatId] = {
        'messages': cached,
        'history': historyVal,
      };

      // perform actual deletion
      await deleteConversation(chatId: chatId);

  // show toast with undo hint and keep cache for potential restoration
  EventBus.instance.emitInfo('Conversation deleted — you can undo for a few seconds');

      // after duration, clear cache if not undone
      Future.delayed(undoDuration, () {
        _recentlyDeletedConversations.remove(chatId);
      });
    } catch (e) {
      log('[ChatProvider] deleteConversationWithUndo failed: $e');
    }
  }

  // delete a single message (user message) both in memory and in Hive
  Future<void> deleteMessage({required String chatId, required String messageId}) async {
    try {
      _inChatMessages.removeWhere((m) => m.messageId == messageId && m.role == Role.user);
      notifyListeners();

      final messagesBox = await Hive.openBox('${Constants.chatMessagesBox}$chatId');
      final keys = messagesBox.keys.toList();
      for (var k in keys) {
        final stored = messagesBox.get(k);
        try {
          final storedId = stored != null && (stored is Map && stored.containsKey('messageId')) ? stored['messageId']?.toString() : null;
          if (storedId != null && storedId == messageId) {
            await messagesBox.delete(k);
            break;
          }
        } catch (e) {
          // ignore malformed entries
        }
      }
      await messagesBox.close();
    } catch (e) {
      log('[ChatProvider] deleteMessage failed: $e');
    }
  }

  // prepare chat room
  Future<void> prepareChatRoom({
    required bool isNewChat,
    required String chatID,
  }) async {
    if (!isNewChat) {
      // Load only the chat summary (prompt + reply) from the ChatHistory box.
      _inChatMessages.clear();
      try {
        if (!Hive.isBoxOpen(Constants.chatHistoryBox)) {
          await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
        }
        final historyBox = Boxes.getChatHistory();
        final val = historyBox.get(chatID);
        if (val != null) {
          final userMessage = Message(
            messageId: '${chatID}_u',
            chatId: chatID,
            role: Role.user,
            message: StringBuffer(val.prompt),
            imagesUrls: val.imagesUrls,
            timeSent: val.timestamp,
          );
          final assistantMessage = Message(
            messageId: '${chatID}_a',
            chatId: chatID,
            role: Role.assistant,
            message: StringBuffer(val.response),
            imagesUrls: val.imagesUrls,
            timeSent: val.timestamp,
          );
          _inChatMessages.add(userMessage);
          _inChatMessages.add(assistantMessage);
        }
      } catch (e) {
        log('[ChatProvider] prepareChatRoom load summary failed: $e');
      }

      setCurrentChatId(newChatId: chatID);
      return;
    } else {
      // new chat: clear messages and set id
      _inChatMessages.clear();
      setCurrentChatId(newChatId: chatID);
      return;
    }
  }

  // send a message (user action) to AI
  Future<void> sentMessage({
    required String message,
    required bool isTextOnly,
  }) async {
    // set the model
    await setModel(isTextOnly: isTextOnly);

    // set loading
    setLoading(value: true);

    // get the chatId
    String chatId = getChatId();

  // Diagnostic: log the outgoing message to help verify Unicode/diacritics preserved
  log('[ChatProvider] sending message (len=${message.length}): $message');

    // list of history messahes
    List<Content> history = [];

    // get the chat history
    history = await getHistory(chatId: chatId);

    // get the imagesUrls
    List<String> imagesUrls = getImagesUrls(isTextOnly: isTextOnly);

//??Copy
    // open the messages box
    final messagesBox =
        await Hive.openBox('${Constants.chatMessagesBox}$chatId');

    // get the last user message id
    final userMessageId = messagesBox.keys.length;

    // assistant messageId
    final assistantMessageId = messagesBox.keys.length + 1;

// ?yeha samma

    // user message
    final userMessage = Message(
      messageId: userMessageId.toString(),
      chatId: chatId,
      role: Role.user,
      message: StringBuffer(message),
      imagesUrls: imagesUrls,
      timeSent: DateTime.now(),
    );

    // add this message to the list on inChatMessages
    _inChatMessages.add(userMessage);
    notifyListeners();

    if (currentChatId.isEmpty) {
      setCurrentChatId(newChatId: chatId);
    }

    // prepare assistant placeholder message so UI shows a reply in progress
    final assistantMessage = userMessage.copyWith(
      messageId: assistantMessageId.toString(),
      role: Role.assistant,
      message: StringBuffer(),
      timeSent: DateTime.now(),
    );
    _inChatMessages.add(assistantMessage);
    notifyListeners();

    // If backend JWT available, forward to backend AI endpoint for personalized reply
    try {
      final jwt = AuthStorage.token; // read backend JWT from AuthStorage
      if (jwt != null && jwt.isNotEmpty) {
        // build a simple history payload: list of { role, content }
        final historyPayload = inChatMessages
            .where((m) => m.role == Role.user || m.role == Role.assistant)
            .map((m) => {
                  'role': m.role == Role.user ? 'user' : 'assistant',
                  'content': m.message.toString(),
                })
            .toList();

        // call backend
        log('[ChatProvider] calling backend /ai/chat with message: ${message.length > 80 ? message.substring(0, 80) : message}');
        final resp = await BackendApi.postAiChat(jwt: jwt, message: message, history: historyPayload);
        final reply = (resp['reply'] ?? '') as String;
        log('[ChatProvider] backend reply length=${reply.length}');

        // Defensive: if backend returned empty reply, show fallback message
        final finalReply = (reply.trim().isEmpty) ? 'Xin lỗi, tôi chưa nhận được phản hồi. Vui lòng thử lại.' : reply;

        // write reply into assistant placeholder
        try {
          final target = _inChatMessages.firstWhere((element) => element.messageId == assistantMessage.messageId && element.role == Role.assistant);
          target.message = StringBuffer(finalReply);
        } catch (e) {
          log('[ChatProvider] failed to write assistant reply into inChatMessages: $e');
        }
        notifyListeners();

        // persist messages
        await saveMessagesToDB(
          chatID: chatId,
          userMessage: userMessage,
          assistantMessage: assistantMessage.copyWith(message: StringBuffer(finalReply)),
          messagesBox: messagesBox,
        );

        setLoading(value: false);
        return;
      }
    } catch (e) {
      log('[ChatProvider] backend call failed: $e');
      // ignore and fallback to local model streaming
    }

    // fallback: use existing local model streaming flow
    await sendMessageAndWaitForResponse(
      message: message,
      chatId: chatId,
      isTextOnly: isTextOnly,
      history: history,
      userMessage: userMessage,
      modelMessageId: assistantMessageId.toString(),
      messagesBox: messagesBox,
    );
  }

  // send message to the model and wait for the response
  Future<void> sendMessageAndWaitForResponse({
    required String message,
    required String chatId,
    required bool isTextOnly,
    required List<Content> history,
    required Message userMessage,
    required String modelMessageId, // ? Add this line
    required Box messagesBox,
  }) async {
    // start the chat session - only send history is its text-only
    final chatSession = _model!.startChat(
      history: history.isEmpty || !isTextOnly ? null : history,
    );

    // get content
    final content = await getContent(
      message: message,
      isTextOnly: isTextOnly,
    );

    // assistant message: if a placeholder already exists (created earlier), reuse it
    Message assistantMessage;
    try {
      assistantMessage = _inChatMessages.firstWhere((element) => element.messageId == modelMessageId && element.role == Role.assistant);
    } catch (_) {
      assistantMessage = userMessage.copyWith(
        messageId: modelMessageId,
        role: Role.assistant,
        message: StringBuffer(),
        timeSent: DateTime.now(),
      );
      // add this message to the list on inChatMessages
      _inChatMessages.add(assistantMessage);
      notifyListeners();
    }

    // wait for stream response
    chatSession.sendMessageStream(content).asyncMap((event) {
      return event;
    }).listen((event) {
      _inChatMessages
          .firstWhere((element) =>
              element.messageId == assistantMessage.messageId &&
              element.role.name == Role.assistant.name)
          .message
          .write(event.text);
      log('event: ${event.text}');
      notifyListeners();
    }, onDone: () async {
      log('stream done');
      // save message to hive db
      await saveMessagesToDB(
        chatID: chatId,
        userMessage: userMessage,
        assistantMessage: assistantMessage,
        messagesBox: messagesBox,
      );
      // set loading to false
      setLoading(value: false);
    }).onError((erro, stackTrace) {
      log('error: $erro');
      // set loading
      setLoading(value: false);
    });

    // If assistant message is still empty after streaming, log fallback for diagnostics
    if (assistantMessage.message.toString().trim().isEmpty) {
      log('[ChatProvider] assistant message empty after streaming - possible empty backend reply or streaming failure');
    }
  }

  // save messages to hive db
  Future<void> saveMessagesToDB({
    required String chatID,
    required Message userMessage,
    required Message assistantMessage,
    required Box messagesBox,
  }) async {
    // Per-message storage was disabled. Persist only the chat summary to
    // the shared ChatHistory box so each conversation appears as a single
    // summary row and is moved to top when updated.
    Box chatHistoryBox;
    if (!Hive.isBoxOpen(Constants.chatHistoryBox)) {
      chatHistoryBox = await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
    } else {
      chatHistoryBox = Boxes.getChatHistory();
    }

    final chatHistory = ChatHistory(
      chatId: chatID,
      prompt: userMessage.message.toString(),
      response: assistantMessage.message.toString(),
      imagesUrls: userMessage.imagesUrls,
      timestamp: DateTime.now(),
    );
    // Persist summary
    await chatHistoryBox.put(chatID, chatHistory);

    // Persist full per-message history into a per-chat messages box.
    try {
      final boxName = '${Constants.chatMessagesBox}$chatID';
      Box messagesBox;
      if (!Hive.isBoxOpen(boxName)) {
        messagesBox = await Hive.openBox(boxName);
      } else {
        messagesBox = Hive.box(boxName);
      }

      // clear existing entries (best-effort) and write current in-memory messages
      try {
        await messagesBox.clear();
      } catch (_) {}

      final source = _inChatMessages.isNotEmpty ? _inChatMessages : [userMessage, assistantMessage];
      for (var m in source) {
        try {
          await messagesBox.add(m.toMap());
        } catch (_) {}
      }

      try {
        await messagesBox.close();
      } catch (_) {}
    } catch (e) {
      log('[ChatProvider] saveMessagesToDB per-chat persist failed: $e');
    }

    // Close per-chat messages box if caller opened it previously.
    try {
      if (Hive.isBoxOpen('${Constants.chatMessagesBox}$chatID')) {
        await Hive.box('${Constants.chatMessagesBox}$chatID').close();
      }
    } catch (_) {}
  }

  // save a chat summary (prompt + response) to ChatHistory box only
  Future<void> saveChatSummaryToDB({
    required String chatID,
    required String prompt,
    required String response,
    required List<String> imagesUrls,
  }) async {
    Box chatHistoryBox;
    if (!Hive.isBoxOpen(Constants.chatHistoryBox)) {
      chatHistoryBox = await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
    } else {
      chatHistoryBox = Boxes.getChatHistory();
    }

    final chatHistory = ChatHistory(
      chatId: chatID,
      prompt: prompt,
      response: response,
      imagesUrls: imagesUrls,
      timestamp: DateTime.now(),
    );

    await chatHistoryBox.put(chatID, chatHistory);

    // Best-effort: if backend JWT is available, also persist summary server-side
    try {
      final jwt = AuthStorage.token;
      if (jwt != null && jwt.isNotEmpty) {
        await BackendApi.postAiSummary(
          jwt: jwt,
          chatId: chatID,
          prompt: prompt,
          response: response,
          imagesUrls: imagesUrls,
        );
      }
    } catch (e) {
      // ignore any network errors - local persistence is the primary source
      log('[ChatProvider] postAiSummary failed: $e');
    }
  }

  Future<Content> getContent({
    required String message,
    required bool isTextOnly,
  }) async {
    if (isTextOnly) {
      // generate text from text-only input
      return Content.text(message);
    } else {
      // generate image from text and image input
      final imageFutures = _imagesFileList
          ?.map((imageFile) => imageFile.readAsBytes())
          .toList(growable: false);

      final imageBytes = await Future.wait(imageFutures!);
      final prompt = TextPart(message);
      final imageParts = imageBytes
          .map((bytes) => DataPart('image/jpeg', Uint8List.fromList(bytes)))
          .toList();

      return Content.multi([prompt, ...imageParts]);
    }
  }

  // get y=the imagesUrls
  List<String> getImagesUrls({
    required bool isTextOnly,
  }) {
    List<String> imagesUrls = [];
    if (!isTextOnly && imagesFileList != null) {
      for (var image in imagesFileList!) {
        imagesUrls.add(image.path);
      }
    }
    return imagesUrls;
  }

  Future<List<Content>> getHistory({required String chatId}) async {
    List<Content> history = [];
    if (currentChatId.isNotEmpty) {
      await setInChatMessages(chatId: chatId);

      for (var message in inChatMessages) {
        if (message.role == Role.user) {
          history.add(Content.text(message.message.toString()));
        } else {
          history.add(Content.model([TextPart(message.message.toString())]));
        }
      }
    }

    return history;
  }

  String getChatId() {
    if (currentChatId.isEmpty) {
      return const Uuid().v4();
    } else {
      return currentChatId;
    }
  }

  // init Hive box
  static Future<void> initHive() async {
    final dir = await path.getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await Hive.initFlutter(Constants.geminiDB);

    // register adapters and ensure boxes are open. Use try/catch per step
    try {
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ChatHistoryAdapter());
      try {
        if (!Hive.isBoxOpen(Constants.chatHistoryBox)) {
          await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
        }
      } catch (e) {
        // box corrupted or incompatible; delete and recreate
        try {
          await Hive.deleteBoxFromDisk(Constants.chatHistoryBox);
        } catch (_) {}
        try {
          await Hive.openBox<ChatHistory>(Constants.chatHistoryBox);
        } catch (e2) {
          debugPrint('ChatProvider: chatHistory open failed after delete: $e2');
        }
      }
      } catch (e) {
        // continue even if chat history adapter/open fails
        debugPrint('ChatProvider: chatHistory init failed: $e');
      }

    try {
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(UserModelAdapter());
      try {
        if (!Hive.isBoxOpen(Constants.userBox)) {
          await Hive.openBox<UserModel>(Constants.userBox);
        }
      } catch (e) {
        try {
          await Hive.deleteBoxFromDisk(Constants.userBox);
        } catch (_) {}
        try {
          await Hive.openBox<UserModel>(Constants.userBox);
        } catch (e2) {
          debugPrint('ChatProvider: userBox open failed after delete: $e2');
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: userBox init failed: $e');
    }

    try {
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SettingsAdapter());
      try {
        if (!Hive.isBoxOpen(Constants.settingsBox)) {
          await Hive.openBox<Settings>(Constants.settingsBox);
        }
      } catch (e) {
        try {
          await Hive.deleteBoxFromDisk(Constants.settingsBox);
        } catch (_) {}
        try {
          await Hive.openBox<Settings>(Constants.settingsBox);
        } catch (e2) {
          debugPrint('ChatProvider: settingsBox open failed after delete: $e2');
        }
      }
    } catch (e) {
      debugPrint('ChatProvider: settingsBox init failed: $e');
    }
  }
}
