from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import sys
import queue
import sounddevice as sd
import json
import threading
import time
from vosk import Model, KaldiRecognizer

app = Flask(__name__)
CORS(app)

# Configuration
LANGUAGE_MODELS = {
    'en': '/Volumes/TANISH/mconnect/vosk-model-small-en-us-0.15',
    'hi': '/Volumes/TANISH/mconnect/vosk-model-small-hi-0.22',
    'fr': '/Volumes/TANISH/mconnect/vosk-model-small-fr-0.22',
    'de': '/Volumes/TANISH/mconnect/vosk-model-small-de-0.15'
}

# Global variables for audio processing
models = {}
current_language = 'en'
recognizer = None
audio_queue = queue.Queue()
is_listening = False
recorded_text = ""

def load_model(language='en'):
    global models, recognizer, current_language
    
    if language not in LANGUAGE_MODELS:
        print(f"Language {language} not supported")
        return False
    
    model_path = LANGUAGE_MODELS[language]
    if not os.path.exists(model_path):
        print(f"Model not found at: {model_path}")
        return False
    
    try:
        if language not in models:
            models[language] = Model(model_path)
        
        recognizer = KaldiRecognizer(models[language], 16000)
        current_language = language
        return True
    except Exception as e:
        print(f"Error loading model for {language}: {e}")
        return False

def audio_callback(indata, frames, time, status):
    if status:
        print(status, file=sys.stderr)
    if is_listening:
        audio_queue.put(bytes(indata))

@app.route('/stt/start', methods=['POST'])
def start_listening():
    global is_listening, recorded_text
    
    data = request.get_json()
    language = data.get('language', 'en') if data else 'en'
    
    # Load model for the requested language
    if not load_model(language):
        return jsonify({'error': f'Failed to load model for language: {language}'}), 500
    
    if is_listening:
        return jsonify({'error': 'Already listening'}), 400
    
    try:
        is_listening = True
        recorded_text = ""
        
        # Start audio stream
        stream = sd.RawInputStream(
            samplerate=16000, 
            blocksize=8000, 
            dtype='int16',
            channels=1, 
            callback=audio_callback
        )
        stream.start()
        
        # Store stream in app context for later use
        app.config['audio_stream'] = stream
        
        return jsonify({
            'success': True, 
            'message': f'Started listening in {language}',
            'language': current_language
        })
    
    except Exception as e:
        is_listening = False
        return jsonify({'error': str(e)}), 500

@app.route('/stt/stop', methods=['POST'])
def stop_listening():
    global is_listening, recorded_text
    
    if not is_listening:
        return jsonify({'error': 'Not currently listening'}), 400
    
    try:
        is_listening = False
        
        # Stop audio stream
        stream = app.config.get('audio_stream')
        if stream:
            stream.stop()
            stream.close()
        
        # Process any remaining audio
        final_result = ""
        if recognizer:
            final_result = json.loads(recognizer.FinalResult()).get("text", "")
        
        # Combine with any partial results
        complete_text = (recorded_text + " " + final_result).strip()
        
        return jsonify({
            'success': True, 
            'text': complete_text,
            'message': 'Stopped listening'
        })
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/stt/status', methods=['GET'])
def get_status():
    return jsonify({
        'listening': is_listening,
        'model_loaded': len(models) > 0,
        'current_language': current_language,
        'supported_languages': list(LANGUAGE_MODELS.keys()),
        'partial_text': recorded_text
    })

def process_audio():
    global recorded_text
    while True:
        if is_listening and not audio_queue.empty():
            try:
                data = audio_queue.get_nowait()
                if recognizer and recognizer.AcceptWaveform(data):
                    result = json.loads(recognizer.Result())
                    text = result.get("text", "")
                    if text:
                        recorded_text += " " + text
                        recorded_text = recorded_text.strip()
            except queue.Empty:
                pass
            except Exception as e:
                print(f"Audio processing error: {e}")
        time.sleep(0.1)

if __name__ == '__main__':
    print("Loading Vosk model...")
    if load_model():
        print("Model loaded successfully")
        # Start audio processing thread
        audio_thread = threading.Thread(target=process_audio, daemon=True)
        audio_thread.start()
        app.run(host='0.0.0.0', port=5002, debug=False)
    else:
        print("Failed to load model. Please check the MODEL_PATH.")