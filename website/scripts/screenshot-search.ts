// Search-interaction screenshot harness (issue 0012 exp 4 verification):
// drives headless Chrome over CDP with REAL time (Pagefind's UI never
// settles under --virtual-time-budget), types a query, waits for result
// links, captures both modes. Generates its own theme-pinned fixtures
// from the built page, so it reproduces from any fresh `bun run build`.
// Requires the preview server: `bun run preview --port 4399`.
import { readFileSync, writeFileSync } from "node:fs";

declare const Bun: any;

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PORT = 9223;

const DIST = new URL("../dist/", import.meta.url).pathname;
const built = readFileSync(`${DIST}/docs/autograd/index.html`, "utf8");
for (const mode of ["light", "dark"]) {
  writeFileSync(
    `${DIST}/docs/autograd/search-${mode}.html`,
    built.replace("<html", `<html data-theme="${mode}"`),
  );
}

const proc = Bun.spawn(
  [CHROME, "--headless", "--disable-gpu", `--remote-debugging-port=${PORT}`,
    "--window-size=1440,1600", "about:blank"],
  { stdout: "ignore", stderr: "ignore" },
);
await new Promise((r) => setTimeout(r, 1500));

async function cdp(modeName: string, url: string, outfile: string) {
  const list = (await (
    await fetch(`http://localhost:${PORT}/json/list`)
  ).json()) as { webSocketDebuggerUrl: string; type: string }[];
  const page = list.find((t) => t.type === "page");
  if (!page) throw new Error("no page target");
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map<number, (v: any) => void>();
  ws.addEventListener("message", (event) => {
    const msg = JSON.parse(String(event.data));
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)!(msg.result);
      pending.delete(msg.id);
    }
  });
  await new Promise((r) => ws.addEventListener("open", r, { once: true }));
  const send = (method: string, params: object = {}) =>
    new Promise<any>((resolve) => {
      pending.set(++id, resolve);
      ws.send(JSON.stringify({ id, method, params }));
    });

  await send("Page.enable");
  await send("Page.navigate", { url });
  await new Promise((r) => setTimeout(r, 2000));
  await send("Runtime.evaluate", {
    expression: `
      const input = document.querySelector("#docs-search input");
      input.value = "backward";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    `,
  });
  // Wait for result links to appear (real time).
  let links = 0;
  for (let i = 0; i < 30; i++) {
    await new Promise((r) => setTimeout(r, 500));
    const res = await send("Runtime.evaluate", {
      expression:
        'document.querySelectorAll(".pagefind-ui__result-link").length',
      returnByValue: true,
    });
    links = res?.result?.value ?? 0;
    if (links > 0) break;
  }
  const refLink = await send("Runtime.evaluate", {
    expression: `[...document.querySelectorAll(".pagefind-ui__result-link")]
      .some((a) => a.getAttribute("href").includes("/docs/reference/"))`,
    returnByValue: true,
  });
  const shot = await send("Page.captureScreenshot", { format: "png" });
  await Bun.write(outfile, Buffer.from(shot.data, "base64"));
  ws.close();
  console.log(
    `${modeName}: ${links} result links, reference-page hit: ${refLink?.result?.value}`,
  );
  if (links === 0) process.exitCode = 1;
}

try {
  for (const mode of ["light", "dark"]) {
    await cdp(
      mode,
      `http://localhost:4399/docs/autograd/search-${mode}.html`,
      `${process.env.HOME}/dev/nutorch/logs/issue-0012/search-${mode}.png`,
    );
  }
} finally {
  proc.kill();
}
