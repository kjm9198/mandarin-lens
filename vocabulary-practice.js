'use strict';
(() => {
 const get=id=>document.getElementById(id);let index=0,current=null,answered=false;
 function draw(){
  answered=false;const kind=get('practiceKind').value;current=MandarinLensLearning.exercise(vocabulary,kind,index);get('practiceOptions').replaceChildren();get('practiceFeedback').textContent='';get('practiceListen').hidden=kind!=='listening';get('practiceReveal').hidden=kind!=='flashcard';
  if(!current){get('practiceQuestion').textContent='Save a word to start practising.';get('practiceNext').disabled=true;return;}
  get('practiceNext').disabled=false;if(current.unavailable){get('practiceQuestion').textContent=current.unavailable;get('practiceListen').hidden=true;get('practiceReveal').hidden=true;return;}
  get('practiceQuestion').textContent=current.question+(kind==='flashcard'&&current.target.pinyin?'\n'+current.target.pinyin:'');
  if(kind==='flashcard')return;
  if(current.options.length<2){get('practiceFeedback').textContent='Add at least two words with different answers for this exercise. Flashcards work with one word.';return;}
  for(const value of current.options){const button=document.createElement('button');button.textContent=value;button.type='button';button.addEventListener('click',async()=>{
   if(answered)return;answered=true;const correct=value===current.answer;get('practiceFeedback').textContent=(correct?'Correct. ':'Try again next time. ')+current.target.word+' · '+current.target.pinyin+' · '+current.target.meaning;
   try{await review(current.target.word,correct?'Good':'Again');}catch{get('practiceFeedback').textContent+=' Review progress could not be saved.';}
   for(const item of get('practiceOptions').querySelectorAll('button'))item.disabled=true;
  });get('practiceOptions').append(button);}
 }
 get('practiceOpen').addEventListener('click',()=>{index=0;draw();get('practice').showModal();});get('practiceClose').addEventListener('click',()=>{speechSynthesis?.cancel();get('practice').close();});
 get('practiceNext').addEventListener('click',()=>{index++;draw();});get('practiceKind').addEventListener('change',draw);
 get('practiceReveal').addEventListener('click',()=>{if(current?.target)get('practiceFeedback').textContent=current.target.meaning+(current.target.example?' · '+current.target.example:'');});
 get('practiceListen').addEventListener('click',()=>{
  if(!current?.target)return;const voice=globalThis.speechSynthesis?.getVoices().find(v=>v.localService&&/^(zh|cmn)/i.test(v.lang));
  if(!voice){get('practiceFeedback').textContent='No installed local Mandarin voice. Choose another exercise or install a Chinese system voice.';return;}
  const utterance=new SpeechSynthesisUtterance(current.target.word);utterance.voice=voice;utterance.lang=voice.lang;utterance.rate=.8;speechSynthesis.cancel();speechSynthesis.speak(utterance);
 });
 get('practice').addEventListener('close',()=>globalThis.speechSynthesis?.cancel());
})();
