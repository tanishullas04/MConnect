from flask import Flask, request, jsonify
from flask_cors import CORS
from gtts import gTTS
from deep_translator import GoogleTranslator
import os
import tempfile
import subprocess

app = Flask(__name__)
CORS(app)

@app.route('/tts', methods=['POST'])
def tts():
    data = request.get_json()
    text = data.get('text', '')
    lang = data.get('lang', 'en')
    translate = data.get('translate', False)  # New parameter to enable translation
    
    if not text:
        return jsonify({'error': 'No text provided'}), 400
    
    try:
        # If translation is requested, translate the text to the target language
        if translate and lang != 'en':
            translator = GoogleTranslator(source='auto', target=lang)
            text_to_speak = translator.translate(text)
        else:
            text_to_speak = text
            
        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as fp:
            tts = gTTS(text=text_to_speak, lang=lang)
            tts.save(fp.name)
            # Use macOS 'afplay' command instead of playsound
            subprocess.run(['afplay', fp.name], check=True)
            os.remove(fp.name)
        
        response_data = {'success': True}
        if translate and lang != 'en':
            response_data['translated_text'] = text_to_speak
            
        return jsonify(response_data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
