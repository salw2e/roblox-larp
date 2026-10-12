import { build } from "esbuild";
import { readFileSync } from "node:fs";

// roavatar-renderer 1.9.10 reads the composited body texture back from a render target it has just disposed,
// so every exported body texture comes out empty. read the final one instead.
const marker = "if (!hasColorLayer && rbxRenderer || FLAGS.RENDERTARGET_TO_CANVASTEXTURE && rbxRenderer) {";
const from = "readRenderTargetPixelsAsync(renderTarget, 0, 0, width, height, data)";
const to = "readRenderTargetPixelsAsync(renderTargetFinal, 0, 0, width, height, data)";
const fix = {
  name: "fix-readback",
  setup(b) {
    b.onLoad({ filter: /roavatar-renderer[\\/]dist[\\/]index\.js$/ }, (args) => {
      const src = readFileSync(args.path, "utf8");
      const at = src.indexOf(marker), call = src.indexOf(from, at);
      if (at < 0 || call < 0 || call - at > 300) throw new Error("the renderer changed, check whether the readback fix is still needed");
      return { contents: src.slice(0, call) + to + src.slice(call + from.length), loader: "js" };
    });
  },
};
await build({ entryPoints: ["page.ts"], bundle: true, format: "iife", outfile: "page.js", logLevel: "warning", plugins: [fix] });
