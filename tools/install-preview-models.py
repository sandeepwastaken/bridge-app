import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile


def download(url, target):
    if not url.startswith('https://argos-net.com/'):
        raise ValueError('The catalog URL must be on the official Argos distribution host.')
    if os.name == 'nt':
        env = dict(os.environ, BRIDGE_DOWNLOAD_URL=url, BRIDGE_DOWNLOAD_FILE=str(target))
        subprocess.run(['powershell.exe', '-NoProfile', '-Command',
                        "$ErrorActionPreference='Stop'; Invoke-WebRequest -Uri $env:BRIDGE_DOWNLOAD_URL -OutFile $env:BRIDGE_DOWNLOAD_FILE -TimeoutSec 180"],
                       env=env, check=True)
    else:
        request = urllib.request.Request(url, headers={'User-Agent': 'Bridge local model installer'})
        with urllib.request.urlopen(request, timeout=180) as source, target.open('wb') as output:
            shutil.copyfileobj(source, output)


def install(output, languages):
    catalog = json.loads((Path(__file__).resolve().parents[1] / 'preview/model-catalog.json').read_text(encoding='utf-8'))
    output.mkdir(parents=True, exist_ok=True)
    for item in catalog:
        if item['from_code'] not in languages or item['to_code'] not in languages:
            continue
        name = item['from_code'] + '_' + item['to_code']
        destination = output / name
        if any(destination.rglob('metadata.json')):
            print('Already installed: ' + name, flush=True)
            continue
        print('Downloading ' + name, flush=True)
        with tempfile.TemporaryDirectory(prefix='bridge-model-') as temporary:
            archive = Path(temporary) / 'model.zip'
            download(item['links'][0], archive)
            with zipfile.ZipFile(archive) as package:
                for info in package.infolist():
                    if not (destination / info.filename).resolve().is_relative_to(destination.resolve()):
                        raise ValueError('Unexpected archive path.')
                    if (info.external_attr >> 16) & 0o170000 == 0o120000:
                        raise ValueError('Unexpected archive link.')
                destination.mkdir(parents=True, exist_ok=True)
                package.extractall(destination)
        print('Installed ' + name, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--languages', default='en,hi,es,fr,de,it,pt,nl,ru,uk,pl,ar,zh,ja,bn')
    args = parser.parse_args()
    install(args.output.resolve(), set(args.languages.split(',')) | {'en'})
