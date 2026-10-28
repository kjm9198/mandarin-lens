'use strict';
const $=id=>document.getElementById(id);
const DEFAULTS={direction:'en-zh',showHanzi:true,showPinyin:true,showOriginal:true,fontSize:22,hanziSize:14,englishSize:14,opacity:12,position:12,horizontal:50,spacing:4,textOpacity:100,backgroundBlur:0,timingOffset:0,fontFamily:'system',toneColors:false,pauseOnWord:true,autoPrepare:true};
const PRESETS={minimal:{fontSize:20,hanziSize:12,englishSize:12,opacity:0,position:8},balanced:{fontSize:22,hanziSize:14,englishSize:14,opacity:12,position:12},large:{fontSize:32,hanziSize:20,englishSize:18,opacity:32,position:16}};
const ranges={fontSize:[14,42,'px'],hanziSize:[10,32,'px'],englishSize:[10,32,'px'],opacity:[0,80,'%'],position:[4,40,'%'],horizontal:[10,90,'%'],spacing:[0,16,'px'],textOpacity:[40,100,'%'],backgroundBlur:[0,16,'px'],timingOffset:[-5,5,'s']};
const fonts={system:'system-ui, sans-serif',serif:'Georgia, serif',rounded:'ui-rounded, system-ui, sans-serif'};
const controls=[...document.querySelectorAll('button,input,select')];
for(const el of controls)el.disabled=true;
function currentPrefs(){const values={};for(const [key,fallback] of Object.entries(DEFAULTS)){const el=$(key);values[key]=typeof fallback==='boolean'?el.checked:ranges[key]?Number(el.value):el.value;}return values;}
function applyValues(values){for(const [key,fallback] of Object.entries(DEFAULTS)){const el=$(key),value=values[key]??fallback;if(typeof fallback==='boolean')el.checked=typeof value==='boolean'?value:fallback;else if(ranges[key]){const n=Number(value);el.value=Number.isFinite(n)?Math.max(ranges[key][0],Math.min(ranges[key][1],n)):fallback;}else el.value=key==='direction'?(value==='zh-en'?'zh-en':'en-zh'):Object.hasOwn(fonts,value)?value:'system';}refresh();}
function refresh(){const v=currentPrefs();for(const [key,range] of Object.entries(ranges))$(key+'Value').textContent=v[key]+range[2];for(const b of document.querySelectorAll('[data-preset]')){const active=Object.entries(PRESETS[b.dataset.preset]).every(([key,value])=>v[key]===value);b.classList.toggle('active',active);b.setAttribute('aria-pressed',String(active));}
const preview=document.querySelector('.preview');preview.style.fontFamily=fonts[v.fontFamily];preview.style.background=`rgba(8,15,25,${v.opacity/100})`;for(const [cls,size,visible] of [['hanzi',v.hanziSize,v.showHanzi],['pinyin',v.fontSize,v.showPinyin],['english',v.englishSize,v.showOriginal]]){const layer=document.querySelector('.'+cls);layer.style.fontSize=size+'px';layer.style.opacity=String(v.textOpacity/100);layer.hidden=!visible;}}
async function persist(){await chrome.storage.local.set(currentPrefs());}
function failure(message){$('status').textContent=message;$('status').classList.add('error');}
for(const key of Object.keys(DEFAULTS))$(key).addEventListener(ranges[key]?'input':'change',()=>{refresh();void persist().catch(()=>failure('Could not save settings. Try reopening Mandarin Lens.'));});
for(const b of document.querySelectorAll('[data-preset]'))b.addEventListener('click',async()=>{applyValues({...currentPrefs(),...PRESETS[b.dataset.preset]});try{await persist();}catch{failure('Could not save this style.');}});
$('resetAppearance').addEventListener('click',async()=>{const next=currentPrefs();for(const key of [...Object.keys(ranges),'fontFamily','showHanzi','showPinyin','showOriginal','toneColors'])next[key]=DEFAULTS[key];applyValues(next);try{await persist();}catch{failure('Could not reset appearance.');}});
$('start').addEventListener('click',async()=>{const button=$('start');button.disabled=true;$('status').classList.remove('error');$('status').textContent='Opening subtitles on this video…';try{const [tab]=await chrome.tabs.query({active:true,currentWindow:true});if(!tab?.id||!/^https?:\/\//i.test(tab.url||'')){failure('Open a video page first. Browser settings and store pages cannot run subtitles.');return;}await persist();await chrome.scripting.executeScript({target:{tabId:tab.id},files:['data/pinyin.js','core.js','preprocess.js','content.js']});$('status').textContent='On your video, press “Start learning” to enable local translation. Turn on CC if needed.';button.textContent='Open subtitles again';}catch{failure('Could not open subtitles. Refresh the video, then try again. Some pages restrict extensions.');}finally{button.disabled=false;}});
$('vocabulary').addEventListener('click',()=>chrome.tabs.create({url:chrome.runtime.getURL('vocabulary.html')}));
$('help').addEventListener('click',()=>chrome.tabs.create({url:chrome.runtime.getURL('help.html')}));
$('deleteData').addEventListener('click',async()=>{if(!confirm('Delete all saved words and preferences from Mandarin Lens? This cannot be undone. Close or refresh video tabs to remove their in-memory subtitles too.'))return;try{await chrome.storage.local.set({dataEpoch:Date.now()});await chrome.storage.local.clear();applyValues(DEFAULTS);$('wordCount').textContent='0';$('status').textContent='All saved learning data deleted. Close or refresh video tabs to clear active sessions.';}catch{failure('Could not delete learning data. Try again.');}});
(async()=>{applyValues(await chrome.storage.local.get(DEFAULTS));const {vocabulary=[]}=await chrome.storage.local.get({vocabulary:[]});$('wordCount').textContent=String(Array.isArray(vocabulary)?vocabulary.length:0);})().catch(()=>failure('Could not load settings. Reopen Mandarin Lens to try again.')).finally(()=>{for(const el of controls)el.disabled=false;if($('learningData').open)void refreshCacheUsage();});

let cacheRequest=0;
async function refreshCacheUsage(){
  const request=++cacheRequest;
  try{
    const all=await chrome.storage.local.get(null),keys=Object.keys(all).filter(key=>key.startsWith('prepared:'));
    const bytes=keys.length?await chrome.storage.local.getBytesInUse(keys):0;
    if(request!==cacheRequest)return;
    $('cacheUsage').textContent=`Prepared captions: ${keys.length} saved ${keys.length===1?'track':'tracks'} · ${bytes<1048576?Math.ceil(bytes/1024)+' KB':(bytes/1048576).toFixed(1)+' MB'}`;
    $('clearCache').disabled=keys.length===0;
  }catch{$('cacheUsage').textContent='Could not measure prepared caption storage.';}
}
$('learningData').addEventListener('toggle',()=>{if($('learningData').open)void refreshCacheUsage();});
$('clearCache').addEventListener('click',async()=>{
  $('clearCache').disabled=true;
  try{
    // Cancel in-flight tab checkpoints before deleting records, without touching vocabulary.
    await chrome.storage.local.set({cacheEpoch:Date.now()});
    const all=await chrome.storage.local.get(null),keys=Object.keys(all).filter(key=>key.startsWith('prepared:'));
    if(keys.length)await chrome.storage.local.remove(keys);
    $('status').textContent='Prepared captions cleared. Saved words and settings kept.';
    await refreshCacheUsage();
  }catch{failure('Could not clear prepared captions. Try again.');$('clearCache').disabled=false;}
});
chrome.storage.onChanged.addListener((changes,area)=>{
  if(area!=='local')return;
  if(changes.vocabulary)$('wordCount').textContent=String(Array.isArray(changes.vocabulary.newValue)?changes.vocabulary.newValue.length:0);
  if($('learningData').open&&Object.keys(changes).some(key=>key.startsWith('prepared:')))void refreshCacheUsage();
});
