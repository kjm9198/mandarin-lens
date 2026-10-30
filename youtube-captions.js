'use strict';
// Keep YouTube's caption feed running, while replacing only its visual subtitle layer.
// No player internals, network requests, page-world execution or caption removal.
(()=>{
  function create(doc,hostname){
    const supported=/(^|\.)youtube\.com$/i.test(hostname);
    let player=null,button=null,originalOff=false,ownsToggle=false,attempts=0,lastAttempt=0,busy=false,closed=false;
    const hidden=new Map();
    function restoreText(node,saved){
      if(node.style.getPropertyValue('opacity')==='0'&&node.style.getPropertyPriority('opacity')==='important'){
        if(saved.opacity)node.style.setProperty('opacity',saved.opacity,saved.priority);else node.style.removeProperty('opacity');
      }
      if(node.getAttribute('aria-hidden')==='true'){
        if(saved.aria===null)node.removeAttribute('aria-hidden');else node.setAttribute('aria-hidden',saved.aria);
      }
    }
    function reveal(){for(const [node,saved]of hidden)restoreText(node,saved);hidden.clear();}
    function release(){
      reveal();
      // Restore only a switch we changed, and only if its original player still exists.
      if(ownsToggle&&originalOff&&button?.isConnected&&button.getAttribute('aria-pressed')==='true')button.click();
      player=null;button=null;ownsToggle=false;attempts=0;
    }
    function sync(video,{autoEnable=true,replace=true,showingReplacement=false}={}){
      if(!supported||closed||busy)return {supported,status:'inactive'};
      busy=true;
      try{
        const next=video?.closest('.html5-video-player');
        if(next!==player){release();player=next;}
        if(!player)return {supported,status:'waiting'};
        const nextButton=player.querySelector('.ytp-subtitles-button');
        if(nextButton!==button){button=nextButton;originalOff=button?.getAttribute('aria-pressed')==='false';ownsToggle=false;attempts=0;lastAttempt=0;}
        const unavailable=button&&(button.disabled||button.getAttribute('aria-disabled')==='true'||doc.defaultView.getComputedStyle(button).display==='none');
        if(autoEnable&&button&&!unavailable&&button.getAttribute('aria-pressed')==='false'&&attempts<3&&Date.now()-lastAttempt>=750){
          attempts++;lastAttempt=Date.now();ownsToggle=originalOff;button.click();
        }
        const nodes=Array.from(player.querySelectorAll('.ytp-caption-window-container')).slice(0,8);
        const shouldHide=replace&&showingReplacement;
        for(const [node,saved]of hidden)if(!shouldHide||!nodes.includes(node)){restoreText(node,saved);hidden.delete(node);}
        if(shouldHide)for(const node of nodes){
          if(!hidden.has(node))hidden.set(node,{opacity:node.style.getPropertyValue('opacity'),priority:node.style.getPropertyPriority('opacity'),aria:node.getAttribute('aria-hidden')});
          if(node.style.getPropertyValue('opacity')!=='0'||node.style.getPropertyPriority('opacity')!=='important')node.style.setProperty('opacity','0','important');
          if(node.getAttribute('aria-hidden')!=='true')node.setAttribute('aria-hidden','true');
        }
        return {supported,status:unavailable?'unavailable':button?.getAttribute('aria-pressed')==='true'?'enabled':autoEnable?'waiting':'manual'};
      }finally{busy=false;}
    }
    return {sync,close(){if(closed)return;closed=true;release();}};
  }
  globalThis.MandarinLensYouTube=Object.freeze({create});
})();
