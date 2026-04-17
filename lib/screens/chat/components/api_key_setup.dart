import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/groq_service.dart';
import '../../../theme/app_theme.dart';

/// API Key Setup modal for configuring AI providers
class ApiKeySetup extends StatefulWidget {
  final bool isChange;
  final VoidCallback onSaved;
  
  const ApiKeySetup({
    super.key,
    required this.isChange,
    required this.onSaved,
  });

  @override
  State<ApiKeySetup> createState() => ApiKeySetupState();
}

class ApiKeySetupState extends State<ApiKeySetup> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  AiProvider _provider = AiProvider.groq;
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    AiService.getProvider().then((p) async {
      final model = await AiService.getModel(p);
      if (mounted) setState(() { _provider = p; _selectedModel = model; });
    });
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter your API key');
      return;
    }
    if (!key.startsWith(_provider.keyPrefix)) {
      setState(() => _error = '${_provider.label} keys start with "${_provider.keyPrefix}"');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await AiService.saveApiKey(key, _provider);
    if (_selectedModel != null) {
      await AiService.setModel(_selectedModel!, _provider);
    }
    widget.onSaved();
  }

  Future<void> _clearKey() async {
    await AiService.clearApiKey(_provider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: AppTheme.emerald),
            const SizedBox(width: 8),
            const Text('Setup AI Assistant',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          const SizedBox(height: 16),

          // Provider selector
          const Text('Choose AI Provider:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ProviderCard(
                provider: AiProvider.groq,
                selected: _provider == AiProvider.groq,
                onTap: () async {
                  final model = await AiService.getModel(AiProvider.groq);
                  setState(() {
                    _provider = AiProvider.groq;
                    _selectedModel = model;
                    _ctrl.clear();
                    _error = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ProviderCard(
                provider: AiProvider.gemini,
                selected: _provider == AiProvider.gemini,
                onTap: () async {
                  final model = await AiService.getModel(AiProvider.gemini);
                  setState(() {
                    _provider = AiProvider.gemini;
                    _selectedModel = model;
                    _ctrl.clear();
                    _error = null;
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Model selector
          const Text('Model:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedModel ?? _provider.defaultModel,
            decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder()),
            items: _provider.models.map((m) => DropdownMenuItem(
              value: m.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(m.description,
                      style: TextStyle(
                          fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedModel = v),
          ),
          const SizedBox(height: 12),

          // Instructions
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                const TextSpan(text: '1. Go to '),
                TextSpan(
                  text: _provider.setupUrl.replaceFirst('https://', ''),
                  style: const TextStyle(
                      color: AppTheme.emerald,
                      decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                        Uri.parse(_provider.setupUrl),
                        mode: LaunchMode.externalApplication),
                ),
                const TextSpan(text: '\n2. Sign up / Log in\n3. Create a free API key\n4. Paste it below'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '${_provider.label} API Key',
              hintText: _provider.hint,
              border: const OutlineInputBorder(),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(children: [
            if (widget.isChange)
              TextButton.icon(
                onPressed: _clearKey,
                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error, size: 16),
                label: Text('Remove Key',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const Spacer(),
            if (!widget.isChange)
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                  : const Text('Save & Enable AI'),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Provider selection card widget
class ProviderCard extends StatelessWidget {
  final AiProvider provider;
  final bool selected;
  final VoidCallback onTap;
  
  const ProviderCard({
    super.key,
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.tertiary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                provider == AiProvider.groq ? '⚡' : '✨',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
              Text(provider.label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurface.withOpacity(0.87))),
            ]),
            const SizedBox(height: 4),
            Text(provider.description,
                style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}
