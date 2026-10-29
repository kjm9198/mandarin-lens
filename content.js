'use strict';
(() => {
  const C = globalThis.MandarinLensCore;
  const P = globalThis.MandarinLensPreprocess;
  const L = globalThis.MandarinLensLearning;
  if (!C || !P) return;
  if (globalThis.__mandarinLensInstance) {
    globalThis.__mandarinLensInstance.open();
    return;
  }

  const state = {
    ...L.DEFAULTS, direction: 'en-zh', showPinyin: true, showOriginal: true, showEnglish:true, fontSize: 18,
    hanziSize:12, englishSize:12, textOpacity:100, horizontal:50, spacing:2, backgroundBlur:0, timingOffset:0, fontFamily:'system', showHanzi:true, toneColors:false, opacity: 0, position: 8, pauseOnWord: true, autoPrepare: true,
    current: '', translation: '', enabled: false, translator: null, pendingTranslation: null,
    generation: 0, dataRevision:0,cacheRevision:0,cache: new Map(), closed: false, selected: '',
    dismissWordFocus:false,loopCue:null,loopSeeking:false,reverseTranslator: null, reverseCreating: null, watchTimer: null, boundVideo:null,boundTracks:[],mediaInitialized:false,mediaSource:null,mediaObject:null,captionSeenAt: 0,
    observer: null, captionFrame: null, hoverTimer: null, leaveTimer: null, wordPinned: false,
    sourceCues: null, sourceUrl: null, activatedAt: 0, prepared: null, preparedUrl: null, preparing: false, prepareToken: 0,
    cacheWarning:false,preparationStatus:'not-prepared',preparePaused:false, partial:[], activeCacheKey:null, sessionUrl:location.href, prepareProgress: 0, prepareTotal: 0, prepareSource: '', prepareCoverage: null, lastCue: null,
  };

  const host = document.createElement('div');
  host.id = 'mandarin-lens-root';
  host.setAttribute('data-mandarin-lens', 'true');
  host.style.cssText = 'position:fixed;inset:0;z-index:2147483646;pointer-events:none;';
  const shadow = host.attachShadow({mode:'closed'});
  const style = document.createElement('style');
  style.textContent = `
    *{box-sizing:border-box}
    #panel{--ml-size:26px;--ml-bg:rgba(8,15,25,.18);--ml-bottom:12%;font-family:var(--ml-font,system-ui,-apple-system,sans-serif);position:absolute;bottom:var(--ml-bottom);left:var(--ml-left,50%);transform:translateX(-50%);width:min(var(--ml-width,92%),920px);color:#fff;text-align:center;pointer-events:none}
    #surface{display:flex;align-items:center;flex-direction:column;gap:3px}
    #top{display:flex;justify-content:space-between;align-items:center;gap:8px;background:rgba(10,18,31,.77);border:1px solid #cedff555;border-radius:20px;padding:3px 8px;pointer-events:auto;font-size:10px;max-width:100%;opacity:.45;transition:opacity .15s}
    #surface:hover #top,#top:focus-within{opacity:1}
    #identity{display:flex;gap:6px;align-items:center;color:#e6f1ff;font-size:10px;letter-spacing:.02em}
    #badge{color:#b6d9ff;font-weight:850;font-size:13px}
    #directionLabel{color:#bcd5f1}
    #actions{display:flex;gap:4px}
    button{font:inherit;cursor:pointer}
    button:focus-visible,input:focus-visible,select:focus-visible{outline:2px solid #7fc8ff;outline-offset:2px}
    .icon{background:transparent;color:#f5f9ff;border:none;padding:3px 8px;font-size:17px;border-radius:8px}
    .icon:hover{background:#ffffff25}.icon[aria-pressed=true]{background:#b4ddff;color:#172a45}
    #main{max-height:var(--ml-height,55vh);overflow-y:auto;overscroll-behavior:contain;padding:3px 10px 5px;opacity:var(--ml-opacity,1);backdrop-filter:blur(var(--ml-blur,0px));border-radius:14px;background:var(--ml-bg);max-width:100%;pointer-events:none;text-shadow:0 1px 4px #000,0 2px 9px #000d}
    #original,#translated{max-width:100%;overflow-wrap:anywhere;line-height:1.25}
    .chinese{font-size:var(--ml-size);font-weight:700;color:#fff}
    .english{font-size:var(--ml-english,14px);font-weight:550;color:#fafcff;margin-top:5px}
    #original:empty,#translated:empty{display:none}
    .word{max-width:100%;overflow-wrap:anywhere;pointer-events:auto;display:inline-flex;flex-direction:column;vertical-align:bottom;align-items:center;border:0;background:transparent;color:inherit;margin:0 calc(var(--ml-spacing,4px) / 2);padding:1px 2px;border-radius:6px;line-height:1.08;text-shadow:inherit}
    .word:hover,.word:focus-visible,.word.selected{background:rgba(79,149,226,.33);color:#fff}
    .han{max-width:100%;font-size:var(--ml-hanzi,14px);font-weight:600;white-space:normal;line-height:1.15;opacity:.95}
    .pron{max-width:100%;font-size:var(--ml-size);font-weight:750;color:#cfebff;line-height:1.2;white-space:normal}
    .word.no-pinyin .han{font-size:var(--ml-hanzi,14px)}
    #panel.hide-hanzi .han{display:none}#panel.tone-colors .tone-1{color:#ffcfcb}#panel.tone-colors .tone-2{color:#ffe39a}#panel.tone-colors .tone-3{color:#b8efcb}#panel.tone-colors .tone-4{color:#c8d9ff}
    #top{touch-action:none}#identity{cursor:grab}#transcript{display:none;position:fixed;right:12px;top:12px;width:min(320px,90vw);max-height:70vh;overflow:auto;background:#122238f5;border:1px solid #8299b5;border-radius:12px;padding:12px;pointer-events:auto;text-align:left;font-size:13px;text-shadow:none}#transcript.show{display:block}#transcript input{width:100%;padding:8px;margin-bottom:8px}#transcript button{display:block;width:100%;text-align:left;border:0;border-bottom:1px solid #456;background:transparent;color:white;padding:8px;line-height:1.5}
    @media(prefers-contrast:more){#main,#top{background:#07111f;border:1px solid white}}@media(prefers-reduced-transparency:reduce){#main,#top{background:#07111f;backdrop-filter:none}}
    .han-char,.syllable{display:inline-block;border-radius:3px;padding:0 2px}
    .syllable+.syllable{margin-left:.12em}.han-char:hover,.syllable:hover{background:rgba(171,217,255,.3)}
    .text-bit{white-space:pre-wrap}
    #status{display:none;max-width:88vw;background:rgba(13,25,40,.92);color:#e1efff;padding:9px 12px;border-radius:11px;font-size:12px;line-height:1.5;pointer-events:auto;text-shadow:none}
    #status.show{display:block}
    #cta{display:none;pointer-events:auto;align-items:center;justify-content:center;background:#b4ddff;color:#172a45;border:0;padding:12px 18px;border-radius:12px;font-size:14px;font-weight:750;margin:8px auto 0;text-shadow:none;box-shadow:0 4px 20px #0009}
    #cta.show{display:flex}#cta:disabled{opacity:.55;cursor:progress}
    #busy{display:none;font-size:10px;letter-spacing:.02em;opacity:.75;line-height:1.5;color:#e6f5ff;text-shadow:0 1px 4px #000,0 1px 7px #000;pointer-events:none}
    #busy.show{display:block}
    #details{display:none;pointer-events:auto;margin:7px auto 0;background:rgba(248,251,255,.98);color:#19293b;padding:13px;border-radius:12px;text-align:left;box-shadow:0 8px 25px #0007;text-shadow:none;max-width:min(370px,92vw)}
    #details.show{display:block}#detailHeading{font-size:21px;font-weight:800}#detailPinyin{color:#3c6a9a;font-size:14px;margin-left:8px}#detailMeaning{font-size:13px;margin-top:6px;line-height:1.4}#detailContext{font-size:11px;color:#64758a;overflow-wrap:anywhere;margin-top:6px}
    #detailHint{font-size:10px;color:#486b92;margin-top:7px}
    .detailBtns{display:flex;gap:8px;margin-top:11px;flex-wrap:wrap}.detailBtns button{padding:7px 11px;border-radius:7px;border:1px solid #a9bdd5;background:#e8f2fd;color:#243b5d;font-weight:650;font-size:11px}
    #prepareRow{display:none;pointer-events:auto;opacity:.35;transition:opacity .15s;gap:6px;align-items:center;justify-content:center;background:rgba(12,21,35,.83);border-radius:12px;padding:5px 9px;max-width:90vw;flex-wrap:wrap;text-shadow:none}
    #prepareRow.show{display:none}#surface:hover #prepareRow.show,#surface:focus-within #prepareRow.show,#prepareRow.preparing{display:flex}#surface:hover #prepareRow,#prepareRow:focus-within,#prepareRow.preparing{opacity:1}
    #prepareRow button{font-size:11px;font-weight:650;padding:6px 10px;border-radius:7px;border:1px solid #608bb5;background:#203b59;color:#f2f8ff}
    #prepareRow button:disabled{opacity:.55}
    #prepStatus{font-size:11px;color:#c7e4ff;max-width:72vw;overflow-wrap:anywhere}
    #top button,#prepareRow button{min-height:28px}
    #prefs{display:none;pointer-events:auto;background:rgba(13,25,43,.97);border:1px solid #647992;border-radius:12px;padding:12px 15px;text-align:left;font-size:12px;color:#e6eef8;width:min(350px,92vw);margin-top:6px;text-shadow:none;box-shadow:0 8px 25px #0008}
    #prefs.show{display:block}#prefs label{display:block;margin:10px 0;line-height:1.45}
    #prefs select{background:#21354b;color:white;border:1px solid #66809d;border-radius:7px;padding:7px;margin:5px 0;width:100%}
    #prefs input[type=range]{display:block;width:100%;accent-color:#b4ddff;margin:7px 0 2px}
    #prefs input[type=checkbox]{accent-color:#b4ddff}
    #prefs{position:fixed;top:16px;left:16px;right:auto;max-height:calc(100vh - 32px);overflow-y:auto;z-index:10;margin:0;width:min(350px,92vw)}
    .range-value{float:right;color:#b9deff;font-variant-numeric:tabular-nums}
    #presets{display:flex;gap:5px;margin:9px 0 12px}#presets button{flex:1;min-height:34px;border:1px solid #587a9f;border-radius:8px;background:#1e344e;color:#e6f4ff;padding:6px 4px;font-size:11px;cursor:pointer}#presets button.active{background:#b4ddff;color:#172a45;font-weight:750}#setupHint{font-size:11px;color:#bcdcf6;line-height:1.45;margin:4px 0 6px}#prefs .toggle{display:flex;gap:8px;align-items:center}#prefs .toggle input{margin:0}#prefsTitle{font-size:13px;font-weight:750}#main:empty{display:none}@media(prefers-reduced-motion:reduce){*{transition:none!important}}
    @media(max-width:600px){#panel{width:96%}#main{padding:5px 8px}}

    #surface{position:relative;width:fit-content;max-width:calc(100% - 32px);margin:0 auto;gap:2px}
    #main{padding:2px 6px 3px;border-radius:6px;text-shadow:0 1px 3px #000,0 0 5px #000b}.han-punctuation{font-size:.95em;font-weight:500}
    .english{margin-top:2px;line-height:1.15}.pron{font-weight:600;line-height:1.1}.han{line-height:1.05}.word{padding:0 1px}.han-char,.syllable{padding:0 1px}
    #controlToggle{position:absolute;right:-24px;bottom:2px;width:24px;height:22px;padding:0;border:0;border-radius:6px;background:#0d1b2d80;color:#fff;pointer-events:auto;opacity:.35;font-size:17px;line-height:1;letter-spacing:1px}
    #controlToggle:hover,#controlToggle:focus-visible,#surface.controls-open #controlToggle{opacity:1}
    #top{display:none;position:absolute;bottom:calc(100% + 6px);left:50%;transform:translateX(-50%);width:max-content;max-width:min(90vw,350px);padding:1px 5px;gap:4px;border-radius:8px;opacity:1;z-index:2}
    #surface.controls-open #top{display:flex}#identity{font-size:9px;gap:4px}#badge{display:none}#actions{gap:1px}#top .icon{font-size:15px;padding:2px 6px;min-height:26px}
    #prepareRow.show,#surface:hover #prepareRow.show,#surface:focus-within #prepareRow.show{display:none}
    #surface.controls-open #prepareRow.show,#prepareRow.preparing{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));position:absolute;bottom:calc(100% + 38px);left:50%;transform:translateX(-50%);width:min(320px,88vw);max-width:88vw;opacity:1;z-index:3;padding:8px;gap:6px;border-radius:10px}
    #prepareRow button{font-size:11px;padding:6px 8px;min-height:32px;white-space:nowrap}#pausePrepare,#prepStatus{grid-column:1 / -1}#prepStatus{font-size:11px;line-height:1.4;text-align:center}
    #details{position:fixed;margin:0;width:max-content;max-width:260px;min-width:120px;padding:7px 9px;border-radius:8px;background:#142336f5;color:#f1f6ff;border:1px solid #ffffff26;box-shadow:0 3px 12px #0005;z-index:5;font:12px/1.3 system-ui,-apple-system,sans-serif;max-height:220px;overflow:auto}
    #detailHeading{font-size:15px;font-weight:650}#detailPinyin{font-size:12px;color:#bedcff;margin-left:6px}#detailMeaning{font-size:12px;margin-top:3px;line-height:1.3;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden}
    #detailContext,#detailHint,.detailBtns{display:none}#details.pinned .detailBtns{display:flex;gap:5px;margin-top:7px;flex-wrap:wrap}.detailBtns button{font-size:11px;font-weight:600;padding:5px 9px;border:0;border-radius:6px;background:#ffffff18;color:#eef5ff;min-height:32px}
    #details.expanded #detailContext{display:block;font-size:11px;color:#c0cfdf;margin-top:6px}#details.expanded #detailMeaning{display:block;overflow:visible}#details.expanded{max-width:min(280px,90vw)}
    #status{font-size:11px;max-width:min(320px,85vw);padding:6px 8px;border-radius:6px}#busy{font-size:9px}
    @media(max-width:600px){#main{padding:2px 4px}#controlToggle{right:-18px;width:18px}}
  `;  const panel = document.createElement('section'); panel.id = 'panel'; panel.setAttribute('aria-label', 'Mandarin Lens subtitles');
  const surface = document.createElement('div'); surface.id = 'surface';
  const top = document.createElement('div'); top.id = 'top';
  const controlToggle=document.createElement('button');controlToggle.id='controlToggle';controlToggle.textContent='···';controlToggle.title='Subtitle controls';controlToggle.setAttribute('aria-label','Subtitle controls');controlToggle.setAttribute('aria-expanded','false');
  const identity = document.createElement('div'); identity.id = 'identity';
  const badge = document.createElement('span'); badge.id = 'badge'; badge.textContent = '文';
  const title = document.createElement('span'); title.textContent = '';
  const directionLabel = document.createElement('span'); directionLabel.id = 'directionLabel';
  identity.append(badge, title, directionLabel);
  const actions = document.createElement('div'); actions.id = 'actions';
  const gear = document.createElement('button'); gear.className = 'icon'; gear.textContent = '⚙'; gear.title = 'Settings'; gear.setAttribute('aria-label','Settings');
  const close = document.createElement('button'); close.className = 'icon'; close.textContent = '×'; close.title = 'Stop and remove overlay'; close.setAttribute('aria-label','Close Mandarin Lens');
  const replay=document.createElement('button');replay.className='icon';replay.textContent='↺';replay.title='Replay current subtitle';replay.setAttribute('aria-label','Replay current subtitle');replay.hidden=true;
  const transcriptButton=document.createElement('button');transcriptButton.className='icon';transcriptButton.textContent='☷';transcriptButton.setAttribute('aria-label','Timed transcript');transcriptButton.setAttribute('aria-expanded','false');
  const loop=document.createElement('button');loop.id='loop';loop.className='icon';loop.textContent='↻';loop.hidden=true;loop.title='Loop current subtitle';loop.setAttribute('aria-label','Loop current subtitle');loop.setAttribute('aria-pressed','false');
  actions.append(replay,loop,transcriptButton,gear,close);top.append(identity,actions);
  const main = document.createElement('div');main.id='main';
  const original = document.createElement('div');original.id='original';
  const translated = document.createElement('div');translated.id='translated';
  const cta = document.createElement('button');cta.id='cta';cta.textContent='▶ Start learning';cta.setAttribute('aria-label','Start local Chinese translation');
  const busy=document.createElement('div');busy.id='busy';busy.setAttribute('role','status');busy.textContent='Translating on this device…';
  const details = document.createElement('section');details.id='details';details.setAttribute('aria-label','Chinese word explanation');
  const detailHeader = document.createElement('div');
  const detailHeading=document.createElement('span');detailHeading.id='detailHeading';
  const detailPinyin=document.createElement('span');detailPinyin.id='detailPinyin';
  detailHeader.append(detailHeading,detailPinyin);
  const detailMeaning=document.createElement('div');detailMeaning.id='detailMeaning';
  const detailContext=document.createElement('div');detailContext.id='detailContext';detailContext.style.whiteSpace='pre-line';
  const detailHint=document.createElement('div');detailHint.id='detailHint';detailHint.textContent='Click a word to keep this explanation open';
  const detailButtons=document.createElement('div');detailButtons.className='detailBtns';
  const sound=document.createElement('button');sound.textContent='Listen';sound.setAttribute('aria-label','Pronounce word');
  const save=document.createElement('button');save.textContent='Save';save.setAttribute('aria-label','Save word');
  const resume=document.createElement('button');resume.textContent='Play';resume.setAttribute('aria-label','Resume video');resume.hidden=true;
  const detailClose=document.createElement('button');detailClose.textContent='×';detailClose.setAttribute('aria-label','Close word explanation');
  const more=document.createElement('button');more.textContent='Context';more.title='Show sentence context';more.setAttribute('aria-label','Show sentence context');more.setAttribute('aria-expanded','false');
  detailButtons.append(sound,save,resume,more,detailClose);details.append(detailHeader,detailMeaning,detailContext,detailHint,detailButtons);
  main.append(original,translated,busy,cta);
  const prepRow=document.createElement('div');prepRow.id='prepareRow';
  const prepareButton=document.createElement('button');prepareButton.textContent='Prepare video first';prepareButton.title='Translate available timed subtitle cues in advance (requires an accessible full transcript or SRT/VTT)';
  const fileButton=document.createElement('button');fileButton.textContent='Import captions';fileButton.title='Import a local subtitle file to prepare the video';
  const fileInput=document.createElement('input');fileInput.type='file';fileInput.multiple=true;fileInput.accept='.srt,.vtt,text/vtt';fileInput.hidden=true;
  const prepStatus=document.createElement('span');prepStatus.id='prepStatus';prepStatus.setAttribute('role','status');
  const pausePrepare=document.createElement('button');pausePrepare.id='pausePrepare';pausePrepare.textContent='Pause preparation';pausePrepare.hidden=true;
  prepRow.append(prepareButton,fileButton,pausePrepare,fileInput,prepStatus);
  const prefs=document.createElement('div');prefs.id='prefs';
  const prefsTitle=document.createElement('div');prefsTitle.id='prefsTitle';prefsTitle.textContent='Make subtitles yours';
  const setupHint=document.createElement('div');setupHint.id='setupHint';setupHint.textContent='Changes appear instantly. Pick a preset or fine-tune below.';
  const presets=document.createElement('div');presets.id='presets';
  const presetMap={minimal:{fontSize:18,hanziSize:12,englishSize:12,opacity:0,position:8,spacing:2},balanced:{fontSize:22,hanziSize:14,englishSize:14,opacity:12,position:12,spacing:4},large:{fontSize:32,hanziSize:20,englishSize:18,opacity:32,position:16}};
  for(const [id,label] of [['minimal','Compact'],['balanced','Comfort'],['large','Large']]){const b=document.createElement('button');b.textContent=label;b.type='button';b.dataset.preset=id;b.addEventListener('click',()=>{const values=presetMap[id];Object.assign(state,values);applyAppearance();render();void chrome.storage.local.set(values);});presets.append(b);}
  const prefLang=document.createElement('label');prefLang.textContent='Source ';const select=document.createElement('select');
  for(const [value,label] of [['en-zh','English → Chinese'],['zh-en','Chinese → English']]){const option=document.createElement('option');option.value=value;option.textContent=label;select.append(option);}prefLang.append(select);
  const prefPinyin=document.createElement('label');prefPinyin.className='toggle';const checkbox=document.createElement('input');checkbox.type='checkbox';checkbox.checked=true;prefPinyin.append(checkbox,document.createTextNode(' Show pinyin below small Chinese characters'));
  const prefOriginal=document.createElement('label');prefOriginal.className='toggle';const originalBox=document.createElement('input');originalBox.type='checkbox';originalBox.checked=true;prefOriginal.append(originalBox,document.createTextNode(' Original subtitles'));
  const autoPrep=document.createElement('label');autoPrep.className='toggle';const autoPrepBox=document.createElement('input');autoPrepBox.type='checkbox';autoPrepBox.checked=true;autoPrep.append(autoPrepBox,document.createTextNode(' Prepare full captions automatically when available'));
  const pauseLabel=document.createElement('label');pauseLabel.className='toggle';const pauseBox=document.createElement('input');pauseBox.type='checkbox';pauseBox.checked=true;pauseLabel.append(pauseBox,document.createTextNode(' Pause video when I click a word'));
  const sizeLabel=document.createElement('label');sizeLabel.textContent='Subtitle size';
  const sizeOutput=document.createElement('span');sizeOutput.className='range-value';sizeOutput.id='sizeValue';
  const fontSlider=document.createElement('input');fontSlider.id='fontSize';fontSlider.type='range';fontSlider.min='14';fontSlider.max='42';fontSlider.step='1';fontSlider.value='26';
  sizeLabel.append(sizeOutput,fontSlider);
  const opacityLabel=document.createElement('label');opacityLabel.textContent='Subtitle background';
  const opacityOutput=document.createElement('span');opacityOutput.className='range-value';opacityOutput.id='opacityValue';
  const opacitySlider=document.createElement('input');opacitySlider.id='opacity';opacitySlider.type='range';opacitySlider.min='0';opacitySlider.max='80';opacitySlider.step='5';opacitySlider.value='18';
  opacityLabel.append(opacityOutput,opacitySlider);
  const positionLabel=document.createElement('label');positionLabel.textContent='Distance above bottom edge';
  const positionOutput=document.createElement('span');positionOutput.className='range-value';positionOutput.id='positionValue';
  const positionSlider=document.createElement('input');positionSlider.id='position';positionSlider.type='range';positionSlider.min='4';positionSlider.max='40';positionSlider.step='1';positionSlider.value='12';
  positionLabel.append(positionOutput,positionSlider);
  prefs.append(prefsTitle,setupHint,presets,prefLang,prefPinyin,prefOriginal,autoPrep,pauseLabel,sizeLabel,opacityLabel,positionLabel);
  const status = document.createElement('div');status.id = 'status';status.setAttribute('role','status');status.textContent = 'Turn on the video’s CC captions to start.';
  const transcript=document.createElement('section');transcript.id='transcript';transcript.setAttribute('aria-label','Timed transcript');const transcriptSearch=document.createElement('input');transcriptSearch.type='search';transcriptSearch.placeholder='Search prepared captions';transcriptSearch.setAttribute('aria-label','Search prepared captions');const transcriptLines=document.createElement('div');transcript.append(transcriptSearch,transcriptLines);
  surface.append(controlToggle,top,prepRow,main,prefs,status);panel.append(surface,transcript);shadow.append(style,panel,details,prefs);

  const extraDefaults={hanziSize:12,englishSize:12,textOpacity:100,horizontal:50,spacing:2,backgroundBlur:0,timingOffset:0,fontFamily:'system',showHanzi:true,showEnglish:true,toneColors:false};
  function applyExtraPrefs(values){
    const ranges={hanziSize:[10,32],englishSize:[10,32],textOpacity:[40,100],horizontal:[10,90],spacing:[0,16],backgroundBlur:[0,16],timingOffset:[-5,5]};
    for(const key of Object.keys(extraDefaults)){
      if(!(key in values))continue;const value=values[key];
      if(key in ranges){const n=Number(value);state[key]=Number.isFinite(n)?Math.max(ranges[key][0],Math.min(ranges[key][1],n)):extraDefaults[key];}
      else if(key==='fontFamily')state[key]=['system','serif','rounded'].includes(value)?value:'system';
      else state[key]=typeof value==='boolean'?value:extraDefaults[key];
    }
  }
  function videoIdentity(){const u=new URL(location.href);if(/(^|\.)youtube\.com$/.test(u.hostname))return 'youtube:'+(u.searchParams.get('v')||u.pathname.split('/').pop()||'video');return u.origin+u.pathname;}
  async function timedTranslate(translator,text){
    let timeout;try{return await Promise.race([translator.translate(text),new Promise((_,reject)=>{timeout=setTimeout(()=>{translator.destroy?.();if(translator===state.translator&&!state.closed)resetTranslation();reject(new Error('Translation took too long. Start learning again to retry.'));},20000);})]);}finally{clearTimeout(timeout);}
  }
  async function savePrepared(key,cues){
    if(!key||!cues.length||state.closed)return;
    const token=state.prepareToken,revision=state.dataRevision,cacheRevision=state.cacheRevision;
    try{if(token!==state.prepareToken)return;const result=await chrome.runtime.sendMessage({action:'cache-save',revision,cacheRevision,key,cues});if(token===state.prepareToken&&!state.closed)state.cacheWarning=!result?.ok;}catch{if(token===state.prepareToken&&!state.closed)state.cacheWarning=true;}if(!state.closed)updatePrepareUi();
  }
  function renderTranscript(){
    const query=transcriptSearch.value.trim().toLowerCase();const cues=(state.prepared||[]).filter(c=>!query||c.text.toLowerCase().includes(query)||c.translation.toLowerCase().includes(query));
    transcriptLines.replaceChildren();
    if(!cues.length){transcriptLines.textContent='Prepare captions first. Search and select a line to seek.';return;}
    for(const cue of cues.slice(0,200)){const b=document.createElement('button');b.textContent=`${Math.floor(cue.start/60)}:${String(Math.floor(cue.start%60)).padStart(2,'0')} · ${cue.text} · ${cue.translation}`;b.addEventListener('click',()=>{const video=currentVideo();if(video){video.currentTime=cue.start+state.timingOffset;checkCaptions();}});transcriptLines.append(b);}
    if(cues.length>200)transcriptLines.append(document.createTextNode('Showing the first 200 matches. Refine your search.'));
  }
  function positionDetails(){
    if(!details.classList.contains('show'))return;
    const anchor=state.detailAnchor?.isConnected?state.detailAnchor.getBoundingClientRect():main.getBoundingClientRect();
    const bounds=host.getBoundingClientRect();prefs.style.left=Math.max(8,bounds.left+8)+'px';prefs.style.top=Math.max(8,bounds.top+8)+'px';prefs.style.maxHeight=Math.max(60,Math.min(innerHeight-16,bounds.height-16))+'px';const left=Math.max(8,bounds.left+4),right=Math.min(innerWidth-8,bounds.right-4),top=Math.max(8,bounds.top+4),bottom=Math.min(innerHeight-8,bounds.bottom-4);
    details.style.maxWidth=Math.max(100,Math.min(details.classList.contains('expanded')?280:240,right-left))+'px';
    details.style.maxHeight=Math.max(40,bottom-top)+'px';details.style.overflowY='auto';const box=details.getBoundingClientRect(),x=Math.max(left,Math.min(right-box.width,anchor.left+anchor.width/2-box.width/2));
    let y=anchor.top-box.height-7;if(y<top)y=anchor.bottom+7;y=Math.max(top,Math.min(bottom-box.height,y));
    details.style.left=x+'px';details.style.top=y+'px';
  }
  function attach() {
    if (state.closed) return;
    const full = document.fullscreenElement;
    const parent = full || document.body || document.documentElement;
    if (parent && host.parentNode !== parent) parent.appendChild(host);
    const rect=currentVideo()?.getBoundingClientRect();
    if(rect?.width>0&&rect?.height>0){panel.style.setProperty('--ml-height',Math.max(40,Math.floor(rect.height*.55))+'px');host.style.inset='auto';host.style.left=rect.left+'px';host.style.top=rect.top+'px';host.style.width=rect.width+'px';host.style.height=rect.height+'px';}else{host.style.inset='0';host.style.width='auto';host.style.height='auto';}
    positionDetails();
  }
  function info(message){
    if(status.textContent===message)return;
    status.textContent=message;
    status.classList.toggle('show', !state.enabled || (!/^Prepared \d/u.test(message) && /error|unavailable|download|waiting|initializ|model|not supported|press|prepar|no captions|turn on CC/i.test(message)));
  }
  function applyAppearance(){
    main.style.rowGap=state.lineSpacing+'px';main.style.textAlign=state.textAlign;main.style.textShadow=state.textShadow==='none'?'none':state.textShadow==='outline'?'-1px -1px 0 #000,1px -1px 0 #000,-1px 1px 0 #000,1px 1px 0 #000':'0 1px 3px #000,0 0 2px #000';panel.style.setProperty('--ml-size', `${state.fontSize}px`);
    panel.style.setProperty('--ml-bg', `rgba(8,15,25,${state.opacity/100})`);
    panel.style.setProperty('--ml-bottom', `${state.position}%`);
    panel.style.setProperty('--ml-hanzi',`${state.hanziSize}px`);panel.style.setProperty('--ml-english',`${state.englishSize}px`);panel.style.setProperty('--ml-opacity',String(state.textOpacity/100));panel.style.setProperty('--ml-left',`${state.horizontal}%`);panel.style.setProperty('--ml-width',`${Math.min(state.horizontal,100-state.horizontal)*1.9}%`);panel.style.setProperty('--ml-spacing',`${state.spacing}px`);panel.style.setProperty('--ml-blur',`${state.backgroundBlur}px`);panel.style.setProperty('--ml-font',({system:'system-ui,-apple-system,sans-serif',serif:'Georgia,serif',rounded:'ui-rounded,system-ui,sans-serif'})[state.fontFamily]);panel.classList.toggle('hide-hanzi',!state.showHanzi);panel.classList.toggle('tone-colors',state.toneColors);
    fontSlider.value=String(state.fontSize);sizeOutput.textContent=`${state.fontSize}px`;
    opacitySlider.value=String(state.opacity);opacityOutput.textContent=`${state.opacity}%`;
    positionSlider.value=String(state.position);positionOutput.textContent=`${state.position}%`;
    for(const button of presets.querySelectorAll('button')){const v=presetMap[button.dataset.preset];const active=Object.keys(v).every(key=>v[key]===state[key]);button.classList.toggle('active',active);button.setAttribute('aria-pressed',String(active));}
  }
  function getClipText(){
    const video=currentVideo();if(!video||video.readyState===0)return '';
    const native=P.activeCaption(video,state.direction);if(native)return native;
    const player=video.closest('.html5-video-player')||video.parentElement;
    const captions=player?.querySelectorAll('.ytp-caption-window-container .ytp-caption-segment')||[];
    const parts=[];for(let i=0;i<Math.min(captions.length,32);i++)parts.push(captions[i].textContent||'');
    return C.normalize(parts.join(' '));
  }
  function tokenButton(word, isOriginal) {
    if (!C.isChinese(word)) {
      const span=document.createElement('span');span.className='text-bit';span.textContent=word;return span;
    }
    const btn=document.createElement('button');btn.className='word'+(state.showPinyin?'':' no-pinyin');btn.type='button';btn.setAttribute('aria-label',`${word} · ${C.pinyinFor(word)}. Select for meaning.`);btn.setAttribute('aria-haspopup','dialog');btn.setAttribute('aria-controls','details');
    const characters=[...word];
    const readings=C.pinyinFor(word,undefined,{sandhi:state.toneSandhi}).split(/\s+/);
    const h=document.createElement('span');h.className='han';
    characters.forEach((character,index)=>{
      const piece=document.createElement('span');piece.className='han-char';piece.textContent=character;
      piece.addEventListener('click',(event)=>{if(event.altKey){event.stopPropagation();void showWord(character,true,btn);}else{event.stopPropagation();void showWord(word,true,btn);}});
      h.append(piece);
    });
    btn.append(h);
    if(state.showPinyin){
      const p=document.createElement('span');p.className='pron';
      if(readings.length===characters.length && characters.every(ch=>C.isChinese(ch))){
        readings.forEach((syllable,index)=>{
          const piece=document.createElement('span');piece.className='syllable tone-'+(/[āēīōūǖ]/i.test(syllable)?1:/[áéíóúǘ]/i.test(syllable)?2:/[ǎěǐǒǔǚ]/i.test(syllable)?3:/[àèìòùǜ]/i.test(syllable)?4:5);piece.textContent=syllable;
          piece.addEventListener('click',(event)=>{event.stopPropagation();clearTimeout(state.leaveTimer);void showWord(event.altKey?characters[index]:word,true,btn);});
          p.append(piece);
        });
      } else {p.textContent=C.pinyinFor(word);}
      btn.append(p);
    }
    btn.addEventListener('pointerenter',()=>{
      clearTimeout(state.leaveTimer);clearTimeout(state.hoverTimer);
      if(state.interactionMode==='hover'&&!state.wordPinned)state.hoverTimer=setTimeout(()=>void showWord(word,false,btn),350);
    });
    btn.addEventListener('pointerleave',()=>{clearTimeout(state.hoverTimer);hideHoverSoon();});
    btn.addEventListener('focus',()=>{if(!state.wordPinned&&!state.dismissWordFocus)void showWord(word,false,btn);});
    btn.addEventListener('click',(event)=>{
      // Avoid replacing a character-level selection with a whole-word popup.
      if(event.target!==btn && event.target!==h && !event.target.classList.contains('pron'))return;
      clearTimeout(state.leaveTimer);void showWord(word,true,btn);
    });return btn;
  }
  function chineseLine(target,text,isOriginal=false) {
    const nodes=[];let opening='';
    for(const chunk of C.segmentChinese(text)){
      const previous=nodes[nodes.length-1];
      // Keep sentence punctuation on the Hanzi row, not hanging beside pinyin.
      if(/^[“‘「『（《【]+$/u.test(chunk)){opening+=chunk;continue;}
      if(/^[。，！？、；：,.!?;:”’」』）》】]+$/u.test(chunk) && previous?.classList?.contains('word')){
        const mark=document.createElement('span');mark.className='han-punctuation';mark.textContent=chunk;
        previous.querySelector('.han')?.append(mark);
      }else {const node=tokenButton(chunk,isOriginal);if(opening){const mark=document.createElement('span');mark.className='han-punctuation';mark.textContent=opening;const han=node.querySelector?.('.han');if(han)han.prepend(mark);else node.prepend(mark);opening='';}nodes.push(node);}
    }
    if(opening){const mark=document.createElement('span');mark.textContent=opening;nodes.push(mark);}target.replaceChildren(...nodes);
  }
  function updatePrepareUi(){
    const phase=state.preparing?(state.preparePaused?'paused':'preparing'):state.prepared?(state.prepareCoverage===true?'completed':'partial'):state.preparationStatus;prepRow.dataset.state=phase;
    prepRow.classList.toggle('show',true);prepRow.classList.toggle('preparing',state.preparing);
    pausePrepare.hidden=!state.preparing;pausePrepare.textContent=state.preparePaused?'Resume preparation':'Pause preparation';
    prepareButton.disabled=!state.enabled;loop.disabled=state.preparing;replay.disabled=state.preparing;
    prepareButton.textContent=state.preparing?'Cancel preparation':state.prepared?'Prepare again':'Prepare video first';
    if(state.preparing){prepStatus.textContent=`${state.preparePaused?'Paused':'Preparing'} ${state.prepareProgress}/${state.prepareTotal} lines · ${state.prepareTotal?Math.floor(state.prepareProgress/state.prepareTotal*100):0}%`;
    }else if(state.prepared){prepStatus.textContent=`Ready · ${state.prepared.length} timed lines${state.prepareCoverage===false?' · partial track':state.prepareCoverage==null?' · coverage unknown':''}`;
    }else if(['failed','unsupported'].includes(state.preparationStatus)){prepStatus.textContent=state.preparationStatus==='failed'?'Failed · retry preparation to resume saved lines':'Unsupported · import captions instead';}else{prepStatus.textContent=state.partial.length?`Partially prepared · ${state.partial.length}/${state.prepareTotal} lines`:'Not prepared · import captions or prepare an accessible track';}
    if(state.cacheWarning)prepStatus.textContent+=' · Cache unavailable: session only; interruption may lose progress';
  }
  function render(){
    updatePrepareUi();
    directionLabel.textContent=state.direction==='en-zh'?'EN → 中文':'中文 → EN';
    select.value=state.direction;checkbox.checked=state.showPinyin;originalBox.checked=state.showOriginal;autoPrepBox.checked=state.autoPrepare;pauseBox.checked=state.pauseOnWord;
    applyAppearance();
    original.replaceChildren();translated.replaceChildren();
    original.className=state.direction==='zh-en'?'chinese':'english';
    translated.className=state.direction==='en-zh'?'chinese':'english';
    // Chinese characters + pinyin always appear above English, in either translation direction.
    main.insertBefore(state.direction==='en-zh'?translated:original,main.firstChild);
    main.insertBefore(state.direction==='en-zh'?original:translated,(state.direction==='en-zh'?translated:original).nextSibling);
    original.style.display=state.showOriginal?'block':'none';translated.style.display='block';if(!state.showEnglish||state.shadowHideEnglish)(state.direction==='en-zh'?original:translated).style.display='none';
    busy.classList.toggle('show',Boolean(state.enabled && state.current && !state.translation));
    replay.hidden=!(state.enabled && state.prepared && state.lastCue);loop.hidden=replay.hidden&&!state.loopCue;loop.setAttribute('aria-pressed',String(Boolean(state.loopCue)));loop.setAttribute('aria-label',state.loopCue?'Stop looping subtitle':'Loop current subtitle');loop.title=state.loopCue?'Stop looping subtitle':'Loop current subtitle';
    if(!state.current)return;
    if(state.direction==='zh-en')chineseLine(original,state.current,true);
    else original.textContent=state.current;
    if(state.translation){
      if(state.direction==='en-zh')chineseLine(translated,state.translation);
      else translated.textContent=state.translation;
    }
    positionDetails();
  }
  const cacheKey=(t)=>`${state.direction}:${t}`;
  // One translation at a time per Translator instance. Coalesce fast captions into
  // the newest line, and never display stale results for a different line or mode.
  async function translateLatest() {
    const translator=state.translator;
    const generation=state.generation;
    if (!state.enabled || !translator || !state.current || state.closed) return;
    if (state.pendingTranslation?.translator===translator) return;
    const task={translator,generation};
    state.pendingTranslation=task;
    try {
      while (!state.closed && state.enabled && state.translator===translator && state.generation===generation) {
        const text=state.current;
        if (!text) break;
        const key=cacheKey(text);
        const cached=state.cache.get(key);
        if(cached){
          if(state.current===text){state.translation=cached;render();}
          break;
        }
        let result;
        try {result=C.normalize(await timedTranslate(translator,text));}
        catch(error){
          if(state.translator===translator && state.generation===generation){resetTranslation();info('Local translation stopped. Press Start learning to retry. No captions were uploaded.');}
          break;
        }
        if (state.closed || state.translator!==translator || state.generation!==generation) break;
        if(result){
          state.cache.set(key,result);
          if(state.cache.size>160)state.cache.delete(state.cache.keys().next().value);
        }
        if(state.current===text){
          state.translation=result;
          render();
          info('Local translation active · Hover over Chinese or pinyin');
          break;
        }
        // New captions replaced this line while the model was working.
        // Move straight to the newest text, skipping superseded intermediate lines.
      }
    } finally {
      if (state.pendingTranslation===task) state.pendingTranslation=null;
      if((state.translator!==translator||state.generation!==generation) && state.enabled && state.current && !state.translation) void translateLatest();
    }
  }
  function unbindVideo(){
    if(state.boundVideo){for(const event of ['play','timeupdate','seeking','seeked','ended','loadedmetadata','emptied','loadstart'])state.boundVideo.removeEventListener(event,checkCaptions);state.boundVideo.textTracks?.removeEventListener('addtrack',bindTracks);state.boundVideo.textTracks?.removeEventListener('change',checkCaptions);}
    for(const track of state.boundTracks)track.removeEventListener('cuechange',checkCaptions);state.boundTracks=[];state.boundVideo=null;
  }
  function bindTracks(){
    for(const track of Array.from(state.boundVideo?.textTracks||[]).slice(0,32))if(!state.boundTracks.includes(track)){state.boundTracks.push(track);track.addEventListener('cuechange',checkCaptions);}
  }
  function bindVideo(){
    const video=currentVideo(),source=video?(video.getAttribute('src')||video.currentSrc||''):'',object=video?.srcObject||null;
    if(state.boundVideo===video&&state.mediaSource===source&&state.mediaObject===object)return;
    const changed=state.mediaInitialized;
    unbindVideo();state.mediaInitialized=true;state.mediaSource=source;state.mediaObject=object;
    if(changed){state.generation++;invalidatePrepared();state.sourceCues=null;state.sourceUrl=null;state.current='';state.translation='';state.selected='';state.wordPinned=false;details.classList.remove('show');render();}
    if(!video)return;
    state.boundVideo=video;
    for(const event of ['play','timeupdate','seeking','seeked','ended','loadedmetadata','emptied','loadstart'])video.addEventListener(event,checkCaptions);
    video.textTracks?.addEventListener('addtrack',bindTracks);video.textTracks?.addEventListener('change',checkCaptions);bindTracks();
  }
  function nativeSignature(){return Array.from(currentVideo()?.textTracks||[]).filter(t=>['subtitles','captions'].includes(t.kind)).slice(0,32).map(t=>[t.language,t.mode,t.cues?.length||0,t.cues?.[0]?.text||'',t.cues?.[t.cues.length-1]?.text||''].join(':')).join('|');}
  function currentVideo(){
    const videos=document.querySelectorAll('video'),candidates=[],full=document.fullscreenElement;
    for(let i=0;i<Math.min(videos.length,32);i++){
      const video=videos[i];if(!video.isConnected)continue;
      const rect=video.getBoundingClientRect(),style=getComputedStyle(video);
      candidates.push({video,visible:style.display!=='none'&&style.visibility!=='hidden'&&style.visibility!=='collapse'&&Number(style.opacity)!==0,
        area:Math.max(0,rect.width)*Math.max(0,rect.height),visibleArea:Math.max(0,Math.min(innerWidth,rect.right)-Math.max(0,rect.left))*Math.max(0,Math.min(innerHeight,rect.bottom)-Math.max(0,rect.top)),
        fullscreen:Boolean(full&&(full===video||full.contains(video))),playing:!video.paused&&!video.ended,current:video===state.boundVideo});
    }
    return P.selectVideo(candidates);
  }
  const shadowButton=document.createElement('button');shadowButton.type='button';shadowButton.textContent='Shadow';shadowButton.title='Listen once, practise, then reveal English';shadowButton.className='icon';shadowButton.id='shadowSentence';actions.append(shadowButton);
  const shadowPractice=document.createElement('div');shadowPractice.id='shadowPractice';shadowPractice.hidden=true;shadowPractice.style.cssText='pointer-events:auto;background:#142336;padding:6px;border-radius:6px;font:12px system-ui;color:white';
  const shadowLabel=document.createElement('span');shadowLabel.textContent='Practise aloud. ';
  const revealEnglish=document.createElement('button');revealEnglish.textContent='Reveal English';revealEnglish.type='button';
  const continueShadow=document.createElement('button');continueShadow.textContent='Continue';continueShadow.type='button';shadowPractice.append(shadowLabel,revealEnglish,continueShadow);surface.append(shadowPractice);
  revealEnglish.addEventListener('click',()=>{state.shadowHideEnglish=false;render();});
  continueShadow.addEventListener('click',()=>{state.shadowWaiting=false;state.shadowHideEnglish=false;shadowPractice.hidden=true;render();void currentVideo()?.play().catch(()=>info('Press Play to continue.'));});
  shadowButton.addEventListener('click',()=>{if(!state.lastCue){info('Prepare timed captions to practise a sentence.');return;}replay.click();state.remaining=1;state.shadowActive=true;});
  function stopLoop(){if(state.replayVideo&&state.originalSpeed!==undefined)state.replayVideo.playbackRate=state.originalSpeed;state.replayVideo=null;state.originalSpeed=undefined;state.remaining=null;state.shadowActive=false;state.loopCue=null;state.loopSeeking=false;loop.setAttribute('aria-pressed','false');loop.setAttribute('aria-label','Loop current subtitle');loop.title='Loop current subtitle';}
  function invalidatePrepared(){
    state.nativePreparedSignature=null;state.preparationStatus='not-prepared';stopLoop();state.shadowWaiting=false;state.shadowHideEnglish=false;shadowPractice.hidden=true;state.partial=[];
    state.prepareToken++;state.preparePaused=false;state.resumePrepare?.();state.resumePrepare=null;
    state.preparing=false;
    state.prepared=null;
    state.preparedUrl=null;
    state.prepareProgress=0;
    state.prepareTotal=0;
    state.prepareCoverage=null;state.lastCue=null;
    renderTranscript();updatePrepareUi();
  }
  async function prepareVideo(){
    try{await prepareVideoJob();}catch{if(!state.closed){invalidatePrepared();info('Could not prepare captions on this page. Try an HTTPS video page and prepare again.');}}
  }
  async function prepareVideoJob(){
    if(state.preparing){const key=state.activeCacheKey,completed=state.partial.slice(),total=state.prepareTotal;invalidatePrepared();state.partial=completed;state.prepareTotal=total;state.prepareProgress=completed.length;state.preparationStatus=completed.length?'partial':'not-prepared';updatePrepareUi();info('Preparation canceled. Completed lines can resume when you prepare again.');await savePrepared(key,completed);return;}
    if(state.sourceCues?.every(c=>c.translation)&&state.sourceUrl===location.href){state.prepared=state.sourceCues;state.preparedUrl=location.href;state.enabled=true;setCta(false);checkCaptions();updatePrepareUi();return;}
    if(!state.enabled || !state.translator){info('Select Start learning first, then prepare the video.');return;}
    const url=location.href;
    let source=state.sourceCues && state.sourceUrl===url?
      {source:'imported subtitle file',cues:state.sourceCues}:P.readPageCues(document,currentVideo(),state.direction);
    if(!source.cues.length){
      state.preparationStatus='unsupported';updatePrepareUi();info('No timed subtitle track found. On YouTube open “Show transcript” and press Prepare again, or import an SRT/VTT file. Live CC still works.');
      return;
    }
    if(source.cues.length>4000){info('Subtitle track is too long (maximum 4,000 cues).');return;}
    const token=++state.prepareToken;
    stopLoop();state.cacheWarning=false;state.partial=[];state.preparing=true;state.preparePaused=false;updatePrepareUi();
    const key=await P.cacheKey(videoIdentity(),state.direction,source.cues);
    if(token!==state.prepareToken||state.closed)return;
    state.activeCacheKey='prepared:'+key;
    const stored=await chrome.storage.local.get(state.activeCacheKey).catch(()=>({}));
    if(token!==state.prepareToken||state.closed)return;
    const saved=stored[state.activeCacheKey];
    const resumed=[];
    if(Array.isArray(saved?.cues))for(let i=0;i<Math.min(saved.cues.length,source.cues.length);i++){const c=saved.cues[i],expected=source.cues[i];if(!c||c.start!==expected.start||c.end!==expected.end||c.text!==expected.text||typeof c.translation!=='string'||!c.translation.length||c.translation.length>600)break;resumed.push({...expected,translation:c.translation});}
    const translator=state.translator;
    const generation=state.generation;
    state.prepared=null;state.preparedUrl=null;
    const coverage=P.coverage(source.cues,currentVideo()?.duration);
    state.preparing=true;state.prepareProgress=resumed.length;state.prepareTotal=source.cues.length;state.prepareSource=source.source;state.prepareCoverage=coverage.complete;
    updatePrepareUi();
    // Preload is a user-controlled operation. If video is playing, pause it now.
    const video=currentVideo();if(video && !video.paused)video.pause();
    // Yield periodically to keep settings and cancel controls responsive.
    const prepared=resumed;state.partial=prepared;
    for(let i=prepared.length;i<source.cues.length;i++){
      while(state.preparePaused && token===state.prepareToken && !state.closed)await new Promise(resolve=>{state.resumePrepare=resolve;});
      if(state.closed||token!==state.prepareToken||generation!==state.generation||translator!==state.translator||url!==location.href)break;
      const cue=source.cues[i],key=cacheKey(cue.text);
      let translation=state.cache.get(key);
      if(!translation){
        try{translation=C.normalize(await timedTranslate(translator,cue.text));}
        catch(error){
          if(token===state.prepareToken){await savePrepared(state.activeCacheKey,prepared);if(token===state.prepareToken&&!state.closed){resetTranslation();state.preparationStatus='failed';updatePrepareUi();info('Preparation stopped. Press Start learning, then prepare again to resume completed lines.');}}
          return;
        }
        if(translation){state.cache.set(key,translation);if(state.cache.size>5000)state.cache.delete(state.cache.keys().next().value);}
      }
      if(!translation){if(token===state.prepareToken)info('Preparation stopped: one subtitle could not be translated.');break;}
      if(token!==state.prepareToken||state.closed||url!==location.href||generation!==state.generation)break;
      prepared.push({...cue,translation});
      if(prepared.length%20===0)await savePrepared(state.activeCacheKey,prepared);
      state.prepareProgress=i+1;
      if(i%8===0 || i===source.cues.length-1){updatePrepareUi();await new Promise(resolve=>setTimeout(resolve,0));}
    }
    if(token!==state.prepareToken)return;
    await savePrepared(state.activeCacheKey,prepared);
    if(token!==state.prepareToken||state.closed)return;
    state.preparing=false;
    if(prepared.length===source.cues.length){
      state.prepared=prepared;state.preparedUrl=url;state.nativePreparedSignature=state.sourceCues?null:nativeSignature();
      info(`Prepared ${prepared.length} timed subtitles from ${source.source}. Press Play for pretranslated captions.${coverage.complete===false?' This track may not cover the entire video.':''}`);
      checkCaptions();
    }else if(!state.closed){
      state.preparationStatus='partial';info(`Preparation incomplete: ${prepared.length}/${source.cues.length} subtitles translated. Live captions remain available.`);
    }
    renderTranscript();updatePrepareUi();
  }
  function updateCaption(raw, translated=null){
    const text=C.normalize(raw);
    if(!text)return;
    const nextTranslation=translated===null?(state.cache.get(cacheKey(text))||''):translated;
    if(text===state.current && nextTranslation===state.translation)return;
    state.current=text;state.translation=nextTranslation;
    state.captionSeenAt=Date.now();
    if(!state.wordPinned){clearTimeout(state.hoverTimer);details.classList.remove('show');}
    render();
    if(state.enabled && translated===null){status.classList.remove('show');if(!state.preparing)void translateLatest();}
    else if(!state.enabled)info('Captions found! Press Start learning to show Chinese and pinyin.');
  }
  function checkCaptions(event){
    if(state.closed)return;
    if(event?.type==='play')state.pausedForWord=null;
    attach();bindVideo();
    if(state.prepared&&state.nativePreparedSignature!==null&&state.nativePreparedSignature!==undefined&&state.nativePreparedSignature!==nativeSignature()){invalidatePrepared();state.current='';state.translation='';info('Caption track changed. Prepare the newly selected captions again.');render();}
    if(state.sessionUrl!==location.href){state.sessionUrl=location.href;state.generation++;invalidatePrepared();state.current='';state.translation='';state.selected='';details.classList.remove('show');render();}
    if(state.prepared && state.preparedUrl===location.href){
      const video=currentVideo();
      if(video&&state.loopCue){
        const start=Math.max(0,state.loopCue.start+state.timingOffset),end=state.loopCue.end+state.timingOffset;
        if(event?.type==='seeking'&&!state.loopSeeking&&(video.currentTime<start-.1||video.currentTime>=end))stopLoop();
        if(event?.type==='seeked'){
          if(!state.loopSeeking&&(video.currentTime<start-.1||video.currentTime>=end))stopLoop();
          state.loopSeeking=false;
        }
        if(state.loopCue&&(!video.paused||video.ended)&&!video.seeking&&video.currentTime>=end){if(state.remaining!==null&&--state.remaining<=0){const shadowing=state.shadowActive;stopLoop();if(shadowing){video.pause();video.currentTime=Math.max(start,end-.05);state.shadowWaiting=true;state.shadowHideEnglish=true;shadowPractice.hidden=false;render();}return;}const ended=video.ended;state.loopSeeking=true;video.currentTime=start+.01;if(ended)void video.play().catch(()=>info('Press Play to continue looping this subtitle.'));}
      }
      const cue=video?P.atTime(state.prepared,video.currentTime-state.timingOffset):null;
      if(cue){state.lastCue=cue;updateCaption(cue.text,cue.translation);loop.hidden=false;}else loop.hidden=!state.loopCue;
      if(!cue){state.lastCue=null;if(state.current){state.current='';state.translation='';render();}}
      return;
    }
    if(state.prepared && state.preparedUrl!==location.href)invalidatePrepared();
    if(state.sourceCues && state.sourceUrl!==location.href){state.sourceCues=null;state.sourceUrl=null;}
    if(!state.enabled)return;
    const text=getClipText();
    if(text)updateCaption(text);
    else if(state.current && Date.now()-state.captionSeenAt > 1100){
      state.current='';state.translation='';
      if(!state.wordPinned){clearTimeout(state.hoverTimer);details.classList.remove('show');}
      render();
    } else if(!state.current && state.enabled && Date.now()-state.activatedAt>2600){
      info('No captions detected. Turn on CC in the video, or import an SRT/VTT file. Audio-only transcription is not available yet.');
    } else if(!state.current && !state.enabled)info('Turn on CC and press Start learning.');
  }
  function setCta(show){cta.classList.toggle('show',show);}
  async function startLocalTranslation(){
    if(state.closed)return;
    if(typeof globalThis.Translator==='undefined'||typeof globalThis.Translator.create!=='function'){
      info('This Chrome version or device cannot translate locally. Try desktop Chrome 138+ and check Chrome language packs. We will never send your captions to a server.');setCta(false);return;
    }
    const startGeneration=state.generation,startDirection=state.direction;
    cta.disabled=true;cta.textContent='Preparing Mandarin…';
    info('Setting up private translation on this device. The first time may download a language pack…');
    try {
      // create() is initiated inside the user click handler, with a user activation.
      const pair=C.options(state.direction);
      if(typeof globalThis.Translator.availability==='function'){const availability=await globalThis.Translator.availability(pair);if(availability==='unavailable')throw new Error('This device does not support the chosen language pair');}
      const trans=await globalThis.Translator.create({
        ...pair, monitor(m){
          m.addEventListener('downloadprogress',e=>{
            info(`Downloading language pack locally: ${Math.round(e.loaded*100)}%`);
          });
        }
      });
      if(state.closed||startGeneration!==state.generation||startDirection!==state.direction){trans.destroy?.();return;}
      state.translator?.destroy?.();state.translator=trans;state.generation++;state.enabled=true;state.activatedAt=Date.now();
      setCta(false);render();info('Ready! Click Chinese or pinyin for meanings. Translation stays on your device.');
      if(state.current)void translateLatest();
      // Do not unexpectedly stop playback: automatic full-video preparation only when paused.
      if(state.autoPrepare && currentVideo()?.paused){const found=state.sourceCues?.length?{cues:state.sourceCues}:P.readPageCues(document,currentVideo(),state.direction);if(found.cues?.length)void prepareVideo();}
    }catch(error){
      if(state.closed||startGeneration!==state.generation)return;
      state.enabled=false;
      setCta(true);
      info(`Chrome could not start the local model: ${error.message || 'device/language pack unavailable'}. No cloud fallback.`);
    }finally{
      cta.disabled=false;cta.textContent='▶ Start learning';
    }
  }
  function resetTranslation(){
    state.generation++;invalidatePrepared();
    if(state.sourceCues?.[0]?.chinese)state.sourceCues=state.sourceCues.map(c=>({...c,text:state.direction==='en-zh'?c.english:c.chinese,translation:state.direction==='en-zh'?c.chinese:c.english}));
    state.translator?.destroy?.();state.translator=null;
    state.enabled=false;state.translation='';state.selected='';state.wordPinned=false;details.classList.remove('show');
    setCta(true);render();
    if(state.sourceCues?.[0]?.chinese){state.prepared=state.sourceCues;state.preparedUrl=state.sourceUrl;state.enabled=true;state.prepareCoverage=P.coverage(state.sourceCues,currentVideo()?.duration).complete;setCta(false);checkCaptions();renderTranscript();info('Paired captions ready in the selected direction. No translation model needed.');}else info('Select Start learning to load the chosen language pair.');
  }
  function hideHoverSoon(){
    if(state.wordPinned)return;
    clearTimeout(state.leaveTimer);
    state.leaveTimer=setTimeout(()=>{if(!state.wordPinned){clearTimeout(state.hoverTimer);details.classList.remove('show');}},340);
  }
  async function showWord(word,pinned,anchor){
    if(anchor){if(state.detailAnchor!==anchor)state.detailAnchor?.removeAttribute('aria-describedby');state.detailAnchor=anchor;anchor.setAttribute('aria-describedby','detailMeaning');}
    if(pinned){state.wordPinned=true;const video=currentVideo();if(state.mode==='learn' && state.pauseOnWord && video && !video.paused){state.pausedForWord=video;video.pause();resume.hidden=false;}else resume.hidden=true;}
    else if(state.wordPinned)return;
    state.selected=word;
    detailHeading.textContent=word;
    detailPinyin.textContent=C.pinyinFor(word);
    const found=C.meaning(word);
    detailMeaning.textContent=found || 'No offline dictionary entry yet. Click for an optional local lookup.';
    const entry=C.lookup(word),sentence=state.direction==='en-zh'?state.translation:state.current,note=L.explain(word,sentence);detailContext.textContent=[entry.traditional!==entry.simplified?'Traditional: '+entry.traditional:'',note.wordClass,note.context,note.grammar,note.example?note.example+' — '+note.translation:'',entry.uncertain?'Multiple readings or an unfamiliar word: this reading may need context.':'', 'Sentence: '+sentence,'Alt-click a character for character lookup.'].filter(Boolean).join('\n\n');
    if(pinned){const tools=document.createElement('div');tools.style.cssText='display:flex;gap:4px;flex-wrap:wrap;margin-top:8px';
      const sentenceVoice=document.createElement('button');sentenceVoice.type='button';sentenceVoice.textContent='Hear sentence';sentenceVoice.addEventListener('click',()=>pronounce(sentence));
      const sentenceReplay=document.createElement('button');sentenceReplay.type='button';sentenceReplay.textContent='Replay sentence';sentenceReplay.disabled=!state.lastCue;sentenceReplay.addEventListener('click',()=>replay.click());tools.append(sentenceVoice,sentenceReplay);
      for(const char of [...word].filter(C.isChinese)){const button=document.createElement('button');button.type='button';button.textContent=char;button.setAttribute('aria-label','Character lookup: '+char);button.addEventListener('click',()=>void showWord(char,true,state.detailAnchor));tools.append(button);}detailContext.append(tools);
    }
    detailHint.textContent=pinned?'Pinned • Close to dismiss':'Hover preview • Click word to pin';
    save.textContent='Save';
    details.setAttribute('role',pinned?'dialog':'tooltip');details.classList.toggle('pinned',Boolean(pinned));details.classList.remove('expanded');more.setAttribute('aria-expanded','false');
    details.classList.add('show');positionDetails();if(pinned){state.selectionContext={chinese:sentence,english:state.direction==='en-zh'?state.current:state.translation,timestamp:Math.max(0,currentVideo()?.currentTime||0)};sound.focus({preventScroll:true});}
    if(!pinned||found)return;
    try {
      if(!state.reverseTranslator){
        if(typeof globalThis.Translator==='undefined')throw new Error('unsupported');
        state.reverseCreating ||= globalThis.Translator.create({sourceLanguage:'zh',targetLanguage:'en'});
        const reverse=await state.reverseCreating;
        if(state.closed){reverse.destroy?.();state.reverseCreating=null;return;}
        state.reverseTranslator=reverse;
      }
      const meaning=C.normalize(await timedTranslate(state.reverseTranslator,word));
      if(!state.closed && state.selected===word){detailMeaning.textContent=meaning || 'No meaning available for this word.';positionDetails();}
    } catch {
      if(state.selected===word)detailMeaning.textContent='No local definition found. Chrome’s on-device Chinese → English pack may be unavailable.';
      state.reverseCreating=null;
    }
  }
  async function saveWord(){
    if(!state.selected||state.closed)return;
    const chinese=state.selectionContext?.chinese||(state.direction==='en-zh'?state.translation:state.current),english=state.selectionContext?.english||(state.direction==='en-zh'?state.current:state.translation);
    const entry={word:state.selected.slice(0,100),pinyin:C.pinyinFor(state.selected),meaning:detailMeaning.textContent.slice(0,2000),traditional:C.lookup(state.selected).traditional,example:C.normalize(chinese),exampleTranslation:C.normalize(english),timestamp:state.selectionContext?.timestamp??Math.max(0,currentVideo()?.currentTime||0),savedAt:Date.now()};
    const url=new URL(location.href),id=url.searchParams.get('v')||url.pathname.split('/').pop();if(/(^|\.)youtube\.com$/u.test(url.hostname)&&/^[A-Za-z0-9_-]{6,20}$/u.test(id||''))entry.sourceId='youtube:'+id;
    try{const result=await chrome.runtime.sendMessage({action:'save-word',revision:state.dataRevision,entry});if(!state.closed)save.textContent=result.ok?(result.saved?'Saved':'Already saved'):result.error;}catch{if(!state.closed)save.textContent='Could not save';}
  }
  function pronounce(text){
    const synth=globalThis.speechSynthesis;
    const spokenText=typeof text==='string'?text:state.selected;if(!synth||!spokenText){info('Speech synthesis is not available.');return;}
    const voices=synth.getVoices();
    // Avoid silently invoking a potentially cloud-backed speech service.
    const voice=voices.find(v=>v.localService&&/^(zh|cmn)/i.test(v.lang));
    if(!voice){info('No installed LOCAL Mandarin voice found. Install a Chinese system voice to use pronunciation safely.');return;}
    const utterance=new SpeechSynthesisUtterance(spokenText);utterance.voice=voice;utterance.lang='zh-CN';utterance.rate=state.pronunciationRate;let left=state.pronunciationRepeats;utterance.onend=()=>{if(--left>0&&!state.closed)synth.speak(utterance);};
    synth.cancel();synth.speak(utterance);
  }
  function closeOverlay(){
    state.closed=true;invalidatePrepared();
    clearTimeout(state.watchTimer);unbindVideo();
    state.observer?.disconnect();cancelAnimationFrame(state.captionFrame);
    clearTimeout(state.hoverTimer);clearTimeout(state.leaveTimer);
    document.removeEventListener('fullscreenchange',attach);window.removeEventListener('resize',attach);window.removeEventListener('scroll',attach,true);
    chrome.storage.onChanged?.removeListener(onStorageChanged);
    state.generation++;
    state.translator?.destroy?.();state.reverseTranslator?.destroy?.();globalThis.speechSynthesis?.cancel();
    host.remove();
    delete globalThis.__mandarinLensInstance;
  }
  function open(){
    if(state.closed)return;
    attach();panel.hidden=false;
    void chrome.storage.local.get({direction:'en-zh',showPinyin:true,showOriginal:true,fontSize:18,hanziSize:12,englishSize:12,opacity:0,position:8,pauseOnWord:true,autoPrepare:true,...extraDefaults,...L.DEFAULTS,compactLayoutVersion:0,dataRevision:0,cacheEpoch:0}).then(async v=>{
      Object.assign(state,L.preferences(v));state.dataRevision=v.dataRevision;state.cacheRevision=v.cacheEpoch;
      const patch=C.compactAppearance(v);if(Object.keys(patch).length){await chrome.storage.local.set(patch);Object.assign(v,patch);}
      if(state.closed)return;
      const next=C.isDirection(v.direction)?v.direction:'en-zh';
      if(state.direction!==next){state.direction=next;resetTranslation();}
      state.showPinyin=Boolean(v.showPinyin);state.showOriginal=Boolean(v.showOriginal);
      state.fontSize=Math.max(14,Math.min(42,Number(v.fontSize)||26));
      state.opacity=Math.max(0,Math.min(80,Number.isFinite(Number(v.opacity))?Number(v.opacity):12));
      applyExtraPrefs(v);state.position=Math.max(4,Math.min(40,Number(v.position)||12));state.pauseOnWord=Boolean(v.pauseOnWord);state.autoPrepare=Boolean(v.autoPrepare);render();
    }).catch(()=>{if(!state.closed)info('Settings could not load. Reopen Mandarin Lens to retry.');});
  }
  pausePrepare.addEventListener('click',()=>{state.preparePaused=!state.preparePaused;if(!state.preparePaused){state.resumePrepare?.();state.resumePrepare=null;}updatePrepareUi();if(state.preparePaused)void savePrepared(state.activeCacheKey,state.partial.slice());});
  transcriptButton.addEventListener('click',()=>{const visible=transcript.classList.toggle('show');transcriptButton.setAttribute('aria-expanded',String(visible));renderTranscript();if(visible)transcriptSearch.focus();});
  transcriptSearch.addEventListener('input',renderTranscript);
  let drag=null;identity.addEventListener('pointerdown',e=>{if(e.button!==0)return;drag={x:e.clientX,y:e.clientY,left:state.horizontal,bottom:state.position};identity.setPointerCapture(e.pointerId);});
  identity.addEventListener('pointermove',e=>{if(!drag)return;state.horizontal=Math.max(10,Math.min(90,drag.left+(e.clientX-drag.x)/(host.clientWidth||innerWidth)*100));state.position=Math.max(4,Math.min(40,drag.bottom-(e.clientY-drag.y)/(host.clientHeight||innerHeight)*100));applyAppearance();});
  identity.addEventListener('pointerup',()=>{if(!drag)return;drag=null;void chrome.storage.local.set({horizontal:Math.round(state.horizontal),position:Math.round(state.position)});});
  identity.addEventListener('pointercancel',()=>{drag=null;});
  prepareButton.addEventListener('click',()=>{void prepareVideo();});
  fileButton.addEventListener('click',()=>fileInput.click());
  fileInput.addEventListener('change',async()=>{
    const importGeneration=state.generation,importUrl=location.href,importVideo=currentVideo();const files=Array.from(fileInput.files||[]);fileInput.value='';if(!files.length)return;
    if(files.length>2||files.some(f=>f.size>2_000_000)){info('Choose one caption file or two aligned Chinese/English files, each smaller than 2 MB.');return;}
    try{
      const tracks=await Promise.all(files.map(async f=>P.parseSubtitleFile(await f.text())));
      if(state.closed||state.generation!==importGeneration||location.href!==importUrl||currentVideo()!==importVideo)return;
      if(tracks.some(c=>!c.length))throw Error('No timed subtitles in this file');
      invalidatePrepared();state.sourceUrl=location.href;
      if(tracks.length===2){const paired=P.pairCues(...tracks,state.direction);state.sourceCues=paired.cues;state.activeCacheKey='prepared:'+await P.cacheKey(videoIdentity(),state.direction,paired.cues);await savePrepared(state.activeCacheKey,paired.cues);if(state.closed||state.generation!==importGeneration||location.href!==importUrl)return;state.prepared=paired.cues;state.preparedUrl=location.href;state.enabled=true;state.prepareCoverage=paired.matched===paired.total&&P.coverage(paired.cues,currentVideo()?.duration).complete;setCta(false);info(`Paired ${paired.matched}/${paired.total} lines locally. No translation model needed. Unmatched lines are omitted.`);checkCaptions();renderTranscript();render();}
      else{state.sourceCues=tracks[0];info(`Imported ${tracks[0].length} private caption lines. Choose Prepare video first to translate them.`);}
    }catch(error){info(`Could not read subtitles: ${error?.message||'Invalid file'}`);}
  });
  controlToggle.addEventListener('click',()=>{const visible=surface.classList.toggle('controls-open');controlToggle.setAttribute('aria-expanded',String(visible));if(visible){clearTimeout(state.hoverTimer);state.wordPinned=false;details.classList.remove('show');}else{prefs.classList.remove('show');gear.setAttribute('aria-expanded','false');}});
  more.addEventListener('click',()=>{const expanded=details.classList.toggle('expanded');more.setAttribute('aria-expanded',String(expanded));positionDetails();});
  gear.addEventListener('click',()=>{const open=prefs.classList.toggle('show');gear.setAttribute('aria-expanded',String(open));});
  loop.addEventListener('click',()=>{if(state.loopCue){stopLoop();render();return;}const video=currentVideo();if(!video||!state.lastCue)return;state.loopCue={...state.lastCue};state.loopSeeking=true;video.currentTime=Math.max(0,state.loopCue.start+state.timingOffset)+.01;render();void video.play().catch(()=>info('Press Play on the video to loop this subtitle.'));});
  replay.addEventListener('click',()=>{const video=currentVideo();if(!video||!state.lastCue)return;stopLoop();state.originalSpeed=video.playbackRate;state.replayVideo=video;state.remaining=state.repeatCount;state.loopCue={...state.lastCue};state.loopSeeking=true;video.playbackRate=state.repeatSpeed;video.currentTime=Math.max(0,state.lastCue.start+state.timingOffset+.02);void video.play().catch(()=>info('Press Play on the video to replay the line.'));});
  resume.addEventListener('click',()=>{const video=currentVideo();if(video)void video.play().catch(()=>info('Press Play on the video to continue.'));resume.hidden=true;});
  autoPrepBox.addEventListener('change',()=>{state.autoPrepare=autoPrepBox.checked;void chrome.storage.local.set({autoPrepare:state.autoPrepare});});
  pauseBox.addEventListener('change',()=>{state.pauseOnWord=pauseBox.checked;void chrome.storage.local.set({pauseOnWord:state.pauseOnWord});});
  close.addEventListener('click',closeOverlay);
  cta.addEventListener('click',startLocalTranslation);
  details.addEventListener('pointerenter',()=>clearTimeout(state.leaveTimer));
  details.addEventListener('pointerleave',hideHoverSoon);
  function resumeDismissed(){if(state.resumeOnDismiss&&state.pausedForWord===currentVideo())void state.pausedForWord.play().catch(()=>{});state.pausedForWord=null;}
  detailClose.addEventListener('click',()=>{resumeDismissed();state.wordPinned=false;details.classList.remove('show');state.dismissWordFocus=true;if(state.detailAnchor?.isConnected)state.detailAnchor.focus({preventScroll:true});state.dismissWordFocus=false;});
  shadow.addEventListener('keydown',event=>{
    if(['ArrowLeft','ArrowRight'].includes(event.key)&&event.target.classList?.contains('word')){const words=[...main.querySelectorAll('.word')],index=words.indexOf(event.target);words[(index+(event.key==='ArrowRight'?1:words.length-1))%words.length]?.focus();event.preventDefault();return;}
    if(event.key!=='Escape')return;
    let focus;
    if(details.classList.contains('show')){resumeDismissed();state.wordPinned=false;details.classList.remove('show');focus=state.detailAnchor?.isConnected?state.detailAnchor:main.querySelector('.word');}
    else if(prefs.classList.contains('show')){prefs.classList.remove('show');gear.setAttribute('aria-expanded','false');focus=gear;}
    else if(transcript.classList.contains('show')){transcript.classList.remove('show');transcriptButton.setAttribute('aria-expanded','false');focus=transcriptButton;}
    else if(surface.classList.contains('controls-open')){surface.classList.remove('controls-open');controlToggle.setAttribute('aria-expanded','false');focus=controlToggle;}
    else return;
    event.preventDefault();event.stopPropagation();state.dismissWordFocus=true;focus?.focus();state.dismissWordFocus=false;
  });
  sound.addEventListener('click',pronounce);
  save.addEventListener('click',saveWord);
  select.addEventListener('change',()=>{
    if(!C.isDirection(select.value))return;
    state.direction=select.value;
    void chrome.storage.local.set({direction:state.direction});
    resetTranslation();
  });
  checkbox.addEventListener('change',()=>{state.showPinyin=checkbox.checked;void chrome.storage.local.set({showPinyin:state.showPinyin});render();});
  originalBox.addEventListener('change',()=>{state.showOriginal=originalBox.checked;void chrome.storage.local.set({showOriginal:state.showOriginal});render();});
  fontSlider.addEventListener('input',()=>{state.fontSize=Number(fontSlider.value);applyAppearance();void chrome.storage.local.set({fontSize:state.fontSize});});
  opacitySlider.addEventListener('input',()=>{state.opacity=Number(opacitySlider.value);applyAppearance();void chrome.storage.local.set({opacity:state.opacity});});
  positionSlider.addEventListener('input',()=>{state.position=Number(positionSlider.value);applyAppearance();void chrome.storage.local.set({position:state.position});});
  // Popup changes take effect immediately while a tab overlay is already open.
  const onStorageChanged=(changes,area)=>{
    if(area!=='local'||state.closed)return;
    const prefs={...state};for(const key of Object.keys(L.DEFAULTS))if(key in changes)prefs[key]=changes[key].newValue;Object.assign(state,L.preferences(prefs));const next=changes.direction?.newValue;
    if(C.isDirection(next) && next!==state.direction){state.direction=next;resetTranslation();}
    if('showPinyin' in changes)state.showPinyin=Boolean(changes.showPinyin.newValue);
    if('showOriginal' in changes)state.showOriginal=Boolean(changes.showOriginal.newValue);
    if('autoPrepare' in changes)state.autoPrepare=Boolean(changes.autoPrepare.newValue);
    if('pauseOnWord' in changes)state.pauseOnWord=Boolean(changes.pauseOnWord.newValue);
    if('fontSize' in changes)state.fontSize=Math.max(14,Math.min(42,Number(changes.fontSize.newValue)||26));
    if('opacity' in changes){const v=Number(changes.opacity.newValue);state.opacity=Number.isFinite(v)?Math.max(0,Math.min(80,v)):12;}
    if('position' in changes)state.position=Math.max(4,Math.min(40,Number(changes.position.newValue)||12));
    if('dataEpoch' in changes){closeOverlay();return;}
    if('cacheEpoch' in changes){state.cacheRevision=changes.cacheEpoch.newValue||0;invalidatePrepared();state.cache.clear();state.current='';state.translation='';render();checkCaptions();}
    if(state.activeCacheKey && state.activeCacheKey in changes && !changes[state.activeCacheKey].newValue)invalidatePrepared();
    for(const key of Object.keys(extraDefaults))if(key in changes)applyExtraPrefs({[key]:changes[key].newValue??extraDefaults[key]});
    render();
  };
  chrome.storage.onChanged?.addListener(onStorageChanged);
  document.addEventListener('fullscreenchange',attach);window.addEventListener('resize',attach,{passive:true});window.addEventListener('scroll',attach,{passive:true,capture:true});
  globalThis.__mandarinLensInstance={open,close:closeOverlay,snapshot:()=>({enabled:state.enabled,mode:state.mode,status:status.textContent,preparing:state.preparing,completed:state.prepareProgress,total:state.prepareTotal})};
  setCta(true);
  open();
  // Captions often mutate several times per second. React on the next animation frame,
  // without adding repeated translation requests for unchanged text.
  state.observer=new MutationObserver((mutations)=>{
    if(state.closed||state.captionFrame)return;
    if(!mutations.some(m=>{
      if(m.type==='childList')for(const nodes of [m.addedNodes,m.removedNodes])for(let i=0;i<Math.min(nodes.length,32);i++){
        const element=nodes[i];if(element.nodeType===1&&(element.matches('video,source')||element.querySelector('video,source')))return true;
      }
      const node=m.target.nodeType===1?m.target:m.target.parentElement;
      return node?.closest?.('.ytp-caption-window-container');
    }))return;
    state.captionFrame=requestAnimationFrame(()=>{state.captionFrame=null;checkCaptions();});
  });
  state.observer.observe(document.documentElement,{subtree:true,childList:true,characterData:true});
  // Fallback for sites with native HTML5 TextTracks (not rendered as DOM nodes).
  function tick(){if(state.closed)return;checkCaptions();state.watchTimer=setTimeout(tick,state.enabled && state.prepared && !currentVideo()?.paused?100:1500);}
  state.watchTimer=setTimeout(tick,1500);
  info('1. Turn on CC in the video.  2. Press Start learning. For no-delay playback, prepare the transcript first.');
  checkCaptions();
})();
