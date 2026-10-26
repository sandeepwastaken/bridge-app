import gc
import json
import os
from pathlib import Path
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

if os.environ.get('BRIDGE_PYTHON_PACKAGES'):
    sys.path.insert(0, os.environ['BRIDGE_PYTHON_PACKAGES'])
import ctranslate2
import numpy as np
import sentencepiece as spm

ROOT = Path(os.environ.get('BRIDGE_MODEL_ROOT', Path(__file__).parent / '.models'))
WHISPER = Path(os.environ.get('BRIDGE_WHISPER_MODEL', ROOT / 'whisper'))
LOCK = threading.Lock()
CURRENT = None
SPEECH = None
LANGUAGES = ('en', 'es', 'hi', 'fr', 'de', 'it', 'pt', 'nl', 'ru', 'uk', 'pl', 'ar', 'zh', 'ja', 'bn')


class TranslationModel:
    def __init__(self, source, target):
        self.source, self.target = source, target
        pair = ROOT / f'{source}_{target}'
        candidates = list(pair.rglob('metadata.json'))
        if not candidates:
            raise ValueError('This language model is not installed on this computer.')
        folder = candidates[0].parent
        sentencepiece = folder / 'sentencepiece.model'
        self.sp = spm.SentencePieceProcessor(model_file=str(sentencepiece)) if sentencepiece.exists() else None
        if not self.sp:
            from subword_nmt.apply_bpe import BPE
            from sacremoses import MosesTokenizer, MosesDetokenizer, MosesPunctNormalizer
            self.moses = MosesTokenizer(lang=source)
            self.normalizer = MosesPunctNormalizer(lang=source)
            self.detokenizer = MosesDetokenizer(lang=target)
            with (folder / 'bpe.model').open(encoding='utf-8') as codes:
                self.bpe = BPE(codes)
        self.engine = ctranslate2.Translator(str(folder / 'model'), device='cpu', compute_type='int8', inter_threads=1, intra_threads=2)

    def translate(self, text):
        lines = re.split(r'(?<=[.!?।])\s+|\n+', text.strip())
        output = []
        for line in lines:
            if not line.strip():
                continue
            tokens = self.sp.encode(line, out_type=str) if self.sp else self.bpe.process_line(self.moses.tokenize(self.normalizer.normalize(line), return_str=True)).split()
            if len(tokens) > 450:
                raise ValueError('This sentence is too long. Split it into smaller sentences and try again.')
            result = self.engine.translate_batch([tokens], beam_size=4, max_decoding_length=512)[0].hypotheses[0]
            decoded = self.sp.decode(result).replace('▁', ' ').replace('_', ' ') if self.sp else self.detokenizer.detokenize(' '.join(result).replace('@@ ', '').split())
            output.append(decoded)
        return '\n'.join(output)


def translate(text, source, target):
    global CURRENT, SPEECH
    if source not in LANGUAGES or target not in LANGUAGES:
        raise ValueError('Choose one of the installed languages.')
    if not isinstance(text, str) or not text.strip() or len(text) > 1500:
        raise ValueError('Enter a message between 1 and 1500 characters.')
    if source == target:
        return text
    SPEECH = None
    pair = (source, target) if 'en' in (source, target) else (source, 'en')
    for step in [pair] + ([] if 'en' in (source, target) else [('en', target)]):
        if CURRENT is None or CURRENT[:2] != step:
            CURRENT = None
            gc.collect()
            CURRENT = (*step, TranslationModel(*step))
        text = CURRENT[2].translate(text)
    return text


def transcribe(data, language):
    global SPEECH, CURRENT
    if language != 'en':
        raise ValueError('Voice input on this computer currently supports English. Type your message for other languages.')
    if len(data) % 4 or len(data) < 3200 or len(data) > 16000 * 4 * 45:
        raise ValueError('Record between a moment and 45 seconds of audio.')
    audio = np.frombuffer(data, dtype='<f4').copy()
    if not np.isfinite(audio).all():
        raise ValueError('The microphone recording was not valid. Please try again.')
    if float(np.max(np.abs(audio))) < 0.003:
        return ''
    CURRENT = None
    gc.collect()
    if SPEECH is None:
        from faster_whisper import WhisperModel
        SPEECH = WhisperModel(str(WHISPER), device='cpu', compute_type='int8', cpu_threads=2, num_workers=1, local_files_only=True)
    segments, _ = SPEECH.transcribe(audio, language='en', beam_size=3, condition_on_previous_text=False, vad_filter=True)
    return ' '.join(s.text.strip() for s in segments if s.no_speech_prob < 0.8).strip()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def respond(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        if self.path != '/capabilities':
            return self.respond(404, {'error': 'Not found.'})
        self.respond(200, {'speech': 'ready' if (WHISPER / 'model.bin').exists() else 'unavailable', 'speechLanguages': ['en'], 'translation': 'ready' if ROOT.exists() else 'unavailable', 'languages': list(LANGUAGES)})

    def do_POST(self):
        if self.headers.get('Origin') or self.headers.get('Host') not in ('127.0.0.1:4174', 'localhost:4174'):
            return self.respond(403, {'error': 'Local preview access only.'})
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 16000 * 4 * 45:
                return self.respond(413, {'error': 'This request is too large.'})
            if not LOCK.acquire(blocking=False):
                return self.respond(429, {'error': 'One request is still finishing. Please try again in a moment.'})
            try:
                data = self.rfile.read(size)
                parsed = urlparse(self.path)
                if parsed.path == '/translate':
                    payload = json.loads(data)
                    result = translate(payload.get('text'), payload.get('from'), payload.get('to'))
                elif parsed.path == '/transcribe':
                    result = transcribe(data, parse_qs(parsed.query).get('language', ['en'])[0])
                else:
                    return self.respond(404, {'error': 'Not found.'})
                self.respond(200, {'text': result})
            finally:
                LOCK.release()
        except (ValueError, json.JSONDecodeError) as error:
            self.respond(400, {'error': str(error)})
        except Exception:
            self.respond(503, {'error': 'The local language service could not finish. Your message is still here. Try a shorter message.'})


if __name__ == '__main__':
    server = ThreadingHTTPServer(('127.0.0.1', 4174), Handler)
    print('Bridge local language service: http://127.0.0.1:4174', flush=True)
    server.serve_forever()
