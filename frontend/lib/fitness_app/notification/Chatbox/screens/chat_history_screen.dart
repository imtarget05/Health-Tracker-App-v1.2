import 'package:flutter/material.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/utility/animated_dialog.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/constants/constants.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/boxes.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/chat_history.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/widgets/chat_history_widget.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/widgets/empty_history_widget.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        centerTitle: true,
        title: const Text('Lịch sử chat'),
        actions: [
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
      body: ValueListenableBuilder<Box<ChatHistory>>(
        valueListenable: Boxes.getChatHistory().listenable(),
        builder: (context, box, _) {
          final chatHistory =
              box.values.toList().cast<ChatHistory>().reversed.toList();
          return chatHistory.isEmpty
              ? const EmptyHistoryWidget()
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: chatHistory.length,
                    itemBuilder: (context, index) {
                      final chat = chatHistory[index];
                      return ChatHistoryWidget(chat: chat);
                    },
                  ),
                );
        },
      ),
    );
  }
}
