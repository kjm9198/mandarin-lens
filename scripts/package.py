#!/usr/bin/env python3
"""Deterministic, allowlisted Manifest V3 release package. No remote build step."""
from pathlib import Path
import hashlib,json,zipfile,shutil
root=Path(__file__).resolve().parents[1]
out=root/'dist';out.mkdir(exist_ok=True)
files=['manifest.json','content.js','core.js','preprocess.js','popup.html','popup.css','popup.js','vocabulary.html','vocabulary.css','vocabulary.js','vocabulary-practice.js','help.html','data/pinyin.js','data/lexicon.js','data/lexicon-provenance.json','learning.js','storage-worker.js','icons/16.png','icons/48.png','icons/128.png','LICENSE','THIRD_PARTY_NOTICES.md','licenses/UNICODE-LICENSE.txt','licenses/CC-BY-SA-4.0.txt','licenses/CC-CEDICT-NOTICE.md','PRIVACY_POLICY.md','PERMISSIONS.md']
version=json.loads((root/'manifest.json').read_text())['version']
stage=out/'mandarin-lens';stage.mkdir(exist_ok=True)
for old in stage.rglob('*'):
    if old.is_file():old.unlink()
archive=out/f'mandarin-lens-{version}.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for name in sorted(files):
        data=(root/name).read_bytes();info=zipfile.ZipInfo(name,date_time=(2026,10,28,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o644<<16
        z.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
        dest=stage/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
with zipfile.ZipFile(archive) as z:
    assert z.namelist()==sorted(files)
    assert z.testzip() is None
    assert json.loads(z.read('manifest.json'))['version']==version
checksum=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/'SHA256SUMS.txt').write_text(f'{checksum}  {archive.name}\n')
(out/'package-report.json').write_text(json.dumps({'version':version,'files':sorted(files),'uncompressedBytes':sum((root/p).stat().st_size for p in files),'zipBytes':archive.stat().st_size,'sha256':checksum},indent=2)+'\n')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'sha256':checksum},indent=2))
