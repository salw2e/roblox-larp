// draws roblox avatars with the open source RoAvatar renderer (GPL-3.0) in a headless chrome.
// POST /draw {def, glb, png, size} -> {glb: base64, png: dataURL}
import http from "node:http";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import puppeteer from "puppeteer-core";

const PORT = Number(process.env.RENDER_PORT ?? 8096);
// a logged-out cookie is refused where no cookie at all is fine, so it is dropped after its first 401
let deadCookie;
const cookie = () => { try { return statSync(process.env.ROBLOX_COOKIE_FILE).mtimeMs === deadCookie ? "" : readFileSync(process.env.ROBLOX_COOKIE_FILE, "utf8").trim(); } catch { return ""; } };
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
  const sent = ["GET", "HEAD"].includes(req.method) ? undefined : await body(req);
  if (roblox && cookie()) headers.cookie = ".ROBLOSECURITY=" + cookie();
  let r = await fetch(target, { method: req.method, headers, body: sent, signal: AbortSignal.timeout(30000) });
  if (r.status === 401 && headers.cookie) {
    deadCookie = statSync(process.env.ROBLOX_COOKIE_FILE).mtimeMs;
    console.error("roblox login expired, going on without it");
    delete headers.cookie;
    r = await fetch(target, { method: req.method, headers, body: sent, signal: AbortSignal.timeout(30000) });
  }
  for (const c of headers.cookie ? r.headers.getSetCookie() : []) {
    const fresh = /^\.ROBLOSECURITY=([^;]+)/.exec(c)?.[1];
    if (fresh && fresh !== cookie()) { writeFileSync(process.env.ROBLOX_COOKIE_FILE + ".new", fresh); renameSync(process.env.ROBLOX_COOKIE_FILE + ".new", process.env.ROBLOX_COOKIE_FILE); console.error("roblox gave a new login, kept it"); }
  }
  const out = { "content-type": r.headers.get("content-type") ?? "application/octet-stream" };
  if (r.headers.get("x-csrf-token")) out["x-csrf-token"] = r.headers.get("x-csrf-token");
  if ([401, 403].includes(r.status) && target.searchParams.get("id")) refused.add(target.searchParams.get("id"));
  if (!r.ok) console.error("roblox", r.status, (target.hostname + target.pathname + target.search).slice(0, 100));
  const bytes = Buffer.from(await r.arrayBuffer());
  if (file && r.status === 200) { writeFileSync(file + ".type", out["content-type"]); writeFileSync(file, bytes); }
  res.writeHead(r.status, out);
  res.end(bytes);
}

// roblox's built-in files (body parts, heads, rigs) only download with a login, so they come from a copy of the roblox app's content folder
const BUILT_IN = process.env.RENDER_BUILT_IN ?? "built-in";
function local(res, path) {
  const file = `${BUILT_IN}${path}`;
  if (!existsSync(file)) { console.error("no built-in file", path); res.writeHead(404); return res.end(); }
  res.writeHead(200, { "content-type": "application/octet-stream" });
  res.end(readFileSync(file));
}

let browser, page, idle, line = Promise.resolve();
const refused = new Set();       // items roblox would not hand over; the page remembers its failures, so this is never cleared

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
    const once = (j) => Promise.race([
      p.evaluate((j) => window.draw(j.def, j), j),
      new Promise((_, no) => setTimeout(() => no(new Error("took too long")), 150000)),
    ]);
    const known = { ...job, def: { ...job.def, assets: job.def.assets.filter((a) => !refused.has(String(a.id))) } };
    let out = await once(known);
    const kept = known.def.assets.filter((a) => !refused.has(String(a.id)));
    if (job.glb && !out.glb && kept.length < known.def.assets.length) {
      // an item roblox keeps behind a login (old classic t-shirts) is left off rather than losing the whole avatar
      console.error("left off", known.def.assets.length - kept.length, "items roblox refused");
      out = await once({ ...job, def: { ...job.def, assets: kept } });
    }
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
    if (/^\/(rbxasset|rig)\//.test(u.pathname) && !u.pathname.includes("..")) return local(res, decodeURIComponent(u.pathname));
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
