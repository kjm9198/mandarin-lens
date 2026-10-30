'use strict';
// Website preferences contain hostnames only; no browsing paths or history.
const siteFiles=['data/pinyin.js','data/lexicon.js','core.js','preprocess.js','learning.js','youtube-captions.js','content.js'];
let siteSync=Promise.resolve();
function syncSites(){const next=siteSync.then(updateSites);siteSync=next.catch(()=>{});return next;}
async function updateSites(){
  const {origins=[]}=await chrome.permissions.getAll();
  const matches=origins.filter(origin=>/^https?:\/\//.test(origin)&&!/^https:\/\/(www|m)\.youtube\.com\//.test(origin));
  if((await chrome.scripting.getRegisteredContentScripts({ids:['mandarin-sites']})).length)await chrome.scripting.unregisterContentScripts({ids:['mandarin-sites']});
  if(matches.length)await chrome.scripting.registerContentScripts([{id:'mandarin-sites',matches,js:['site-prompt.js'],runAt:'document_start',persistAcrossSessions:true}]);
}
chrome.runtime.onInstalled?.addListener(()=>{void syncSites().catch(()=>{});});
chrome.permissions?.onAdded?.addListener(()=>{void syncSites().catch(()=>{});});
chrome.permissions?.onRemoved?.addListener(()=>{void syncSites().catch(()=>{});});
chrome.runtime.onMessage.addListener((message,sender,reply)=>{
  if(!message?.action?.startsWith('site-'))return false;
  (async()=>{
    if(sender.id!==chrome.runtime.id)throw Error('Unsupported sender');
    if(message.action==='site-sync'){
      if(!sender.url?.startsWith(chrome.runtime.getURL('')))throw Error('Open extension controls');
      await syncSites();return;
    }
    if(message.action!=='site-start'||!sender.tab?.id||sender.frameId!==0||!/^https?:\/\//.test(sender.url||''))throw Error('Open a video website');
    await chrome.scripting.executeScript({target:{tabId:sender.tab.id},files:siteFiles});
    await chrome.scripting.executeScript({target:{tabId:sender.tab.id},args:[sender.url,Boolean(message.auto)],func:async(expectedUrl,auto)=>{
      const lens=globalThis.__mandarinLensInstance;if(!lens)return;
      const key='site:'+location.hostname,values=await chrome.storage.local.get(key);
      if(values[key]?.mode==='off')return;
      await lens.open();
      // Existing packs can initialize automatically. First-time downloads keep the visible click.
      if(auto&&typeof Translator!=='undefined'){
        try{
          const {direction='en-zh'}=await chrome.storage.local.get('direction');
          if(!lens.snapshot().enabled&&await Translator.availability(MandarinLensCore.options(direction))==='available')await lens.start();
        }catch{/* Keep the visible Start learning button when Chrome cannot initialize automatically. */}
      }
    }});
  })().then(()=>reply({ok:true}),error=>reply({ok:false,error:error.message}));return true;
});
