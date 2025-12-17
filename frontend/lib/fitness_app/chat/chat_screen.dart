import 'package:flutter/material.dart';
import '../../services/backend_api.dart';
import '../../services/auth_storage.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _controller.clear();
      _loading = true;
    });

    try {
      final jwt = AuthStorage.token;
      final resp = await BackendApi.chat(jwt: jwt ?? '', message: text);
      final reply = resp['reply'] ?? 'Không có trả lời';
      setState(() {
        _messages.add({'role': 'assistant', 'text': reply.toString()});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Lỗi: $e'});
      });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ai Coach')),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) {
              final m = _messages[i];
              final isUser = m['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.purple.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(m['text'] ?? ''),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Hỏi Ai Coach...')),
              ),
            ),
            IconButton(icon: _loading ? const CircularProgressIndicator() : const Icon(Icons.send), onPressed: _loading ? null : _send)
          ]),
        )
      ]),
    );
  }
}
