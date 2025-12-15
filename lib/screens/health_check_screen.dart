import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/backend_api.dart';

class HealthCheckScreen extends StatefulWidget {
  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  String _result = 'Idle';
  bool _loading = false;

  Future<void> _runHealthCheck() async {
    setState(() {
      _loading = true;
      _result = 'Checking... (baseUrl=${dotenv.env['BASE_API_URL'] ?? 'default'})';
    });

    try {
      final res = await BackendApi.healthCheck();
      setState(() {
        _result = res.toString();
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Backend Health Check')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _runHealthCheck,
              child: _loading ? CircularProgressIndicator() : Text('Run Health Check'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
