#!/usr/bin/env python3
"""Prepare static legal pages from reviewed Markdown, rendering all content as text."""
from pathlib import Path
import html,shutil
root=Path(__file__).resolve().parents[1];site=root/'website'
for source,dest in [('PRIVACY_POLICY.md','privacy.html'),('PERMISSIONS.md','security.html')]:
    chunks=[]
    for para in (root/source).read_text().split('\n\n'):
        tag='h1' if para.startswith('# ') else 'h2' if para.startswith('## ') else 'p'
        if tag.startswith('h'):para=para.split(' ',1)[1]
        chunks.append(f'<{tag}>{html.escape(para)}</{tag}>')
    (site/dest).write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mandarin Lens · '+('Privacy' if dest.startswith('privacy') else 'Security')+'</title><link rel="stylesheet" href="style.css"><main class="document"><a href="./">← Mandarin Lens</a>'+''.join(chunks)+'<p><a href="https://github.com/kjm9198/mandarin-lens/blob/main/docs/SECURITY_REVIEW.md">Development security review</a> · <a href="https://github.com/kjm9198/mandarin-lens/blob/main/THREAT_MODEL.md">Threat model</a></p></main></html>')
shutil.copy2(root/'icons/128.png',site/'icon.png')
shot=root/'output/playwright/real-extension-en-zh.png'
if shot.exists():shutil.copy2(shot,site/'overlay.png')
(site/'.nojekyll').touch()
print('Static website prepared without external scripts, fonts or analytics.')
