'use strict';
/** Local subtitle parsers and page caption discovery. No network or page code execution. */
(() => {
  const MAX_CUES=4000, PIPELINE_VERSION='1.0.0';
  const normalize = value => (typeof value==='string'?value:'').slice(0,10000).replace(/\s+/gu, ' ').trim().slice(0, 600);
  function parseClock(value) {
    const s=(typeof value==='string'?value:'').trim().replace(',', '.');
    const m=/^(?:(\d{1,3}):)?(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?$/.exec(s);
    if(!m) return null;
    const h=Number(m[1] || 0), min=Number(m[2]), sec=Number(m[3]);
    if((m[1] && min>59) || sec>59 || (!m[1] && min>999))return null;
    return h*3600+min*60+sec+(m[4]?Number(m[4].padEnd(3,'0'))/1000:0);
  }
  function decodeEntities(input) {
    return input.replace(/&(#x[0-9a-f]{1,6}|#\d{1,7}|amp|lt|gt|quot|apos|nbsp);/gi,(all,e)=>{
      const named={amp:'&',lt:'<',gt:'>',quot:'"',apos:"'",nbsp:' '};
      if(Object.hasOwn(named,e.toLowerCase()))return named[e.toLowerCase()];
      if(e[0]==='#'){
        const n=e[1].toLowerCase()==='x'?parseInt(e.slice(2),16):parseInt(e.slice(1),10);
        return n>0&&n<=0x10ffff&&!(n>=0xd800&&n<=0xdfff)?String.fromCodePoint(n):'';
      }
      return all;
    });
  }
  function normalizeSubtitle(value) {
    return normalize(decodeEntities(String(value || '').replace(/<[^>]*>/g,'')));
  }
  function validCues(cues) {
    if(!Array.isArray(cues))return [];
    const safe=cues.slice(0,MAX_CUES).filter(c=>c && typeof c==='object').map(c=>{
      const start=c.start, end=c.end, text=normalize(c.text);
      return {start,end,text};
    }).filter(c=>Number.isFinite(c.start)&&Number.isFinite(c.end)&&c.start>=0&&c.end>c.start&&c.end<=108000&&c.text);
    safe.sort((a,b)=>a.start-b.start || a.end-b.end);
    return safe;
  }
  function parseSubtitleFile(text){
    if(typeof text!=='string'||text.length>2_000_000)throw new Error('Subtitle file must be smaller than 2 MB');
    const input=text.replace(/^\uFEFF/,'').replace(/\r\n?/g,'\n');
    const blocks=input.split(/\n\s*\n/);
    const cues=[];
    for(const block of blocks){
      if(/^(?:NOTE(?:[ \t]|$)|STYLE(?:\n|$)|REGION(?:\n|$))/u.test(block.trim()))continue;
      const lines=block.split('\n');
      const index=lines.findIndex(s=>s.includes('-->'));
      if(index<0)continue;
      const [startRaw,endRaw]=lines[index].split(/\s*-->\s*/);
      const start=parseClock(startRaw);
      const end=parseClock((endRaw||'').split(/\s+/)[0]);
      if(start===null||end===null)continue;
      const caption=normalizeSubtitle(lines.slice(index+1).join(' '));
      if(start<0 || end<=start || end>108000 || !caption)continue;
      if(cues.length>=MAX_CUES)throw new Error('Subtitle files can contain up to 4,000 cues. Split this file into smaller parts.');
      cues.push({start,end,text:caption});
    }
    return validCues(cues);
  }
  function nativeCues(video,direction='en-zh'){
    if(!video)return [];
    const groups=[];
    try{
      for(const track of Array.from(video.textTracks||[])){
        if(!['subtitles','captions'].includes(track.kind) || !track.cues?.length)continue;
        const cues=Array.from(track.cues).slice(0,MAX_CUES).map(c=>({start:c.startTime,end:c.endTime,text:normalizeSubtitle(c.text)}));
        if(cues.length)groups.push({kind:track.kind,language:(track.language||'').toLowerCase(),cues});
      }
    }catch{return [];}
    // Prefer the language selected in settings: English-to-Chinese or Chinese-to-English.
    const primary=direction==='zh-en'?'zh':'en';
    groups.sort((a,b)=>Number(b.language.startsWith(primary))-Number(a.language.startsWith(primary))||b.cues.length-a.cues.length);
    const eligible=groups.filter(group=>!group.language || group.language===primary || group.language.startsWith(primary+'-'));
    return validCues(eligible[0]?.cues || []);
  }
  function transcriptCues(document){
    const panel=document.querySelector('ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-searchable-transcript"]') || document.querySelector('ytd-transcript-renderer');
    if(!panel)return [];
    const segments=Array.from(panel.querySelectorAll('ytd-transcript-segment-renderer')).slice(0,MAX_CUES);
    const lines=[];
    for(const s of segments){
      const start=parseClock(s.querySelector('.segment-timestamp')?.textContent);
      const text=normalize(s.querySelector('.segment-text')?.textContent);
      if(start!==null&&text)lines.push({start,text});
    }
    lines.sort((a,b)=>a.start-b.start);
    const cues=lines.map((line,i)=>({start:line.start,end:Math.max(line.start+.1,Math.min(line.start+8,lines[i+1]?.start || line.start+6)),text:line.text}));
    return validCues(cues);
  }
  function readPageCues(document,video,direction='en-zh'){
    const tracks=nativeCues(video,direction);
    if(tracks.length)return {source:'embedded timed subtitle track',cues:tracks};
    const transcripts=transcriptCues(document);
    if(transcripts.length)return {source:'YouTube transcript panel',cues:transcripts};
    return {source:null,cues:[]};
  }
  // An estimate only: some films intentionally have long spans without subtitles.
  // Do not claim every spoken sentence is covered by a page transcript.
  function coverage(cues,duration){
    const list=validCues(cues);
    const lastEnd=list.reduce((end,cue)=>Math.max(end,cue.end),0);
    const videoDuration=Number(duration);
    if(!list.length || !Number.isFinite(videoDuration) || videoDuration<=0)return {complete:null,lastEnd};
    return {complete:lastEnd>=videoDuration-Math.min(30,videoDuration*.05),lastEnd};
  }
  function atTime(cues,time){
    if(!Number.isFinite(time)||!cues?.length)return null;
    let low=0,high=cues.length-1,candidate=-1;
    while(low<=high){const mid=(low+high)>>1;if(cues[mid].start<=time){candidate=mid;low=mid+1;}else high=mid-1;}
    if(candidate<0)return null;
    // A short overlapping cue can end while an earlier, longer cue remains active.
    for(let i=candidate;i>=0;i--){const cue=cues[i];if(time>=cue.start && time<cue.end)return cue;}
    return null;
  }
  async function cacheKey(videoId,direction,cues,settings={}){
    if(!globalThis.crypto?.subtle)throw new Error('Secure local cache is unavailable in this browser.');
    if(typeof videoId!=='string' || !['en-zh','zh-en'].includes(direction))throw new Error('Invalid subtitle cache identity.');
    const safeSettings=Object.fromEntries(Object.entries(settings || {}).filter(([key,value])=>['string','number','boolean'].includes(typeof value)).sort(([a],[b])=>a.localeCompare(b)));
    const payload=JSON.stringify([PIPELINE_VERSION,videoId.slice(0,2048),direction,safeSettings,validCues(cues)]);
    const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(payload));
    return PIPELINE_VERSION+':'+Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join('');
  }
  globalThis.MandarinLensPreprocess=Object.freeze({PIPELINE_VERSION,MAX_CUES,cacheKey,parseClock,parseSubtitleFile,validCues,nativeCues,transcriptCues,readPageCues,coverage,atTime});
})();
