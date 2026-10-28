'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
function load(extra={}){
 const context=vm.createContext({Intl,crypto:globalThis.crypto,TextEncoder,...extra});
 for(const file of ['data/pinyin.js','core.js','preprocess.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'..',file),'utf8'),context);
 return {C:context.MandarinLensCore,P:context.MandarinLensPreprocess};
}
const {C,P}=load();
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
test('native track selection excludes metadata and wrong-language tracks',()=>{
 const cue={startTime:0,endTime:1,text:'hello'};
 const video={textTracks:[{kind:'metadata',language:'en',cues:[cue]},{kind:'subtitles',language:'fr',cues:[cue]},{kind:'captions',language:'zh-CN',cues:[{...cue,text:'你好'}]}]};
 assert.equal(P.nativeCues(video).length,0);assert.equal(P.nativeCues(video,'zh-en')[0].text,'你好');
});
test('cache key distinguishes transcript, direction, video and settings',async()=>{
 const cues=[{start:0,end:1,text:'hello'}],base=await P.cacheKey('video-a','en-zh',cues);
 assert.equal(base,await P.cacheKey('video-a','en-zh',cues));
 for(const args of [['video-b','en-zh',cues],['video-a','zh-en',cues],['video-a','en-zh',[{start:0,end:1,text:'bye'}]],['video-a','en-zh',cues,{traditional:true}]])assert.notEqual(await P.cacheKey(...args),base);
 assert.match(base,/^1\.0\.0:[a-f0-9]{64}$/);
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
