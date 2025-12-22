import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/hive/chat_history.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/providers/chat_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/utility/animated_dialog.dart';
import 'package:best_flutter_ui_templates/services/auth_storage.dart';
import 'package:best_flutter_ui_templates/services/backend_api.dart';
import 'package:provider/provider.dart';

class ChatHistoryWidget extends StatelessWidget {
  const ChatHistoryWidget({
    super.key,
    required this.chat,
  });

  final ChatHistory chat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () async {
          final chatProvider = context.read<ChatProvider>();
          await chatProvider.prepareChatRoom(isNewChat: false, chatID: chat.chatId);
          chatProvider.setCurrentIndex(newIndex: 1);
          chatProvider.pageController.jumpToPage(1);
        },
        onLongPress: () {
          showMyAnimatedDialog(
            context: context,
            title: 'Delete Chat',
            content: 'Are you sure you want to delete this chat?',
            actionText: 'Delete',
            onActionPressed: (value) async {
              if (value) {
                // delete local messages and Hive entry
                await context.read<ChatProvider>().deleteChatMessages(chatId: chat.chatId);
                try {
                  final jwt = AuthStorage.token;
                  if (jwt != null && jwt.isNotEmpty) {
                    await BackendApi.deleteAiSummary(jwt: jwt, chatId: chat.chatId);
                  }
                } catch (e) {
                  // ignore network failures
                }
                await chat.delete();
              }
            },
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.04 * 255).round()),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E9FF), // light purple background
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.chat_bubble_2,
                      color: Color(0xFF7B3FE4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.prompt.trim().isEmpty ? '(Không có nội dung)' : chat.prompt.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // timestamp (ChatHistory.timestamp is non-nullable)
                          Text(
                            // show short date/time
                            '${chat.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${chat.timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        chat.response.trim().isEmpty ? '' : chat.response.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withAlpha((0.2 * 255).round())),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
