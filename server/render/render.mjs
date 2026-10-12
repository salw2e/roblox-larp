// draws roblox avatars with the open source RoAvatar renderer (GPL-3.0) in a headless chrome.
// POST /draw {def, glb, png, size} -> {glb: base64, png: dataURL}
import http from "node:http";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import puppeteer from "puppeteer-core";

const PORT = Number(process.env.RENDER_PORT ?? 8096);
const cookie = () => readFileSync(process.env.ROBLOX_COOKIE_FILE, "utf8").trim();
const files = {
  "/": ["text/html", '<!doctype html><script src="/draco_decoder.js"></script><script src="/page.js"></script>'],
  "/page.js": ["text/javascript", readFileSync(new URL("page.js", import.meta.url))],
  "/draco_decoder.js": ["text/javascript", readFileSync(new URL("node_modules/roavatar-renderer/dist/draco_decoder.js", import.meta.url))],
};
const body = (req) => new Promise((ok) => { const c = []; req.on("data", (d) => c.push(d)); req.on("end", () => ok(Buffer.concat(c))); });

const KEEP = process.env.RENDER_CACHE ?? "asset-cache";
mkdirSync(KEEP, { recursive: true });
const kept = (url) => `${KEEP}/${createHash("sha1").update(url).digest("hex")}`;

async function proxy(req, res, u) {
  const target = new URL(u.searchParams.get("u"));
  // item files never change under the same address, so they are kept on disk for a day
  const file = req.method === "GET" && /^(assetdelivery\.roblox\.com|contentdelivery\.roblox\.com|.*\.rbxcdn\.com)$/.test(target.hostname) ? kept(target.href) : null;
  if (file && existsSync(file) && Date.now() - statSync(file).mtimeMs < 86400000) {
    res.writeHead(200, { "content-type": readFileSync(file + ".type", "utf8") });
    return res.end(readFileSync(file));
  }
  const roblox = target.hostname === "roblox.com" || target.hostname.endsWith(".roblox.com");
  if (target.protocol !== "https:" || (!roblox && !target.hostname.endsWith(".rbxcdn.com"))) { res.writeHead(403); return res.end("no"); }
  const headers = { "user-agent": "Mozilla/5.0" };
  for (const [k, v] of Object.entries(req.headers)) {
    if (!["host", "origin", "referer", "cookie", "connection", "content-length", "accept-encoding", "user-agent"].includes(k) && !k.startsWith("sec-")) headers[k] = v;
  }
  if (roblox) headers.cookie = ".ROBLOSECURITY=" + cookie();
  const r = await fetch(target, { method: req.method, headers, body: ["GET", "HEAD"].includes(req.method) ? undefined : await body(req), signal: AbortSignal.timeout(30000) });
  const out = { "content-type": r.headers.get("content-type") ?? "application/octet-stream" };
  if (r.headers.get("x-csrf-token")) out["x-csrf-token"] = r.headers.get("x-csrf-token");
  if (!r.ok) console.error("roblox", r.status, target.hostname + target.pathname.slice(0, 60));
  const bytes = Buffer.from(await r.arrayBuffer());
  if (file && r.status === 200) { writeFileSync(file + ".type", out["content-type"]); writeFileSync(file, bytes); }
  res.writeHead(r.status, out);
  res.end(bytes);
}

let browser, page, idle, line = Promise.resolve();

async function tab() {
  if (page && !page.isClosed() && browser?.connected) return page;
  await browser?.close().catch(() => {});
  browser = await puppeteer.launch({
    executablePath: process.env.CHROME ?? "/opt/google/chrome/chrome",
    args: ["--no-sandbox", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--disable-dev-shm-usage"],
  });
  page = await browser.newPage();
  page.on("pageerror", (e) => console.error("page:", e.message.slice(0, 200)));
  await page.goto(`http://127.0.0.1:${PORT}/`);
  await page.waitForFunction("window.loaded === true", { timeout: 30000 });
  return page;
}

const shut = () => { browser?.close().catch(() => {}); browser = page = undefined; };

async function draw(job) {
  clearTimeout(idle);
  const started = Date.now();
  try {
    const p = await tab();
    const out = await Promise.race([
      p.evaluate((j) => window.draw(j.def, j), job),
      new Promise((_, no) => setTimeout(() => no(new Error("took too long")), 150000)),
    ]);
    console.error("drew", job.def.assets.length, "items in", Date.now() - started, "ms");
    return out;
  } catch (e) {
    shut();                                 // a stuck page is cheaper to replace than to trust
    throw e;
  } finally {
    idle = setTimeout(shut, Number(process.env.RENDER_IDLE ?? 120) * 1000);       // chrome goes away when nobody is dressing up
  }
}

http.createServer(async (req, res) => {
  const u = new URL(req.url, "http://x");
  try {
    if (files[u.pathname]) { res.writeHead(200, { "content-type": files[u.pathname][0] }); return res.end(files[u.pathname][1]); }
    if (u.pathname === "/rbx") return await proxy(req, res, u);
    if (u.pathname === "/draw" && req.method === "POST") {
      const job = JSON.parse(await body(req));
      const out = await (line = line.catch(() => {}).then(() => draw(job)));
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify(out));
    }
    res.writeHead(404); res.end();
  } catch (e) {
    console.error("failed:", e.message.slice(0, 300));
    if (!res.headersSent) res.writeHead(500, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: String(e.message).slice(0, 300) }));
  }
}).listen(PORT, "127.0.0.1", () => console.error("render service on", PORT));

// item files older than a week go
setInterval(() => {
  for (const f of readdirSync(KEEP)) if (Date.now() - statSync(`${KEEP}/${f}`).mtimeMs > 7 * 86400000) rmSync(`${KEEP}/${f}`, { force: true });
}, 6 * 3600000).unref();
