import subprocess,json,os
from pathlib import Path
root=os.path.expanduser('~/Library/Application Support/Mandarin Lens')
p=subprocess.Popen([root+'/mlx-runtime/bin/python','-u',str(Path(__file__).resolve().parents[1] / 'Resources/model_worker.py'),root+'/Models/Qwen3.5-2B-4bit'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
messages=[{'role':'system','content':'You are a concise Chinese tutor. Answer the latest user question in English. Include Chinese and pinyin.'},{'role':'user','content':'Give one example using beautiful.'},{'role':'assistant','content':'She is a beautiful woman.'},{'role':'user','content':'Give one everyday Chinese example using 学习, with pinyin and English.'}]
p.stdin.write(json.dumps({'messages':messages})+'\n');p.stdin.flush();result='';chunks=0
while True:
 d=json.loads(p.stdout.readline())
 if 'error' in d:raise RuntimeError(d['error'])
 result+=d.get('delta','');chunks+=bool(d.get('delta'))
 if d.get('done'):break
p.terminate();p.wait()
print('CHUNKS',chunks);print(result)
assert '学习' in result and 'beautiful' not in result.lower(), 'Latest word must replace the prior example context'
print('PASS structured multi-turn response addresses the latest Chinese word.')
