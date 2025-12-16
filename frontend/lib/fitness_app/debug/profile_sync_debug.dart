import 'package:flutter/material.dart';
import '../../services/profile_sync_service.dart';

class ProfileSyncDebugPage extends StatefulWidget {
  const ProfileSyncDebugPage({super.key});

  @override
  State<ProfileSyncDebugPage> createState() => _ProfileSyncDebugPageState();
}

class _ProfileSyncDebugPageState extends State<ProfileSyncDebugPage> {
  List<Map<String, dynamic>> items = [];

  Future<void> refresh() async {
    items = ProfileSyncService.instance.readQueue();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Sync Queue')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton(onPressed: () async { await ProfileSyncService.instance.retryQueue(); await refresh(); }, child: const Text('Retry')),
                SizedBox(width: 8),
                ElevatedButton(onPressed: () async { await ProfileSyncService.instance.clearQueue(); await refresh(); }, child: const Text('Clear')),
                SizedBox(width: 8),
                ElevatedButton(onPressed: () async { await refresh(); }, child: const Text('Refresh')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return ListTile(
                  title: Text(it['createdAt'] ?? ''),
                  subtitle: Text(it['data']?.toString() ?? ''),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
