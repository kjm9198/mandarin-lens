// Offline Pinyin dictionary and tone-mark generator for Kamihi Lens
(function(root) {
  // Common Hanzi to Pinyin tone map
  const DICT = {
    "你": "nǐ", "好": "hǎo", "我": "wǒ", "是": "shì", "的": "de", "了": "le", "不": "bù", "在": "zài", "有": "yǒu",
    "人": "rén", "这": "zhè", "中": "zhōng", "大": "dà", "国": "guó", "上": "shàng", "个": "gè", "们": "men", "到": "dào",
    "说": "shuō", "他": "tā", "她": "tā", "它": "tā", "子": "zǐ", "得": "dé", "也": "yě", "着": "zhe", "下": "xià",
    "自": "zì", "之": "zhī", "年": "nián", "过": "guò", "发": "fā", "后": "hòu", "作": "zuò", "里": "lǐ", "用": "yòng",
    "道": "dào", "行": "xíng", "所": "suǒ", "然": "rán", "家": "jiā", "种": "zhǒng", "事": "shì", "成": "chéng", "方": "fāng",
    "多": "duō", "经": "jīng", "么": "me", "去": "qù", "法": "fǎ", "学": "xué", "如": "rú", "都": "dōu", "同": "tóng",
    "现": "xiàn", "当": "dāng", "没": "méi", "动": "dòng", "面": "miàn", "起": "qǐ", "看": "kàn", "定": "dìng", "天": "tiān",
    "分": "fēn", "点": "diǎn", "想": "xiǎng", "能": "néng", "生": "shēng", "文": "wén", "吃": "chī", "喝": "hē", "茶": "chá",
    "水": "shuǐ", "米": "mǐ", "饭": "fàn", "菜": "cài", "面": "miàn", "书": "shū", "话": "huà", "字": "zì", "买": "mǎi",
    "卖": "mài", "钱": "qián", "车": "chē", "站": "zhàn", "路": "lù", "门": "mén", "机": "jī", "飞": "fēi", "机": "jī",
    "电": "diàn", "脑": "nǎo", "语": "yǔ", "汉": "hàn", "友": "yǒu", "朋": "péng", "爸": "bà", "妈": "mā", "哥": "gē",
    "弟": "dì", "姐": "jiě", "妹": "mèi", "儿": "ér", "喜": "xǐ", "欢": "huan", "爱": "ài", "谢": "xiè", "再": "zài",
    "见": "jiàn", "问": "wèn", "答": "dá", "早": "zǎo", "安": "ān", "请": "qǐng", "对": "duì", "帮": "bāng", "助": "zhù",
    "懂": "dǒng", "开": "kāi", "关": "guān", "快": "kuài", "慢": "màn", "新": "xīn", "旧": "jiù", "高": "gāo", "兴": "xìng",
    "累": "lèi", "难": "nán", "易": "yì", "贵": "guì", "便": "pián", "宜": "yi", "红": "hóng", "蓝": "lán", "绿": "lǜ",
    "白": "bái", "黑": "hēi", "黄": "huáng", "日": "rì", "月": "yuè", "星": "xīng", "期": "qī", "今": "jīn", "明": "míng",
    "昨": "zuó", "现": "xiàn", "时": "shí", "候": "hou", "岁": "suì", "两": "liǎng", "百": "bǎi", "千": "qiān", "万": "wàn",
    "一": "yī", "二": "èr", "三": "sān", "四": "sì", "五": "wǔ", "六": "liù", "七": "qī", "八": "bā", "九": "jiǔ", "十": "shí"
  };

  const WORDS = {
    "你好": "nǐ hǎo",
    "谢谢": "xiè xie",
    "再见": "zài jiàn",
    "不客气": "bù kè qi",
    "对不起": "duì bu qǐ",
    "没关系": "méi guān xi",
    "早上好": "zǎo shang hǎo",
    "晚上好": "wǎn shang hǎo",
    "晚安": "wǎn ān",
    "中国": "zhōng guó",
    "北京": "běi jīng",
    "普通话": "pǔ tōng huà",
    "汉语": "hàn yǔ",
    "中文": "zhōng wén",
    "朋友": "péng you",
    "老师": "lǎo shī",
    "学生": "xué sheng",
    "学校": "xué xiào",
    "咖啡": "kā fēi",
    "米饭": "mǐ fàn",
    "面条": "miàn tiáo",
    "喝茶": "hē chá",
    "吃饭": "chī fàn",
    "高兴": "gāo xìng",
    "喜欢": "xǐ huan",
    "明天": "míng tiān",
    "今天": "jīn tiān",
    "昨天": "zuó tiān",
    "电脑": "diàn nǎo",
    "手机": "shǒu jī",
    "飞机": "fēi jī",
    "车站": "chē zhàn",
    "机场": "jī chǎng",
    "怎么走": "zěn me zǒu",
    "多少钱": "duō shao qián"
  };

  function toPinyin(text) {
    if (!text) return "";
    let trimmed = text.trim();
    if (WORDS[trimmed]) return WORDS[trimmed];
    let res = [];
    for (let char of trimmed) {
      if (DICT[char]) {
        res.push(DICT[char]);
      } else if (/\s/.test(char)) {
        res.push(" ");
      } else {
        res.push(char);
      }
    }
    return res.join(" ").replace(/\s+/g, " ").trim();
  }

  function hasHan(text) {
    return /[\u4e00-\u9fa5]/.test(text);
  }

  root.PinyinEngine = {
    toPinyin: toPinyin,
    hasHan: hasHan,
    dict: DICT,
    words: WORDS
  };
})(typeof window !== 'undefined' ? window : this);
