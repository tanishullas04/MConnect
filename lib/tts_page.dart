import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TTSPage extends StatefulWidget {
  const TTSPage({super.key});

  @override
  State<TTSPage> createState() => _TTSPageState();
}

class _TTSPageState extends State<TTSPage> {
  final TextEditingController _controller = TextEditingController();
  String _selectedLang = 'en';
  bool _isLoading = false;
  String? _error;
  String? _translatedText;

  @override
  void initState() {
    super.initState();
    _checkAPIStatus();
  }

  Future<void> _checkAPIStatus() async {
    // Just check if API is running and show status
    try {
      await http.get(Uri.parse('http://localhost:5001/'));
      print('✅ API is running and ready');
    } catch (e) {
      print('❌ API not running. Please start it manually: python tts_api.py');
      setState(() {
        _error = 'API not running. Please start the Flask server first.';
      });
    }
  }

  Future<void> _sendTTSRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _translatedText = null;
    });
    final url = Uri.parse('http://localhost:5001/tts');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': _controller.text,
          'lang': _selectedLang,
          'translate': _selectedLang != 'en', // Auto-enable translation for non-English
        }),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _translatedText = responseData['translated_text'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech played successfully!')),
        );
      } else {
        setState(() {
          _error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8CDE0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8CDE0),
        elevation: 0,
        title: const Text("TTS", style: TextStyle(color: Color(0xFF2E0854))),
        iconTheme: const IconThemeData(color: Color(0xFF2E0854)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Enter text to speak',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: _selectedLang,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedLang = val!;
                  });
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendTTSRequest,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Speak'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_translatedText != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Translated Text:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_translatedText!),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
