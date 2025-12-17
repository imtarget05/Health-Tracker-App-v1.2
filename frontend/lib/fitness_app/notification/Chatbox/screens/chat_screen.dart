import 'package:flutter/material.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/providers/chat_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/utility/animated_dialog.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/widgets/bottom_chat_field.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/widgets/chat_messages.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();

      chatProvider.addListener(() {
        if (chatProvider.inChatMessages.isNotEmpty) {
          _scrollToBottom();
        }
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0.0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Trò chuyện'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Tạo cuộc hội thoại mới',
                onPressed: () async {
                  // create a new chat
                  await chatProvider.prepareChatRoom(isNewChat: true, chatID: '');
                },
              ),
              if (chatProvider.inChatMessages.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: 'Xoá cuộc hội thoại',
                  onPressed: () {
                    showMyAnimatedDialog(
                      context: context,
                      title: 'Xoá cuộc hội thoại',
                      content: 'Bạn có chắc muốn xoá cuộc hội thoại này? Hành động này sẽ xoá toàn bộ tin nhắn.',
                      actionText: 'Xoá',
                      onActionPressed: (value) async {
                        if (value) {
                          // delete the whole conversation with undo support and go back
                          await chatProvider.deleteConversationWithUndo(context: context, chatId: chatProvider.currentChatId);
                          if (mounted) Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                )
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: chatProvider.inChatMessages.isEmpty
                      ? const Center(child: Text('No messages yet'))
                      : ChatMessages(
                    scrollController: _scrollController,
                    chatProvider: chatProvider,
                  ),
                ),
                BottomChatField(chatProvider: chatProvider)
              ],
            ),
          ),
        );
      },
    );
  }
}
