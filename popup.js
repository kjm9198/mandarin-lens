'use strict';
const $=id=>document.getElementById(id);
const DEFAULTS={direction:'en-zh',showHanzi:true,showPinyin:true,showOriginal:true,showEnglish:true,fontSize:18,hanziSize:12,englishSize:12,opacity:0,position:8,horizontal:50,spacing:2,textOpacity:100,backgroundBlur:0,timingOffset:0,fontFamily:'system',toneColors:false,pauseOnWord:true,autoPrepare:true,sentenceMode:true,pauseOnHover:true,...MandarinLensLearning.DEFAULTS};
const PRESETS={minimal:{fontSize:18,hanziSize:12,englishSize:12,opacity:0,position:8,spacing:2},balanced:{fontSize:22,hanziSize:14,englishSize:14,opacity:12,position:12,spacing:4},large:{fontSize:32,hanziSize:20,englishSize:18,opacity:32,position:16}};
const ranges={lineSpacing:[0,12,'px'],fontSize:[14,42,'px'],hanziSize:[10,32,'px'],englishSize:[10,32,'px'],opacity:[0,80,'%'],position:[4,40,'%'],horizontal:[10,90,'%'],spacing:[0,16,'px'],textOpacity:[40,100,'%'],backgroundBlur:[0,16,'px'],timingOffset:[-5,5,'s']};
const fonts={system:'system-ui, sans-serif',serif:'Georgia, serif',rounded:'ui-rounded, system-ui, sans-serif'};
const controls=[...document.querySelectorAll('button,input,select')];
for(const el of controls)el.disabled=true;
function currentPrefs(){const values={};for(const [key,fallback] of Object.entries(DEFAULTS)){const el=$(key);if(!el)continue;values[key]=typeof fallback==='boolean'?el.checked:ranges[key]?Number(el.value):el.value;}return values;}
function applyValues(values){for(const [key,fallback] of Object.entries(DEFAULTS)){const el=$(key);if(!el)continue;const value=values[key]??fallback;if(typeof fallback==='boolean')el.checked=typeof value==='boolean'?value:fallback;else if(ranges[key]){const n=Number(value);el.value=Number.isFinite(n)?Math.max(ranges[key][0],Math.min(ranges[key][1],n)):fallback;}else el.value=String(value);}refresh();}
function refresh(){const v=currentPrefs();for(const [key,range] of Object.entries(ranges)){const out=$(key+'Value');if(out)out.textContent=v[key]+range[2];}for(const b of document.querySelectorAll('[data-preset]')){const active=Object.entries(PRESETS[b.dataset.preset]).every(([key,value])=>v[key]===value);b.classList.toggle('active',active);b.setAttribute('aria-pressed',String(active));}
const preview=document.querySelector('.preview');preview.style.fontFamily=fonts[v.fontFamily]||fonts.system;preview.style.background=`rgba(8,15,25,${v.opacity/100})`;for(const [cls,size,visible] of [['hanzi',v.hanziSize,v.showHanzi],['pinyin',v.fontSize,v.showPinyin],['english',v.englishSize,v.showOriginal&&v.showEnglish]]){const layer=document.querySelector('.'+cls);if(layer){layer.style.fontSize=size+'px';layer.style.opacity=String(v.textOpacity/100);layer.hidden=!visible;}}}
async function persist(){await chrome.storage.local.set(currentPrefs());}
function failure(message){$('status').textContent=message;$('status').classList.add('error');}
for(const key of Object.keys(DEFAULTS)){const el=$(key);if(el)el.addEventListener(ranges[key]?'input':'change',()=>{refresh();void persist().catch(()=>failure('Could not save settings. Try reopening Mandarin Lens.'));});}
for(const b of document.querySelectorAll('[data-preset]'))b.addEventListener('click',async()=>{applyValues({...currentPrefs(),...PRESETS[b.dataset.preset]});try{await persist();}catch{failure('Could not save this style.');}});
$('resetAppearance').addEventListener('click',async()=>{const next=currentPrefs();for(const key of [...Object.keys(ranges),'fontFamily','showHanzi','showPinyin','showOriginal','showEnglish','toneColors','textShadow','textAlign'])next[key]=DEFAULTS[key];applyValues(next);try{await persist();}catch{failure('Could not reset appearance.');}});
$('start').addEventListener('click',async()=>{const button=$('start');button.disabled=true;$('status').classList.remove('error');$('status').textContent='Opening subtitles on this video…';try{const [tab]=await chrome.tabs.query({active:true,currentWindow:true});if(!tab?.id||!/^https?:\/\//i.test(tab.url||'')){failure('Open a video page first. Browser settings and store pages cannot run subtitles.');return;}await persist();await chrome.scripting.executeScript({target:{tabId:tab.id},files:['data/pinyin.js','data/lexicon.js','core.js','preprocess.js','learning.js','youtube-captions.js','content.js']});$('status').textContent=/(^|\.)youtube\.com$/i.test(new URL(tab.url).hostname)?'YouTube CC starts automatically. Press Start learning on the video if Chrome needs its language pack.':'On your video, press “Start learning” to enable local translation. Turn on CC if needed.';button.textContent='Open subtitles again';}catch{failure('Could not open subtitles. Refresh the video, then try again. Some pages restrict extensions.');}finally{button.disabled=false;}});
$('vocabulary').addEventListener('click',()=>chrome.tabs.create({url:chrome.runtime.getURL('vocabulary.html')}));
$('help').addEventListener('click',()=>chrome.tabs.create({url:chrome.runtime.getURL('help.html')}));
$('deleteData').addEventListener('click',async()=>{if(!confirm('Delete all saved words and preferences from Mandarin Lens? This cannot be undone. Close or refresh video tabs to remove their in-memory subtitles too.'))return;try{const result=await chrome.runtime.sendMessage({action:'delete-all'});if(!result.ok)throw Error(result.error);applyValues(DEFAULTS);$('wordCount').textContent='0';$('status').textContent='All saved learning data deleted. Close or refresh video tabs to clear active sessions.';}catch{failure('Could not delete learning data. Try again.');}});
(async()=>{const values=await chrome.storage.local.get({...DEFAULTS,compactLayoutVersion:0}),patch=MandarinLensCore.compactAppearance(values);if(Object.keys(patch).length)await chrome.storage.local.set(patch);applyValues({...values,...patch});const {vocabulary=[]}=await chrome.storage.local.get({vocabulary:[]});$('wordCount').textContent=String(Array.isArray(vocabulary)?vocabulary.length:0);})().catch(()=>failure('Could not load settings. Reopen Mandarin Lens to try again.')).finally(()=>{for(const el of controls)el.disabled=el.id==='transcriptionUnavailable';if($('learningData').open)void refreshCacheUsage();});

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
    const {dataRevision=0}=await chrome.storage.local.get({dataRevision:0});const result=await chrome.runtime.sendMessage({action:'cache-clear',revision:dataRevision});if(!result.ok)throw Error(result.error);
    $('status').textContent='Prepared captions cleared. Saved words and settings kept.';
    await refreshCacheUsage();
  }catch{failure('Could not clear prepared captions. Try again.');$('clearCache').disabled=false;}
});
chrome.storage.onChanged.addListener((changes,area)=>{
  if(area!=='local')return;
  if(changes.vocabulary)$('wordCount').textContent=String(Array.isArray(changes.vocabulary.newValue)?changes.vocabulary.newValue.length:0);
  if($('learningData').open&&Object.keys(changes).some(key=>key.startsWith('prepared:')))void refreshCacheUsage();
});

$('stop').addEventListener('click',async()=>{try{const [tab]=await chrome.tabs.query({active:true,currentWindow:true});await chrome.scripting.executeScript({target:{tabId:tab.id},func:()=>globalThis.__mandarinLensInstance?.close()});$('status').textContent='Stopped on this tab.';}catch{failure('Open a regular video tab to stop subtitles.');}});

(async()=>{try{const [tab]=await chrome.tabs.query({active:true,currentWindow:true});if(!tab?.id||!/^https?:\/\//i.test(tab.url||''))return;const [result]=await chrome.scripting.executeScript({target:{tabId:tab.id},func:()=>globalThis.__mandarinLensInstance?.snapshot()});if(result?.result){const view=result.result;$('status').textContent=view.preparing?`Preparing ${view.completed}/${view.total} available lines`:view.enabled?'Active on this tab · '+view.mode+' mode':view.status;}}catch{/* The first activation can be restricted; Start provides the actionable error. */}})();

let websiteTab=null,websiteKey=null,websitePattern=null;
(async()=>{
  [websiteTab]=await chrome.tabs.query({active:true,currentWindow:true});
  if(!/^https?:\/\//.test(websiteTab?.url||'')){ $('saveSite').disabled=true;$('siteMode').disabled=true;return; }
  const url=new URL(websiteTab.url);websiteKey='site:'+url.hostname;websitePattern=url.protocol+'//'+url.hostname+'/*';
  $('siteName').textContent=url.hostname;
  const values=await chrome.storage.local.get(websiteKey),pref=values[websiteKey]||{};
  $('siteMode').value=['ask','compact','always','off'].includes(pref.mode)?pref.mode:'ask';$('pauseBefore').checked=pref.pause!==false;
})().catch(()=>{$('siteStatus').textContent='Could not read this website. Reopen the extension.';});
$('saveSite').addEventListener('click',async()=>{
  if(!websiteKey)return;
  const mode=$('siteMode').value;
  try{
    // Keep the permission request directly inside the user's click.
    if(mode!=='off'&&!await chrome.permissions.request({origins:[websitePattern]})){
      $('siteStatus').textContent='Website access was not granted. Preference was not changed.';return;
    }
    await chrome.storage.local.set({[websiteKey]:{mode,pause:$('pauseBefore').checked}});
    const response=await chrome.runtime.sendMessage({action:'site-sync'});if(!response?.ok)throw Error('sync');
    if(mode!=='off')await chrome.scripting.executeScript({target:{tabId:websiteTab.id},files:['site-prompt.js']});
    $('siteStatus').textContent=mode==='off'?'Off on this website.':mode==='always'?'Will start automatically on this website.':mode==='compact'?'Compact pill only on this website.':'Will ask for each video on this website.';
  }catch{$('siteStatus').textContent='Could not update this website. Refresh the page and try again.';}
});
