import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/settings_provider.dart';

class GatewaySettingsScreen extends ConsumerStatefulWidget {
  const GatewaySettingsScreen({super.key});

  @override
  ConsumerState<GatewaySettingsScreen> createState() => _GatewaySettingsScreenState();
}

class _GatewaySettingsScreenState extends ConsumerState<GatewaySettingsScreen> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _tokenCtrl;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _urlCtrl = TextEditingController(text: settings.ssoGatewayUrl);
    _tokenCtrl = TextEditingController(
      text: settings.ssoApiToken.isEmpty ? 'dont_use_please' : settings.ssoApiToken,
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(settingsProvider.notifier).updateSsoGatewayUrl(_urlCtrl.text.trim());
    ref.read(settingsProvider.notifier).updateSsoApiToken(_tokenCtrl.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gateway configuration saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gateway & Proxy'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gateway URL',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bearer Token',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenCtrl,
                    decoration: InputDecoration(
                      hintText: 'Authorization token',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Configuration'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
