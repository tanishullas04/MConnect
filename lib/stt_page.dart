import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class STTPage extends StatefulWidget {
  const STTPage({super.key});

  @override
  State<STTPage> createState() => _STTPageState();
}

class _STTPageState extends State<STTPage> {
  bool _isListening = false;
  bool _isLoading = false;
  String _transcribedText = "";
  String? _error;
  String _selectedLanguage = 'en';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkAPIStatus();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    if (_isListening) {
      _stopListening();
    }
    super.dispose();
  }

  Future<void> _checkAPIStatus() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5002/stt/status'));
      if (response.statusCode == 200) {
        print('✅ STT API is running and ready');
      }
    } catch (e) {
      print('❌ STT API not running. Please start it manually');
      setState(() {
        _error = 'STT API not running. Please start the Flask server first.';
      });
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5002/stt/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'language': _selectedLanguage}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isListening = true;
          _isLoading = false;
          _transcribedText = "";
        });

        // Start polling for status updates
        _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _getPartialText();
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _error = errorData['error'] ?? 'Failed to start listening';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _isLoading = true;
    });

    _statusTimer?.cancel();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5002/stt/stop'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _isListening = false;
          _isLoading = false;
          _transcribedText = responseData['text'] ?? _transcribedText;
        });

        if (_transcribedText.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech transcription completed!')),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _error = errorData['error'] ?? 'Failed to stop listening';
          _isLoading = false;
          _isListening = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isListening = false;
      });
    }
  }

  Future<void> _getPartialText() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5002/stt/status'));
      if (response.statusCode == 200) {
        final statusData = jsonDecode(response.body);
        if (mounted && _isListening) {
          setState(() {
            _transcribedText = statusData['partial_text'] ?? _transcribedText;
          });
        }
      }
    } catch (e) {
      // Ignore errors during polling
    }
  }

  void _clearText() {
    setState(() {
      _transcribedText = "";
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8CDE0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8CDE0),
        elevation: 0,
        title: const Text("STT", style: TextStyle(color: Color(0xFF2E0854))),
        iconTheme: const IconThemeData(color: Color(0xFF2E0854)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Microphone Icon with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red.shade100 : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: _isListening ? Colors.red.withOpacity(0.3) : Colors.black.withOpacity(0.1),
                      blurRadius: _isListening ? 20 : 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 60,
                  color: _isListening ? Colors.red : const Color(0xFF2E0854),
                ),
              ),
              const SizedBox(height: 20),
              
              // Language Selection
              DropdownButton<String>(
                value: _selectedLanguage,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                ],
                onChanged: _isListening ? null : (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              
              // Status Text
              Text(
                _isListening ? "Listening..." : "Ready to listen",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _isListening ? Colors.red : const Color(0xFF2E0854),
                ),
              ),
              const SizedBox(height: 30),
              
              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : (_isListening ? _stopListening : _startListening),
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isListening ? Icons.stop : Icons.mic),
                    label: Text(_isListening ? 'Stop' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.red : Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _transcribedText.isEmpty ? null : _clearText,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Error Message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Transcribed Text
              if (_transcribedText.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_fields, color: Color(0xFF2E0854)),
                          const SizedBox(width: 8),
                          const Text(
                            'Transcribed Text:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E0854),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _transcribedText,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
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
