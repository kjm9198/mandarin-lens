import subprocess,json,time,os
from pathlib import Path
root=os.path.expanduser('~/Library/Application Support/Mandarin Lens')
p=subprocess.Popen([root+'/mlx-runtime/bin/python','-u',str(Path(__file__).resolve().parents[1] / 'Resources/model_worker.py'),root+'/Models/Qwen3.5-2B-4bit'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=open('/tmp/lens-worker-error.txt','w'),text=True)
for prompt in ['Explain 茶 in English in one short sentence with pinyin.','Give one short Chinese sentence using 茶, with pinyin and English.']:
 t=time.monotonic();first=None;count=0;result=''
 p.stdin.write(json.dumps({'prompt':prompt})+'\n');p.stdin.flush()
 while True:
  line=p.stdout.readline()
  if not line: raise RuntimeError(open('/tmp/lens-worker-error.txt').read()[-1500:])
  event=json.loads(line)
  if 'error' in event: raise RuntimeError(event['error'])
  if 'delta' in event:
   if first is None:first=time.monotonic()-t
   result+=event['delta'];count+=1
  if event.get('done'):break
 print(json.dumps({'first':first,'total':time.monotonic()-t,'chunks':count,'text':result},ensure_ascii=False),flush=True)
p.terminate();p.wait()
