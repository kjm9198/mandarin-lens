'use strict';
/** Pure text and language helpers. Exported globally for an MV3 isolated content script. */
(() => {
  const HAN = /[\u3400-\u9fff\uf900-\ufaff]/u;
  const PHRASES = Object.freeze({
    '中文':'zhōng wén','中国':'zhōng guó','中文课':'zhōng wén kè',
    '你好':'nǐ hǎo','您好':'nín hǎo','谢谢':'xiè xie','再见':'zài jiàn',
    '不客气':'bú kè qi','对不起':'duì bu qǐ','没关系':'méi guān xi',
    '什么':'shén me','为什么':'wèi shén me','怎么':'zěn me',
    '哪里':'nǎ lǐ','现在':'xiàn zài','今天':'jīn tiān','明天':'míng tiān',
    '昨天':'zuó tiān','喜欢':'xǐ huan','学习':'xué xí','学生':'xué sheng',
    '老师':'lǎo shī','朋友':'péng you','认识':'rèn shi',
    '工作':'gōng zuò','学校':'xué xiào','生活':'shēng huó',
    '时候':'shí hou','可以':'kě yǐ','应该':'yīng gāi',
    '知道':'zhī dào','觉得':'jué de','因为':'yīn wèi',
    '所以':'suǒ yǐ','虽然':'suī rán','但是':'dàn shì',
    '银行':'yín háng','音乐':'yīn yuè','快乐':'kuài lè',
    '重庆':'chóng qìng','重要':'zhòng yào','重复':'chóng fù',
    '长大':'zhǎng dà','长城':'cháng chéng','行走':'xíng zǒu',
    '行长':'háng zhǎng','行业':'háng yè','一行':'yì háng','行人':'xíng rén',
    '重新':'chóng xīn','重量':'zhòng liàng','长短':'cháng duǎn','长发':'cháng fà',
    '校长':'xiào zhǎng','长高':'zhǎng gāo','长江':'cháng jiāng','乐器':'yuè qì',
    '乐队':'yuè duì','欢乐':'huān lè','还钱':'huán qián','归还':'guī huán',
    '还是':'hái shi','还有':'hái yǒu','得到':'dé dào','得分':'dé fēn',
    '觉得':'jué de','不得不':'bù dé bù','得去':'děi qù','得走':'děi zǒu',
    '跑得快':'pǎo de kuài','说得好':'shuō de hǎo','英语':'yīng yǔ',
    '还书':'huán shū','还给':'huán gěi','还得':'hái děi','一个':'yī ge','语法':'yǔ fǎ','很好':'hěn hǎo','不是':'bù shì','一天':'yī tiān','还好':'hái hǎo','便宜':'pián yi','方便':'fāng biàn',
    '好吃':'hǎo chī','喝水':'hē shuǐ','中国人':'zhōng guó rén',
  });
  const DEFINITIONS = Object.freeze({
    '我':'I; me','你':'you (singular)','他':'he; him','她':'she; her','们':'plural suffix for pronouns',
    '是':'to be; yes','不':'not; no','吗':'yes/no question particle','的':'possessive / descriptive particle',
    '了':'completed-action or change-of-state particle','在':'at; located in; ongoing action',
    '有':'to have; there is','没':'not; did not','很':'very; quite','也':'also; too',
    '想':'to want; to think; to miss','学':'to study; learn','说':'to speak; say',
    '会':'can (learned skill); will','能':'can (ability); be able to',
    '要':'to want; need; will','去':'to go','来':'to come','看':'to see; watch; read',
    '听':'to listen; hear','吃':'to eat','喝':'to drink','买':'to buy','做':'to do; make',
    '好':'good; well','大':'big','小':'small','多':'many; much','少':'few; little',
    '太':'too; excessively','新':'new','老':'old','人':'person','书':'book',
    '水':'water','茶':'tea','饭':'rice; cooked meal','天':'day; sky',
    '中':'middle; China in compounds','文':'language; writing','家':'home; family',
    '爱':'love','朋友':'friend','学生':'student','老师':'teacher',
    '你好':'hello','谢谢':'thank you','再见':'goodbye','对不起':'sorry',
    '中文':'Chinese language','中国':'China','英语':'English language',
    '学习':'to study; to learn','喜欢':'to like; enjoy','学校':'school',
    '工作':'work; job','生活':'life; to live','今天':'today','明天':'tomorrow',
    '昨天':'yesterday','现在':'now','天气':'weather','什么':'what',
    '为什么':'why','怎么':'how','哪里':'where','可以':'can; may',
    '知道':'to know (a fact)','觉得':'to feel; to think','因为':'because',
    '所以':'therefore; so','但是':'but; however','和':'and; with',
    '跟':'with; and','都':'all; both','个':'general measure word',
    '这':'this','那':'that','些':'some; plural quantity',
    '多少':'how many; how much','几':'how many (small number)',
    '一个':'one; one measure word','没有':'to not have; there is not',
    '喜欢':'to like','学习中文':'to learn Chinese',
    '银行':'bank','音乐':'music','快乐':'happy; joyful','重要':'important',
    '方便':'convenient','便宜':'cheap; inexpensive','好吃':'tasty; delicious',
    // Everyday beginner vocabulary; offline, no API calls or tracking.
    '早上好':'good morning','晚上好':'good evening','晚安':'good night',
    '请问':'excuse me, may I ask','不客气':'you are welcome','没关系':'it is okay; no problem',
    '多少钱':'how much does it cost?','附近':'nearby; in the vicinity',
    '火车站':'train station','地铁':'subway; metro','机场':'airport',
    '饭店':'restaurant; hotel (context-dependent)','餐厅':'restaurant; dining room',
    '医院':'hospital','商店':'shop; store','超市':'supermarket','公园':'park',
    '厕所':'restroom; toilet','洗手间':'bathroom; restroom',
    '左':'left','右':'right','前面':'in front; ahead','后面':'behind',
    '旁边':'beside; next to','远':'far','近':'near','走':'walk; go',
    '公交车':'city bus','出租车':'taxi','地铁站':'metro station',
    '飞机':'airplane','火车':'train','车票':'ticket','地图':'map',
    '手机':'mobile phone','电脑':'computer','电话':'telephone; phone call',
    '名字':'name','姓':'family name','叫':'to be called; to shout',
    '今年':'this year','去年':'last year','明年':'next year','星期':'week',
    '分钟':'minute','小时':'hour','时间':'time','几点':'what time?',
    '上午':'morning (before noon)','下午':'afternoon','晚上':'evening',
    '早':'early; morning','晚':'late; evening','快':'fast','慢':'slow',
    '一点':'a little; a bit','非常':'extremely; very','特别':'especially; special',
    '觉得':'think; feel','知道':'know (information)','明白':'understand',
    '懂':'to understand','问题':'question; problem','回答':'answer; reply',
    '可能':'possible; maybe','需要':'need; require','希望':'to hope; wish',
    '帮忙':'help; do a favor','帮助':'to help; assistance',
    '请':'please; to invite','谢谢你':'thank you','不用谢':'you are welcome',
    '你好呀':'hello (friendly)','不好意思':'excuse me; sorry to bother you',
    '再说一遍':'say that again','请慢一点':'please speak more slowly',
    '可以吗':'is it okay?; may I?','听不懂':'cannot understand what is heard',
    '什么名字':'what name?','怎么说':'how do you say it?',
    '漂亮':'pretty; beautiful','开心':'happy; glad','难过':'sad; upset',
    '累':'tired','饿':'hungry','渴':'thirsty','冷':'cold','热':'hot',
    '好喝':'tasty to drink','早餐':'breakfast','午餐':'lunch','晚餐':'dinner',
    '咖啡':'coffee','牛奶':'milk','水果':'fruit','蔬菜':'vegetables',
    '米饭':'cooked rice','面条':'noodles','鸡肉':'chicken meat','鱼':'fish',
    '多少钱一个':'how much for one?','付款':'to pay','现金':'cash',
    '刷卡':'pay by card','可以刷卡吗':'can I pay by card?',
    '下载':'to download','字幕':'subtitles; captions','翻译':'translation; to translate',
    '拼音':'pinyin (romanization of Mandarin)','汉字':'Chinese characters',
    '普通话':'Standard Mandarin Chinese',

  });
  const normalize = (value) => (typeof value === 'string' ? value : '').slice(0, 10000).replace(/\s+/gu, ' ').trim().slice(0, 600);
  const own = (object, key) => Object.hasOwn(object, key) ? object[key] : '';
  const lexicon=globalThis.MandarinLensLexicon||{};
  const dictionary=new Map();
  for(const [simplified,records]of Object.entries(lexicon)){
    if(!Array.isArray(records))continue;
    for(const [traditional,numbered,definition]of records){
      const entry={simplified,traditional,numbered,definition};
      for(const word of new Set([simplified,traditional])){if(!dictionary.has(word))dictionary.set(word,[]);dictionary.get(word).push(entry);}
    }
  }
  const wordKeys=[...new Set([...Object.keys(DEFINITIONS),...Object.keys(PHRASES),...dictionary.keys()])].sort((a,b)=>b.length-a.length);
  const knownWords=new Set(wordKeys),prefixes=new Map();
  for(const word of wordKeys){const first=Array.from(word)[0];if(!prefixes.has(first))prefixes.set(first,[]);prefixes.get(first).push(word);}
  const segmenter=typeof Intl.Segmenter==='function'?new Intl.Segmenter('zh',{granularity:'word'}):null;
  const isChinese=s=>typeof s==='string'&&HAN.test(s);
  const isDirection=s=>s==='en-zh'||s==='zh-en';
  const options=direction=>direction==='zh-en'?{sourceLanguage:'zh',targetLanguage:'en'}:{sourceLanguage:'en',targetLanguage:'zh'};
  function toneMarks(input){
    return String(input||'').replace(/u:|v/gi,match=>match[0]===match[0].toUpperCase()?'Ü':'ü').split(/\s+/).map(raw=>{
      const m=/^([a-züê]+)([0-5])$/i.exec(raw);if(!m)return raw;
      let letters=m[1],tone=Number(m[2]);if(tone===0||tone===5)return letters;
      const lower=letters.toLowerCase();let index=lower.indexOf('a');if(index<0)index=lower.indexOf('e');if(index<0&&lower.includes('ou'))index=lower.indexOf('o');if(index<0)for(let n=letters.length-1;n>=0;n--)if('aeiouü'.includes(lower[n])){index=n;break;}
      const marks={a:'āáǎà',e:'ēéěè',i:'īíǐì',o:'ōóǒò',u:'ūúǔù',ü:'ǖǘǚǜ'};
      if(index>=0&&marks[lower[index]]){let mark=marks[lower[index]][tone-1];if(letters[index]===letters[index].toUpperCase())mark=mark.toUpperCase();letters=letters.slice(0,index)+mark+letters.slice(index+1);}
      return letters;
    }).join(' ');
  }
  const spoken=Object.freeze({'你好':'ní hǎo','很好':'hén hǎo','可以':'ké yǐ','语法':'yú fǎ','不是':'bú shì','一个':'yí ge','一天':'yì tiān'});
  function lookup(word){
    const records=dictionary.get(word)||[],record=records[0];
    return {word,simplified:record?.simplified||word,traditional:record?.traditional||word,pinyin:own(PHRASES,word)||(record?toneMarks(record.numbered):''),meaning:own(DEFINITIONS,word)||record?.definition||'',
      alternatives:records.slice(0,3).map(r=>({pinyin:toneMarks(r.numbered),meaning:r.definition})),source:own(DEFINITIONS,word)?'Curated beginner glossary':record?'CC-CEDICT (offline)':'Unavailable',uncertain:!own(PHRASES,word)&&records.length!==1};
  }
  function pinyinFor(text, characterMap=globalThis.CJK_PINYIN_MAP||{}, settings={}){
    const value=normalize(text),readings=[];
    for(let i=0;i<value.length;){
      const ch=String.fromCodePoint(value.codePointAt(i)),word=(prefixes.get(ch)||[]).find(w=>value.startsWith(w,i));
      if(word){const entry=lookup(word),reading=settings.sandhi&&own(spoken,word)||entry.pinyin;if(reading){readings.push(reading);i+=word.length;continue;}}
      readings.push(own(characterMap,ch)||(isChinese(ch)?'?':ch));i+=ch.length;
    }
    return readings.join(' ').replace(/\s+([.,!?。，？！；：、])/gu,'$1').replace(/\s+/gu,' ').trim();
  }
  const segmentCache=new Map();
  function segmentChinese(text){
    const value=normalize(text);if(!value)return [];if(segmentCache.has(value))return segmentCache.get(value).slice();
    function split(chunk,preserveUnknown=false){
      const result=[];let unknown=false;
      for(let i=0;i<chunk.length;){const ch=String.fromCodePoint(chunk.codePointAt(i)),word=(prefixes.get(ch)||[]).find(w=>chunk.startsWith(w,i));if(!word)unknown=true;result.push(word||ch);i+=(word||ch).length;}
      return preserveUnknown&&unknown?[chunk]:result;
    }
    const parts=segmenter?Array.from(segmenter.segment(value),part=>part.segment).flatMap(chunk=>/^[\p{Script=Han}]+$/u.test(chunk)&&!knownWords.has(chunk)?split(chunk,true):[chunk]):split(value);
    segmentCache.set(value,parts);if(segmentCache.size>256)segmentCache.delete(segmentCache.keys().next().value);return parts.slice();
  }
  const meaning=word=>typeof word==='string'?lookup(word).meaning:'';
  function compactAppearance(values){
    if(values?.compactLayoutVersion>=1)return {};
    const legacy={fontSize:22,hanziSize:14,englishSize:14,opacity:12,position:12,spacing:4};
    const patch={compactLayoutVersion:1};
    if(values&&Object.entries(legacy).every(([key,value])=>values[key]===value))Object.assign(patch,{fontSize:18,hanziSize:12,englishSize:12,opacity:0,position:8,spacing:2});
    return patch;
  }
  const api = Object.freeze({normalize, isChinese, isDirection, options, pinyinFor, segmentChinese, meaning, compactAppearance, lookup, toneMarks});
  globalThis.MandarinLensCore = api;
})();
