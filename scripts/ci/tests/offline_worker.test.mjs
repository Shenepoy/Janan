import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

const template = await readFile(new URL('../offline_worker.js', import.meta.url), 'utf8');
const scope = 'https://diary.example/app/';
const files = {'index.html':'sha256-shell','main.dart.js':'sha256-code',
  'assets/translations/ar.json':'sha256-ar','sqlite3.wasm':'sha256-sqlite', 'version.json':'sha256-version'};
function harness({version='a', store=new Map(), fail=false}={}) {
  const handlers = {}, requests = [];
  let online = true, storageMode = 'normal';
  const calls = {claim:0,skip:0};
  const caches = {
    async open(name) {
      if (storageMode === 'unavailable') throw Error('Storage blocked');
      if (!store.has(name)) store.set(name,new Map());
      const entries=store.get(name);
      return {async put(url,response){if(storageMode==='readonly')throw Error('Quota exceeded');entries.set(url,response);}, async match(url){return entries.get(url);}};
    }, async keys(){return [...store.keys()];}, async delete(name){return store.delete(name);},
  };
  vm.runInNewContext(template.replace('/* BUILD_MANIFEST */',JSON.stringify({version,files})), {
    URL, Request, Response, caches,
    self:{registration:{scope, async update(){}},addEventListener:(name,handler)=>handlers[name]=handler,
      skipWaiting(){calls.skip++;},clients:{claim(){calls.claim++;}}},
    fetch: async request=>{
      requests.push(request);
      if (!online || fail && request.url.endsWith('main.dart.js')) throw Error('interrupted');
      return {ok:true,type:'basic',body:version+':'+request.url, clone(){return this;}};
    },
  });
  return {store,requests,calls, setOnline(value){online=value;}, setStorageMode(value){storageMode=value;},
    async event(name){let work;handlers[name]({waitUntil:p=>work=p});await work;},
    async get(path,options={}) {
      let work;
      const request={url:new URL(path,scope).href,method:'GET',mode:'cors',headers:new Headers(),...options};
      handlers.fetch({request,respondWith:p=>work=p,waitUntil:p=>p.catch(()=>{})});
      return work;
    },
  };
}

test('offline shell serves complete static assets and bare diary navigations',async()=>{
  const h=harness();await h.event('install');await h.event('activate');
  assert.equal(h.requests.length,5);
  for (const req of h.requests) {
    assert.equal(req.credentials,'omit');assert.equal(req.redirect,'error');
    assert.equal(req.integrity,files[req.url.slice(scope.length)]);
  }
  const before=h.requests.length;
  assert.equal((await h.get('',{mode:'navigate'})).body,'a:'+scope+'index.html');
  assert.equal((await h.get('assets/translations/ar.json')).body,'a:'+scope+'assets/translations/ar.json');
  assert.equal(h.requests.length,before);
});

test('API, auth, report, queried, authorized and non-GET requests never enter the cache handler',async()=>{
  const h=harness();await h.event('install');
  for (const path of ['recover?code=secret','caregivers','connect','oauth/consent',
    'sharing/','functions/v1/report','?token=secret','main.dart.js?secret=x',
    'https://api.example/main.dart.js','https://diary.example/other/']) {
    assert.equal(await h.get(path,{mode:'navigate'}),undefined,path);
  }
  assert.equal(await h.get('main.dart.js',{method:'POST'}),undefined);
  assert.equal(await h.get('main.dart.js',{headers:new Headers({Authorization:'Bearer fixture'})}),undefined);
  assert.equal(await h.get('sqlite3.wasm',{headers:new Headers({Range:'bytes=0-9'})}),undefined);
  assert.equal(h.requests.length,5);
});

test('failed updates discard partial new assets and keep previous offline version intact',async()=>{
  const old=harness();await old.event('install');
  old.store.set('unrelated-cache',new Map([['private','untouched']]));
  const next=harness({version:'b',store:old.store,fail:true});
  await assert.rejects(next.event('install'),/incomplete/);
  assert.equal(old.store.has('janan-shell:'+scope+':b'),false);
  assert.equal((await old.get('main.dart.js')).body,'a:'+scope+'main.dart.js');
  assert.deepEqual([...old.store.keys()],['janan-shell:'+scope+':a','unrelated-cache']);
});

test('updates do not take over live tabs; activation removes only this scope’s old shell',async()=>{
  const old=harness();await old.event('install');
  old.store.set('janan-shell:https://diary.example/elsewhere/:a',new Map());
  old.store.set('unrelated-cache',new Map());
  const next=harness({version:'b',store:old.store});await next.event('install');
  assert.equal((await old.get('main.dart.js')).body,'a:'+scope+'main.dart.js');
  assert.equal((await next.get('main.dart.js')).body,'b:'+scope+'main.dart.js');
  assert.deepEqual(next.calls,{claim:0,skip:0});
  await next.event('activate');
  assert.equal(old.store.has('janan-shell:'+scope+':a'),false);
  assert.equal(old.store.has('unrelated-cache'),true);
  assert.equal(old.store.has('janan-shell:https://diary.example/elsewhere/:a'),true);
  assert.deepEqual(next.calls,{claim:0,skip:0});
});

test('evicted files must match the active build instead of silently mixing deployments',async()=>{
  const h=harness();await h.event('install');
  h.store.get('janan-shell:'+scope+':a').delete(scope+'main.dart.js');
  await h.get('main.dart.js');
  assert.equal(h.requests.at(-1).integrity,'sha256-code');
  assert.equal(h.requests.at(-1).cache,'reload');
});


test('Flutter version metadata is available offline with its numeric cachebuster',async()=>{
  const h=harness(); await h.event('install');
  const before=h.requests.length;
  assert.equal((await h.get('version.json?cachebuster=1794194028958'))?.body,'a:'+scope+'version.json');
  assert.equal(h.requests.length,before);
  for (const path of ['version.json?token=secret','version.json?cachebuster=1&token=secret',
    'version.json?cachebuster=1&cachebuster=2','version.json?cachebuster=secret']) {
    assert.equal(await h.get(path),undefined);
  }
});

const registrationScript = await readFile(new URL('../../../web/offline.js',import.meta.url),'utf8');
async function registrationAt(path,registration={}) {
  const calls=[],nodes=new Map();
  function element() {
    return {children:[],textContent:'',setAttribute(){},addEventListener(){},
      append(...children){this.children.push(...children);},get firstChild(){return this.children[0];}};
  }
  vm.runInNewContext(registrationScript,{
    URL, location:new URL(path,scope),
    document:{addEventListener(){},removeEventListener(){},baseURI:scope,getElementById:id=>nodes.get(id),createElement:element,
      body:{append(node){nodes.set(node.id,node);}}},
    navigator:{serviceWorker:{async register(url,options){calls.push({url,options});return {
      addEventListener(){},...registration,
    };}}},
  });
  await new Promise(resolve=>setImmediate(resolve));
  return {calls,message:nodes.get('janan-offline-status')?.firstChild.textContent};
}

test('only a clean diary entry registers offline caching, never account/report links',async()=>{
  for (const path of ['recover','connect','caregivers','oauth/consent','?code=secret','#invite=secret','#report=secret']) {
    assert.equal((await registrationAt(path)).calls.length,0,path);
  }
  const diary=await registrationAt('');
  assert.equal(diary.calls.length,1);
  assert.equal(diary.calls[0].url.href,scope+'janan_service_worker.js');
  assert.equal(diary.calls[0].options.updateViaCache,'none');
  assert.equal(diary.calls[0].options.scope,'/app/');
});

test('waiting updates explain safe reopening; registration alone never claims cached readiness',async()=>{
  assert.match((await registrationAt('',{waiting:{}})).message,/Close all Janan tabs/);
  assert.equal((await registrationAt('',{active:{}})).message,undefined);
});


test('an evicted app file is repaired for the next offline request',async()=>{
  const h=harness(); await h.event('install');
  h.store.get('janan-shell:'+scope+':a').delete(scope+'main.dart.js');
  await h.get('main.dart.js');
  h.setOnline(false);
  assert.equal((await h.get('main.dart.js')).body,'a:'+scope+'main.dart.js');
});

test('a missing offline shell returns recovery guidance without exposing request details',async()=>{
  const h=harness(); await h.event('install');
  h.store.delete('janan-shell:'+scope+':a');
  h.setOnline(false);
  const response=await h.get('',{mode:'navigate'});
  assert.equal(response.status,503);
  assert.match(await response.text(),/Try again/);
  assert.equal(response.headers.get('cache-control'),'no-store');
  assert.match(response.headers.get('content-security-policy'),/default-src 'none'/);
});


test('restricted cache access and quota failures do not prevent verified online use',async()=>{
  for (const mode of ['unavailable','readonly']) {
    const h=harness();await h.event('install');
    h.store.get('janan-shell:'+scope+':a').delete(scope+'main.dart.js');
    h.store.set('unrelated-cache',new Map([['keep','untouched']]));
    h.setStorageMode(mode);
    assert.equal((await h.get('main.dart.js')).body,'a:'+scope+'main.dart.js');
    assert.equal(h.store.get('unrelated-cache').get('keep'),'untouched');
  }
});
