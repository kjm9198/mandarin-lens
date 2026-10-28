'use strict';
const fs=require('node:fs'),{execFileSync}=require('node:child_process'),assert=require('node:assert/strict');
const manifest=JSON.parse(fs.readFileSync('manifest.json','utf8'));
assert.equal(manifest.version,'1.0.0');assert.equal(manifest.manifest_version,3);
assert.deepEqual([...manifest.permissions].sort(),['activeTab','scripting','storage'].sort());
assert.ok(!manifest.host_permissions&&!manifest.content_scripts&&!manifest.web_accessible_resources&&!manifest.externally_connectable);
assert.equal(manifest.content_security_policy.extension_pages,"script-src 'self'; object-src 'none'; base-uri 'none'; connect-src 'none'");
for(const file of ['content.js','core.js','preprocess.js','popup.js','vocabulary.js','data/pinyin.js']){
  execFileSync(process.execPath,['--check',file]);const text=fs.readFileSync(file,'utf8');
  for(const unsafe of [/\binnerHTML\b/,/\beval\s*\(/,/new\s+Function\b/,/\bfetch\s*\(/,/\bXMLHttpRequest\b/,/\bWebSocket\b/,/AKIA[0-9A-Z]{16}/,/gh[pousr]_[A-Za-z0-9]{20,}/,/-----BEGIN .*PRIVATE KEY-----/])assert.ok(!unsafe.test(text),`${file} failed source check ${unsafe}`);
}
for(const file of ['popup.html','vocabulary.html','help.html'])assert.ok(!/<script[^>]*src=["']https?:|\son\w+\s*=/i.test(fs.readFileSync(file,'utf8')),`Unsafe script/event attribute in ${file}`);
assert.ok(fs.readFileSync('licenses/UNICODE-LICENSE.txt','utf8').includes('Permission is hereby granted'));
console.log('Manifest, application syntax, permission, executable/network sink and credential-pattern checks passed. Static checks are not an independent security audit.');
