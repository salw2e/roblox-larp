#!/usr/bin/env python3
import base64, collections, gzip, hashlib, http.server, json, os, re, shutil, struct, sys, threading, time
import urllib.error, urllib.parse, urllib.request
import numpy as np

COOKIE_FILE = os.environ.get("ROBLOX_COOKIE_FILE", "cookie.txt")
KEY_FILE = os.environ.get("BLOX_KEY_FILE", "key.txt")
CI_REPO = "salw2e/roblox-larp"
CACHE = os.environ.get("BLOX_CACHE", "cache")
PUBLIC = os.environ.get("BLOX_PUBLIC", "")
RENDER = os.environ.get("BLOX_RENDER", "")       # the renderer in server/render, when it runs beside this
UA = "Mozilla/5.0"
csrf = ""
BUDGET_FILE = os.path.join(CACHE, "budget.json")
TYPES_FILE = os.path.join(CACHE, "types.json")
LOOKS_FILE = os.path.join(CACHE, "looks.json")
DRAWN_FILE = os.path.join(CACHE, "drawn.json")
budget = {"left": None, "reset_at": 0.0}
asset_types = {}
real_looks = {}
drawn = {}
render_lock = threading.Lock()
store_lock = threading.Lock()
calls = collections.deque()
CALLS_PER_HOUR = 60

def cookie():
    return open(COOKIE_FILE).read().strip()

def remember(path, value):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(value, f)
    os.replace(tmp, path)

def recall():
    try:
        budget.update(json.load(open(BUDGET_FILE)))
    except (OSError, ValueError):
        pass
    try:
        asset_types.update({int(k): v for k, v in json.load(open(TYPES_FILE)).items()})
    except (OSError, ValueError):
        pass
    try:
        real_looks.update(json.load(open(LOOKS_FILE)))
    except (OSError, ValueError):
        pass
    try:
        drawn.update(json.load(open(DRAWN_FILE)))
    except (OSError, ValueError):
        pass

def note_budget(headers):
    left, reset = headers.get("x-ratelimit-remaining"), headers.get("x-ratelimit-reset")
    if left is not None and reset is not None:
        budget["left"], budget["reset_at"] = int(left), time.time() + int(reset)
        remember(BUDGET_FILE, budget)

def budget_now():
    if budget["left"] is not None and time.time() >= budget["reset_at"]:
        budget["left"] = None
    return {"left": budget["left"], "resetIn": max(0, int(budget["reset_at"] - time.time())) if budget["left"] is not None else 0}

def budget_told():
    # what the app hears: with our own renderer beside us there is nothing for it to wait for
    return {"left": None, "resetIn": 0} if RENDER else budget_now()

SINGLE = {2, 11, 12, 17, 18, 27, 28, 29, 30, 31, 76, 77, 78, 79} | set(range(48, 57))
LAYERED = set(range(64, 73))
ACCESSORY = {8, 41, 42, 43, 44, 45, 46, 47}
MAX_ACCESSORIES = 10
WEARABLE = SINGLE | LAYERED | ACCESSORY
DEFAULT_BODY = {
    "bodyColors": {k: "#A3A2A5" for k in ("headColor", "leftArmColor", "leftLegColor", "rightArmColor", "rightLegColor", "torsoColor")},
    "scales": {"depth": 1, "head": 1, "height": 1, "proportion": 0, "width": 1, "bodyType": 0},
    "playerAvatarType": {"playerAvatarType": "R15"},
}

class Refused(Exception):
    pass

class Busy(Refused):
    pass

def render_wait():
    return f"Roblox only draws a few new outfits an hour. Try again in about {max(1, round(budget_now()['resetIn'] / 60))} min."

def rbx(url, body=None, login=True):
    global csrf
    for attempt in range(2):
        headers = {"User-Agent": UA, "Accept": "application/json"}
        if login:
            headers["Cookie"] = ".ROBLOSECURITY=" + cookie()
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
            headers["x-csrf-token"] = csrf
        try:
            with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers), timeout=25) as r:
                if "/avatar/render" in url:
                    note_budget(r.headers)
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if "/avatar/render" in url:
                note_budget(e.headers)
            token = e.headers.get("x-csrf-token")
            if e.code == 403 and token and attempt == 0:
                csrf = token
                continue
            if e.code == 401:
                raise Refused("The Roblox login on the server has expired. Sal needs to send a new cookie.")
            if e.code == 429:
                raise Busy(render_wait() if "/avatar/render" in url else "Roblox is busy (too many requests). Try again in a minute.")
            detail = e.read().decode("utf-8", "replace")[:300]
            try:
                detail = json.loads(detail)["errors"][0]["message"] or detail
            except Exception:
                pass
            raise Refused(f"Roblox refused ({e.code}): {detail}")
        except (urllib.error.URLError, TimeoutError):
            raise Refused("Roblox didn't answer. Try again.")

def cdn(h):
    i = 31
    for c in h[:38]:
        i ^= ord(c)
    return f"https://t{i % 8}.rbxcdn.com/{h}"

def download(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Encoding": "gzip"})
    with urllib.request.urlopen(req, timeout=30) as r:
        b = r.read()
    return gzip.decompress(b) if b[:2] == b"\x1f\x8b" else b

def plain_mtl(mtl, names):
    out = []
    for block in re.split(r"(?m)^(?=newmtl )", mtl):
        lines = [l for l in block.splitlines() if l.strip() and not l.startswith(("map_d", "map_Ka", "Material"))]
        textured = any(l.startswith("map_Kd") for l in lines)
        for l in lines:
            if l.startswith("map_Kd"):
                l = "map_Kd " + names.get(l.split()[-1], l.split()[-1])
            elif textured and l.startswith(("Kd ", "Ka ")):
                l = l[:2] + " 1 1 1"
            elif l.startswith("Ks "):
                l = "Ks 0 0 0"
            out.append(l)
        out.append("")
    return "\n".join(out)

def upright(obj, toward_camera):
    lines = obj.split("\n")
    v = np.array([[float(x) for x in l.split()[1:4]] for l in lines if l.startswith("v ")])
    body, group = set(), ""
    for l in lines:
        if l.startswith("g "):
            group = l[2:].strip()
        elif l.startswith("f ") and group.startswith("Player"):
            body.update(int(c.split("/")[0]) - 1 for c in l.split()[1:])
    pts = v[sorted(i for i in body if 0 <= i < len(v))] if body else v
    if len(pts) < 4:
        return obj
    _, axes = np.linalg.eigh(np.cov((pts - pts.mean(0)).T))
    front = axes[:, 0] * (1 if axes[:, 0] @ toward_camera >= 0 else -1)
    up = np.array([0.0, 1.0, 0.0]) - front[1] * front
    if np.linalg.norm(up) < 0.5:
        return obj
    up /= np.linalg.norm(up)
    side = np.cross(up, front)
    turn = np.array([[-1, 0, 0], [0, 1, 0], [0, 0, -1]]) @ np.array([side, up, front])   # side->-X, up->+Y, front->-Z
    if np.allclose(turn, np.eye(3), atol=0.002):
        return obj
    out = []
    for l in lines:
        if l.startswith("v ") or l.startswith("vn "):
            head, *xyz = l.split()
            r = turn @ np.array([float(x) for x in xyz[:3]])
            l = f"{head} {r[0]:.6g} {r[1]:.6g} {r[2]:.6g}"
        out.append(l)
    return "\n".join(out)

def store_model(description_url):
    d = json.loads(download(description_url))
    key = hashlib.sha1("|".join(["up1", d["obj"], d["mtl"]] + d.get("textures", [])).encode()).hexdigest()[:20]
    folder = os.path.join(CACHE, key)
    names = {h: f"tex{i}.png" for i, h in enumerate(d.get("textures", []))}
    with store_lock:
        fetch_model(d, folder, names)
    base = f"{PUBLIC}/file/{key}"
    return {"obj": f"{base}/a.obj", "mtl": f"{base}/a.mtl", "textures": [f"{base}/{n}" for n in names.values()],
            "camera": d.get("camera"), "aabb": d.get("aabb")}

def fetch_model(d, folder, names):
    if not os.path.exists(os.path.join(folder, "done")):
        tmp = folder + ".part"
        shutil.rmtree(tmp, ignore_errors=True)
        os.makedirs(tmp)
        obj = download(cdn(d["obj"])).decode("utf-8", "replace")
        obj = re.sub(r"(?m)^mtllib .*$", "mtllib a.mtl", obj)
        if "mtllib" not in obj:
            obj = "mtllib a.mtl\n" + obj
        cam = (d.get("camera") or {}).get("direction") or {}
        obj = upright(obj, np.array([cam.get("x", 0), cam.get("y", 0), cam.get("z", -1)], dtype=float))
        open(os.path.join(tmp, "a.obj"), "w").write(obj)
        open(os.path.join(tmp, "a.mtl"), "w").write(plain_mtl(download(cdn(d["mtl"])).decode("utf-8", "replace"), names))
        for h, name in names.items():
            open(os.path.join(tmp, name), "wb").write(download(cdn(h)))
        open(os.path.join(tmp, "done"), "w").close()
        shutil.rmtree(folder, ignore_errors=True)
        os.rename(tmp, folder)
        sweep()

def sweep():
    for name in os.listdir(CACHE):
        path = os.path.join(CACHE, name)
        if os.path.isdir(path) and time.time() - os.path.getmtime(path) > 2 * 86400:
            shutil.rmtree(path, ignore_errors=True)

def wait_for(fetch):
    deadline = time.time() + 60
    while time.time() < deadline:
        try:
            r = fetch()
        except Busy:
            time.sleep(4)
            continue
        r = r["data"][0] if "data" in r else r
        if r.get("state") == "Completed" and r.get("imageUrl"):
            return r["imageUrl"]
        if r.get("state") not in ("Pending", None):
            raise Refused(f"Roblox could not draw that avatar ({r.get('state')}).")
        time.sleep(2)
    raise Refused("Roblox took too long to draw the avatar. Try again.")

def look_of_user(username):
    found = rbx("https://users.roblox.com/v1/usernames/users", {"usernames": [username], "excludeBannedUsers": True}, login=False)
    if not found.get("data"):
        raise Refused("No Roblox user with that name.")
    uid = found["data"][0]["id"]
    a = rbx(f"https://avatar.roblox.com/v2/avatar/users/{uid}/avatar")
    for x in a.get("assets", []):
        if x.get("assetType", {}).get("id"):
            asset_types[x["id"]] = x["assetType"]["id"]
    remember(TYPES_FILE, asset_types)
    colours = a.get("bodyColor3s", {})
    definition = {
        "assets": [{k: v for k, v in x.items() if k in ("id", "meta")} for x in a.get("assets", [])],
        "bodyColors": {k[:-1]: "#" + v for k, v in colours.items()},     # headColor3 -> headColor
        "scales": a.get("scales", DEFAULT_BODY["scales"]),
        "playerAvatarType": {"playerAvatarType": a.get("playerAvatarType", "R15")},
    }
    model = store_model(wait_for(lambda: rbx(f"https://thumbnails.roblox.com/v1/users/avatar-3d?userId={uid}")))
    image = wait_for(lambda: rbx(f"https://thumbnails.roblox.com/v1/users/avatar?userIds={uid}&size=720x720&format=Png", login=False))
    while len(real_looks) > 300:
        real_looks.pop(next(iter(real_looks)))
    real_looks[look_key(definition)] = username
    remember(LOOKS_FILE, real_looks)
    return {"definition": definition, "image": image, "model": model}

def look_key(d):
    return hashlib.sha1(json.dumps([sorted(a["id"] for a in d["assets"]), d["bodyColors"], d["scales"], d["playerAvatarType"]], sort_keys=True).encode()).hexdigest()

def asset_ids(wear):
    ids = []
    for w in wear:
        if w.get("bundle"):
            d = rbx(f"https://catalog.roblox.com/v1/bundles/{int(w['id'])}/details", login=False)
            ids += [i["id"] for i in d.get("items", []) if i.get("type") == "Asset"]
        else:
            ids.append(int(w["id"]))
    return ids

def one_per_slot(picks, worn_before=()):
    picks = [(aid, kind) for aid, kind in picks if kind in WEARABLE or aid in worn_before]
    last = {kind: aid for aid, kind in picks if kind in SINGLE}
    extras = [aid for aid, kind in picks if kind in ACCESSORY]
    dropped = set(extras[:-MAX_ACCESSORIES]) if len(extras) > MAX_ACCESSORIES else set()
    return [aid for aid, kind in picks if aid not in dropped and (kind not in SINGLE or last[kind] == aid)]

def learn_types(ids):
    missing = [i for i in dict.fromkeys(ids) if i not in asset_types]
    for n in range(0, len(missing), 100):
        ask = {"items": [{"itemType": "Asset", "id": i} for i in missing[n:n + 100]]}
        try:
            found = rbx("https://catalog.roblox.com/v1/catalog/items/details", ask)
        except Refused:
            try:
                found = rbx("https://catalog.roblox.com/v1/catalog/items/details", ask, login=False)
            except Refused:
                break
        for item in found.get("data", []):
            if item.get("assetType"):
                asset_types[item["id"]] = item["assetType"]
    if any(i in asset_types for i in missing):
        remember(TYPES_FILE, asset_types)

def type_of(aid):
    if aid not in asset_types:
        try:
            asset_types[aid] = rbx(f"https://economy.roblox.com/v2/assets/{aid}/details", login=False).get("AssetTypeId")
        except Refused:
            return None
        remember(TYPES_FILE, asset_types)
    return asset_types[aid]

def outfit(base, wear):
    base = base or {}
    known = {a["id"]: a for a in base.get("assets", [])}
    ids = list(dict.fromkeys(asset_ids(wear)))
    learn_types(ids)
    picks = [(aid, type_of(aid)) for aid in ids]
    kinds = dict(picks)
    assets = []
    for n, aid in enumerate(one_per_slot(picks, set(known))):
        entry = {"id": aid}
        if "meta" in known.get(aid, {}):
            entry["meta"] = known[aid]["meta"]
        elif kinds[aid] in LAYERED:
            entry["meta"] = {"order": 5 + n, "version": 1}
        assets.append(entry)
    return {
        "assets": assets,
        "bodyColors": base.get("bodyColors", DEFAULT_BODY["bodyColors"]),
        "scales": base.get("scales", DEFAULT_BODY["scales"]),
        "playerAvatarType": base.get("playerAvatarType", DEFAULT_BODY["playerAvatarType"]),
    }

COMP = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

def write_model(glb, folder):
    magic, _, _ = struct.unpack("<III", glb[:12])
    assert magic == 0x46546C67, "not a glb"
    n, _ = struct.unpack("<II", glb[12:20])
    j = json.loads(glb[20:20 + n])
    blob = glb[20 + n + 8:]

    def view(i):
        v = j["bufferViews"][i]
        return blob[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]], v.get("byteStride")

    def read(i):
        a = j["accessors"][i]
        data, stride = view(a["bufferView"])
        kind, width = np.dtype(COMP[a["componentType"]]), WIDTH[a["type"]]
        start, size = a.get("byteOffset", 0), kind.itemsize * width
        if stride and stride != size:
            rows = [np.frombuffer(data, kind, width, start + r * stride) for r in range(a["count"])]
            out = np.array(rows)
        else:
            out = np.frombuffer(data, kind, a["count"] * width, start).reshape(a["count"], width)
        if a.get("normalized") and kind.kind in "ui":
            out = out / np.iinfo(kind).max
        return out.astype(np.float64) if kind.kind == "f" or a.get("normalized") else out

    def local(node):
        if "matrix" in node:
            return np.array(node["matrix"], float).reshape(4, 4).T
        m = np.eye(4)
        if "rotation" in node:
            x, y, z, w = node["rotation"]
            m[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
        m[:3, :3] *= np.array(node.get("scale", [1, 1, 1]), float)
        m[:3, 3] = node.get("translation", [0, 0, 0])
        return m

    world = {}
    def walk(i, parent):
        world[i] = parent @ local(j["nodes"][i])
        for c in j["nodes"][i].get("children", []):
            walk(c, world[i])
    for root in j["scenes"][j.get("scene", 0)]["nodes"]:
        walk(root, np.eye(4))

    os.makedirs(folder, exist_ok=True)
    textures = {}
    def texture(material):
        t = j["materials"][material].get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if t is None:
            return None
        image = j["textures"][t["index"]]["source"]
        if image not in textures:
            textures[image] = f"tex{len(textures)}.png"
            open(os.path.join(folder, textures[image]), "wb").write(view(j["images"][image]["bufferView"])[0])
        return textures[image]

    obj, mtl, base, parts = ["mtllib a.mtl"], [], 1, 0
    for i, node in enumerate(j["nodes"]):
        if "mesh" not in node or i not in world:
            continue
        for prim in j["meshes"][node["mesh"]]["primitives"]:
            at = prim["attributes"]
            pos = read(at["POSITION"])[:, :3]
            ones = np.c_[pos, np.ones(len(pos))]
            nor = read(at["NORMAL"])[:, :3] if "NORMAL" in at else None
            if "skin" in node and "JOINTS_0" in at:
                skin = j["skins"][node["skin"]]
                inverse = read(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
                bones = np.array([world[b] @ inverse[k] for k, b in enumerate(skin["joints"])])
                joints, weights = read(at["JOINTS_0"]).astype(int), read(at["WEIGHTS_0"])
                weights = weights / np.maximum(weights.sum(1, keepdims=True), 1e-9)
                each = np.einsum("vk,vkab->vab", weights, bones[joints])
                pos = np.einsum("vab,vb->va", each, ones)[:, :3]
                if nor is not None:
                    nor = np.einsum("vab,vb->va", each[:, :3, :3], nor)
            else:
                m = world[i]
                pos = (ones @ m.T)[:, :3]
                if nor is not None:
                    nor = nor @ np.linalg.inv(m[:3, :3])
            uv = read(at["TEXCOORD_0"])[:, :2] if "TEXCOORD_0" in at else None
            faces = read(prim["indices"]).reshape(-1, 3) if "indices" in prim else np.arange(len(pos)).reshape(-1, 3)
            parts += 1
            name = f"Part{parts}"
            file = texture(prim["material"]) if "material" in prim else None
            colour = j["materials"][prim["material"]].get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1]) if "material" in prim else [1, 1, 1, 1]
            mtl += [f"newmtl {name}Mtl", "Ka 1 1 1", "Kd %g %g %g" % tuple(colour[:3]), "Ks 0 0 0", "d 1", "Ns 0"] + ([f"map_Kd {file}"] if file else []) + [""]
            obj += [f"g {name}", f"usemtl {name}Mtl"]
            obj += ["v %.5f %.5f %.5f" % tuple(p) for p in pos]
            if uv is not None:
                obj += ["vt %.5f %.5f" % (t[0], 1 - t[1]) for t in uv]
            if nor is not None:
                nor = nor / np.maximum(np.linalg.norm(nor, axis=1, keepdims=True), 1e-9)
                obj += ["vn %.4f %.4f %.4f" % tuple(x) for x in nor]
            def corner(k):
                k += base
                return f"{k}/{k if uv is not None else ''}/{k}" if nor is not None else (f"{k}/{k}" if uv is not None else f"{k}")
            obj += ["f " + " ".join(corner(int(k)) for k in f) for f in faces]
            base += len(pos)
    open(os.path.join(folder, "a.obj"), "w").write("\n".join(obj) + "\n")
    open(os.path.join(folder, "a.mtl"), "w").write("\n".join(mtl) + "\n")
    return list(textures.values())

def draw_here(definition):
    if not RENDER or any(a["id"] not in asset_types for a in definition["assets"]):
        return None
    job = {"def": {**definition, "assets": [{**a, "type": asset_types[a["id"]]} for a in definition["assets"]]},
           "glb": True, "png": True, "size": 720, "camera": "default"}
    try:
        ask = urllib.request.Request(RENDER + "/draw", data=json.dumps(job).encode(), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(ask, timeout=170) as r:
            out = json.loads(r.read())
        glb = base64.b64decode(out["glb"])
        picture = base64.b64decode(out["png"].split(",", 1)[1]) if out.get("png") else None
        key = hashlib.sha1(("own1|" + look_key(definition)).encode()).hexdigest()[:20]
        folder, tmp = os.path.join(CACHE, key), os.path.join(CACHE, key + ".part")
        with store_lock:
            shutil.rmtree(tmp, ignore_errors=True)
            textures = write_model(glb, tmp)
            if picture:
                open(os.path.join(tmp, "pic.png"), "wb").write(picture)
            open(os.path.join(tmp, "done"), "w").close()
            shutil.rmtree(folder, ignore_errors=True)
            os.rename(tmp, folder)
    except Exception as e:
        sys.stderr.write(f"own renderer failed: {e!r}\n")
        return None
    base = f"{PUBLIC}/file/{key}"
    return {"image": f"{base}/pic.png" if picture else None,
            "model": {"obj": f"{base}/a.obj", "mtl": f"{base}/a.mtl", "textures": [f"{base}/{n}" for n in textures], "camera": None, "aabb": None}}

def look_of_outfit(base, wear):
    definition = outfit(base, wear)
    owner = real_looks.get(look_key(definition))
    if owner:
        # exactly what a real user wears: their own roblox picture, and no render used up
        try:
            real = look_of_user(owner)
            if look_key(real["definition"]) == look_key(definition):
                return real
        except Refused:
            pass
    key = look_key(definition)
    kept = drawn.get(key)
    if kept:
        # drawn before: the same outfit again costs nothing
        if "obj" in kept:
            kept = {"image": None, "model": kept}
        folder = os.path.join(CACHE, kept["model"]["obj"].split("/")[-2])
        if os.path.exists(os.path.join(folder, "done")):
            os.utime(folder)
            return {"definition": definition, **kept}
        drawn.pop(key, None)
    mine = draw_here(definition)
    if mine:
        # our own drawing: no roblox render, so no hourly limit
        while len(drawn) > 400:
            drawn.pop(next(iter(drawn)))
        drawn[key] = mine
        remember(DRAWN_FILE, drawn)
        return {"definition": definition, **mine}
    body = {"thumbnailConfig": {"thumbnailId": 1, "thumbnailType": "3d", "size": "420x420"}, "avatarDefinition": definition}
    with render_lock:
        if budget_now()["left"] is not None and budget_now()["left"] < 2:
            raise Busy(render_wait())
        for pause in (0, 7, 10):
            if pause and budget_now()["left"] == 0:
                raise Busy("Roblox is still drawing this outfit and this hour's requests are used up. " + render_wait())
            time.sleep(pause)
            r = rbx("https://avatar.roblox.com/v1/avatar/render", body)
            if r.get("state") == "Completed" and r.get("imageUrl"):
                model = store_model(r["imageUrl"])
                while len(drawn) > 400:
                    drawn.pop(next(iter(drawn)))
                drawn[key] = {"image": None, "model": model}
                remember(DRAWN_FILE, drawn)
                return {"definition": definition, "image": None, "model": model}
            if r.get("state") != "Pending":
                raise Refused(f"Roblox could not draw that outfit ({r.get('state')}).")
        raise Refused("Roblox took too long to draw the outfit. Try again.")

class Handler(http.server.BaseHTTPRequestHandler):
    def reply(self, code, body, kind="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/budget":
            return self.reply(200, budget_told())
        g = re.fullmatch(r"/game/(\d{1,15})", self.path)
        if g:
            try:
                return self.reply(200, game_extras(int(g.group(1))))
            except Refused as e:
                return self.reply(422, {"error": str(e)})
        b = re.fullmatch(r"/badges/(\d{1,15})", self.path)
        if b:
            try:
                return self.reply(200, {"badges": badges_of(int(b.group(1)))})
            except Refused as e:
                return self.reply(422, {"error": str(e)})
        m = re.fullmatch(r"/file/([0-9a-f]{20})/(a\.obj|a\.mtl|pic\.png|tex\d{1,2}\.png)", self.path)
        path = m and os.path.join(CACHE, m.group(1), m.group(2))
        if not path or not os.path.isfile(path):
            return self.reply(404, {"error": "not found"})
        self.reply(200, open(path, "rb").read(), "image/png" if path.endswith(".png") else "text/plain")

    def do_POST(self):
        if self.path == "/ci-key":
            return self.ci_key()
        if self.path != "/look":
            return self.reply(404, {"error": "not found"})
        q = {}
        try:
            n = int(self.headers.get("Content-Length", 0))
            if not 0 < n <= 200_000:
                raise Refused("Bad request.")
            q = json.loads(self.rfile.read(n))
            now = time.time()
            while calls and now - calls[0] > 3600:
                calls.popleft()
            if len(calls) >= CALLS_PER_HOUR:
                raise Busy("The avatar service has been asked too often this hour. Try again later.")
            calls.append(now)
            if q.get("user"):
                out = look_of_user(str(q["user"])[:40])
            else:
                wear = q.get("wear") or []
                if not isinstance(wear, list) or len(wear) > 60:
                    raise Refused("Too many items.")
                out = look_of_outfit(q.get("base"), wear)
            self.reply(200, {**out, "budget": budget_told()})
        except Refused as e:
            what = q.get("user") if isinstance(q, dict) and q.get("user") else [w.get("id") for w in (q.get("wear") or [])] if isinstance(q, dict) else "?"
            sys.stderr.write(f"look refused: {e} | {what}\n")
            self.reply(422, {"error": str(e), "budget": budget_told()})
        except Exception as e:
            sys.stderr.write(f"look failed: {e!r}\n")
            self.reply(500, {"error": "The avatar service hit a problem. Try again."})

    def ci_key(self):
        try:
            token = self.headers.get("Authorization", "").removeprefix("Bearer ").strip()
            if not ci_may_have_key(token):
                return self.reply(403, {"error": "not for you"})
            self.reply(200, {"key": open(KEY_FILE).read().strip()})
        except Exception as e:
            sys.stderr.write(f"ci-key refused: {e!r}\n")
            self.reply(403, {"error": "not for you"})

    def log_message(self, *a):
        pass

GITHUB_ISSUER = "https://token.actions.githubusercontent.com"
_jwks = None

def ci_may_have_key(token, claims=None):
    global _jwks
    if claims is None:
        import jwt
        if _jwks is None:
            _jwks = jwt.PyJWKClient(GITHUB_ISSUER + "/.well-known/jwks")
        key = _jwks.get_signing_key_from_jwt(token).key
        claims = jwt.decode(token, key, algorithms=["RS256"], audience="blox-api", issuer=GITHUB_ISSUER)
    return (claims.get("repository") == CI_REPO and claims.get("ref") == "refs/heads/main"
            and claims.get("event_name") in ("push", "workflow_dispatch")
            and str(claims.get("workflow_ref", "")).startswith(CI_REPO + "/.github/workflows/build.yml@"))

badge_cache = {}

extras_cache = {}

def game_extras(universe):
    when, found = extras_cache.get(universe, (0, None))
    if found is not None and time.time() - when < 600:
        return found
    links = rbx(f"https://games.roblox.com/v1/games/{universe}/social-links/list")
    voice = rbx(f"https://voice.roblox.com/v1/settings/universe/{universe}")
    found = {"social": [{"type": x.get("type", ""), "url": x.get("url", ""), "title": x.get("title", "")} for x in links.get("data", [])],
             "voice": bool(voice.get("isUniverseEnabledForVoice")), "camera": bool(voice.get("isUniverseEnabledForAvatarVideo"))}
    extras_cache[universe] = (time.time(), found)
    return found

def badges_of(user_id):
    when, found = badge_cache.get(user_id, (0, None))
    if found is not None and time.time() - when < 600:
        return found
    r = rbx(f"https://badges.roblox.com/v1/users/{user_id}/badges?limit=10&sortOrder=Desc")
    badges = [{"id": x["id"], "name": x.get("name", "")} for x in r.get("data", [])]
    if badges:
        icons = rbx("https://thumbnails.roblox.com/v1/badges/icons?badgeIds=" + ",".join(str(x["id"]) for x in badges)
                    + "&size=150x150&format=Png", login=False)
        pics = {t["targetId"]: t.get("imageUrl") for t in icons.get("data", []) if t.get("state") == "Completed"}
        for x in badges:
            x["icon"] = pics.get(x["id"])
    badge_cache[user_id] = (time.time(), badges)
    return badges

def demo():
    assert cdn("1DAY-aed8e568ed6d47ef5a75c41782ffdfda").startswith("https://t")
    m = plain_mtl("newmtl A\nKa 0.5 0.5 0.5\nKd 0.5 0.5 0.5\nKs 0.1 0.1 0.1\nmap_Ka H1\nmap_Kd H1\nmap_d H1\n\nnewmtl B\nKd 0.2 0.3 0.4\n", {"H1": "tex0.png"})
    assert "map_Kd tex0.png" in m and "map_d" not in m and "map_Ka" not in m
    assert "Kd 1 1 1" in m.split("newmtl B")[0] and "Kd 0.2 0.3 0.4" in m.split("newmtl B")[1]     # plain colours survive
    ok = {"repository": CI_REPO, "ref": "refs/heads/main", "event_name": "push",
          "workflow_ref": CI_REPO + "/.github/workflows/build.yml@refs/heads/main"}
    assert ci_may_have_key("", ok)
    for change in ({"repository": "someone/jynx-ios"}, {"ref": "refs/heads/x"}, {"event_name": "pull_request"},
                   {"workflow_ref": CI_REPO + "/.github/workflows/evil.yml@refs/heads/main"}, {"repository": None}):
        assert not ci_may_have_key("", {**ok, **change}), change
    try:
        ci_may_have_key("not.a.token")
        raise AssertionError("a made-up token must not pass")
    except AssertionError:
        raise
    except Exception:
        pass
    box = [(x, y, z) for x in (-1, 1) for y in (-2, 2) for z in (-0.5, 0.5)]
    a = 0.3
    lean = np.array([[np.cos(a), -np.sin(a), 0], [np.sin(a), np.cos(a), 0], [0, 0, 1]])
    yaw = np.array([[0, 0, 1], [0, 1, 0], [-1, 0, 0]])                   # -Z (front) becomes -X
    turned = [lean @ yaw @ np.array(p) for p in box]
    text = "\n".join(["g Handle1", "v 9 9 9", "g Player1"] + [f"v {p[0]} {p[1]} {p[2]}" for p in turned] +
                     ["vn %g %g %g" % tuple(lean @ yaw @ np.array([0, 0, -1]))] + ["g Player1", "f 2/1/1 3/1/1 4/1/1 5/1/1", "f 6/1/1 7/1/1 8/1/1 9/1/1", "g Handle1", "f 1/1/1 1/1/1 1/1/1"])
    back = np.array([[float(x) for x in l.split()[1:]] for l in upright(text, lean @ yaw @ np.array([0.3, 0.2, -1])).split("\n") if l.startswith("v ")])
    assert np.allclose(np.sort(np.abs(back[1:]), 0), np.sort(np.abs(np.array(box)), 0), atol=1e-4), back
    assert np.ptp(back[1:, 1]) > 3.9 and np.ptp(back[1:, 2]) < 1.1                     # stands up, thin front to back
    normal = [l for l in upright(text, lean @ yaw @ np.array([0.3, 0.2, -1])).split("\n") if l.startswith("vn ")][0]
    assert np.allclose([float(x) for x in normal.split()[1:]], [0, 0, -1], atol=1e-4), normal        # front faces -Z
    assert upright("g Player1\n" + "\n".join(f"v {p[0]} {p[1]} {p[2]}" for p in box) + "\nf 1 2 3 4\nf 5 6 7 8", np.array([0, 0.3, -1.0])).startswith("g Player1\nv -1 -2")  # already right: untouched
    extras = game_extras(383310974)
    assert "social" in extras and isinstance(extras["voice"], bool), extras
    got = badges_of(261)
    assert isinstance(got, list) and all("name" in x for x in got), got
    before = budget_now()
    user = look_of_user("builderman")
    assert user["definition"]["bodyColors"]["headColor"].startswith("#") and user["model"]["obj"].endswith("/a.obj")
    assert user["image"].startswith("https://")
    assert one_per_slot([(1, 8), (2, 11), (3, 8), (4, 11), (5, 12), (6, 61), (7, None)]) == [1, 3, 4, 5]
    assert one_per_slot([(1, 79), (2, 78), (3, 79), (4, 78), (5, 92)]) == [3, 4]                       # one head, one mood, no backgrounds
    same = look_of_outfit(user["definition"], [{"id": a["id"]} for a in user["definition"]["assets"]])
    assert same["image"] == user["image"] or same["image"].startswith("https://"), same                # a real user's exact look comes back as their own picture
    assert budget_now()["left"] == before["left"], (before, budget_now())                                             # and costs no render
    hats = [(100 + i, 8) for i in range(12)]
    assert one_per_slot(hats + [(9, 11)]) == [102 + i for i in range(10)] + [9]      # the newest ten accessories
    assert type_of(1028606) == type_of(1028606) and 1028606 in asset_types
    learn_types([63690008, 75789087422384, 86500008])
    assert (asset_types[63690008], asset_types[75789087422384], asset_types[86500008]) == (41, 92, 27), asset_types
    assert [x["id"] for x in outfit(None, [{"id": 63690008}, {"id": 75789087422384}])["assets"]] == [63690008]    # a profile background is not clothing
    assert type_of(3) is None and 3 not in asset_types
    assert one_per_slot([(1142116, None), (5, 8)], {1142116}) == [1142116, 5]
    assert one_per_slot([(1142116, None), (5, 8)]) == [5]
    kept = outfit(user["definition"], [{"id": 1080951}, {"id": 1142116}])
    assert [a["id"] for a in kept["assets"]] == [1080951, 1142116], kept["assets"]
    d = outfit(user["definition"], [{"id": 1028606}, {"id": 144076760}, {"id": 144076760}])
    assert [a["id"] for a in d["assets"]] == [1028606, 144076760] and d["bodyColors"] == user["definition"]["bodyColors"]
    spent = budget_now()["left"]
    worn = look_of_outfit(user["definition"], [{"id": 215718515}, {"id": 1028606}]) if os.environ.get("DEMO_RENDER") or RENDER else user
    if RENDER:
        own = os.path.join(CACHE, worn["model"]["obj"].split("/")[-2])
        assert worn["image"].endswith("/pic.png") and os.path.getsize(os.path.join(own, "pic.png")) > 5000, worn      # our renderer drew it
        assert budget_now()["left"] == spent, "drawing it ourselves must not use a roblox render"
        assert len(worn["model"]["textures"]) > 3 and open(os.path.join(own, "a.obj")).read().count("\ng Part") > 5
    if os.environ.get("DEMO_RENDER") or RENDER:
        spent = budget_now()["left"]
        again = look_of_outfit(user["definition"], [{"id": 215718515}, {"id": 1028606}])
        assert again["model"] == worn["model"] and budget_now()["left"] == spent, "the same outfit twice must not be drawn twice"
    key = worn["model"]["obj"].split("/")[-2]
    obj = open(os.path.join(CACHE, key, "a.obj")).read()
    assert obj.count("\nv ") > 500 and "mtllib a.mtl" in obj
    assert "map_Kd tex0.png" in open(os.path.join(CACHE, key, "a.mtl")).read()
    assert all(os.path.isfile(os.path.join(CACHE, key, t.split("/")[-1])) for t in worn["model"]["textures"])
    assert RENDER or worn["model"]["camera"]["fov"] > 0
    seen = []
    globals()["fetch_model"] = lambda d, folder, names: seen.append(folder)
    globals()["download"] = lambda url: json.dumps(shape).encode()
    shape = {"obj": "O", "mtl": "M1", "textures": ["T1"]}
    store_model("x")
    shape = {"obj": "O", "mtl": "M1", "textures": ["T2"]}
    store_model("x")
    assert len(set(seen)) == 2, seen
    saved = dict(budget)
    note_budget({"x-ratelimit-remaining": "0", "x-ratelimit-reset": "900"})
    assert budget_now() == {"left": 0, "resetIn": 900} or budget_now()["resetIn"] == 899
    assert json.load(open(BUDGET_FILE))["left"] == 0                                 # a restart would still know
    ours, globals()["RENDER"] = RENDER, ""                                           # without our own renderer
    drawn.pop(look_key(outfit(None, [])), None)
    try:
        look_of_outfit(None, [])
        raise AssertionError("an empty budget must refuse before asking Roblox")
    except Busy as e:
        assert "15 min" in str(e), str(e)
    globals()["RENDER"] = ours
    budget.update(saved)
    remember(BUDGET_FILE, budget)
    try:
        look_of_user("nosuchuser_zz_9q_x")
        raise AssertionError("an unknown user must be refused")
    except Refused:
        pass
    print("ok", key)

if __name__ == "__main__":
    os.makedirs(CACHE, exist_ok=True)
    recall()
    if sys.argv[1:] == ["demo"]:
        demo()
    elif not PUBLIC.startswith("http"):
        sys.exit("BLOX_PUBLIC must be the service's public address (https://.../blox-api/<key>): model links are built from it.")
    else:
        http.server.ThreadingHTTPServer(("127.0.0.1", 8766), Handler).serve_forever()
