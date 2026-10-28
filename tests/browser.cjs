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
 manifest.host_permissions=['http://127.0.0.1/*'];manifest.background={service_worker:'test-discovery-worker.js'};
 await fs.writeFile(path.join(extension,'manifest.json'),JSON.stringify(manifest));await fs.writeFile(path.join(extension,'test-discovery-worker.js'),'// Test-only worker; no listeners or privileged operations.\n');
 const fixture=await fs.readFile(path.join(__dirname,'fixtures/video.html'));
 const server=http.createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(fixture);});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 let context;const report={label:'Real Chromium MV3 integration with local generated video; translation rendering uses an explicit test double',testOnlyManifestChanges:['localhost host permission replaces browser-toolbar activeTab gesture in automation','inert background worker enables test extension discovery'],packageSha256,packageFile:path.basename(archive),checks:[],translator:null,errors:[],screenshotNotes:{'popup.png':'Actual packaged popup, persisted customization','overlay-clean.png':'Local generated-video fixture and explicit Translator double; not a real-model translation-quality claim','overlay.png':'Malicious imported-subtitle test evidence; explicit Translator double'}};
 try{
  context=await chromium.launchPersistentContext(path.join(temporary,'profile'),{channel:'chromium',executablePath:chromiumExecutable(),headless:true,args:[`--disable-extensions-except=${extension}`,`--load-extension=${extension}`],viewport:{width:1280,height:800}});
  let worker=context.serviceWorkers()[0];if(!worker)worker=await context.waitForEvent('serviceworker');const id=new URL(worker.url()).host;
  const popup=await context.newPage();await popup.goto(`chrome-extension://${id}/popup.html`);await popup.locator('#start:not([disabled])').waitFor();
  report.browser=context.browser().version();report.extensionVersion=manifest.version;
  await popup.getByRole('button',{name:'Minimal',exact:true}).click();assert.equal(await popup.locator('#fontSize').inputValue(),'20');
  await popup.locator('#advanced summary').click();await popup.locator('#fontSize').fill('28');await popup.locator('#fontSize').dispatchEvent('input');
  await popup.waitForFunction(async()=> (await chrome.storage.local.get('fontSize')).fontSize===28);
  await popup.getByText('Learning & data',{exact:true}).click();popup.once('dialog',dialog=>dialog.dismiss());await popup.locator('#deleteData').click();assert.equal(await popup.evaluate(async()=> (await chrome.storage.local.get('fontSize')).fontSize),28);report.checks.push('Canceling data deletion preserves saved customization');
  await popup.reload();await popup.locator('#start:not([disabled])').waitFor();assert.equal(await popup.locator('#fontSize').inputValue(),'28');report.checks.push('Popup preset and customization persist in actual chrome.storage.local');
  await popup.setViewportSize({width:360,height:760});assert(await popup.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await popup.screenshot({path:path.join(output,'popup.png'),fullPage:true});report.checks.push('Popup has no horizontal overflow at 360px');
  const page=await context.newPage();page.on('pageerror',error=>report.errors.push(error.message));await page.goto(`http://127.0.0.1:${server.address().port}/video`);
  const target=await popup.evaluate(async()=> (await chrome.tabs.query({})).find(tab=>tab.url?.startsWith('http://127.0.0.1/'))?.id).catch(()=>null);
  const tabId=target || await popup.evaluate(async()=> (await chrome.tabs.query({})).find(tab=>tab.url?.startsWith('http://127.0.0.1:')).id);
  async function inject(files){return popup.evaluate(async({tabId,files})=>chrome.scripting.executeScript({target:{tabId},files}),{tabId,files});}
  await inject(['data/pinyin.js','core.js','preprocess.js','content.js']);await page.locator('#mandarin-lens-root').waitFor();
  const cdp=await context.newCDPSession(page);
  async function shadowObject(){const {root:tree}=await cdp.send('DOM.getDocument',{depth:-1,pierce:true});function find(node){if(node.attributes?.includes('mandarin-lens-root'))return node;for(const child of [...(node.children||[]),...(node.shadowRoots||[])]){const found=find(child);if(found)return found;}}const host=find(tree);assert(host?.shadowRoots?.[0]);return (await cdp.send('DOM.resolveNode',{nodeId:host.shadowRoots[0].nodeId})).object.objectId;}
  async function shadow(fn,arg){const objectId=await shadowObject();const result=await cdp.send('Runtime.callFunctionOn',{objectId,functionDeclaration:`function(arg){return (${fn.toString()})(this,arg)}`,arguments:[{value:arg}],returnByValue:true,awaitPromise:true});if(result.exceptionDetails)throw Error(JSON.stringify(result.exceptionDetails));return result.result.value;}
  report.translator=await popup.evaluate(async tabId=> (await chrome.scripting.executeScript({target:{tabId},func:async()=>{if(typeof Translator==='undefined')return {present:false};try{return {present:true,availability:await Translator.availability({sourceLanguage:'en',targetLanguage:'zh'})};}catch(error){return {present:true,error:error.message};}}}))[0].result,tabId);
  if(!report.translator.present || report.translator.availability==='unavailable'){
   await shadow(root=>root.querySelector('#cta').click());await page.waitForTimeout(100);assert.match(await shadow(root=>root.querySelector('#status').textContent),/cannot translate locally|does not support|could not start/i);report.checks.push('Actual unsupported Translator environment shows a local-only fallback without downloading a model');
  }else report.checks.push('Actual Translator availability inspected only; model creation/download deliberately not triggered');
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.Translator=undefined;}}),tabId);await shadow(root=>root.querySelector('#cta').click());assert.match(await shadow(root=>root.querySelector('#status').textContent),/cannot translate locally/);report.checks.push('Explicit API-absent test double verifies unsupported-device message');
  await popup.evaluate(async tabId=>chrome.scripting.executeScript({target:{tabId},func:()=>{globalThis.Translator={availability:async()=> 'available',create:async()=>({translate:async text=>text.includes('Chinese')?'我学习中文。':'我想喝咖啡。',destroy(){}})};}}),tabId);
  await popup.evaluate(()=>chrome.storage.local.set({autoPrepare:false}));
  await shadow(root=>root.querySelector('#cta').click());await page.waitForTimeout(200);
  for(let attempt=0;attempt<30;attempt++){if((await shadow(root=>[...root.querySelectorAll('#main .han')].map(el=>el.textContent).join(''))).includes('咖啡'))break;await page.waitForTimeout(100);}
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
  await shadow(root=>root.querySelector('[aria-label="Close Mandarin Lens"]').click());await page.locator('#mandarin-lens-root').waitFor({state:'detached'});report.checks.push('Overlay close removes host in actual extension runtime');
  await inject(['content.js']);await page.locator('#mandarin-lens-root').waitFor();await popup.getByText('Learning & data',{exact:true}).click();popup.once('dialog',dialog=>dialog.accept());await popup.locator('#deleteData').click();await page.locator('#mandarin-lens-root').waitFor({state:'detached'});assert.equal(await popup.evaluate(async()=>Object.keys(await chrome.storage.local.get(null)).length),0);report.checks.push('Confirmed data deletion clears extension storage and closes active overlay');
  assert.equal(report.errors.length,0);assert.deepEqual(await fs.readFile(path.join(root,'manifest.json')),sourceManifest);assert.equal(createHash('sha256').update(await fs.readFile(archive)).digest('hex'),packageSha256);report.checks.push('Release ZIP and original manifest unchanged by temporary test permissions');report.passed=true;
 }catch(error){report.passed=false;report.failure=error.stack;throw error;}
 finally{await fs.writeFile(path.join(output,'browser-results.json'),JSON.stringify(report,null,2)+'\n');if(context)await context.close();await new Promise(resolve=>server.close(resolve));await fs.rm(temporary,{recursive:true,force:true});}
 console.log(JSON.stringify(report,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
