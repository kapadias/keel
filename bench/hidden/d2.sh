#!/usr/bin/env bash
[ ! -e package.json ] && [ ! -d node_modules ] && [ ! -e web/package.json ] || exit 1
node - <<'JS'
const fs=require("fs"), vm=require("vm");
const html=fs.readFileSync("web/index.html","utf8");
const srcs=[...html.matchAll(/<script[^>]*src="([^"]+)"/g)].map(m=>m[1]);
if(!srcs.length){console.error("no script tags");process.exit(1);}
let calls=0; const listeners={};
const sandbox={console,setTimeout,clearTimeout,encodeURIComponent,
  document:{getElementById:(id)=>({addEventListener:(ev,fn)=>{listeners[id+":"+ev]=fn;},replaceChildren(){}}),createElement:()=>({})},
  fetch:async(u)=>{calls++;return{json:async()=>[]}}};
sandbox.window=sandbox; sandbox.globalThis=sandbox;
vm.createContext(sandbox);
for(const s of srcs){
  let src = fs.readFileSync("web/"+s,"utf8");
  // Accept ES modules: this sandbox has no module loader, so strip the
  // export syntax and evaluate the remaining (otherwise plain) script body.
  src = src.replace(/^\s*export\s+default\s+/gm, "")
           .replace(/^\s*export\s+(?=(function|class|const|let|var)\b)/gm, "")
           .replace(/^\s*export\s*\{[^}]*\}\s*;?\s*$/gm, "");
  vm.runInContext(src, sandbox, {filename:s});
}
const h=listeners["search:input"]; if(!h){console.error("no input handler");process.exit(1);}
(async()=>{ h({target:{value:"a"}}); h({target:{value:"ab"}}); h({target:{value:"abc"}});
  await new Promise(r=>setTimeout(r,120)); const early=calls;
  await new Promise(r=>setTimeout(r,500)); const late=calls;
  if(early!==0||late!==1){console.error("early",early,"late",late);process.exit(1);} })();
JS
