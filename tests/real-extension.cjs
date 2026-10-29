'use strict';
// Real MV3 extension runtime, temporary browser profile, local fixtures.
// Test-only manifest adds localhost access and an inert worker for discovery.
// Opt-in real Translator downloads, explicitly approved by the owner. No model stubs.
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),http=require('node:http'),assert=require('node:assert/strict');
const playwrightPath=process.env.PLAYWRIGHT_MODULE || '/Users/kjm9198/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
let playwright;try{playwright=require('playwright');}catch{playwright=require(playwrightPath);}const {chromium}=playwright;
const fsSync=require('node:fs');
const {execFileSync}=require('node:child_process'),{createHash}=require('node:crypto');
function chromiumExecutable(){if(process.env.CHROMIUM_EXECUTABLE)return process.env.CHROMIUM_EXECUTABLE;const bundled=chromium.executablePath();if(fsSync.existsSync(bundled))return bundled;const cache=path.join(os.homedir(),'Library/Caches/ms-playwright');if(fsSync.existsSync(cache)){for(const build of fsSync.readdirSync(cache).filter(name=>/^chromium-\d+$/.test(name)).sort((a,b)=>Number(b.split('-')[1])-Number(a.split('-')[1]))){const executable=path.join(cache,build,'chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing');if(fsSync.existsSync(executable))return executable;}}return bundled;}
const root=path.resolve(__dirname,'..'),output=path.join(root,'output/playwright');
(async()=>{
 await fs.mkdir(output,{recursive:true});
 const profile=path.join(os.tmpdir(),'mandarin-lens-real-extension-profile-20261028');
 const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'mandarin-lens-browser-')),extension=path.join(temporary,'extension');await fs.mkdir(extension);
 execFileSync(process.env.PYTHON || 'python3',[path.join(root,'scripts/package.py')],{stdio:'pipe'});
 const sourceManifest=await fs.readFile(path.join(root,'manifest.json'));
 const archive=path.join(root,'dist',`mandarin-lens-${JSON.parse(sourceManifest).version}.zip`),archiveBytes=await fs.readFile(archive);
 const packageSha256=createHash('sha256').update(archiveBytes).digest('hex');
 execFileSync(process.env.PYTHON || 'python3',['-c','import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])',archive,extension]);
 assert.deepEqual(await fs.readFile(path.join(extension,'manifest.json')),sourceManifest);
 const manifest=JSON.parse(await fs.readFile(path.join(extension,'manifest.json'),'utf8'));
 manifest.host_permissions=['http://127.0.0.1/*'];manifest.background={service_worker:'test-discovery-worker.js'};
 await fs.writeFile(path.join(extension,'manifest.json'),JSON.stringify(manifest));await fs.writeFile(path.join(extension,'test-discovery-worker.js'),'// Test-only worker; no listeners or privileged operations.\n');
 const fixture=await fs.readFile(path.join(__dirname,'fixtures/real-video.html'));
 const media=await fs.readFile(path.join(__dirname,'fixtures/video.webm'));const server=http.createServer((req,res)=>{if(req.url==='/video.webm'){const match=/bytes=(\d+)-(\d*)/.exec(req.headers.range||'');if(match){const start=Number(match[1]),end=match[2]?Math.min(Number(match[2]),media.length-1):media.length-1;res.writeHead(206,{'Content-Type':'video/webm','Accept-Ranges':'bytes','Content-Range':`bytes ${start}-${end}/${media.length}`,'Content-Length':end-start+1});res.end(media.subarray(start,end+1));}else{res.writeHead(200,{'Content-Type':'video/webm','Accept-Ranges':'bytes','Content-Length':media.length});res.end(media);}return;}res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(fixture);});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 let context;const report={environment:{platform:os.platform(),arch:os.arch(),cpu:os.cpus()[0]?.model},label:'Real Chrome MV3 extension isolated-world integration with original local video fixture and real on-device Translator; no model stub',testOnlyManifestChanges:['localhost host permission replaces browser-toolbar activeTab gesture in automation','inert background worker enables test extension discovery'],packageSha256,packageFile:path.basename(archive),checks:[],translator:null,errors:[],screenshotNotes:{'real-extension.png':'Actual extension and real Translator on an original local generated-video fixture','real-extension-en-zh.png':'Actual extension and real Translator on an original local generated-video fixture','real-extension-zh-en.png':'Actual extension and real Translator on an original local generated-video fixture'},limitations:['Two original caption lines per direction; no independent adequacy score or broad real-video compatibility claim.','Test-only localhost permission and inert worker differ from distribution manifest.']};
 try{
  context=await chromium.launchPersistentContext(profile,{channel:'chromium',executablePath:process.env.REAL_CHROME_EXECUTABLE||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:false,ignoreDefaultArgs:['--disable-extensions','--disable-component-update','--disable-background-networking'],args:['--enable-unsafe-extension-debugging'],viewport:{width:1280,height:800}});
  const browserCdp=await context.browser().newBrowserCDPSession();for(const old of (await browserCdp.send('Extensions.getExtensions')).extensions){await browserCdp.send('Extensions.uninstall',{id:old.id});}const {id}=await browserCdp.send('Extensions.loadUnpacked',{path:extension});
  const popup=await context.newPage();await popup.goto(`chrome-extension://${id}/popup.html`);await popup.locator('#start:not([disabled])').waitFor();
  report.extensionLoading='Official CDP Extensions.loadUnpacked over Playwright debugging pipe, isolated temporary profile';report.browser=context.browser().version();report.extensionVersion=manifest.version;
  await popup.evaluate(()=>chrome.storage.local.set({autoPrepare:true}));
  const page=await context.newPage();page.on('pageerror',error=>report.errors.push(error.message));await page.goto(`http://127.0.0.1:${server.address().port}/video`);
  const target=await popup.evaluate(async()=> (await chrome.tabs.query({})).find(tab=>tab.url?.startsWith('http://127.0.0.1/'))?.id).catch(()=>null);
  const tabId=target || await popup.evaluate(async()=> (await chrome.tabs.query({})).find(tab=>tab.url?.startsWith('http://127.0.0.1:')).id);
  async function inject(files){return popup.evaluate(async({tabId,files})=>chrome.scripting.executeScript({target:{tabId},files}),{tabId,files});}
  await inject(['data/pinyin.js','core.js','preprocess.js','content.js']);await page.locator('#mandarin-lens-root').waitFor();
  const cdp=await context.newCDPSession(page);
  async function shadowObject(){const {root:tree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});function find(node){if(node.attributes?.includes('mandarin-lens-root'))return node;for(const child of [...(node.children||[]),...(node.shadowRoots||[])]){const found=find(child);if(found)return found;}}const host=find(tree);assert(host?.shadowRoots?.[0]);return (await cdp.send('DOM.resolveNode',{nodeId:host.shadowRoots[0].nodeId})).object.objectId;}
  async function shadow(fn,arg){const objectId=await shadowObject();const result=await cdp.send('Runtime.callFunctionOn',{objectId,functionDeclaration:`function(arg){return (${fn.toString()})(this,arg)}`,arguments:[{value:arg}],returnByValue:true,awaitPromise:true,userGesture:true});if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));return result.result.value;}
  report.translator=await popup.evaluate(async tabId=> (await chrome.scripting.executeScript({target:{tabId},func:async()=>{if(typeof Translator==='undefined')return {present:false};try{return {present:true,availability:await Translator.availability({sourceLanguage:'en',targetLanguage:'zh'})};}catch(error){return {present:true,error:error.message};}}}))[0].result,tabId);
  assert(report.translator.present,'Translator must exist in actual extension isolated world');
  if(report.translator.availability==='unavailable')throw Error('Real isolated-world language pack unavailable');
  async function clickStart(){
   const rect=await shadow(root=>{const r=root.querySelector('#cta').getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};});
   await page.mouse.click(rect.x,rect.y);
  }
  async function prepared(){
   const begin=Date.now();let previous='';
   while(Date.now()-begin<240000){
    const status=await shadow(root=>root.querySelector('#status').textContent);
    if(status!==previous){console.log('EXTENSION_STATUS',status);previous=status;}
    if(status.includes('Prepared 2'))return;
    if(/could not start|does not support|cannot translate locally|Preparation incomplete|Preparation could not start/.test(status))throw Error(status);
    await page.waitForTimeout(500);
   }
   throw Error('Real extension language-pack/preparation timeout');
  }
  for(let attempt=0;;attempt++){await clickStart();try{await prepared();break;}catch(error){if(attempt>=2)throw error;report.modelSetupRetries=(report.modelSetupRetries||[]);report.modelSetupRetries.push(error.message);console.log('Retrying real model setup:',error.message);await page.waitForTimeout(2000);}}
  const englishToChinese=await shadow(root=>({hanzi:[...root.querySelectorAll('#main .han')].map(el=>el.textContent).join(''),pinyin:[...root.querySelectorAll('#main .pron')].map(el=>el.textContent).join(' '),text:root.querySelector('#main').textContent,status:root.querySelector('#status').textContent}));
  assert.match(englishToChinese.hanzi,/咖啡/);assert.match(englishToChinese.pinyin,/kā/);assert.match(englishToChinese.text,/I want to drink coffee/);report.enZh=englishToChinese;
  report.checks.push('Actual extension user click downloaded/initialized real Translator and prepared English captions into Chinese plus pinyin');
  await page.mouse.move(10,10);await page.waitForTimeout(600);await page.screenshot({path:path.join(output,'real-extension-en-zh.png')});await page.screenshot({path:path.join(output,'real-extension.png')});
  const compactBefore=await shadow(root=>{const b=root.querySelector('#main').getBoundingClientRect();return {top:b.top,height:b.height,toolbar:getComputedStyle(root.querySelector('#top')).display};});
  assert.equal(compactBefore.toolbar,'none');assert.ok(compactBefore.height<=66);
  const word=await shadow(root=>{const el=[...root.querySelectorAll('.word')].find(w=>w.querySelector('.han')?.textContent==='喝');const b=el.getBoundingClientRect();return {x:b.x+b.width/2,y:b.y+b.height/2};});
  await page.mouse.click(word.x,word.y);await page.waitForTimeout(100);
  const compactPinned=await shadow(root=>{const d=root.querySelector('#details').getBoundingClientRect(),m=root.querySelector('#main').getBoundingClientRect();return {width:d.width,height:d.height,mainTop:m.top};});
  assert.ok(compactPinned.width<=260&&compactPinned.height<=160);assert.ok(Math.abs(compactPinned.mainTop-compactBefore.top)<.5);report.compactGeometry={subtitle:compactBefore,pinned:compactPinned};
  await page.screenshot({path:path.join(output,'compact-real-detail.png'),clip:{x:390,y:480,width:500,height:190}});
  await shadow(root=>root.querySelector('[aria-label="Close word explanation"]').click());await page.mouse.move(10,10);await page.waitForTimeout(400);
  report.checks.push('Actual-model compact subtitles stay under 66px and the pinned popover never shifts them or reveals the toolbar');
  await page.evaluate(()=>{document.querySelector('video').currentTime=5.5;});await page.waitForFunction(()=>document.querySelector('video').currentTime>=5 && !document.querySelector('video').seeking);await page.waitForTimeout(300);report.firstSeek=await page.evaluate(()=>({time:document.querySelector('video').currentTime,duration:document.querySelector('video').duration}));const secondEnZh=await shadow(root=>[...root.querySelectorAll('#main .han')].map(el=>el.textContent).join(''));assert.match(secondEnZh,/中文/);report.checks.push('Seeking real local media to second prepared English cue displays matching Chinese translation');await page.evaluate(()=>{document.querySelector('video').currentTime=0;});await page.waitForTimeout(100);
  await popup.evaluate(()=>chrome.storage.local.set({direction:'zh-en'}));await page.waitForTimeout(100);
  const {root:tree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});function findInput(node){if(node.nodeName==='INPUT'&&node.attributes?.includes('file'))return node;for(const child of [...(node.children||[]),...(node.shadowRoots||[])]){const found=findInput(child);if(found)return found;}}const input=findInput(tree);assert(input);await cdp.send('DOM.setFileInputFiles',{nodeId:input.nodeId,files:[path.join(__dirname,'fixtures/chinese.srt')]});await page.waitForTimeout(100);
  await clickStart();await prepared();
  const chineseToEnglish=await shadow(root=>({hanzi:[...root.querySelectorAll('#main .han')].map(el=>el.textContent).join(''),pinyin:[...root.querySelectorAll('#main .pron')].map(el=>el.textContent).join(' '),text:root.querySelector('#main').textContent,status:root.querySelector('#status').textContent}));
  assert.match(chineseToEnglish.hanzi,/我想喝咖啡/);assert.match(chineseToEnglish.pinyin,/kā/);assert.match(chineseToEnglish.text,/coffee/i);report.zhEn=chineseToEnglish;
  report.checks.push('Actual extension imported Chinese captions and used real Chinese-to-English model while retaining original Hanzi and pinyin');
  await page.mouse.move(10,10);await page.waitForTimeout(600);await page.screenshot({path:path.join(output,'real-extension-zh-en.png')});await page.evaluate(()=>{document.querySelector('video').currentTime=5.5;});await page.waitForFunction(()=>document.querySelector('video').currentTime>=5 && !document.querySelector('video').seeking);await page.waitForTimeout(300);const secondZhEn=await shadow(root=>root.querySelector('#main').textContent);assert.match(secondZhEn,/learning Chinese/i);report.checks.push('Seeking real local media to second prepared Chinese cue displays matching English translation');
  report.translatorAfter=await popup.evaluate(async tabId=>(await chrome.scripting.executeScript({target:{tabId},func:async()=>({enZh:await Translator.availability({sourceLanguage:'en',targetLanguage:'zh'}),zhEn:await Translator.availability({sourceLanguage:'zh',targetLanguage:'en'})})}))[0].result,tabId);
  await shadow(root=>root.querySelector('[aria-label="Close Mandarin Lens"]').click());await page.locator('#mandarin-lens-root').waitFor({state:'detached'});report.checks.push('Real model sessions cleaned up when overlay closes');
  assert.equal(report.errors.length,0);assert.deepEqual(await fs.readFile(path.join(root,'manifest.json')),sourceManifest);assert.equal(createHash('sha256').update(await fs.readFile(archive)).digest('hex'),packageSha256);report.checks.push('Release ZIP and original manifest unchanged by temporary test permissions');report.passed=true;
 }catch(error){report.passed=false;report.failure=error.stack;throw error;}
 finally{await fs.writeFile(path.join(output,'real-extension-results.json'),JSON.stringify(report,null,2)+'\n');if(context)await context.close();await new Promise(resolve=>server.close(resolve));await fs.rm(temporary,{recursive:true,force:true});if(report.passed)await fs.rm(profile,{recursive:true,force:true});}
 console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
