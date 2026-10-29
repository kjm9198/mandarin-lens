#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build a bounded CC-CEDICT subset. Data remains CC BY-SA 4.0; code MIT.
Usage: python3 scripts/build_lexicon.py /path/to/original-cedict.txt.gz
The source is an explicit owner-approved MDBG downloadable export, never runtime scraping.
"""
import gzip,hashlib,json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]);raw=gzip.open(source,'rt',encoding='utf-8').read()
core=(root/'core.js').read_text()
seeds=set(re.findall(r"'([\u3400-\u9fff]+)'\s*:",core))
common='的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题党程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处理世车价今今书喝咖啡钱银校师朋友音乐快走慢懂请谢饭食肉菜鱼米面奶茶店商院医洗厕机场火站票买卖付卡现名姓叫字汉拼普通话语爱喜欢学习老师学生工作时间分钟小时昨天今天明天去年今年明年星期早晚上午下午累饿渴冷热美漂亮开心难过希望帮助附近可以应该因为所以虽然但是银行音乐重要重复长大长城归还还钱还书还给重行得乐長還銀行樂學習咖啡歡謝現在時候點兒裡飯館說聽見車買賣錢電腦手機書問為什麼怎麼哪裡誰幾多少'
rank={c:i for i,c in enumerate(dict.fromkeys(common))};allowed=set(rank)
records={}
for line in raw.splitlines():
 m=re.match(r'^([^ ]+) ([^ ]+) \[([^\]]+)\] /(.*)/$',line)
 if not m:continue
 trad,simp,pinyin,gloss=m.groups()
 if not re.fullmatch(r'[\u3400-\u9fff]{1,4}',simp):continue
 if simp not in seeds and (not set(simp)<=allowed or re.search(r'\b(surname|variant of|old variant|abbr\.|Taiwan pr\.)\b',gloss,re.I)):continue
 definitions=[g for g in gloss.split('/') if not g.startswith(('CL:','see ','variant of','also pr.'))][:4]
 if not definitions:continue
 record=[trad,pinyin,'; '.join(definitions)[:500]]
 records.setdefault(simp,[])
 if record not in records[simp] and len(records[simp])<3:records[simp].append(record)
keys=sorted(records,key=lambda w:(w not in seeds,len(w),sum(rank.get(c,1000)for c in w),w))[:6500]
data={w:records[w]for w in sorted(keys)}
header=[s for s in raw.splitlines()if s.startswith('#')][:50]
meta={'source':'CC-CEDICT / MDBG and contributors','url':'https://www.mdbg.net/chinese/dictionary?page=cc-cedict','license':'CC-BY-SA-4.0','originalSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'entries':len(data),'selection':'Known project glossary words plus bounded 1–4-character entries over a curated common-character set; not HSK/frequency certification','sourceHeader':header}
(root/'data/lexicon.js').write_text('/* CC-CEDICT subset, CC BY-SA 4.0. See licenses/CC-CEDICT-NOTICE.md. */\nglobalThis.MandarinLensLexicon='+json.dumps(data,ensure_ascii=False,separators=(',',':'))+';\n')
(root/'data/lexicon-provenance.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'entries':len(data),'bytes':(root/'data/lexicon.js').stat().st_size}))
