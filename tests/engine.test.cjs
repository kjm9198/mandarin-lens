'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
function load(extra={}){
 const context=vm.createContext({Intl,crypto:globalThis.crypto,TextEncoder,...extra});
 for(const file of ['data/pinyin.js','data/lexicon.js','core.js','preprocess.js','learning.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'..',file),'utf8'),context);
 return {C:context.MandarinLensCore,P:context.MandarinLensPreprocess,L:context.MandarinLensLearning};
}
const {C,P,L}=load();
const plain=value=>JSON.parse(JSON.stringify(value));
test('normalization is bounded and does not stringify arbitrary objects',()=>{
 assert.equal(C.normalize(' a\n b '),'a b');assert.equal(C.normalize('x'.repeat(100000)).length,600);
 assert.equal(C.normalize({toString(){throw Error('untrusted')}}),'');
});
test('dictionary lookups do not expose inherited properties',()=>{
 for(const word of ['__proto__','constructor','toString']){assert.equal(C.meaning(word),'');assert.equal(typeof C.pinyinFor(word),'string');}
});
test('phrase-aware pinyin distinguishes common polyphonic contexts',()=>{
 for(const [text,expected] of Object.entries({'银行':'yín háng','行走':'xíng zǒu','重新':'chóng xīn','重要':'zhòng yào','长大':'zhǎng dà','长江':'cháng jiāng','音乐':'yīn yuè','快乐':'kuài lè','还钱':'huán qián','还有':'hái yǒu','得到':'dé dào','得去':'děi qù','跑得快':'pǎo de kuài'})) assert.equal(C.pinyinFor(text),expected,text);
 assert.equal(C.pinyinFor('我去银行。'),'wǒ qù yín háng。');
 assert.equal(C.pinyinFor('我在重庆。'),'wǒ zài chóng qìng。');
});
test('fallback segmentation groups known words without Intl.Segmenter',()=>{
 const {C:fallback}=load({Intl:{}});assert.deepEqual(plain(fallback.segmentChinese('我喜欢咖啡。')),['我','喜欢','咖啡','。']);
});
test('Intl segmentation splits beginner words without breaking known phrases',()=>{
 const fakeIntl={Segmenter:class {segment(){return [{segment:'我想'},{segment:'喝'},{segment:'咖啡'},{segment:'。'}];}}};
 const {C:segmented}=load({Intl:fakeIntl});
 assert.deepEqual(plain(segmented.segmentChinese('我想喝咖啡。')),['我','想','喝','咖啡','。']);
 assert.deepEqual(plain(C.segmentChinese('我想喝咖啡。')).filter(part=>/[\u3400-\u9fff]/u.test(part)),['我','想','喝','咖啡']);
});
test('SRT and VTT timestamps parse safely',()=>{
 assert.equal(P.parseClock('01:02:03,045'),3723.045);assert.equal(P.parseClock('120:03'),7203);
 for(const value of ['01:60:00','01:99','-1:20','1:2','not a clock',null])assert.equal(P.parseClock(value),null);
});
test('SRT/VTT imports normalize formatting as inert text and skip metadata',()=>{
 const cues=P.parseSubtitleFile('\uFEFFWEBVTT\r\n\r\nNOTE test\r\n00:00.000 --> 00:01.000\r\nIgnore\r\n\r\none\r\n00:01.500 --> 00:03.000 align:start\r\n<b>Hello</b> &amp; &#x4f60;&#x597d;\r\n\r\n2\r\n00:03,000 --> 00:04,000\r\n&lt;img src=x&gt;');
 assert.deepEqual(plain(cues),[{start:1.5,end:3,text:'Hello & 你好'},{start:3,end:4,text:'<img src=x>'}]);
});
test('cue validator rejects malformed values and sorts valid cues',()=>{
 assert.deepEqual(plain(P.validCues([null,{},'bad',{start:'1',end:'2',text:'no'},{start:NaN,end:2,text:'bad'},{start:2,end:1,text:'bad'},{start:2,end:3,text:'second'},{start:0,end:1,text:'first'}])),[{start:0,end:1,text:'first'},{start:2,end:3,text:'second'}]);
});
test('imports reject oversized or too many subtitles instead of pretending complete',()=>{
 assert.throws(()=>P.parseSubtitleFile('x'.repeat(2000001)),/smaller/);
 const lines=Array.from({length:4001},(_,i)=>`${i}\n00:00.000 --> 00:01.000\nx`).join('\n\n');assert.throws(()=>P.parseSubtitleFile(lines),/4,000/);
});
test('subtitle lookup handles gaps, exact ends, seeks and overlaps',()=>{
 const cues=P.validCues([{start:0,end:10,text:'long'},{start:2,end:3,text:'short'},{start:11,end:12,text:'last'}]);
 assert.equal(P.atTime(cues,2.5).text,'short');assert.equal(P.atTime(cues,3).text,'long');assert.equal(P.atTime(cues,10),null);assert.equal(P.atTime(cues,11).text,'last');assert.equal(P.atTime(cues,-1),null);
});
test('live captions coalesce repeats and discard pending text on reset',()=>{
 let next=0;const timers=new Map(),shown=[];
 const captions=P.liveCaptionCoalescer(text=>shown.push(text),{
  setTimer(fn,delay){const id=++next;timers.set(id,{fn,delay});return id;},
  clearTimer(id){timers.delete(id);}
 });
 captions.push('Hello');const first=[...timers.keys()][0];
 captions.push('Hello');assert.deepEqual([...timers.keys()],[first]);
 captions.push('Hello there');assert.equal(timers.size,1);assert.notEqual([...timers.keys()][0],first);
 const scheduled=[...timers.entries()][0];timers.delete(scheduled[0]);scheduled[1].fn();assert.deepEqual(shown,['Hello there']);
 captions.push('A new');captions.reset();assert.equal(timers.size,0);
 captions.push('After seeking.');assert.deepEqual(shown,['Hello there','After seeking.']);
});
test('native track selection excludes metadata and wrong-language tracks',()=>{
 const cue={startTime:0,endTime:1,text:'hello'};
 const video={textTracks:[{kind:'metadata',language:'en',cues:[cue]},{kind:'subtitles',language:'fr',cues:[cue]},{kind:'captions',language:'zh-CN',cues:[{...cue,text:'你好'}]}]};
 assert.equal(P.nativeCues(video).length,0);assert.equal(P.nativeCues(video,'zh-en')[0].text,'你好');
});
test('cache key distinguishes transcript, direction, video and settings',async()=>{
 const cues=[{start:0,end:1,text:'hello'}],base=await P.cacheKey('video-a','en-zh',cues);
 assert.equal(base,await P.cacheKey('video-a','en-zh',cues));
 for(const args of [['video-b','en-zh',cues],['video-a','zh-en',cues],['video-a','en-zh',[{start:0,end:1,text:'bye'}]],['video-a','en-zh',cues,{traditional:true}]])assert.notEqual(await P.cacheKey(...args),base);
 assert.match(base,/^2\.0\.0:[a-f0-9]{64}$/);
});

test('coverage estimate does not mark a short video complete from an opening cue',()=>{assert.equal(P.coverage([{start:0,end:1,text:'opening'}],20).complete,false);assert.equal(P.coverage([{start:0,end:20,text:'full'}],20).complete,true);});


test('main video selection excludes hidden players and favors substantial visible media',()=>{
 const hidden={video:'hidden',visible:false,area:1000000,visibleArea:1000000,playing:true};
 const main={video:'main',visible:true,area:500000,visibleArea:400000};
 const ad={video:'small-ad',visible:true,area:10000,visibleArea:10000,playing:true};
 assert.equal(P.selectVideo([hidden,ad,main]),'main');
 assert.equal(P.selectVideo([hidden]),null);
 assert.equal(P.selectVideo([main,{...ad,fullscreen:true}]),'small-ad');
});
test('equally sized videos prefer playback but keep the current selection on ties',()=>{
 const a={video:'a',visible:true,area:10000,visibleArea:10000,current:true};
 const b={video:'b',visible:true,area:10000,visibleArea:10000};
 assert.equal(P.selectVideo([b,a]),'a');assert.equal(P.selectVideo([a,{...b,playing:true}]),'b');
 assert.equal(P.selectVideo([{...a,visibleArea:0},{...b,visibleArea:0}]),'a');
});
test('live captions exclude metadata and wrong language and normalize inert text',()=>{
 const cue=text=>({text});
 const track=(kind,language,text,mode='showing')=>({kind,language,mode,activeCues:[cue(text)]});
 const video={textTracks:[track('metadata','en','metadata'),track('subtitles','fr','French'),track('captions','zh-CN','你好'),track('captions','en-US','<b>Hello</b> &amp; world')]};
 assert.equal(P.activeCaption(video),'Hello & world');assert.equal(P.activeCaption(video,'zh-en'),'你好');
 assert.equal(P.activeCaption({textTracks:[track('captions','fr','French')]}),'');
});
test('live source prefers explicit language and selected matching track with bounded deduplication',()=>{
 const caption=(language,mode,text)=>({kind:'captions',language,mode,activeCues:[{text},{text}]});
 assert.equal(P.activeCaption({textTracks:[caption('','showing','unknown'),caption('en','hidden','known')]}),'known');
 assert.equal(P.activeCaption({textTracks:[caption('en','hidden','hidden'),caption('en','showing','shown')]}),'shown');
 assert.equal(P.activeCaption(null),'');
});


test('compact migration updates only the exact previous default appearance',()=>{
 const legacy={fontSize:22,hanziSize:14,englishSize:14,opacity:12,position:12,spacing:4};
 assert.deepEqual(plain(C.compactAppearance(legacy)),{compactLayoutVersion:1,fontSize:18,hanziSize:12,englishSize:12,opacity:0,position:8,spacing:2});
 assert.deepEqual(plain(C.compactAppearance({...legacy,fontSize:28})),{compactLayoutVersion:1});
 assert.deepEqual(plain(C.compactAppearance({...legacy,compactLayoutVersion:1})),{});
 assert.deepEqual(plain(C.compactAppearance({})),{compactLayoutVersion:1});
});

test('licensed lexicon aliases traditional and marks numbered neutral tones',()=>{
 assert.equal(C.lookup('銀行').simplified,'银行');assert.equal(C.toneMarks('nu:3 peng2 you5'),'nǚ péng you');assert.equal(C.pinyinFor('还书'),'huán shū');assert.equal(C.pinyinFor('你好',undefined,{sandhi:true}),'ní hǎo');
});
test('context notes disclose unsupported grammar and recognize wanting an action',()=>{
 assert.equal(L.explain('想','我想喝咖啡。').reliable,true);assert.equal(L.explain('想','我想你。').reliable,false);assert.equal(L.explain('咖啡','咖啡很好。').reliable,false);
});
test('bounded learning preferences and review history preserve legacy data',()=>{
 const prefs=L.preferences({mode:'bad',repeatCount:100,repeatSpeed:-1});assert.equal(prefs.mode,'watch');assert.equal(prefs.repeatCount,3);assert.equal(prefs.repeatSpeed,.5);
 let word={word:'茶',pinyin:'chá',meaning:'tea'};for(let i=0;i<150;i++)word=L.grade(word,'Good',1000+i);assert.equal(word.reviewHistory.length,100);assert.equal(word.review.interval,365);assert.equal(L.grade(word,'Again',2000).review.due,602000);assert.equal(L.grade(word,'Known').known,true);
 assert.equal(L.cleanEntry({...word,sourceId:'https://private.example/secret'}).sourceId,undefined);
});
test('offline practice uses saved answers and discloses missing sentence context',()=>{
 const words=[{word:'茶',meaning:'tea',pinyin:'chá',example:'我喝茶。'},{word:'水',meaning:'water',pinyin:'shuǐ'}];for(const mode of ['flashcard','meaning','pinyin','listening','sentence']){const e=L.exercise(words,mode,0);assert.equal(e.options.includes(e.answer),true);}assert.match(L.exercise(words,'sentence',1).unavailable,/example sentence/);
});
test('bilingual caption pairing reuses matching lines and reports omissions',()=>{
 const zh=[{start:0,end:2,text:'我喝茶。'},{start:3,end:4,text:'你好。'}],en=[{start:.1,end:2.1,text:'I drink tea.'}];const paired=P.pairCues(zh,en);assert.equal(paired.matched,1);assert.equal(paired.total,2);assert.equal(paired.cues[0].translation,'我喝茶。');assert.throws(()=>P.pairCues(zh,zh));
});

test('accelerated 30-, 60- and 120-minute timelines remain synchronized across seeks',()=>{
 for(const minutes of [30,60,120]){const cues=Array.from({length:minutes*30},(_,i)=>({start:i*2,end:i*2+1.8,text:'学习中文。'}));for(let t=0;t<minutes*60;t+=.7){const cue=P.atTime(cues,t),i=Math.floor(t/2);assert.equal(cue?.text,(t<cues[i].end)?'学习中文。':undefined);}}
});
