'use strict';
// Real MV3 extension runtime, temporary browser profile, local fixtures.
// Test-only manifest adds localhost access and an inert worker for discovery.
// Translation rendering tests explicitly replace Translator; never claim model quality.
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),http=require('node:http'),assert=require('node:assert/strict');
const playwrightPath=process.env.PLAYWRIGHT_MODULE || '/Users/kjm9198/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
let playwright;try{playwright=require('playwright');}catch{playwright=require(playwrightPath);}const {chromium}=playwright;
const fsSync=require('node:fs');
const {execFileSync}=require('node:child_process'),{createHash}=require('node:crypto');
function chromiumExecutable(){if(process.env.CHROMIUM_EXECUTABLE)return process.env.CHROMIUM_EXECUTABLE;const bundled=chromium.executablePath();if(fsSync.existsSync(bundled))return bundled;const cache=path.join(os.homedir(),'Library/Caches/ms-playwright');if(fsSync.existsSync(cache)){for(const build of fsSync.readdirSync(cache).filter(name=>/^chromium-\d+$/.test(name)).sort((a,b)=>Number(b.split('-')[1])-Number(a.split('-')[1]))){const executable=path.join(cache,build,'chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing');if(fsSync.existsSync(executable))return executable;}}return bundled;}
const root=path.resolve(__dirname,'..'),output=path.join(root,'output/playwright');
(async()=>{
 await fs.mkdir(output,{recursive:true});
 const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'mandarin-lens-browser-')),extension=path.join(temporary,'extension');await fs.mkdir(extension);
 execFileSync(process.env.PYTHON || 'python3',[path.join(root,'scripts/package.py')],{stdio:'pipe'});
 const sourceManifest=await fs.readFile(path.join(root,'manifest.json'));
 const archive=path.join(root,'dist',`mandarin-lens-${JSON.parse(sourceManifest).version}.zip`),archiveBytes=await fs.readFile(archive);
 const packageSha256=createHash('sha256').update(archiveBytes).digest('hex');
 execFileSync(process.env.PYTHON || 'python3',['-c','import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])',archive,extension]);
 assert.deepEqual(await fs.readFile(path.join(extension,'manifest.json')),sourceManifest);
 const manifest=JSON.parse(await fs.readFile(path.join(extension,'manifest.json'),'utf8'));
 manifest.host_permissions=['http://127.0.0.1/*'];
 await fs.writeFile(path.join(extension,'manifest.json'),JSON.stringify(manifest));await fs.writeFile(path.join(extension,'test-discovery-worker.js'),'// Test-only worker; no listeners or privileged operations.\n');
 const fixture=await fs.readFile(path.join(__dirname,'fixtures/real-video.html'));
 const media=await fs.readFile(path.join(__dirname,'fixtures/video.webm'));
 const server=http.createServer((req,res)=>{if(req.url.split('?')[0]==='/video.webm'){const m=/bytes=(\d+)-(\d*)/.exec(req.headers.range||'');const start=m?Number(m[1]):0,end=m?.[2]?Math.min(Number(m[2]),media.length-1):media.length-1;if(start>=media.length){res.writeHead(416);res.end();return;}res.writeHead(m?206:200,{'Content-Type':'video/webm','Accept-Ranges':'bytes','Content-Length':end-start+1,...(m?{'Content-Range':`bytes ${start}-${end}/${media.length}`}:{})});res.end(media.subarray(start,end+1));return;}res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(fixture);});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 let context;const report={label:'Real Chromium MV3 integration with local generated video; translation rendering uses an explicit test double',testOnlyManifestChanges:['localhost host permission replaces browser-toolbar activeTab gesture in automation','distribution storage worker also enables test extension discovery'],packageSha256,packageFile:path.basename(archive),checks:[],translator:null,errors:[],screenshotNotes:{'popup.png':'Actual packaged popup, persisted customization','overlay-clean.png':'Local generated-video fixture and explicit Translator double; not a real-model translation-quality claim','overlay.png':'Malicious imported-subtitle test evidence; explicit Translator double'}};
 try{
  context=await chromium.launchPersistentContext(path.join(temporary,'profile'),{channel:'chromium',executablePath:chromiumExecutable(),headless:true,args:[`--disable-extensions-except=${extension}`,`--load-extension=${extension}`],viewport:{width:1280,height:800}});
  let worker=context.serviceWorkers()[0];if(!worker)worker=await context.waitForEvent('serviceworker');const id=new URL(worker.url()).host;
  await worker.evaluate(()=>chrome.storage.local.set({fontSize:22,hanziSize:14,englishSize:14,opacity:12,position:12,spacing:4,vocabulary:[{word:'旧',pinyin:'jiù',meaning:'old'}]}));
  const popup=await context.newPage();await popup.goto(`chrome-extension://${id}/popup.html`);await popup.locator('#start:not([disabled])').waitFor();
  report.browser=context.browser().version();report.extensionVersion=manifest.version;
  assert.equal(await popup.locator('#fontSize').inputValue(),'18');assert.equal(await popup.evaluate(async()=>(await chrome.storage.local.get('vocabulary')).vocabulary[0].word),'旧');report.checks.push('Previous default appearance migrates to Compact without deleting existing vocabulary');
  await popup.getByRole('button',{name:'Compact',exact:true}).click();assert.equal(await popup.locator('#fontSize').inputValue(),'18');
  await popup.locator('#advanced summary').click();await popup.locator('#fontSize').fill('28');await popup.locator('#fontSize').dispatchEvent('input');
  await popup.waitForFunction(async()=> (await chrome.storage.local.get('fontSize')).fontSize===28);
  await popup.getByText('Learning & data',{exact:true}).click();popup.once('dialog',dialog=>dialog.dismiss());await popup.locator('#deleteData').click();assert.equal(await popup.evaluate(async()=> (await chrome.storage.local.get('fontSize')).fontSize),28);report.checks.push('Canceling data deletion preserves saved customization');
  await popup.reload();await popup.locator('#start:not([disabled])').waitFor();assert.equal(await popup.locator('#fontSize').inputValue(),'28');report.checks.push('Popup preset and customization persist in actual chrome.storage.local');
  await popup.setViewportSize({width:360,height:760});assert(await popup.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await popup.screenshot({path:path.join(output,'popup.png'),fullPage:true});report.checks.push('Popup has no horizontal overflow at 360px');
  await popup.getByRole('button',{name:'Compact',exact:true}).click();
  const page=await context.newPage();page.on('pageerror',error=>report.errors.push(error.message));await page.goto(`http://127.0.0.1:${server.address().port}/video`);
  await page.evaluate(()=>{
   const video=document.querySelector('video:not(#hidden-ad)');video.textTracks[0].mode='disabled';
   const hidden=document.createElement('video');hidden.id='hidden-ad';hidden.style.display='none';document.querySelector('main').prepend(hidden);
   for(const [kind,language,text]of [['metadata','en','metadata should never appear'],['captions','fr','French should never appear'],['captions','en','I want to drink coffee.']]){const track=video.addTextTrack(kind,'Test '+language,language);track.mode='hidden';track.addCue(new VTTCue(0,12,text));}
  });
  await page.evaluate(()=>{document.querySelector('video:not(#hidden-ad)').currentTime=.1;});await page.waitForFunction(()=>!document.querySelector('video:not(#hidden-ad)').seeking);
  await page.waitForFunction(()=>Array.from(document.querySelector('video:not(#hidden-ad)').textTracks).slice(1).every(track=>track.activeCues?.length===1));
  const target=await popup.evaluate(async()=> (await chrome.tabs.query({})).find(tab=>tab.url?.startsWith('http://127.0.0.1/'))?.id).catch(()=>null);
  const tabId=target || await popup.evaluate(async()=> (await chrome.tabs.query({})).find(tab=>tab.url?.startsWith('http://127.0.0.1:')).id);
  async function inject(files){return popup.evaluate(async({tabId,files})=>chrome.scripting.executeScript({target:{tabId},files}),{tabId,files});}
  await inject(['data/pinyin.js','data/lexicon.js','core.js','preprocess.js','learning.js','content.js']);await page.locator('#mandarin-lens-root').waitFor();
  assert.ok(await page.evaluate(()=>{const video=document.querySelector('video:not(#hidden-ad)').getBoundingClientRect(),host=document.querySelector('#mandarin-lens-root').getBoundingClientRect();return Math.abs(video.top-host.top)<1&&Math.abs(video.height-host.height)<1;}));report.checks.push('Overlay anchors to visible main video when the first video is hidden');
  const cdp=await context.newCDPSession(page);
  async function shadowObject(){const {root:tree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});function find(node){if(node.attributes?.includes('mandarin-lens-root'))return node;for(const child of [...(node.children||[]),...(node.shadowRoots||[])]){const found=find(child);if(found)return found;}}const host=find(tree);assert(host?.shadowRoots?.[0]);return (await cdp.send('DOM.resolveNode',{nodeId:host.shadowRoots[0].nodeId})).object.objectId;}
  async function shadow(fn,arg){const objectId=await shadowObject();const result=await cdp.send('Runtime.callFunctionOn',{objectId,functionDeclaration:`function(arg){return (${fn.toString()})(this,arg)}`,arguments:[{value:arg}],returnByValue:true,awaitPromise:true});if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));return result.result.value;}
  report.translator=await popup.evaluate(async tabId=> (await chrome.scripting.executeScript({target:{tabId},func:async()=>{if(typeof Translator==='undefined')return {present:false};try{return {present:true,availability:await Translator.availability({sourceLanguage:'en',targetLanguage:'zh'})};}catch(error){return {present:true,error:error.message};}}}))[0].result,tabId);
  if(!report.translator.present || report.translator.availability==='unavailable'){
   await shadow(root=>root.querySelector('#cta').click());await page.waitForTimeout(100);assert.match(await shadow(root=>root.querySelector('#status').textContent),/cannot translate locally|does not support|could not start/i);report.checks.push('Actual unsupported Translator environment shows a local-only fallback without downloading a model');
  }else report.checks.push('Actual Translator availability inspected only; model creation/download deliberately not triggered');
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.Translator=undefined;}}),tabId);await shadow(root=>root.querySelector('#cta').click());assert.match(await shadow(root=>root.querySelector('#status').textContent),/cannot translate locally/);report.checks.push('Explicit API-absent test double verifies unsupported-device message');
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.Translator={availability:async()=> 'available',create:async()=>({translate:async text=>{if(globalThis.__slowPrepare)await new Promise(resolve=>setTimeout(resolve,250));if(globalThis.__failNext){globalThis.__failNext=false;throw Error('Synthetic local-model failure');}if(Number.isInteger(globalThis.__failAfter)&&--globalThis.__failAfter===0){delete globalThis.__failAfter;throw Error('Synthetic preparation failure');}return text.includes('Chinese')?'我学习中文。':'我想喝咖啡。';},destroy(){}})};}}),tabId);
  await popup.evaluate(()=>chrome.storage.local.set({autoPrepare:false}));
  await shadow(root=>root.querySelector('#cta').click());await page.waitForTimeout(200);
  for(let attempt=0;attempt<30;attempt++){if((await shadow(root=>[...root.querySelectorAll('#main .han')].map(el=>el.textContent).join(''))).includes('咖啡'))break;await page.waitForTimeout(100);}
  assert.match(await shadow(root=>root.querySelector('#original').textContent),/I want to drink coffee/);assert.doesNotMatch(await shadow(root=>root.querySelector('#original').textContent),/metadata|French/);report.checks.push('Live captions use matching-language subtitles instead of active metadata or French tracks');
  const learningTokens=await shadow(root=>({words:[...root.querySelectorAll('#main .word')].map(el=>(el.querySelector('.han')?.textContent||'').replace(/[。，！？、；：,.!?;:]+$/u,'')),punctuation:[...root.querySelectorAll('#main .han-punctuation')].map(el=>el.textContent)}));
  assert.deepEqual(learningTokens.words,['我','想','喝','咖啡']);assert.deepEqual(learningTokens.punctuation,['。']);
  report.checks.push('Chinese word grouping separates 我 and 想, preserves 咖啡, and displays punctuation with Hanzi');
  const compactBefore=await shadow(root=>{const b=root.querySelector('#main').getBoundingClientRect();return {top:b.top,left:b.left,width:b.width,height:b.height,toolbar:getComputedStyle(root.querySelector('#top')).display};});
  assert.equal(compactBefore.toolbar,'none');assert.ok(compactBefore.height<=66,JSON.stringify(compactBefore));
  const wordRect=await shadow(root=>{const word=[...root.querySelectorAll('.word')].find(w=>w.querySelector('.han')?.textContent==='喝');const b=word.getBoundingClientRect();return {x:b.x+b.width/2,y:b.y+b.height/2};});
  await page.mouse.move(wordRect.x,wordRect.y);await page.waitForTimeout(450);
  const hover=await shadow(root=>{const card=root.querySelector('#details'),b=card.getBoundingClientRect(),m=root.querySelector('#main').getBoundingClientRect();return {width:b.width,height:b.height,show:card.classList.contains('show'),pinned:card.classList.contains('pinned'),mainTop:m.top,mainHeight:m.height,actions:getComputedStyle(card.querySelector('.detailBtns')).display,toolbar:getComputedStyle(root.querySelector('#top')).display};});
  assert.equal(hover.show,true);assert.equal(hover.pinned,false);assert.ok(hover.height<=72&&hover.width<=240,JSON.stringify(hover));assert.equal(hover.actions,'none');assert.equal(hover.toolbar,'none');assert.ok(Math.abs(hover.mainTop-compactBefore.top)<.5&&Math.abs(hover.mainHeight-compactBefore.height)<.5);
  await page.screenshot({path:path.join(output,'compact-hover.png')});
  await page.mouse.click(wordRect.x,wordRect.y);await page.waitForTimeout(100);
  const pinned=await shadow(root=>{const d=root.querySelector('#details'),b=d.getBoundingClientRect(),m=root.querySelector('#main').getBoundingClientRect();return {height:b.height,width:b.width,pinned:d.classList.contains('pinned'),mainTop:m.top,mainHeight:m.height};});
  assert.equal(pinned.pinned,true);assert.ok(pinned.height<=160&&pinned.width<=260,JSON.stringify(pinned));assert.ok(Math.abs(pinned.mainTop-compactBefore.top)<.5);
  await page.screenshot({path:path.join(output,'compact-pinned.png')});await shadow(root=>root.querySelector('#details .detailBtns button[aria-label="Show sentence context"]').click());await page.screenshot({path:path.join(output,'v2-context.png')});await shadow(root=>root.querySelector('#details .detailBtns button[aria-label="Show sentence context"]').click());
  await page.screenshot({path:path.join(output,'compact-detail.png'),clip:{x:390,y:480,width:500,height:190}});
  for(const width of [540,320]){
    await page.setViewportSize({width,height:600});await page.waitForTimeout(100);
    const bounds=await shadow(root=>{const d=root.querySelector('#details').getBoundingClientRect(),m=root.querySelector('#main').getBoundingClientRect();return {left:d.left,right:d.right,top:d.top,bottom:d.bottom,mainHeight:m.height};});
    assert.ok(bounds.left>=0&&bounds.right<=width&&bounds.top>=0&&bounds.bottom<=600,JSON.stringify(bounds));
    assert.ok(bounds.mainHeight<=66,JSON.stringify(bounds));
  }
  await page.setViewportSize({width:1280,height:800});await page.waitForTimeout(100);
  report.checks.push('Compact popovers stay within the viewport at 540px and 320px widths');
  await shadow(root=>root.querySelector('[aria-label="Close word explanation"]').click());await page.mouse.move(10,10);await page.waitForTimeout(400);
  report.compactGeometry={subtitle:compactBefore,hover,pinned};report.checks.push('Compact subtitles stay below 66px for the fixture; hover and pinned cards are bounded and never move subtitles or reveal the toolbar');
  await shadow(root=>root.querySelector('#controlToggle').click());assert.equal(await shadow(root=>getComputedStyle(root.querySelector('#top')).display),'flex');await shadow(root=>root.querySelector('#controlToggle').click());
  report.checks.push('One small control explicitly opens and closes the toolbar; caption hovering leaves it hidden');
  await page.screenshot({path:path.join(output,'overlay-clean.png')});
  // CDP sets the real hidden input's file list without exposing closed shadow roots to webpages.
  const {root:tree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});function findInput(node){if(node.nodeName==='INPUT'&&node.attributes?.includes('file'))return node;for(const child of [...(node.children||[]),...(node.shadowRoots||[])]){const found=findInput(child);if(found)return found;}}const input=findInput(tree);assert(input);await cdp.send('DOM.setFileInputFiles',{nodeId:input.nodeId,files:[path.join(__dirname,'fixtures/untrusted.srt')]});
  await page.waitForTimeout(150);assert.match(await shadow(root=>root.querySelector('#status').textContent),/Imported 2/);
  await shadow(root=>[...root.querySelectorAll('#prepareRow button')][0].click());
  for(let attempt=0;attempt<30;attempt++){if((await shadow(root=>root.querySelector('#status').textContent)).includes('Prepared 2'))break;await page.waitForTimeout(100);}
  assert.match(await shadow(root=>root.querySelector('#status').textContent),/Prepared 2/);
  assert.equal(await shadow(root=>root.querySelectorAll('img,script').length),0);assert.equal(await page.evaluate(()=>window.__injected),undefined);assert.match(await shadow(root=>[...root.querySelectorAll('#main .han')].map(el=>el.textContent).join('')),/我想喝咖啡/);
  report.checks.push('Real SRT file input, preparation and synchronized initial overlay render with explicit test Translator');report.checks.push('Encoded malicious subtitle remains inert text; no injected element or handler executes');
  await page.screenshot({path:path.join(output,'overlay.png')});
  await shadow(root=>root.querySelector('[aria-label="Timed transcript"]').click());assert.match(await shadow(root=>root.querySelector('#transcript').textContent),/I am learning Chinese/);report.checks.push('Timed transcript renders imported prepared cues');
  // Exercise real media looping; model output remains explicitly simulated.
  await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').pause());
  await shadow(root=>root.querySelector('#loop').click());
  await page.waitForFunction(()=>!document.querySelector('video:not(#hidden-ad)').paused);
  await page.evaluate(()=>{document.querySelector('video:not(#hidden-ad)').currentTime=4.9;});
  await page.waitForFunction(()=>!document.querySelector('video:not(#hidden-ad)').seeking);
  await page.waitForTimeout(500);
  assert.equal(await shadow(root=>root.querySelector('#loop').getAttribute('aria-pressed')),'true');
  assert.ok(await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').currentTime<2));
  await page.evaluate(()=>{document.querySelector('video:not(#hidden-ad)').currentTime=8;});
  await page.waitForFunction(()=>!document.querySelector('video:not(#hidden-ad)').seeking);await page.waitForTimeout(100);
  assert.equal(await shadow(root=>root.querySelector('#loop').getAttribute('aria-pressed')),'false');
  await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').pause());
  report.checks.push('Sentence loop wraps real media and releases on manual seek outside its cue');
  await shadow(root=>root.querySelector('#loop').click());
  await page.waitForFunction(()=>!document.querySelector('video:not(#hidden-ad)').paused);
  await page.evaluate(()=>{document.querySelector('video:not(#hidden-ad)').currentTime=11.9;});
  await page.waitForFunction(()=>!document.querySelector('video:not(#hidden-ad)').seeking);await page.waitForTimeout(500);
  assert.ok(await page.evaluate(()=>{const v=document.querySelector('video:not(#hidden-ad)');return !v.paused&&v.currentTime>=5&&v.currentTime<7;}));
  await shadow(root=>root.querySelector('#loop').click());await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').pause());
  report.checks.push('Looping the final sentence resumes after the media reaches its natural end');
  await shadow(root=>root.querySelector('#transcript input').focus());await page.keyboard.press('Escape');
  assert.equal(await shadow(root=>root.querySelector('#transcript').classList.contains('show')),false);
  await shadow(root=>{root.querySelector('[aria-label="Settings"]').click();root.querySelector('#prefs select').focus();});await page.keyboard.press('Escape');
  assert.equal(await shadow(root=>root.querySelector('#prefs').classList.contains('show')),false);
  await shadow(root=>{root.querySelector('.word').click();root.querySelector('#details .detailBtns button').focus();});await page.keyboard.press('Escape');
  assert.equal(await shadow(root=>root.querySelector('#details').classList.contains('show')),false);
  report.checks.push('Escape dismisses transcript, settings and word details without reopening them on restored focus');
  await popup.evaluate(()=>chrome.storage.local.set({vocabulary:[{word:'你好',pinyin:'nǐ hǎo',meaning:'hello'}]}));
  await popup.locator('#learningData summary').click();await popup.locator('#clearCache:not([disabled])').waitFor();await popup.locator('#clearCache').click();
  await popup.waitForFunction(async()=>!Object.keys(await chrome.storage.local.get(null)).some(key=>key.startsWith('prepared:')));
  const retained=await popup.evaluate(()=>chrome.storage.local.get(['fontSize','vocabulary']));assert.equal(retained.fontSize,18);assert.equal(retained.vocabulary[0].word,'你好');
  await page.locator('#mandarin-lens-root').waitFor();await popup.waitForFunction(()=>document.querySelector('#cacheUsage').textContent.includes('0 saved tracks'));
  await popup.screenshot({path:path.join(output,'popup-storage.png'),fullPage:true});report.checks.push('Cache-only deletion removes prepared tracks while keeping saved words, appearance and active overlay');
  const shortFile=path.join(temporary,'checkpoint.srt');await fs.writeFile(shortFile,'1\n00:00:00,000 --> 00:00:03,000\nCheckpoint one.\n\n2\n00:00:03,000 --> 00:00:06,000\nCheckpoint two.\n\n3\n00:00:06,000 --> 00:00:09,000\nCheckpoint three.\n');
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.__slowPrepare=true;}}),tabId);
  const {root:refreshedTree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});const refreshedInput=findInput(refreshedTree);assert(refreshedInput);await cdp.send('DOM.setFileInputFiles',{nodeId:refreshedInput.nodeId,files:[shortFile]});await page.waitForTimeout(100);
  await shadow(root=>root.querySelector('#prepareRow button').click());
  for(let i=0;i<30;i++){if((await shadow(root=>root.querySelector('#prepStatus').textContent)).includes('1/3'))break;await page.waitForTimeout(40);}
  assert.match(await shadow(root=>root.querySelector('#prepStatus').textContent),/1\/3/);assert.equal(await shadow(root=>root.querySelector('#loop').disabled),true);
  await shadow(root=>root.querySelector('#prepareRow button').click());
  await popup.waitForFunction(async()=>Object.entries(await chrome.storage.local.get(null)).some(([key,value])=>key.startsWith('prepared:')&&value.cues?.length===1));
  await page.waitForTimeout(350);
  assert.equal(await popup.evaluate(async()=>Object.entries(await chrome.storage.local.get(null)).find(([key])=>key.startsWith('prepared:'))[1].cues.length),1);
  await shadow(root=>root.querySelector('#prepareRow button').click());
  for(let i=0;i<40;i++){if((await shadow(root=>root.querySelector('#status').textContent)).includes('Prepared 3'))break;await page.waitForTimeout(100);}
  assert.match(await shadow(root=>root.querySelector('#status').textContent),/Prepared 3/);
  report.checks.push('Cancel before the twentieth line saves its completed prefix, ignores the stale in-flight result and can resume');
  await page.evaluate(()=>{const v=document.querySelector('video:not(#hidden-ad)');v.src='/video.webm?switched=1';v.load();});
  await page.waitForFunction(()=>document.querySelector('video:not(#hidden-ad)').readyState>=2);await page.waitForTimeout(200);
  assert.doesNotMatch(await shadow(root=>root.querySelector('#prepStatus').textContent),/Ready/);
  assert.doesNotMatch(await shadow(root=>root.querySelector('#transcript').textContent),/Checkpoint one/);
  report.checks.push('Changing the same video element source at the same page URL invalidates prepared/imported captions');
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.__failNext=true;}}),tabId);
  await page.evaluate(()=>{const v=document.querySelector('video:not(#hidden-ad)');v.textTracks[v.textTracks.length-1].cues[0].text='Recovering from a local failure.';document.querySelector('.ytp-caption-segment').textContent='Recovering from a local failure.';v.currentTime=.1;v.dispatchEvent(new Event('timeupdate'));});
  for(let i=0;i<40;i++){if(await shadow(root=>root.querySelector('#cta').classList.contains('show')))break;await page.waitForTimeout(100);}
  if(!(await shadow(root=>root.querySelector('#status').textContent)).includes('Press Start learning to retry'))console.log('RECOVERY_DIAGNOSTIC',JSON.stringify(await popup.evaluate(async tabId=>(await chrome.scripting.executeScript({target:{tabId},func:()=>{const v=document.querySelector('video:not(#hidden-ad)');return {failNext:globalThis.__failNext,ready:v.readyState,time:v.currentTime,tracks:Array.from(v.textTracks).map(t=>({kind:t.kind,lang:t.language,mode:t.mode,cues:t.cues?.length,active:t.activeCues?.length})),native:MandarinLensPreprocess.activeCaption(v,'en-zh'),dom:v.parentElement.querySelector('.ytp-caption-segment')?.textContent};}}))[0].result,tabId)));
  assert.match(await shadow(root=>root.querySelector('#status').textContent),/Press Start learning to retry/);
  await shadow(root=>root.querySelector('#cta').click());
  for(let i=0;i<40;i++){if((await shadow(root=>root.querySelector('#main .han')?.textContent||'')))break;await page.waitForTimeout(100);}
  assert.equal(await shadow(root=>root.querySelector('#cta').classList.contains('show')),false);
  assert.match(await shadow(root=>root.querySelector('#translated').textContent),/咖啡/);
  report.checks.push('An actual rejected live translation exposes a retry control and resumes after reactivation');
  const failFile=path.join(temporary,'failure.srt');await fs.writeFile(failFile,'1\n00:00:00,000 --> 00:00:03,000\nFailure one.\n\n2\n00:00:03,000 --> 00:00:06,000\nFailure two.\n\n3\n00:00:06,000 --> 00:00:09,000\nFailure three.\n');
  const {root:failureTree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});await cdp.send('DOM.setFileInputFiles',{nodeId:findInput(failureTree).nodeId,files:[failFile]});await page.waitForTimeout(100);
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.__failAfter=2;}}),tabId);
  await shadow(root=>root.querySelector('#prepareRow button').click());
  for(let i=0;i<40;i++){if((await shadow(root=>root.querySelector('#status').textContent)).includes('Preparation stopped.'))break;await page.waitForTimeout(100);}
  assert.match(await shadow(root=>root.querySelector('#status').textContent),/prepare again to resume/);
  assert.ok(await popup.evaluate(async()=>Object.entries(await chrome.storage.local.get(null)).some(([key,value])=>key.startsWith('prepared:')&&value.cues?.length===1&&value.cues[0].text==='Failure one.')));
  await shadow(root=>root.querySelector('#cta').click());await page.waitForTimeout(400);await shadow(root=>root.querySelector('#prepareRow button').click());
  for(let i=0;i<40;i++){if((await shadow(root=>root.querySelector('#status').textContent)).includes('Prepared 3'))break;await page.waitForTimeout(100);}
  assert.match(await shadow(root=>root.querySelector('#status').textContent),/Prepared 3/);
  report.checks.push('Preparation model failure preserves completed lines and offers retry/resume without a page refresh');
  await page.evaluate(()=>{const old=document.querySelector('video:not(#hidden-ad)'),next=old.cloneNode(false);next.src='/video.webm?replaced=1';old.replaceWith(next);});
  for(let i=0;i<40;i++){if(!(await shadow(root=>root.querySelector('#prepStatus').textContent)).includes('Ready'))break;await page.waitForTimeout(50);}
  assert.doesNotMatch(await shadow(root=>root.querySelector('#prepStatus').textContent),/Ready/);
  assert.doesNotMatch(await shadow(root=>root.querySelector('#transcript').textContent),/Failure one/);
  report.checks.push('Replacing a media element at the same page URL clears its old preparation and transcript');
  await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').pause());await cdp.send('Performance.enable');
  const perfBefore=await cdp.send('Performance.getMetrics'),idleStart=Date.now();await page.waitForTimeout(20000);const perfAfter=await cdp.send('Performance.getMetrics');
  const metric=(set,name)=>set.metrics.find(m=>m.name===name)?.value||0;report.performance={condition:'20-second paused original-video fixture, overlay active; translation double, renderer metrics only',elapsedMs:Date.now()-idleStart,rendererTaskSeconds:metric(perfAfter,'TaskDuration')-metric(perfBefore,'TaskDuration'),rendererJSHeapBytes:metric(perfAfter,'JSHeapUsedSize'),platform:process.platform,architecture:process.arch};
  await page.emulateMedia({reducedMotion:'reduce'});assert.equal(await shadow(root=>getComputedStyle(root.querySelector('#top')).transitionDuration),'0s');await page.emulateMedia({reducedMotion:'no-preference'});
  await page.evaluate(()=>document.querySelector('main').requestFullscreen());await page.waitForTimeout(150);assert.equal(await page.evaluate(()=>document.querySelector('#mandarin-lens-root').parentNode===document.fullscreenElement),true);await page.screenshot({path:path.join(output,'v2-fullscreen.png')});await page.evaluate(()=>document.exitFullscreen());
  for(const [name,brightness]of [['bright',4],['dark',.15]]){await page.evaluate(value=>document.querySelector('video:not(#hidden-ad)').style.filter=`brightness(${value})`,brightness);await page.screenshot({path:path.join(output,`v2-${name}.png`)});}await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').style.filter='none');
  report.checks.push('Reduced motion disables transitions; fullscreen player-container anchoring and bright/dark original-media screenshots verified');
  // V2: exercise actual storage worker, review page and offline paired-caption route.
  const vocabularyPage=await context.newPage();await vocabularyPage.goto(`chrome-extension://${id}/vocabulary.html`);
  await vocabularyPage.waitForFunction(()=>!document.querySelector('#count').textContent.includes('Loading'));
  await vocabularyPage.locator('#practiceOpen').click();await vocabularyPage.locator('#practiceQuestion').waitFor({state:'visible'});
  assert.match(await vocabularyPage.locator('#practiceQuestion').textContent(),/你好/);await vocabularyPage.locator('#practiceReveal').click();assert.match(await vocabularyPage.locator('#practiceFeedback').textContent(),/hello/);
  await vocabularyPage.locator('#practiceClose').click();await vocabularyPage.close();report.checks.push('Actual vocabulary page opens an accessible practice dialog and reveals a saved flashcard');
  const pairedZh=path.join(temporary,'chinese.srt'),pairedEn=path.join(temporary,'english.srt');await fs.writeFile(pairedZh,'1\n00:00:00,000 --> 00:00:02,000\n我想喝咖啡。\n');await fs.writeFile(pairedEn,'1\n00:00:00,000 --> 00:00:02,000\nI would like coffee.\n');
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.Translator=undefined;}}),tabId);
  const {root:pairedTree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});await cdp.send('DOM.setFileInputFiles',{nodeId:findInput(pairedTree).nodeId,files:[pairedZh,pairedEn]});
  await page.evaluate(()=>{const v=document.querySelector('video:not(#hidden-ad)');v.pause();v.currentTime=.2;});await page.waitForTimeout(300);
  assert.match(await shadow(root=>root.querySelector('#translated').textContent),/咖啡/);assert.match(await shadow(root=>root.querySelector('#original').textContent),/would like/);
  report.checks.push('Two real SRT files pair and play bilingual captions with Translator explicitly absent');
  await popup.evaluate(()=>chrome.storage.local.set({mode:'watch',interactionMode:'click',resumeOnDismiss:false}));await page.waitForTimeout(100);
  await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').play());await shadow(root=>root.querySelector('.word').click());assert.equal(await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').paused),false);
  await shadow(root=>root.querySelector('#details .detailBtns button:last-child').click());
  await popup.evaluate(()=>chrome.storage.local.set({mode:'learn',resumeOnDismiss:true}));await page.waitForTimeout(100);await shadow(root=>root.querySelector('.word').click());assert.equal(await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').paused),true);
  await shadow(root=>root.querySelector('#details .detailBtns button:last-child').click());await page.waitForFunction(()=>!document.querySelector('video:not(#hidden-ad)').paused);
  await page.evaluate(()=>{const v=document.querySelector('video:not(#hidden-ad)');v.pause();v.currentTime=.1;v.playbackRate=1.25;});await page.waitForTimeout(150);
  await popup.evaluate(()=>chrome.storage.local.set({repeatCount:1,repeatSpeed:.75}));await page.waitForTimeout(100);await shadow(root=>root.querySelector('[aria-label="Replay current subtitle"]').click());assert.equal(await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').playbackRate),.75);
  await page.waitForFunction(()=>document.querySelector('video:not(#hidden-ad)').playbackRate===1.25,{},{timeout:8000});
  report.checks.push('Watch does not pause, Learn pauses and optionally resumes, and finite sentence replay restores the previous speed');
  await page.evaluate(()=>{const v=document.querySelector('video:not(#hidden-ad)');v.pause();v.currentTime=.1;});await page.waitForTimeout(100);await shadow(root=>root.querySelector('#shadowSentence').click());
  for(let n=0;n<80;n++){if(await shadow(root=>!root.querySelector('#shadowPractice').hidden))break;await page.waitForTimeout(100);}
  assert.equal(await shadow(root=>root.querySelector('#shadowPractice').hidden),false);assert.equal(await page.evaluate(()=>document.querySelector('video:not(#hidden-ad)').paused),true);assert.equal(await shadow(root=>root.querySelector('#original').style.display),'none');
  await page.screenshot({path:path.join(output,'v2-shadowing.png')});await shadow(root=>root.querySelector('#shadowPractice button').click());assert.equal(await shadow(root=>root.querySelector('#original').style.display),'block');
  report.checks.push('Shadowing listens once, pauses with English hidden, and reveals meaning only when requested');
  await shadow(root=>root.querySelector('[aria-label="Close Mandarin Lens"]').click());await page.locator('#mandarin-lens-root').waitFor({state:'detached'});report.checks.push('Overlay close removes host in actual extension runtime');
  await inject(['content.js']);await page.locator('#mandarin-lens-root').waitFor();if(!await popup.locator('#learningData').evaluate(el=>el.open))await popup.getByText('Learning & data',{exact:true}).click();popup.once('dialog',dialog=>dialog.accept());await popup.locator('#deleteData').click();await page.locator('#mandarin-lens-root').waitFor({state:'detached'});assert.deepEqual(await popup.evaluate(async()=>Object.keys(await chrome.storage.local.get(null))),['dataRevision']);report.checks.push('Confirmed data deletion clears extension storage and closes active overlay');
  assert.equal(report.errors.length,0);assert.deepEqual(await fs.readFile(path.join(root,'manifest.json')),sourceManifest);assert.equal(createHash('sha256').update(await fs.readFile(archive)).digest('hex'),packageSha256);report.checks.push('Release ZIP and original manifest unchanged by temporary test permissions');report.passed=true;
 }catch(error){report.passed=false;report.failure=error.stack;throw error;}
 finally{await fs.writeFile(path.join(output,'browser-results.json'),JSON.stringify(report,null,2)+'\n');if(context)await context.close();await new Promise(resolve=>server.close(resolve));await fs.rm(temporary,{recursive:true,force:true});}
 console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
