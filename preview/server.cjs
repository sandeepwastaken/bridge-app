const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const port = Number(process.env.BRIDGE_PORT || 4173);
const types = {'.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.html':'text/html; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.md':'text/plain; charset=utf-8','.woff2':'font/woff2','.ttf':'font/ttf','.gif':'image/gif','.mp4':'video/mp4','.txt':'text/plain; charset=utf-8'};
http.createServer(async (req, res) => {
  const host = req.headers.host;
  if (!['127.0.0.1:' + port, 'localhost:' + port].includes(host)) { res.writeHead(403); return res.end('Local access only'); }
  const origin = req.headers.origin;
  if (origin && !['http://127.0.0.1:' + port,'http://localhost:' + port].includes(origin)) { res.writeHead(403); return res.end('Local access only'); }
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Referrer-Policy','no-referrer');
  res.setHeader('Permissions-Policy','microphone=(self), camera=(), geolocation=()');
  let url;
  try { url = new URL(req.url, 'http://' + host); } catch { res.writeHead(400); return res.end(); }
  if (url.pathname.startsWith('/api/')) {
    const endpoint = url.pathname.slice(5);
    if (!['capabilities','translate','transcribe'].includes(endpoint) || (endpoint === 'capabilities' ? req.method !== 'GET' : req.method !== 'POST')) { res.writeHead(404); return res.end(); }
    const chunks=[]; let size=0;
    try {
      for await (const chunk of req) { size+=chunk.length; if(size > 2880000) {res.writeHead(413);return res.end();} chunks.push(chunk); }
      const controller = new AbortController();
      const timer = setTimeout(()=>controller.abort(), 175000);
      try {
        const upstream = await fetch('http://127.0.0.1:4174/' + endpoint + url.search, {method:req.method, headers:{'Content-Type': endpoint === 'transcribe' ? 'application/octet-stream' : 'application/json'}, ...(req.method === 'POST' ? {body:Buffer.concat(chunks)} : {}),signal:controller.signal});
        res.writeHead(upstream.status,{'Content-Type':'application/json; charset=utf-8'}); res.end(await upstream.text());
      } finally { clearTimeout(timer); }
    } catch { if(!res.headersSent)res.writeHead(503,{'Content-Type':'application/json'});res.end(JSON.stringify({error:'The local language service is not running. You can still type, read and use saved phrases.',speech:'unavailable',translation:'unavailable'})); }
    return;
  }
  if (req.method !== 'GET' && req.method !== 'HEAD') {res.writeHead(405);return res.end();}
  let pathname; try {pathname=decodeURIComponent(url.pathname);}catch{res.writeHead(400);return res.end();}
  const documents=pathname.startsWith('/docs/');
  const rootDocument=/^\/(README|PRIVACY_POLICY)\.md$/.test(pathname);
  const allowedRoot=documents?path.resolve(root,'../docs'):rootDocument?path.resolve(root,'..'):root;
  const relative=documents?pathname.slice(5):pathname;
  const file=path.resolve(allowedRoot,'.'+(relative==='/'?'/index.html':relative));
  const type=types[path.extname(file)];
  if (!file.startsWith(allowedRoot+path.sep)||!type||file.includes(path.sep+'.')){res.writeHead(403);return res.end();}
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404);return res.end('Not found');}res.setHeader('Content-Type',type);res.end(req.method==='HEAD'?undefined:data);});
}).listen(port,'127.0.0.1',()=>console.log('Bridge preview: http://127.0.0.1:'+port));
