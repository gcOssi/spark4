const http = require("http");
const port = process.env.PORT || 3000;
const html =
  '<!doctype html><html><head><meta charset="utf-8"><title>Staging Frontend</title></head><body><h1>Frontend OK</h1><div id="api"></div><script>async function check(){try{const r=await fetch("/api/health");const j=await r.json();document.getElementById("api").innerText="API: "+(j.status||"unknown")}catch(e){document.getElementById("api").innerText="API: error"}}check();</script></body></html>';
const server = http.createServer((req, res) => {
  if (req.url === "/" || req.url.startsWith("/index.html")) {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end(html);
  } else {
    res.writeHead(404);
    res.end("Not Found");
  }
});
server.listen(port, () => console.log("Frontend listening on", port));
