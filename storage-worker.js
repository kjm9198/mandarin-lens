'use strict';
/* Event-driven persistence coordinator. No network, capture, polling or external connection. */
importScripts('learning.js','preprocess.js','site-worker.js');
let queue=Promise.resolve();
const L=globalThis.MandarinLensLearning,P=globalThis.MandarinLensPreprocess;
const PAGE_ACTIONS=new Set(['patch','review','delete-all','cache-clear']);
const ACTIONS=new Set(['save-word','patch','review','delete-all','cache-clear','cache-save']);
function checkMessage(message,sender){
  if(sender.id!==chrome.runtime.id||!message||typeof message!=='object'||!ACTIONS.has(message.action))throw Error('Unsupported request');
  if(JSON.stringify(message).length>2_100_000)throw Error('Request is too large');
  if(PAGE_ACTIONS.has(message.action)&&!String(sender.url||'').startsWith(chrome.runtime.getURL('')))throw Error('Open extension controls for this action');
}
function cleanPrepared(cues){
  if(!Array.isArray(cues)||!cues.length||cues.length>4000)throw Error('Invalid prepared captions');
  return cues.map(c=>{const checked=P.validCues([c])[0];if(!checked||typeof c.translation!=='string'||!c.translation.trim()||c.translation.length>600)throw Error('Invalid prepared line');return {...checked,translation:c.translation, ...(typeof c.chinese==='string'?{chinese:c.chinese.slice(0,600)}:{}),...(typeof c.english==='string'?{english:c.english.slice(0,600)}:{})};});
}
async function mutate(message){
  const all=await chrome.storage.local.get(null),revision=all.dataRevision||0;
  if(message.action==='delete-all'){
    const next=crypto.randomUUID();await chrome.storage.local.set({dataEpoch:next});await chrome.storage.local.clear();await chrome.storage.local.set({dataRevision:next});return {revision:next};
  }
  if(message.revision!==revision)throw Error('Learning data was reset. Reopen the controls to continue.');
  if(message.action==='cache-clear'){
    const epoch=crypto.randomUUID();await chrome.storage.local.set({cacheEpoch:epoch});const keys=Object.keys(all).filter(k=>k.startsWith('prepared:'));if(keys.length)await chrome.storage.local.remove(keys);return {removed:keys.length};
  }
  if(message.action==='cache-save'){
    if(message.cacheRevision!==(all.cacheEpoch||0))throw Error('Preparation was canceled by cache clearing');
    if(typeof message.key!=='string'||!/^prepared:[0-9.]+:[a-f0-9]{64}$/u.test(message.key))throw Error('Invalid cache key');
    const record={savedAt:Date.now(),cues:cleanPrepared(message.cues)};let bytes=JSON.stringify(record).length*2,count=1;
    if(bytes>4_000_000)throw Error('Prepared captions exceed the local cache limit');
    const remove=[];
    for(const [key,value]of Object.entries(all).filter(([key])=>key.startsWith('prepared:')&&key!==message.key).sort((a,b)=>(b[1]?.savedAt||0)-(a[1]?.savedAt||0))){const size=JSON.stringify(value).length*2;if(count>=3||bytes+size>4_000_000)remove.push(key);else{bytes+=size;count++;}}
    if(remove.length)await chrome.storage.local.remove(remove);await chrome.storage.local.set({[message.key]:record});return {saved:true};
  }
  const entries=Array.isArray(all.vocabulary)?all.vocabulary.map(L.cleanEntry).filter(Boolean).slice(-500):[],map=new Map(entries.map(entry=>[entry.word,entry]));
  if(message.action==='save-word'){
    const entry=L.cleanEntry(message.entry);if(!entry)throw Error('Invalid word');if(map.has(entry.word))return {saved:false,entry:map.get(entry.word)};if(map.size>=500)throw Error('Collection full. Export or remove words first.');map.set(entry.word,entry);
  }else if(message.action==='review'){
    if(typeof message.word!=='string'||!map.has(message.word))throw Error('Word no longer exists');map.set(message.word,L.grade(map.get(message.word),message.grade));
  }else if(message.action==='patch'){
    if(!Array.isArray(message.remove)||!Array.isArray(message.upsert)||message.remove.length>500||message.upsert.length>500)throw Error('Invalid vocabulary changes');
    for(const word of message.remove){if(typeof word!=='string'||word.length>100)throw Error('Invalid word');map.delete(word);}
    for(const raw of message.upsert){const entry=L.cleanEntry(raw);if(!entry)throw Error('Invalid word');const latest=map.get(entry.word);map.set(entry.word,latest?{...entry,review:latest.review,reviewHistory:latest.reviewHistory,known:latest.known}:entry);}if(map.size>500)throw Error('Collection limit is 500 words');
  }
  const vocabulary=[...map.values()];await chrome.storage.local.set({vocabulary});return {vocabulary};
}
chrome.runtime.onMessage.addListener((message,sender,sendResponse)=>{
  if(message?.action?.startsWith('site-'))return false;
  try{checkMessage(message,sender);}catch(error){sendResponse({ok:false,error:error.message});return false;}
  const result=queue.then(()=>mutate(message));queue=result.catch(()=>{});
  result.then(value=>sendResponse({ok:true,...value}),error=>sendResponse({ok:false,error:error.message}));return true;
});
