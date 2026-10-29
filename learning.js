'use strict';
/** Bounded learning metadata and review helpers. No model, capture, network or HTML execution. */
(() => {
  const DAY=86400000;
  const DEFAULTS=Object.freeze({mode:'watch',interactionMode:'hover',resumeOnDismiss:false,lineSpacing:2,textShadow:'soft',textAlign:'center',toneSandhi:false,pronunciationRate:.8,pronunciationRepeats:1,repeatSpeed:.75,repeatCount:2});
  function preferences(value={}){
    const out={...DEFAULTS};
    for(const key of ['mode','interactionMode','textShadow','textAlign']){const choices={mode:['watch','learn'],interactionMode:['hover','click'],textShadow:['soft','outline','none'],textAlign:['left','center','right']};if(choices[key].includes(value[key]))out[key]=value[key];}
    for(const key of ['resumeOnDismiss','toneSandhi'])if(typeof value[key]==='boolean')out[key]=value[key];
    for(const [key,min,max]of [['lineSpacing',0,12],['pronunciationRate',.5,1.2],['pronunciationRepeats',1,3],['repeatSpeed',.5,1],['repeatCount',1,3]]){const n=Number(value[key]);if(value[key]!==undefined&&Number.isFinite(n))out[key]=Math.max(min,Math.min(max,n));}
    out.repeatCount=Math.round(out.repeatCount);out.pronunciationRepeats=Math.round(out.pronunciationRepeats);return out;
  }
  const rules=Object.freeze({
    '想':{wordClass:'modal verb',context:'想 before an action expresses wanting or intending to do it.',grammar:'Subject + 想 + action. 想 can sound less direct than 要; the nuance depends on the sentence.',match:s=>/想(?:喝|吃|去|学|學|买|買|看|听|聽|做|说|說|要)/u.test(s),example:'我想喝咖啡。',translation:'I would like to drink coffee.'},
    '要':{wordClass:'verb / modal verb',context:'要 can express wanting or needing something; before an action it can also express an intention.',grammar:'Its meaning depends on context. It is not always interchangeable with 想.',match:s=>/要(?:喝|吃|去|学|學|买|買|看|做)/u.test(s),example:'我要去学校。',translation:'I am going to school.'},
    '吗':{wordClass:'question particle',context:'吗 at the end turns a statement into a yes/no question.',grammar:'Keep statement word order and add 吗. A question containing a question word usually does not also need 吗.',match:s=>/[吗嗎][？?]?$/u.test(s),example:'你喝茶吗？',translation:'Do you drink tea?'},
    '的':{wordClass:'particle',context:'的 can connect a possessor or description to a noun.',grammar:'For example, 我的书 means my book. Other uses need more context.',match:s=>/的[\p{Script=Han}]/u.test(s),example:'这是我的书。',translation:'This is my book.'},
    '喝':{wordClass:'verb',context:'喝 describes drinking; the following noun can name the drink.',grammar:'Subject + 喝 + drink. Add 想 before 喝 to express wanting to drink.',match:s=>/喝(?:水|茶|咖啡|牛奶|酒)/u.test(s),example:'我喝茶。',translation:'I drink tea.'},
    '是':{wordClass:'verb',context:'是 can identify or classify someone or something.',grammar:'Subject + 是 + noun phrase. Basic adjective predicates often do not use 是.',match:s=>/是[\p{Script=Han}]/u.test(s),example:'她是老师。',translation:'She is a teacher.'}
  });
  function explain(word,sentence=''){
    const normalized=word==='嗎'?'吗':word,rule=rules[normalized];
    if(rule&&rule.match(sentence))return {...rule,source:'Curated pattern note',reliable:true};
    return {wordClass:'Not classified',context:'A reliable sentence-specific explanation is unavailable. Use the dictionary senses and surrounding sentence.',grammar:'No verified grammar note for this word in this sentence.',example:'',translation:'',source:'Dictionary only',reliable:false};
  }
  function cleanEntry(entry){
    if(!entry||typeof entry.word!=='string'||!entry.word.trim()||entry.word.length>100||typeof entry.meaning!=='string'||entry.meaning.length>2000)return null;
    const out={word:entry.word.trim(),pinyin:typeof entry.pinyin==='string'?entry.pinyin.slice(0,300):'',meaning:entry.meaning,example:typeof entry.example==='string'?entry.example.slice(0,2000):''};
    for(const key of ['savedAt','timestamp'])if(Number.isFinite(entry[key])&&entry[key]>=0&&entry[key]<1e15)out[key]=entry[key];
    for(const key of ['traditional','exampleTranslation'])if(typeof entry[key]==='string')out[key]=entry[key].slice(0,2000);
    if(typeof entry.sourceId==='string'&&/^[A-Za-z0-9:_-]{1,120}$/u.test(entry.sourceId))out.sourceId=entry.sourceId;
    out.known=entry.known===true;
    if(entry.review&&typeof entry.review==='object'){const r=entry.review;out.review={interval:Number.isFinite(r.interval)?Math.max(0,Math.min(365,r.interval)):0,due:Number.isFinite(r.due)?Math.max(0,Math.min(1e15,r.due)):0,count:Number.isInteger(r.count)?Math.max(0,Math.min(100000,r.count)):0};}
    out.reviewHistory=Array.isArray(entry.reviewHistory)?entry.reviewHistory.filter(r=>r&&['Again','Good','Easy','Known'].includes(r.grade)&&Number.isFinite(r.at)&&r.at>=0&&r.at<1e15).slice(-100).map(r=>({grade:r.grade,at:r.at})):[];
    return out;
  }
  function grade(entry,choice,now=Date.now()){
    const clean=cleanEntry(entry);if(!clean||!['Again','Good','Easy','Known'].includes(choice))throw Error('Invalid review');
    const previous=clean.review?.interval||0,interval=choice==='Again'?0:choice==='Known'?365:choice==='Good'?Math.min(365,previous?Math.max(1,previous*2):1):Math.min(365,previous?Math.max(3,previous*3):3);
    return {...clean,known:choice==='Known',review:{interval,due:now+(choice==='Again'?600000:interval*DAY),count:Math.min(100000,(clean.review?.count||0)+1)},reviewHistory:[...clean.reviewHistory,{grade:choice,at:now}].slice(-100)};
  }
  function exercise(entries,kind,index=0){
    const words=entries.map(cleanEntry).filter(Boolean);if(!words.length)return null;
    const target=words[Math.abs(index)%words.length];let question=target.word,answer=target.meaning,field='meaning';
    if(kind==='pinyin'){answer=target.pinyin;field='pinyin';}
    if(kind==='listening'){question='Listen, then choose the word.';answer=target.word;field='word';}
    if(kind==='sentence'){if(!target.example.includes(target.word))return {unavailable:'This word needs an example sentence. Edit it or save a word from a subtitle.'};question=target.example.replace(target.word,'____');answer=target.word;field='word';}
    const options=[answer,...words.filter(w=>w.word!==target.word).map(w=>w[field])].filter((v,i,a)=>v&&a.indexOf(v)===i).slice(0,4);
    // Deterministic rotation keeps choices inspectable and does not always reveal the first answer.
    for(let n=0;n<(index+1)%options.length;n++)options.push(options.shift());
    return {target,question,answer,options,kind};
  }
  globalThis.MandarinLensLearning=Object.freeze({DEFAULTS,preferences,explain,cleanEntry,grade,exercise});
})();
