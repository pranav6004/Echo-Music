import 'package:flutter/material.dart';

import '../../data/settings.dart';
import '../../services/ai_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late TextEditingController _keyCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _endpointCtrl;
  bool _obscureKey = true;
  bool _testing = false;

  final _providers = const [
    ('openrouter', 'OpenRouter (Recommended)'),
    ('openai', 'OpenAI'),
    ('anthropic', 'Anthropic Claude'),
    ('gemini', 'Google Gemini'),
    ('groq', 'Groq (Ultra Fast)'),
    ('mistral', 'Mistral AI'),
    ('custom', 'Custom Endpoint / Local LLM'),
  ];

  @override
  void initState() {
    super.initState();
    final s = Settings.instance;
    _keyCtrl = TextEditingController(text: s.aiApiKey);
    _modelCtrl = TextEditingController(text: s.aiModel);
    _endpointCtrl = TextEditingController(text: s.aiCustomEndpoint);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final s = Settings.instance;
    s.aiApiKey = _keyCtrl.text.trim();
    s.aiModel = _modelCtrl.text.trim();
    s.aiCustomEndpoint = _endpointCtrl.text.trim();
  }

  Future<void> _testConnection() async {
    _save();
    setState(() => _testing = true);

    final res = await AiService.instance.testConnection();

    if (mounted) {
      setState(() => _testing = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            res.success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: res.success ? Colors.green : Colors.red,
            size: 36,
          ),
          title: Text(res.success ? 'Connection Successful' : 'Connection Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(res.message),
              const SizedBox(height: 12),
              if (res.success) ...[
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Text('Latency: ${res.latencyMs} ms'),
                  ],
                ),
                if (res.model != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.memory_rounded, size: 16, color: Colors.purpleAccent),
                      const SizedBox(width: 6),
                      Text('Model: ${res.model}'),
                    ],
                  ),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = Settings.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Hub Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // Hero card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.5),
                      scheme.surfaceContainerLow,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LLM & Multi-AI Engine',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure your AI API keys for smart playlist generation, mood editing, and real-time lyrics translation.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Provider Selector
              DropdownButtonFormField<String>(
                value: s.aiProvider,
                decoration: InputDecoration(
                  labelText: 'AI Provider',
                  prefixIcon: const Icon(Icons.psychology_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _providers
                    .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      s.aiProvider = val;
                      final def = AiService.defaultModels[val];
                      if (def != null && def.isNotEmpty) {
                        _modelCtrl.text = def;
                        s.aiModel = def;
                      }
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              // Custom Endpoint (if provider == custom)
              if (s.aiProvider == 'custom') ...[
                TextField(
                  controller: _endpointCtrl,
                  decoration: InputDecoration(
                    labelText: 'Custom Endpoint URL',
                    hintText: 'http://localhost:20128/v1/chat/completions',
                    prefixIcon: const Icon(Icons.lan_rounded),
                    helperText: 'Completion endpoint will be auto-normalized',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => _save(),
                ),
                const SizedBox(height: 16),
              ],

              // Model Name
              TextField(
                controller: _modelCtrl,
                decoration: InputDecoration(
                  labelText: 'Model Identifier',
                  hintText: 'e.g. google/gemini-2.0-flash-exp:free',
                  prefixIcon: const Icon(Icons.memory_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _save(),
              ),

              const SizedBox(height: 16),

              // API Key
              TextField(
                controller: _keyCtrl,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: s.aiProvider == 'custom' ? 'Optional for local endpoints' : 'Paste API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _save(),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  FilledButton.icon(
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Test Connection'),
                    onPressed: _testing ? null : _testConnection,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
