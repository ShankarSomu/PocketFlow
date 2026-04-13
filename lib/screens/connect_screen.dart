import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_server.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _running = false;
  String? _ip;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final ip = await NetworkInfo().getWifiIP();
    setState(() => _ip = ip);
  }

  Future<void> _toggle() async {
    if (_running) {
      await ApiServer.stop();
      await WakelockPlus.disable();
    } else {
      await ApiServer.start();
      await WakelockPlus.enable(); // keep screen on while serving
      await _loadIp();
    }
    setState(() => _running = !_running);
  }

  String get _baseUrl => 'http://${_ip ?? '...'}:${ApiServer.port}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusCard(running: _running, url: _baseUrl, onToggle: _toggle),
          const SizedBox(height: 20),
          if (_running && _ip != null) ...[
            _QrCard(url: _baseUrl),
            const SizedBox(height: 20),
          ],
          _EndpointDocs(baseUrl: _baseUrl),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool running;
  final String url;
  final VoidCallback onToggle;

  const _StatusCard({required this.running, required this.url, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.circle, size: 12, color: running ? Colors.green : Colors.grey),
            const SizedBox(width: 8),
            Text(running ? 'Server Running' : 'Server Stopped',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          if (running) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(url, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('URL copied')));
                },
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Make sure your AI app is on the same WiFi network.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onToggle,
            icon: Icon(running ? Icons.stop : Icons.play_arrow),
            label: Text(running ? 'Stop Server' : 'Start Server'),
            style: FilledButton.styleFrom(
              backgroundColor: running ? Colors.red : Colors.green,
            ),
          ),
        ]),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String url;
  const _QrCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('Scan to connect', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          QrImageView(data: url, size: 180),
          const SizedBox(height: 8),
          const Text('Point your AI app\'s connector setup at this URL',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _EndpointDocs extends StatelessWidget {
  final String baseUrl;
  const _EndpointDocs({required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final endpoints = [
      ('GET', '/health', 'Check server status'),
      ('GET', '/summary', 'Monthly income, expenses, net, savings'),
      ('GET', '/transactions', 'List transactions\n?type=expense|income\n?from=YYYY-MM-DD&to=YYYY-MM-DD\n?keyword=groceries'),
      ('POST', '/transactions', 'Add transaction\n{"type","amount","category","note","date"}'),
      ('GET', '/budgets', 'List budgets with spent/remaining\n?month=1&year=2025'),
      ('POST', '/budgets', 'Set budget\n{"category","limit"}'),
      ('GET', '/savings', 'List savings goals with progress'),
      ('POST', '/savings', 'Create goal\n{"name","target"}'),
      ('POST', '/savings/:name/contribute', 'Add to goal\n{"amount"}'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('API Endpoints',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...endpoints.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: e.$1 == 'GET' ? Colors.blue.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(e.$1,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: e.$1 == 'GET' ? Colors.blue : Colors.green)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$baseUrl${e.$2}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Text(e.$3,
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ]),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
