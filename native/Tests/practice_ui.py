"""Controlled native UI acceptance. Requires an already open --acceptance-testing app."""
import hashlib,json,re,subprocess,time,sys
from collections import Counter
from pathlib import Path
D='/tmp/kamihi-native-driver';B='studio.kamihi.mandarinlens.v31'
root=Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/kamihi-4-acceptance-data').absolute();path=root/'words.json'
processes=subprocess.check_output(['ps','-ax','-o','command='],text=True)
assert any('Kamihi Lens.app/Contents/MacOS/MandarinLens' in line and '--acceptance-testing' in line and '--test-data-directory '+str(root) in line for line in processes.splitlines()), 'Launch the isolated acceptance app first; personal app state was not touched.'
words=json.loads(path.read_text());before=hashlib.sha256(path.read_bytes()).hexdigest()
pinyin={'学':'xué','学习':'xué xí','你好':'nǐ hǎo','咖啡':'kā fēi','朋友':'péng yǒu','美丽':'měi lì','谢谢':'xiè xiè','控制':'kòng zhì'}
def run(*args):return subprocess.check_output([D,'--app',B,'--window','Kamihi Lens',*args],text=True)
def state():return run('--dump')
def click(label):run('--click',label)
def wait(contains):
 for _ in range(80):
  s=state()
  if contains in s:return s
  time.sleep(.04)
 raise AssertionError((contains,s))
def buttons(s):return re.findall(r'^AXButton (.*)$',s,re.M)
def start(mode):
 s=state()
 if 'AXButton All games' in s:click('All games')
 elif 'Pick a game' not in s:click('Play')
 s=wait('Pick a game');click(next(x for x in buttons(s) if x.startswith(mode+',')))
 return wait('AXButton All games')
def finish(mode):
 s=wait('Round complete')
 assert 'AXButton Play again' in s
 print('PASS native full round:',mode,flush=True)
for mode in ['Meaning finder','Reverse recall','Listen & choose','Pinyin path','Word builder']:
 s=start(mode)
 for i in range(5):
  s=wait(f'AXStaticText {i+1} of 5')
  if mode=='Listen & choose':click('Listen to the word');click('Show text');s=state()
  instruction={'Meaning finder':'What does this mean?','Reverse recall':'Which word belongs here?','Listen & choose':'Which word did you hear?','Pinyin path':'Which pinyin matches?','Word builder':'Build the word or phrase.'}[mode]
  question=s.split('AXStaticText '+instruction+'\n',1)[1]
  if mode in ['Reverse recall','Word builder']:
   word=next(w for w in words if 'AXStaticText '+w['meaning']+'\n' in question and (mode!='Word builder' or 2<=len(w['term'])<=16))
  else:word=next(w for w in words if 'AXStaticText '+w['term']+'\n' in question)
  if mode=='Word builder':
   for _ in range(50):
    s=state()
    available=[x.split(': ',1)[1] for x in buttons(s) if re.match(r'^Tile \d+: ',x)]
    if not (Counter(word['term'])-Counter(available)):break
    time.sleep(.05)
   else:raise AssertionError(('Builder bank did not match the prompt',word,s))
   used=set()
   for ch in word['term']:
    label=next(x for x in buttons(s) if re.match(r'^Tile \d+: ',x) and x.endswith(': '+ch) and x not in used)
    click(label);used.add(label)
  else:
   answer=word['meaning'] if mode=='Meaning finder' else pinyin[word['term']] if mode=='Pinyin path' else word['term']
   choice=next(x for x in buttons(s) if re.match(r'^\d, ',x) and x.split(', ',1)[1]==answer)
   if mode=='Meaning finder' and i==0:choice=next(x for x in buttons(s) if re.match(r'^\d, ',x) and x!=choice)
   click(choice)
  click('Check answer')
  wait('See result' if i==4 else 'AXButton Continue')
  if not (mode=='Meaning finder' and i==0):assert 'AXStaticText Correct\n' in state(),(mode,word,state())
  if mode=='Meaning finder' and i==0:assert 'Correct answer' in state()
  click('See result' if i==4 else 'Continue')
 finish(mode)
s=start('Meaning map')
terms=set(buttons(s))
seen=set()
for w in words:
 if w['term'] in terms and w['meaning'] not in seen:
  click(w['term']);click(w['meaning']);seen.add(w['meaning'])
finish('Meaning map')
s=start('Memory match');known={};matched=set()
for _ in range(120):
 s=state()
 if 'Round complete' in s:break
 labels=buttons(s)
 visible={}
 for x in labels:
  m=re.match(r'Card (\d+), (word|meaning): (.*)',x)
  if m:known[int(m[1])]=(m[2],m[3]);visible[int(m[1])]=(m[2],m[3])
 # Record completed pairs when the UI reports a new pair.
 if 'A pair found.' in s:
  for n,v in visible.items():
   for k,u in visible.items():
    if n!=k and v[0]!=u[0] and any((v[1]==w['term'] and u[1]==w['meaning']) or (u[1]==w['term'] and v[1]==w['meaning']) for w in words):matched.update([n,k])
 if 'AXButton Try another pair' in s:click('Try another pair');continue
 hidden=[]
 for x in labels:
  m=re.match(r'Card (\d+), face down$',x)
  if m:hidden.append(int(m[1]))
 open_cards=[n for n in visible if n not in matched]
 if open_cards:
  n=open_cards[0];side,text=known[n]
  matching=next((k for k in hidden if k in known and known[k][0]!=side and any((text==w['term'] and known[k][1]==w['meaning']) or (known[k][1]==w['term'] and text==w['meaning']) for w in words)),None)
  chosen=matching or next((k for k in hidden if k not in known),None) or (hidden[0] if hidden else None)
 else:
  chosen=next((n for n in hidden if any(k!=n and k in hidden and known.get(n) and k in known and known[n][0]!=known[k][0] and any((known[n][1]==w['term'] and known[k][1]==w['meaning']) or (known[k][1]==w['term'] and known[n][1]==w['meaning']) for w in words) for k in hidden)),None)
  chosen=chosen or next((n for n in hidden if n not in known),None) or (hidden[0] if hidden else None)
 assert chosen,(s,known,matched)
 click(f'Card {chosen}, face down')
else:raise AssertionError('Memory game did not finish')
finish('Memory match')
assert hashlib.sha256(path.read_bytes()).hexdigest()==before
print('PASS all seven native game rounds; saved vocabulary/review file unchanged.',flush=True)
