import { FLAGS, RBXRenderer, Outfit, Authentication, generateOutfitThumbnail, AssetTypes } from "roavatar-renderer";

const via = (u: string) => (u.startsWith("http") ? "/rbx?u=" + encodeURIComponent(u) : u);

FLAGS.ONLINE_ASSETS = false;
FLAGS.ASSETS_PATH = "/rbxasset/";
FLAGS.RIG_PATH = "/rig/";
FLAGS.USE_WORKERS = false;
FLAGS.ASSETDELIVERY_V2 = false;
FLAGS.FETCH_FUNC = (input, init) => {
  if (typeof input === "string" || input instanceof URL) return fetch(via(String(input)), init);
  return fetch(new Request(via(input.url), input), init);
};
FLAGS.IMAGE_FUNC = async (u) => via(u);

const b64 = (buf: ArrayBuffer) => {
  let s = "";
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
};

const auth = new Authentication();
let ready: Promise<boolean> | undefined;

(window as any).draw = async (def: any, want: { glb?: boolean; png?: boolean; size?: number }) => {
  ready ??= RBXRenderer.fullSetup(true, false, false);      // no render loop: frames are only drawn when asked for
  if (!(await ready)) throw new Error("renderer could not start");
  const outfit = new Outfit();
  outfit.fromJson({
    playerAvatarType: def.playerAvatarType?.playerAvatarType ?? "R15",
    scales: def.scales,
    bodyColor3s: Object.fromEntries(Object.entries(def.bodyColors).map(([k, v]) => [k + "3", String(v).replace("#", "")])),
    assets: def.assets.map((a: any) => ({ id: a.id, name: String(a.id), assetType: { id: a.type, name: AssetTypes[a.type] }, meta: a.meta })),
  });
  const out: Record<string, unknown> = {};
  const size = want.size ?? 840;
  if (want.glb) {
    FLAGS.RENDERTARGET_TO_CANVASTEXTURE = true;
    const glb = await generateOutfitThumbnail(auth, outfit, [size, size], "glb", 1, false, false);
    FLAGS.RENDERTARGET_TO_CANVASTEXTURE = false;
    out.glb = glb instanceof ArrayBuffer ? b64(glb) : null;
  }
  if (want.png) out.png = await generateOutfitThumbnail(auth, outfit, [size, size], "png", 1, false, false, undefined, (want as any).camera ?? "avatarFullbody");
  return out;
};
(window as any).loaded = true;
