// Kamihi Lens 4.3 — Application Controller (Windows Edition)
(function () {
  'use strict';

  const CURRENT_VERSION = "4.3.1";
  const UPDATE_API = "https://lens.kamihi.workers.dev/api/version";
  const DOWNLOAD_URL = "https://lens.kamihi.workers.dev/download/windows/latest";

  // Bidirectional Dictionaries for Polish, English, Chinese
  const POLISH_TO_ENGLISH = {
    "strajk": "Strike",
    "strajki": "Strikes",
    "strajkować": "To strike",
    "dzień dobry": "Good morning / Hello",
    "dzien dobry": "Good morning / Hello",
    "dziękuję": "Thank you",
    "dziekuje": "Thank you",
    "dzięki": "Thanks",
    "dzieki": "Thanks",
    "cześć": "Hello / Hi",
    "czesc": "Hello / Hi",
    "proszę": "Please / You're welcome",
    "prosze": "Please / You're welcome",
    "przepraszam": "Excuse me / I'm sorry",
    "tak": "Yes",
    "nie": "No",
    "jak się masz": "How are you?",
    "jak sie masz": "How are you?",
    "co tam": "What's up?",
    "co słychać": "How are things? / What's up?",
    "co slychac": "How are things? / What's up?",
    "do widzenia": "Goodbye",
    "dobranoc": "Good night",
    "woda": "Water",
    "herbata": "Tea",
    "kawa": "Coffee",
    "chleb": "Bread",
    "jedzenie": "Food",
    "praca": "Work / Job",
    "dom": "Home / House",
    "szkoła": "School",
    "szkola": "School",
    "kot": "Cat",
    "pies": "Dog",
    "jutro": "Tomorrow",
    "dzisiaj": "Today",
    "wczoraj": "Yesterday",
    "miłość": "Love",
    "milosc": "Love",
    "przyjaciel": "Friend",
    "rodzina": "Family",
    "pieniądze": "Money",
    "pieniadze": "Money",
    "sklep": "Shop / Store",
    "pomoc": "Help",
    "czas": "Time",
    "życie": "Life",
    "zycie": "Life",
    "ludzie": "People",
    "człowiek": "Person",
    "droga": "Road",
    "morze": "Sea",
    "miasto": "City",
    "świat": "World",
    "pokój": "Peace / Room",
    "wojna": "War",
    "protest": "Protest",
    "wolność": "Freedom"
  };

  const ENGLISH_TO_POLISH = {
    "strike": "Strajk",
    "strikes": "Strajki",
    "good morning": "Dzień dobry",
    "hello": "Cześć / Dzień dobry",
    "hi": "Cześć",
    "thank you": "Dziękuję",
    "thanks": "Dzięki",
    "please": "Proszę",
    "excuse me": "Przepraszam",
    "sorry": "Przepraszam",
    "yes": "Tak",
    "no": "Nie",
    "how are you": "Jak się masz?",
    "how are you?": "Jak się masz?",
    "what's up": "Co słychać?",
    "goodbye": "Do widzenia",
    "bye": "Do widzenia",
    "good night": "Dobranoc",
    "water": "Woda",
    "tea": "Herbata",
    "coffee": "Kawa",
    "bread": "Chleb",
    "food": "Jedzenie",
    "work": "Praca",
    "home": "Dom",
    "house": "Dom",
    "school": "Szkoła",
    "cat": "Kot",
    "dog": "Pies",
    "tomorrow": "Jutro",
    "today": "Dzisiaj",
    "yesterday": "Wczoraj",
    "friend": "Przyjaciel",
    "family": "Rodzina",
    "money": "Pieniądze",
    "shop": "Sklep",
    "help": "Pomoc"
  };

  const ENGLISH_TO_CHINESE = {
    "strike": { term: "罢工", pinyin: "bà gōng" },
    "strikes": { term: "罢工", pinyin: "bà gōng" },
    "good morning": { term: "早上好", pinyin: "zǎo shang hǎo" },
    "hello": { term: "你好", pinyin: "nǐ hǎo" },
    "hi": { term: "你好", pinyin: "nǐ hǎo" },
    "thank you": { term: "谢谢", pinyin: "xiè xie" },
    "thanks": { term: "多谢", pinyin: "duō xiè" },
    "please": { term: "请", pinyin: "qǐng" },
    "excuse me": { term: "不好意思", pinyin: "bù hǎo yì si" },
    "sorry": { term: "对不起", pinyin: "duì bu qǐ" },
    "yes": { term: "是的", pinyin: "shì de" },
    "no": { term: "不是", pinyin: "bù shì" },
    "how are you": { term: "你好吗？", pinyin: "nǐ hǎo ma ?" },
    "how are you?": { term: "你好吗？", pinyin: "nǐ hǎo ma ?" },
    "goodbye": { term: "再见", pinyin: "zài jiàn" },
    "bye": { term: "拜拜", pinyin: "bái bái" },
    "good night": { term: "晚安", pinyin: "wǎn ān" },
    "water": { term: "水", pinyin: "shuǐ" },
    "tea": { term: "茶", pinyin: "chá" },
    "coffee": { term: "咖啡", pinyin: "kā fēi" },
    "bread": { term: "面包", pinyin: "miàn bāo" },
    "food": { term: "食物", pinyin: "shí wù" },
    "work": { term: "工作", pinyin: "gōng zuò" },
    "home": { term: "家", pinyin: "jiā" },
    "house": { term: "房子", pinyin: "fáng zi" },
    "school": { term: "学校", pinyin: "xué xiào" },
    "cat": { term: "猫", pinyin: "māo" },
    "dog": { term: "狗", pinyin: "gǒu" },
    "tomorrow": { term: "明天", pinyin: "míng tiān" },
    "today": { term: "今天", pinyin: "jīn tiān" },
    "yesterday": { term: "昨天", pinyin: "zuó tiān" },
    "friend": { term: "朋友", pinyin: "péng you" },
    "family": { term: "家人", pinyin: "jiā rén" }
  };

  // State
  let state = {
    words: JSON.parse(localStorage.getItem('kamihi_words') || '[]'),
    history: JSON.parse(localStorage.getItem('kamihi_history') || '[]'),
    notes: JSON.parse(localStorage.getItem('kamihi_notes') || '[]'),
    currentNoteId: null,
    recallMode: false,
    slowSpeech: true,
    currentSecondaryText: "",
    currentSecondaryLang: "pl-PL",
    game: {
      mode: 'meaning',
      score: 0,
      currentQuestion: null,
      deck: []
    },
    update: {
      available: false,
      latestVersion: null,
      status: "Ready to check for updates."
    }
  };

  // Seed default words if empty
  if (state.words.length === 0) {
    state.words = [
      { id: "1", term: "你好", meaning: "Hello / Hi", category: "Everyday", pronunciation: "nǐ hǎo" },
      { id: "2", term: "谢谢", meaning: "Thank you", category: "Everyday", pronunciation: "xiè xie" },
      { id: "3", term: "咖啡", meaning: "Coffee", category: "Food & drink", pronunciation: "kā fēi" },
      { id: "4", term: "米饭", meaning: "Cooked rice", category: "Food & drink", pronunciation: "mǐ fàn" },
      { id: "5", term: "机场", meaning: "Airport", category: "Travel", pronunciation: "jī chǎng" },
      { id: "6", term: "学习", meaning: "To study / learn", category: "Work & study", pronunciation: "xué xí" },
      { id: "7", term: "高兴", meaning: "Happy / Pleased", category: "Feelings", pronunciation: "gāo xìng" },
      { id: "8", term: "多少钱", meaning: "How much is it?", category: "Shopping", pronunciation: "duō shao qián" }
    ];
    saveWords();
  }

  // Seed default note if empty
  if (state.notes.length === 0) {
    state.notes = [
      {
        id: "default-note",
        title: "Welcome to Kamihi Lens",
        body: "# Welcome to Kamihi Lens 4.3 (Windows Edition)\n\nA private Chinese study workspace on your desktop.\n\n- [x] Explore vocabulary in My words\n- [ ] Practice with 7 study games\n- [ ] Type Chinese text to get Pinyin with tone marks\n- [ ] Practice Polish and English dual translations\n- [ ] Enjoy slower pronunciation to understand every word clearly\n\n## Quick Tip\nUse Recall mode to hide translations and test your memory before exams!",
        pinned: true,
        modified: new Date().toISOString()
      }
    ];
    saveNotes();
  }

  // DOM Elements
  const navItems = document.querySelectorAll('.nav-item');
  const views = document.querySelectorAll('.view');
  const pageTitle = document.getElementById('pageTitle');
  const sidebarUpdateBtn = document.getElementById('sidebarUpdateBtn');

  // Initialization
  document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initTranslateView();
    initHistoryView();
    initNotepadView();
    initWordsView();
    initPlayView();
    initSettingsView();
    checkUpdates(false);
  });

  // Navigation
  function initNavigation() {
    navItems.forEach(item => {
      item.addEventListener('click', () => {
        const page = item.getAttribute('data-page');
        switchPage(page);
      });
    });

    const themeToggleBtn = document.getElementById('themeToggleBtn');
    const savedTheme = localStorage.getItem('kamihi_theme');
    if (savedTheme === 'light' || savedTheme === 'dark') {
      document.body.classList.toggle('theme-light', savedTheme === 'light');
      document.body.classList.toggle('theme-dark', savedTheme === 'dark');
    }
    themeToggleBtn.addEventListener('click', () => {
      const light = !document.body.classList.contains('theme-light');
      document.body.classList.toggle('theme-light', light);
      document.body.classList.toggle('theme-dark', !light);
      localStorage.setItem('kamihi_theme', light ? 'light' : 'dark');
      const selector = document.getElementById('themeSelect');
      if (selector) selector.value = light ? 'light' : 'dark';
    });

    const checkUpdatesQuickBtn = document.getElementById('checkUpdatesQuickBtn');
    checkUpdatesQuickBtn.addEventListener('click', () => {
      switchPage('settings');
      checkUpdates(true);
    });

    sidebarUpdateBtn.addEventListener('click', () => {
      switchPage('settings');
    });
  }

  function switchPage(page) {
    navItems.forEach(n => n.classList.toggle('active', n.getAttribute('data-page') === page));
    views.forEach(v => v.classList.toggle('active', v.id === `view-${page}`));
    pageTitle.textContent = page.charAt(0).toUpperCase() + page.slice(1);

    if (page === 'words') renderWords();
    if (page === 'history') renderHistory();
    if (page === 'notepad') renderNotepadList();
    if (page === 'play') startNewGame();
  }

  // 1. TRANSLATE (DUAL TARGET & SLOWER SPEECH SUPPORT)
  function initTranslateView() {
    const translateInput = document.getElementById('translateInput');
    const doTranslateBtn = document.getElementById('doTranslateBtn');
    const clearInputBtn = document.getElementById('clearInputBtn');
    const resultTerm = document.getElementById('resultTerm');
    const speakTermBtn = document.getElementById('speakTermBtn');
    const copyResultBtn = document.getElementById('copyResultBtn');
    const saveWordBtn = document.getElementById('saveWordBtn');
    const addNoteBtn = document.getElementById('addNoteBtn');
    const targetLangSelect = document.getElementById('targetLangSelect');
    const secondaryTargetSelect = document.getElementById('secondaryTargetSelect');
    const speakSecBtn = document.getElementById('speakSecBtn');
    const copySecBtn = document.getElementById('copySecBtn');

    doTranslateBtn.addEventListener('click', () => performTranslate());
    targetLangSelect.addEventListener('change', () => performTranslate());
    secondaryTargetSelect.addEventListener('change', () => performTranslate());

    clearInputBtn.addEventListener('click', () => {
      translateInput.value = '';
      performTranslate();
      translateInput.focus();
    });

    speakTermBtn.addEventListener('click', () => {
      const term = resultTerm.textContent;
      const primaryTarget = targetLangSelect.value;
      const lang = primaryTarget.startsWith('zh') ? 'zh-CN' : (primaryTarget === 'pl' ? 'pl-PL' : 'en-US');
      speakText(term, lang, true);
    });

    speakSecBtn.addEventListener('click', () => {
      if (state.currentSecondaryText) {
        speakText(state.currentSecondaryText, state.currentSecondaryLang, true);
      }
    });

    copyResultBtn.addEventListener('click', () => {
      const text = `${resultTerm.textContent} (${document.getElementById('resultPinyin').textContent}) — ${document.getElementById('resultMeaning').textContent}`;
      navigator.clipboard.writeText(text);
      copyResultBtn.textContent = '✓ Copied';
      setTimeout(() => copyResultBtn.textContent = '📋 Copy', 1500);
    });

    copySecBtn.addEventListener('click', () => {
      if (state.currentSecondaryText) {
        navigator.clipboard.writeText(state.currentSecondaryText);
        copySecBtn.textContent = '✓ Copied';
        setTimeout(() => copySecBtn.textContent = '📋 Copy second', 1500);
      }
    });

    saveWordBtn.addEventListener('click', () => {
      const term = resultTerm.textContent.trim();
      const pinyin = document.getElementById('resultPinyin').textContent.trim();
      const meaning = document.getElementById('resultMeaning').textContent.trim();
      if (!term) return;

      const existing = state.words.find(w => w.term === term);
      if (!existing) {
        state.words.push({
          id: Date.now().toString(),
          term,
          meaning,
          pronunciation: pinyin,
          category: "Everyday"
        });
        saveWords();
        saveWordBtn.textContent = '✓ Saved';
        setTimeout(() => saveWordBtn.textContent = '⭐ Save word', 1500);
      }
    });

    addNoteBtn.addEventListener('click', () => {
      const term = resultTerm.textContent.trim();
      const pinyin = document.getElementById('resultPinyin').textContent.trim();
      const meaning = document.getElementById('resultMeaning').textContent.trim();
      let entryText = `\n\n### ${term} (${pinyin})\n${meaning}\n`;
      if (state.currentSecondaryText) {
        entryText += `*${state.currentSecondaryText}*\n`;
      }

      if (state.notes.length === 0) createNote("Study Notes");
      const active = state.notes.find(n => n.id === state.currentNoteId) || state.notes[0];
      active.body += entryText;
      saveNotes();
      switchPage('notepad');
    });

    // Auto-translate on typing after a short pause
    let debounceTimer;
    translateInput.addEventListener('input', () => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => performTranslate(), 400);
    });
  }

  function getLanguageName(code) {
    if (code.startsWith('zh')) return code === 'zh-Hant' ? 'Traditional Chinese' : 'Simplified Chinese';
    if (code === 'pl') return 'Polish (Polski)';
    if (code === 'vi') return 'Vietnamese';
    if (code === 'en') return 'English';
    return code;
  }

  function translateForTarget(input, clean, target) {
    // Polish input -> Polish to English
    if (POLISH_TO_ENGLISH[clean]) {
      if (target === 'en') return { term: POLISH_TO_ENGLISH[clean], pinyin: '', meaning: `Polish: ${input}` };
      if (target.startsWith('zh')) {
        const eng = POLISH_TO_ENGLISH[clean].split('/')[0].trim().toLowerCase();
        if (ENGLISH_TO_CHINESE[eng]) return { term: ENGLISH_TO_CHINESE[eng].term, pinyin: ENGLISH_TO_CHINESE[eng].pinyin, meaning: POLISH_TO_ENGLISH[clean] };
      }
    }

    // English input -> Polish
    if (target === 'pl') {
      if (ENGLISH_TO_POLISH[clean]) return { term: ENGLISH_TO_POLISH[clean], pinyin: '', meaning: input };
    }

    // English input -> Chinese
    if (target.startsWith('zh')) {
      if (ENGLISH_TO_CHINESE[clean]) {
        return { term: ENGLISH_TO_CHINESE[clean].term, pinyin: ENGLISH_TO_CHINESE[clean].pinyin, meaning: input };
      }
    }

    // Chinese input -> English or Polish
    const wordMatch = state.words.find(w => w.term === input);
    if (wordMatch) {
      if (target === 'en') return { term: wordMatch.meaning, pinyin: wordMatch.pronunciation, meaning: wordMatch.term };
      if (target === 'pl') {
        const cleanMeaning = wordMatch.meaning.toLowerCase().split('/')[0].trim();
        const pl = ENGLISH_TO_POLISH[cleanMeaning] || wordMatch.meaning;
        return { term: pl, pinyin: wordMatch.pronunciation, meaning: wordMatch.term };
      }
    }

    // Fallbacks
    if (target === 'pl') {
      return { term: `Przetłumaczono: ${input}`, pinyin: '', meaning: input };
    }
    if (target === 'en') {
      return { term: `Translated: ${input}`, pinyin: '', meaning: input };
    }
    const pinyin = window.PinyinEngine ? window.PinyinEngine.toPinyin(input) : '';
    return { term: input, pinyin: pinyin, meaning: `Translated into Chinese: ${input}` };
  }

  let translationRequestId = 0;
  let translationAbortController = null;

  async function performTranslate() {
    const input = document.getElementById('translateInput').value.trim();
    const resultTerm = document.getElementById('resultTerm');
    const resultPinyin = document.getElementById('resultPinyin');
    const resultMeaning = document.getElementById('resultMeaning');
    const secBox = document.getElementById('secondaryResultBox');
    const requestId = ++translationRequestId;
    if (translationAbortController) translationAbortController.abort();
    translationAbortController = new AbortController();
    const signal = translationAbortController.signal;
    if (!input) {
      resultTerm.textContent = '';
      resultPinyin.textContent = '';
      resultMeaning.textContent = '';
      secBox.style.display = 'none';
      state.currentSecondaryText = '';
      return;
    }
    const target = document.getElementById('targetLangSelect').value;
    const secondaryTarget = document.getElementById('secondaryTargetSelect').value;
    const clean = input.toLowerCase().replace(/[.,!?;:]/g, '').trim();

    // Only display a local result when the dictionary actually knows the translation.
    function localResult(language) {
      const candidate = translateForTarget(input, clean, language);
      if (!candidate || candidate.term === input ||
          candidate.term.startsWith('Translated:') ||
          candidate.term.startsWith('Przetłumaczono:')) return null;
      return candidate;
    }
    async function resolve(language) {
      const local = localResult(language);
      if (local) return { ...local, origin: 'local' };
      const code = language.startsWith('zh') ? (language === 'zh-Hant' ? 'zh-TW' : 'zh-CN') : language;
      const endpoint = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=' +
        encodeURIComponent(code) + '&dt=t&q=' + encodeURIComponent(input);
      const response = await fetch(endpoint, { signal });
      if (!response.ok) throw new Error('Translation service unavailable');
      const data = await response.json();
      const translated = Array.isArray(data?.[0]) ? data[0].map(part => part?.[0] || '').join('').trim() : '';
      if (!translated || translated === input) throw new Error('No verified translation returned');
      return {
        term: translated,
        pinyin: window.PinyinEngine && window.PinyinEngine.hasHan(translated) ?
          window.PinyinEngine.toPinyin(translated) : '',
        meaning: input,
        origin: 'online'
      };
    }
    resultTerm.textContent = 'Translating…';
    resultPinyin.textContent = '';
    resultMeaning.textContent = '';
    secBox.style.display = 'none';
    state.currentSecondaryText = '';
    const [primary, secondary] = await Promise.allSettled([
      resolve(target),
      secondaryTarget !== 'none' && secondaryTarget !== target ? resolve(secondaryTarget) : Promise.resolve(null)
    ]);
    if (requestId !== translationRequestId || signal.aborted) return;
    if (primary.status === 'fulfilled') {
      const value = primary.value;
      resultTerm.textContent = value.term;
      resultPinyin.textContent = value.pinyin || '';
      resultMeaning.textContent = value.origin === 'online' ?
        'Online translation · ' + input : 'Offline dictionary · ' + input;
      state.history.unshift({
        id: Date.now().toString(),
        source: input,
        translation: value.term,
        pinyin: value.pinyin,
        date: new Date().toLocaleDateString()
      });
      state.history = state.history.slice(0, 100);
      saveHistory();
    } else {
      resultTerm.textContent = 'Translation unavailable';
      resultMeaning.textContent = 'No offline dictionary match. Check your internet connection and try again.';
    }
    if (secondary.status === 'fulfilled' && secondary.value) {
      const value = secondary.value;
      secBox.style.display = 'block';
      document.getElementById('secLangName').textContent = getLanguageName(secondaryTarget);
      document.getElementById('secResultMeaning').textContent = value.term;
      state.currentSecondaryText = value.term;
      state.currentSecondaryLang = secondaryTarget === 'pl' ? 'pl-PL' :
        secondaryTarget.startsWith('zh') ? 'zh-CN' : secondaryTarget === 'vi' ? 'vi-VN' : 'en-US';
    } else if (secondaryTarget !== 'none' && secondaryTarget !== target) {
      secBox.style.display = 'block';
      document.getElementById('secLangName').textContent = getLanguageName(secondaryTarget);
      document.getElementById('secResultMeaning').textContent = 'Translation unavailable';
    }
  }

  // 2. HISTORY
  function initHistoryView() {
    const clearHistoryBtn = document.getElementById('clearHistoryBtn');
    const historySearch = document.getElementById('historySearch');

    clearHistoryBtn.addEventListener('click', () => {
      if (confirm("Clear all history?")) {
        state.history = [];
        saveHistory();
        renderHistory();
      }
    });

    historySearch.addEventListener('input', () => renderHistory());
  }

  function renderHistory() {
    const list = document.getElementById('historyList');
    const query = (document.getElementById('historySearch').value || '').toLowerCase();
    list.innerHTML = '';

    const filtered = state.history.filter(h =>
      h.source.toLowerCase().includes(query) ||
      h.translation.toLowerCase().includes(query) ||
      (h.pinyin && h.pinyin.toLowerCase().includes(query))
    );

    if (filtered.length === 0) {
      list.innerHTML = '<div style="color:var(--text-muted);text-align:center;padding:24px;">No history entries yet.</div>';
      return;
    }

    filtered.forEach(item => {
      const el = document.createElement('div');
      el.className = 'history-item';
      el.innerHTML = `
        <div>
          <span class="hist-term">${item.source}</span>
          <span class="hist-pinyin">${item.pinyin || ''}</span>
          <div class="hist-meaning">${item.translation}</div>
        </div>
        <button class="btn btn-sm" onclick="speakText('${item.source}', 'zh-CN', true)">🔊</button>
      `;
      list.appendChild(el);
    });
  }

  // 3. NOTEPAD
  function initNotepadView() {
    const newNoteBtn = document.getElementById('newNoteBtn');
    const noteTemplateSelect = document.getElementById('noteTemplateSelect');
    const noteTitleInput = document.getElementById('noteTitleInput');
    const noteBodyInput = document.getElementById('noteBodyInput');
    const toggleRecallBtn = document.getElementById('toggleRecallBtn');
    const revealRecallBtn = document.getElementById('revealRecallBtn');
    const deleteNoteBtn = document.getElementById('deleteNoteBtn');
    const exportNoteBtn = document.getElementById('exportNoteBtn');

    newNoteBtn.addEventListener('click', () => {
      const template = noteTemplateSelect.value;
      let body = "";
      if (template === 'checklist') body = "- [ ] Review today's vocabulary\n- [ ] Practice slower pronunciation\n- [ ] Write one Polish & Chinese sentence\n";
      if (template === 'journal') body = "## Today\n\n## Words learned\n\n## Next steps\n";
      if (template === 'prompt') body = "## Writing Prompt\nDescribe your favorite food or beverage in Mandarin and Polish.\n\n## Answer\n";
      createNote("Untitled Note", body);
    });

    noteTitleInput.addEventListener('input', () => {
      const active = state.notes.find(n => n.id === state.currentNoteId);
      if (active) {
        active.title = noteTitleInput.value;
        active.modified = new Date().toISOString();
        saveNotes();
        renderNotepadList();
      }
    });

    noteBodyInput.addEventListener('input', () => {
      const active = state.notes.find(n => n.id === state.currentNoteId);
      if (active) {
        active.body = noteBodyInput.value;
        active.modified = new Date().toISOString();
        saveNotes();
      }
    });

    deleteNoteBtn.addEventListener('click', () => {
      if (confirm("Delete this note?")) {
        state.notes = state.notes.filter(n => n.id !== state.currentNoteId);
        state.currentNoteId = state.notes[0]?.id || null;
        saveNotes();
        renderNotepadList();
        loadActiveNote();
      }
    });

    exportNoteBtn.addEventListener('click', () => {
      const active = state.notes.find(n => n.id === state.currentNoteId);
      if (!active) return;
      const blob = new Blob([`# ${active.title}\n\n${active.body}`], { type: 'text/markdown' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `${active.title.replace(/[^a-z0-9]/gi, '_')}.md`;
      a.click();
    });

    toggleRecallBtn.addEventListener('click', () => {
      state.recallMode = !state.recallMode;
      const recallPane = document.getElementById('recallPane');
      recallPane.style.display = state.recallMode ? 'block' : 'none';
      document.getElementById('revealedContent').style.display = 'none';
    });

    revealRecallBtn.addEventListener('click', () => {
      const active = state.notes.find(n => n.id === state.currentNoteId);
      const revealed = document.getElementById('revealedContent');
      revealed.textContent = active ? active.body : '';
      revealed.style.display = 'block';
    });

    if (state.notes.length > 0) {
      state.currentNoteId = state.notes[0].id;
      loadActiveNote();
    }
  }

  function createNote(title, body = "") {
    const note = {
      id: Date.now().toString(),
      title,
      body,
      pinned: false,
      modified: new Date().toISOString()
    };
    state.notes.unshift(note);
    state.currentNoteId = note.id;
    saveNotes();
    renderNotepadList();
    loadActiveNote();
  }

  function renderNotepadList() {
    const list = document.getElementById('notesList');
    list.innerHTML = '';
    state.notes.forEach(note => {
      const card = document.createElement('div');
      card.className = `note-card ${note.id === state.currentNoteId ? 'active' : ''}`;
      card.innerHTML = `
        <div class="note-card-title">${note.title || 'Untitled note'}</div>
        <div class="note-card-preview">${note.body.slice(0, 45) || 'Empty note'}</div>
      `;
      card.addEventListener('click', () => {
        state.currentNoteId = note.id;
        renderNotepadList();
        loadActiveNote();
      });
      list.appendChild(card);
    });
  }

  function loadActiveNote() {
    const active = state.notes.find(n => n.id === state.currentNoteId);
    const titleInput = document.getElementById('noteTitleInput');
    const bodyInput = document.getElementById('noteBodyInput');

    if (active) {
      titleInput.value = active.title;
      bodyInput.value = active.body;
      titleInput.disabled = false;
      bodyInput.disabled = false;
    } else {
      titleInput.value = '';
      bodyInput.value = '';
      titleInput.disabled = true;
      bodyInput.disabled = true;
    }
  }

  // 4. MY WORDS (DICTIONARY)
  function initWordsView() {
    const wordsSearch = document.getElementById('wordsSearch');
    const categoryFilter = document.getElementById('categoryFilter');
    const addCustomWordBtn = document.getElementById('addCustomWordBtn');
    const exportWordsBtn = document.getElementById('exportWordsBtn');
    const importWordsFile = document.getElementById('importWordsFile');
    const playFromWordsBtn = document.getElementById('playFromWordsBtn');

    wordsSearch.addEventListener('input', () => renderWords());
    categoryFilter.addEventListener('change', () => renderWords());

    addCustomWordBtn.addEventListener('click', () => {
      const term = prompt("Enter Chinese word / Hanzi:");
      if (!term) return;
      const meaning = prompt("Enter English / Polish meaning:");
      if (!meaning) return;
      const pinyin = window.PinyinEngine ? window.PinyinEngine.toPinyin(term) : "";
      state.words.push({
        id: Date.now().toString(),
        term,
        meaning,
        pronunciation: pinyin,
        category: "Everyday"
      });
      saveWords();
      renderWords();
    });

    exportWordsBtn.addEventListener('click', () => {
      const blob = new Blob([JSON.stringify(state.words, null, 2)], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `kamihi_words_${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
    });

    importWordsFile.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (event) => {
        try {
          const imported = JSON.parse(event.target.result);
          if (Array.isArray(imported)) {
            state.words = imported;
            saveWords();
            renderWords();
            alert(`Imported ${imported.length} vocabulary entries.`);
          }
        } catch (err) {
          alert("Invalid words.json file.");
        }
      };
      reader.readAsText(file);
    });

    playFromWordsBtn.addEventListener('click', () => {
      switchPage('play');
    });

    renderWords();
  }

  function renderWords() {
    const grid = document.getElementById('wordsGrid');
    const query = (document.getElementById('wordsSearch').value || '').toLowerCase();
    const cat = document.getElementById('categoryFilter').value;
    grid.innerHTML = '';

    const filtered = state.words.filter(w => {
      const matchCat = (cat === 'All' || w.category === cat);
      const matchQuery = w.term.toLowerCase().includes(query) ||
                          w.meaning.toLowerCase().includes(query) ||
                          (w.pronunciation && w.pronunciation.toLowerCase().includes(query));
      return matchCat && matchQuery;
    });

    if (filtered.length === 0) {
      grid.innerHTML = '<div style="grid-column: 1/-1; color:var(--text-muted); text-align:center; padding:32px;">No words found matching filter.</div>';
      return;
    }

    filtered.forEach(word => {
      const card = document.createElement('div');
      card.className = 'word-card';
      card.innerHTML = `
        <div class="word-card-top">
          <div class="word-term">${word.term}</div>
          <button class="btn btn-sm btn-ghost" onclick="speakText('${word.term}', 'zh-CN', true)" title="Listen at slower pace">🔊</button>
        </div>
        <div class="word-pinyin">${word.pronunciation || ''}</div>
        <div class="word-meaning">${word.meaning}</div>
        <div class="word-category">${word.category || 'Unsorted'}</div>
      `;
      grid.appendChild(card);
    });
  }

  // 5. PLAY (7 STUDY GAMES)
  function initPlayView() {
    const gameTabs = document.querySelectorAll('.game-tab');
    const gameNextBtn = document.getElementById('gameNextBtn');

    gameTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        gameTabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        state.game.mode = tab.getAttribute('data-game');
        document.getElementById('gameTitle').textContent = tab.textContent;
        startNewGame();
      });
    });

    gameNextBtn.addEventListener('click', () => {
      loadNextQuestion();
    });
  }

  function startNewGame() {
    state.game.score = 0;
    document.getElementById('gameScore').textContent = '0';
    loadNextQuestion();
  }

  function loadNextQuestion() {
    const feedback = document.getElementById('gameFeedback');
    feedback.textContent = '';
    const interaction = document.getElementById('gameInteraction');
    interaction.innerHTML = '';

    if (state.words.length < 2) {
      document.getElementById('gamePrompt').textContent = "Save at least 2 words to play games.";
      return;
    }

    const mode = state.game.mode;
    const shuffled = [...state.words].sort(() => 0.5 - Math.random());
    const target = shuffled[0];
    state.game.currentQuestion = target;

    // Game modes
    if (mode === 'meaning') {
      document.getElementById('gamePrompt').innerHTML = `${target.term} <span style="font-size:18px;color:var(--accent);">(${target.pronunciation})</span>`;
      const choices = [target.meaning, shuffled[1]?.meaning, shuffled[2]?.meaning || "Another option"].filter(Boolean).sort(() => 0.5 - Math.random());
      choices.forEach(ch => {
        const btn = document.createElement('button');
        btn.className = 'game-choice-btn';
        btn.textContent = ch;
        btn.onclick = () => checkAnswer(ch === target.meaning);
        interaction.appendChild(btn);
      });
    } else if (mode === 'reverse') {
      document.getElementById('gamePrompt').textContent = target.meaning;
      const choices = [target.term, shuffled[1]?.term, shuffled[2]?.term || "其他"].filter(Boolean).sort(() => 0.5 - Math.random());
      choices.forEach(ch => {
        const btn = document.createElement('button');
        btn.className = 'game-choice-btn';
        btn.textContent = ch;
        btn.onclick = () => checkAnswer(ch === target.term);
        interaction.appendChild(btn);
      });
    } else if (mode === 'listen') {
      document.getElementById('gamePrompt').innerHTML = `🔊 <button class="btn btn-sm btn-primary" onclick="speakText('${target.term}', 'zh-CN', true)">Listen again (Slower)</button>`;
      speakText(target.term, 'zh-CN', true);
      const choices = [target.term, shuffled[1]?.term, shuffled[2]?.term || "你好"].filter(Boolean).sort(() => 0.5 - Math.random());
      choices.forEach(ch => {
        const btn = document.createElement('button');
        btn.className = 'game-choice-btn';
        btn.textContent = ch;
        btn.onclick = () => checkAnswer(ch === target.term);
        interaction.appendChild(btn);
      });
    } else if (mode === 'pinyin') {
      document.getElementById('gamePrompt').textContent = target.term;
      const choices = [target.pronunciation, shuffled[1]?.pronunciation, shuffled[2]?.pronunciation || "pīnyīn"].filter(Boolean).sort(() => 0.5 - Math.random());
      choices.forEach(ch => {
        const btn = document.createElement('button');
        btn.className = 'game-choice-btn';
        btn.textContent = ch;
        btn.onclick = () => checkAnswer(ch === target.pronunciation);
        interaction.appendChild(btn);
      });
    } else if (mode === 'build') {
      document.getElementById('gamePrompt').textContent = target.meaning;
      const chars = target.term.split('').sort(() => 0.5 - Math.random());
      let built = "";
      const display = document.createElement('div');
      display.style.fontSize = '24px';
      display.style.margin = '10px 0';
      display.textContent = "_ ".repeat(target.term.length);
      interaction.appendChild(display);

      chars.forEach(c => {
        const btn = document.createElement('button');
        btn.className = 'game-choice-btn';
        btn.style.minWidth = '50px';
        btn.textContent = c;
        btn.onclick = () => {
          built += c;
          display.textContent = built;
          btn.disabled = true;
          if (built.length === target.term.length) {
            checkAnswer(built === target.term);
          }
        };
        interaction.appendChild(btn);
      });
    } else {
      document.getElementById('gamePrompt').textContent = "Match the pair:";
      const pair = [
        { text: target.term, key: target.id },
        { text: target.meaning, key: target.id },
        { text: shuffled[1].term, key: shuffled[1].id },
        { text: shuffled[1].meaning, key: shuffled[1].id }
      ].sort(() => 0.5 - Math.random());

      let selected = null;
      pair.forEach(item => {
        const btn = document.createElement('button');
        btn.className = 'game-choice-btn';
        btn.textContent = item.text;
        btn.onclick = () => {
          if (!selected) {
            selected = { btn, item };
            btn.style.borderColor = 'var(--accent)';
          } else {
            if (selected.item.key === item.key && selected.btn !== btn) {
              selected.btn.disabled = true;
              btn.disabled = true;
              selected.btn.style.background = 'var(--success)';
              btn.style.background = 'var(--success)';
              checkAnswer(true);
            } else {
              selected.btn.style.borderColor = 'var(--border-line)';
              checkAnswer(false);
            }
            selected = null;
          }
        };
        interaction.appendChild(btn);
      });
    }
  }

  function checkAnswer(correct) {
    const feedback = document.getElementById('gameFeedback');
    if (correct) {
      state.game.score += 10;
      feedback.textContent = "✓ Excellent! +10 points";
      feedback.style.color = "var(--success)";
    } else {
      feedback.textContent = "Not quite — keep practicing!";
      feedback.style.color = "var(--danger)";
    }
    document.getElementById('gameScore').textContent = state.game.score;
  }

  // 6. SETTINGS & UPDATES
  function initSettingsView() {
    const checkUpdatesBtn = document.getElementById('checkUpdatesBtn');
    const downloadUpdateBtn = document.getElementById('downloadUpdateBtn');

    checkUpdatesBtn.addEventListener('click', () => checkUpdates(true));
    downloadUpdateBtn.addEventListener('click', () => downloadUpdate());
    const themeSelect = document.getElementById('themeSelect');
    if (themeSelect) {
      themeSelect.value = document.body.classList.contains('theme-light') ? 'light' : 'dark';
      themeSelect.addEventListener('change', () => {
        const light = themeSelect.value === 'light';
        document.body.classList.toggle('theme-light', light);
        document.body.classList.toggle('theme-dark', !light);
        localStorage.setItem('kamihi_theme', themeSelect.value);
      });
    }
  }

  function checkUpdates(manual = false) {
    const statusText = document.getElementById('updateStatusText');
    if (manual) statusText.textContent = "Checking for latest release...";

    fetch(UPDATE_API)
      .then(res => res.json())
      .then(data => {
        const remoteVer = data.windows?.version || data.latestVersion;
        state.update.latestVersion = remoteVer;
        const isNewer = isNewerVersion(remoteVer, CURRENT_VERSION);
        state.update.available = isNewer;

        if (isNewer) {
          statusText.textContent = `New version ${remoteVer} is available!`;
          statusText.style.color = "var(--accent)";
          sidebarUpdateBtn.style.display = "block";
        } else {
          statusText.textContent = `You're up to date! Kamihi Lens v${CURRENT_VERSION} is the latest version.`;
          statusText.style.color = "var(--text-secondary)";
          sidebarUpdateBtn.style.display = "none";
        }
      })
      .catch(() => {
        if (manual) {
          statusText.textContent = "Could not check updates. You can download the latest installer from lens.kamihi.workers.dev.";
          statusText.style.color = "var(--text-muted)";
        }
      });
  }

  function downloadUpdate() {
    const statusText = document.getElementById('updateStatusText');
    statusText.textContent = "Initiating update download...";
    window.location.href = DOWNLOAD_URL;
  }

  function isNewerVersion(remote, local) {
    if (!remote || !local) return false;
    const r = remote.replace(/^[vV]/, '').split('.').map(Number);
    const l = local.replace(/^[vV]/, '').split('.').map(Number);
    for (let i = 0; i < Math.max(r.length, l.length); i++) {
      const rv = r[i] || 0;
      const lv = l[i] || 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  // Multi-lingual speech helper with measured, slower speech pace
  window.speakText = function (text, lang = 'zh-CN', slower = true) {
    if (!('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = lang;
    // 0.55 creates a measured, articulate slower speed for language learning
    utterance.rate = slower ? 0.55 : 0.85;
    window.speechSynthesis.speak(utterance);
  };

  // Backwards compatibility alias
  window.speakMandarin = function (text) {
    window.speakText(text, 'zh-CN', true);
  };

  // Persistence helpers
  function saveWords() { localStorage.setItem('kamihi_words', JSON.stringify(state.words)); }
  function saveHistory() { localStorage.setItem('kamihi_history', JSON.stringify(state.history)); }
  function saveNotes() { localStorage.setItem('kamihi_notes', JSON.stringify(state.notes)); }

})();
