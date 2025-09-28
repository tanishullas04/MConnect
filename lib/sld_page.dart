import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

class SLDPage extends StatefulWidget {
  const SLDPage({super.key});

  @override
  State<SLDPage> createState() => _SLDPageState();
}

class _SLDPageState extends State<SLDPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  String _detectedText = 'Tap "Test API Connection" or "Start Detection" to begin...';
  Timer? _detectionTimer;
  bool _isDetectionActive = false;
  
  // API Configuration - Using localhost with fallback to demo mode
  static const String _apiBaseUrl = 'http://localhost:8003';
  static const bool _useDemoMode = false; // Set to true for demo mode

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        
        await _cameraController!.initialize();
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        _showErrorDialog('Camera initialization failed: $e');
      }
    }
  }

  Future<void> _startDetection() async {
    if (!_isCameraInitialized || _isDetectionActive) return;
    
    setState(() {
      _isDetectionActive = true;
      _detectedText = 'Starting detection...';
    });

    // Start periodic detection every 1 second
    _detectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDetectionActive && !_isDetecting) {
        _captureAndDetect();
      }
    });
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _detectedText = 'Testing API connection...';
    });

    // Demo mode for testing without API
    if (_useDemoMode) {
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _detectedText = 'Demo Mode Active!\nAPI: Mock Success\nModel: Loaded (Demo)\nSign Language Detection Ready!';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/health'),
        headers: {
          'Access-Control-Allow-Origin': '*',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _detectedText = 'API Connection Success!\n${result.toString()}';
        });
      } else {
        setState(() {
          _detectedText = 'API Connection Failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _detectedText = 'API Connection Error: $e\n\nMake sure Python API is running on $_apiBaseUrl';
      });
    }
  }

  Future<void> _stopDetection() async {
    setState(() {
      _isDetectionActive = false;
    });
    
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  Future<void> _captureAndDetect() async {
    if (!_isCameraInitialized || _isDetecting) return;

    setState(() {
      _isDetecting = true;
    });

    try {
      // Demo mode with mock responses
      if (_useDemoMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Simulate different detection results
        final demoResponses = [
          'Hello',
          'Thank You',
          'Good Morning',
          'How Are You',
          'Nice to Meet You',
          'Please',
          'Sorry',
          'Yes',
          'No',
        ];
        
        final randomResponse = demoResponses[DateTime.now().millisecondsSinceEpoch % demoResponses.length];
        
        setState(() {
          _detectedText = '$randomResponse (Demo Mode)';
        });
        return;
      }

      final XFile image = await _cameraController!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();
      
      // Convert image to base64
      final String base64Image = base64Encode(imageBytes);
      
      // Send to API for detection
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/detect'),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        },
        body: jsonEncode({
          'image': 'data:image/jpeg;base64,$base64Image',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        
        setState(() {
          _detectedText = result['text'] ?? 'No signs detected';
          
          if (_detectedText.isEmpty) {
            _detectedText = 'No signs detected';
          }
        });
      } else {
        setState(() {
          _detectedText = 'Detection failed: ${response.statusCode}\nResponse: ${response.body}';
        });
      }
    } on http.ClientException catch (e) {
      setState(() {
        _detectedText = 'Network Error: $e\n\nMake sure the Python API is running on $_apiBaseUrl';
      });
    } catch (e) {
      setState(() {
        _detectedText = 'Error: $e';
      });
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopDetection();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8CDE0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8CDE0),
        elevation: 0,
        title: Text(
          "Sign Language Detection ${_useDemoMode ? '(Demo Mode)' : '(Live API)'}", 
          style: const TextStyle(color: Color(0xFF2E0854))
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E0854)),
      ),
      body: Column(
        children: [
          // Camera Preview Section
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2E0854), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildCameraPreview(),
              ),
            ),
          ),
          
          // Detection Results Section
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2E0854), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detected Signs:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E0854),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _detectedText,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF2E0854),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_isDetecting)
                    const LinearProgressIndicator(
                      backgroundColor: Color(0xFFD8CDE0),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E0854)),
                    ),
                ],
              ),
            ),
          ),
          
          // Control Buttons Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isCameraInitialized && !_isDetectionActive 
                          ? _startDetection 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E0854),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Detection'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isDetectionActive ? _stopDetection : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Detection'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: !_isDetectionActive ? _testApiConnection : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  icon: const Icon(Icons.network_check),
                  label: const Text('Test API Connection'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        CameraPreview(_cameraController!),
        if (_isDetectionActive)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDetecting ? Colors.orange : Colors.green,
                width: 4,
              ),
            ),
          ),
        if (_isDetectionActive)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isDetecting ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isDetecting ? Icons.camera : Icons.videocam,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isDetecting ? 'DETECTING' : 'LIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
