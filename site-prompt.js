'use strict';
(()=>{
  if(globalThis.__mandarinSitePrompt)return;
  globalThis.__mandarinSitePrompt=true;
  const key='site:'+location.hostname;
  let prefs={mode:'ask',pause:true},identity='',handled='',host,root,held=null,wasPlaying=false,busy=false,scheduled=false,revision=0,preferencesReady=false;
  const youtube=/(^|\.)youtube\.com$/.test(location.hostname);
  function video(){return Array.from(document.querySelectorAll('video')).filter(v=>v.clientWidth>120&&v.clientHeight>70).sort((a,b)=>b.clientWidth*b.clientHeight-a.clientWidth*a.clientHeight)[0];}
  function id(){const u=new URL(location.href);return youtube?(u.searchParams.get('v')||(/^\/shorts\//.test(u.pathname)?u.pathname:'')):(u.origin+u.pathname+'|'+(video()?.currentSrc||video()?.getAttribute('src')||''));}
  function release(){const v=held;held=null;if(v&&wasPlaying)void v.play().catch(()=>{});wasPlaying=false;}
  function hold(){const v=video();if(!prefs.pause||!v)return;if(held!==v){held=v;wasPlaying=!v.paused;}else if(!v.paused)wasPlaying=true;if(!v.paused)v.pause();}
  async function save(mode){prefs={...prefs,mode};await chrome.storage.local.set({[key]:prefs});}
  async function start(always=false){
    if(busy)return;busy=true;const token=revision;
    try{if(always&&prefs.mode!=='always')await save('always');const response=await chrome.runtime.sendMessage({action:'site-start',auto:true});if(token!==revision)return;if(!response?.ok)throw Error(response?.error||'Could not open Mandarin Lens');handled=identity;release();render(false);}
    catch{if(token===revision){handled=identity;render(true);root.querySelector('p').textContent='Could not start. Refresh this page and try again.';release();}}
    finally{busy=false;}
  }
  function button(text,fn){const b=document.createElement('button');b.textContent=text;b.type='button';b.addEventListener('click',()=>{void fn().catch(()=>{render(true);root.querySelector('p').textContent='Could not save. Try again.';release();});});return b;}
  function render(prompt){
    if(!host){host=document.createElement('div');host.id='mandarin-site-prompt';root=host.attachShadow({mode:'closed'});(document.body||document.documentElement).append(host);}
    root.replaceChildren();const style=document.createElement('style');style.textContent=':host{all:initial;position:fixed;right:16px;bottom:18px;z-index:2147483647;font:14px/1.5 system-ui,sans-serif;color:#eff7ff}section{position:relative;max-width:min(340px,calc(100vw - 48px));padding:14px;background:#122238;border:1px solid #9db6ce;border-radius:14px;box-shadow:0 6px 24px #0005}strong{font-size:15px;display:block;padding-right:24px}p{margin:6px 0 10px;color:#d0e2f2}div{display:flex;flex-wrap:wrap;gap:6px}button{font:600 13px/1.3 system-ui;min-height:36px;padding:8px 10px;background:#c6e9ff;color:#152e45;border:1px solid #9db6ce;border-radius:8px;cursor:pointer}button:active{filter:brightness(.85)}button:focus-visible{outline:3px solid white;outline-offset:2px}.close{position:absolute;top:10px;right:10px;width:24px;height:24px;min-height:24px;padding:0;background:transparent;border:0;color:#9db6ce;font-size:18px;line-height:1;border-radius:6px;cursor:pointer}.close:hover{background:#ffffff20;color:#fff}@media(prefers-contrast:more){section{background:#07111d;border:2px solid white}}';root.append(style);
    if(!prompt){root.append(button('文 Mandarin Lens',async()=>{handled='';render(true);hold();}));return;}
    const section=document.createElement('section');section.setAttribute('aria-label','Mandarin Lens video choice');
    const closeBtn=document.createElement('button');closeBtn.className='close';closeBtn.textContent='×';closeBtn.type='button';closeBtn.title='Dismiss to pill';closeBtn.setAttribute('aria-label','Dismiss to compact pill');closeBtn.addEventListener('click',()=>{handled=identity;release();render(false);});
    const title=document.createElement('strong');title.textContent='Learn Chinese with this video?';const p=document.createElement('p');p.textContent='Chinese, pinyin and English captions. Choose when to run; customize anytime from the extension.';section.addEventListener('keydown',event=>{if(event.key==='Escape'){event.preventDefault();event.stopPropagation();handled=identity;globalThis.__mandarinLensInstance?.close();release();render(false);root.querySelector('button').focus();}});const actions=document.createElement('div');actions.append(button('Learn once',()=>start()),button('Always here',()=>start(true)),button('Skip video',async()=>{handled=identity;globalThis.__mandarinLensInstance?.close();release();render(false);}),button('Ask each video',async()=>{await save('ask');handled='';render(true);hold();}),button('Off here',async()=>{await save('off');handled=identity;release();host?.remove();host=null;}));section.append(closeBtn,title,p,actions);root.append(section);
  }
  function check(){
    scheduled=false;if(!preferencesReady||prefs.mode==='off')return;const next=id();if(!next||!video())return;
    if(next!==identity){identity=next;handled='';revision++;busy=false;release();globalThis.__mandarinLensInstance?.close();host?.remove();host=null;}
    if(prefs.mode==='off')return;
    if(handled===identity)return;
    if(prefs.mode==='always'){handled=identity;render(false);void start(true);return;}
    if(prefs.mode==='compact'||prefs.compact){handled=identity;render(false);return;}
    if(!host||!root.querySelector('section'))render(true);hold();
  }
  function schedule(){if(!scheduled){scheduled=true;requestAnimationFrame(check);}}
  chrome.storage.local.get(key).then(values=>{prefs={...prefs,...values[key]};preferencesReady=true;schedule();}).catch(()=>{preferencesReady=true;schedule();});
  chrome.storage.onChanged.addListener((changes,area)=>{if(area!=='local')return;if(changes.dataEpoch){prefs={mode:'off',pause:true};release();host?.remove();host=null;return;}if(changes[key]){prefs={mode:'ask',pause:true,...changes[key].newValue};handled='';if(prefs.mode==='off'){release();globalThis.__mandarinLensInstance?.close();host?.remove();host=null;}schedule();}});
  document.addEventListener('play',schedule,true);document.addEventListener('loadedmetadata',schedule,true);document.addEventListener('yt-navigate-finish',schedule);window.addEventListener('popstate',schedule);
  new MutationObserver(mutations=>{if(mutations.some(m=>Array.from(m.addedNodes).some(n=>n.nodeType===1&&(n.matches('video')||n.querySelector('video')))))schedule();}).observe(document.documentElement,{childList:true,subtree:true});
  document.addEventListener('DOMContentLoaded',schedule,{once:true});
})();
