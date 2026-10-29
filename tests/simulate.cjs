'use strict';
// Synthetic engine journeys, not real people, browser compatibility or translation benchmarks.
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const os=require('node:os');
const assert=require('node:assert/strict');
const {performance}=require('node:perf_hooks');
const context=vm.createContext({Intl,crypto:globalThis.crypto,TextEncoder});
for(const file of ['data/pinyin.js','data/lexicon.js','core.js','preprocess.js','learning.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'..',file),'utf8'),context);
const {MandarinLensCore:C,MandarinLensPreprocess:P,MandarinLensLearning:L}=context;
let seed=20261028;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const latencies=[],failures=[],outcomes={timedCaptionJourneys:0,liveCaptionFallbacks:0,noCaptionFallbacks:0,modelUnavailableFallbacks:0,interruptedJourneys:0};
const start=performance.now(),cpu=process.cpuUsage(),heapStart=process.memoryUsage().heapUsed;
for(let session=0;session<10000;session++){
 try{
  const learning=L.preferences({mode:random()<.5?'watch':'learn',interactionMode:random()<.5?'hover':'click',repeatCount:1+Math.floor(random()*3)});assert(['watch','learn'].includes(learning.mode));const reviewed=L.grade({word:'茶',meaning:'tea',pinyin:'chá'},random()<.25?'Again':'Good');assert(reviewed.reviewHistory.length===1);
  const direction=random()<.5?'en-zh':'zh-en',captionState=Math.floor(random()*3),modelAvailable=random()>.2;
  const interrupted=random()<.25,captionCount=10+Math.floor(random()*150),speed=[.5,1,1.5,2][Math.floor(random()*4)];
  const size=12+Math.floor(random()*37),mode=['watch','learn','practice'][Math.floor(random()*3)];
  assert(size>=12&&size<=48);assert(['watch','learn','practice'].includes(mode));assert(C.isDirection(direction));
  if(!modelAvailable){outcomes.modelUnavailableFallbacks++;continue;}
  if(captionState===0){outcomes.noCaptionFallbacks++;continue;}
  if(captionState===1){outcomes.liveCaptionFallbacks++;assert(C.normalize(' repeated\n caption ')==='repeated caption');continue;}
  const raw=Array.from({length:captionCount},(_,i)=>`${i+1}\n00:${String(Math.floor(i*3/60)).padStart(2,'0')}:${String(i*3%60).padStart(2,'0')},000 --> 00:${String(Math.floor((i*3+2)/60)).padStart(2,'0')}:${String((i*3+2)%60).padStart(2,'0')},000\n${direction==='en-zh'?'I am learning Chinese.':'我去银行。'}`).join('\n\n');
  const cues=P.parseSubtitleFile(raw);assert.equal(cues.length,captionCount);
  // Random seeks, gaps, speed-adjusted progression and replay all use the real timestamp lookup.
  for(let step=0;step<20;step++){
   const time=step<10?random()*captionCount*3:(step-10)*speed;
   const before=performance.now(),cue=P.atTime(cues,time);latencies.push(performance.now()-before);
   const oracle=[...cues].reverse().find(cue=>cue.start<=time&&time<cue.end)||null;assert.equal(cue,oracle);
  }
  const visible=P.atTime(cues,0);assert(visible&&visible.text);assert(C.pinyinFor('我去银行。').includes('yín háng'));
  if(interrupted){outcomes.interruptedJourneys++;const reloaded=P.parseSubtitleFile(raw);assert.equal(reloaded.length,cues.length);assert.equal(P.atTime(reloaded,3).text,cues[1].text);}
  outcomes.timedCaptionJourneys++;
 }catch(error){failures.push({session,error:error.message});}
}
latencies.sort((a,b)=>a-b);
const percentile=q=>latencies[Math.floor((latencies.length-1)*q)]||0;
const used=process.cpuUsage(cpu);
const report={label:'10,000 synthetic engine journeys; no human participants or browser/translation verification',seed:20261028,sessions:10000,passed:10000-failures.length,failed:failures.length,outcomes,failures,measurements:{scope:'Node timestamp lookup only; not translation or Chrome rendering latency',lookupSamples:latencies.length,lookupP50Ms:percentile(.5),lookupP95Ms:percentile(.95),elapsedMs:performance.now()-start,cpuUserMs:used.user/1000,cpuSystemMs:used.system/1000,heapStartBytes:heapStart,heapEndBytes:process.memoryUsage().heapUsed},environment:{node:process.version,platform:process.platform,arch:process.arch,cpu:os.cpus()[0]?.model,chrome:'Not measured'},limitations:['Caption/model/device states are synthetic branches, not browser capability measurements.','Appearance values and learning-mode selections do not exercise the DOM.','No speech recognition, remote video access, real translation quality or long-session browser memory measured.','Fallback branch counts are expected safe outcomes, not successful translations.']};
fs.writeFileSync(path.join(__dirname,'simulation-results.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
if(failures.length)process.exitCode=1;
