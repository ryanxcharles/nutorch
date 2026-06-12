// Link integrity gate (issue 0012 exp 4): every internal href in built
// HTML must resolve to a built file; anchors must exist as ids on the
// target page. External links are listed, never fetched (local-only).
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const DIST = new URL("../dist/", import.meta.url).pathname;
let failed = false;
const external = new Set<string>();

function htmlFiles(dir: string): string[] {
  const out: string[] = [];
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...htmlFiles(path));
    else if (name.endsWith(".html")) out.push(path);
  }
  return out;
}

function targetFile(route: string): string | undefined {
  for (const candidate of [
    join(DIST, route),
    join(DIST, route, "index.html"),
    join(DIST, `${route.replace(/\/$/, "")}.html`),
  ]) {
    if (existsSync(candidate) && statSync(candidate).isFile()) {
      return candidate;
    }
  }
  return undefined;
}

const files = htmlFiles(DIST);
for (const file of files) {
  const html = readFileSync(file, "utf8");
  for (const match of html.matchAll(/href="([^"]+)"/g)) {
    const href = match[1];
    if (/^(https?:|mailto:)/.test(href)) {
      external.add(href);
      continue;
    }
    if (href.startsWith("#")) {
      if (!html.includes(`id="${href.slice(1)}"`)) {
        console.error(`FAIL: ${file.replace(DIST, "")}: missing anchor ${href}`);
        failed = true;
      }
      continue;
    }
    const [route, anchor] = href.split("#");
    const target = targetFile(route);
    if (!target) {
      console.error(`FAIL: ${file.replace(DIST, "")}: dead link ${href}`);
      failed = true;
      continue;
    }
    if (anchor && !readFileSync(target, "utf8").includes(`id="${anchor}"`)) {
      console.error(`FAIL: ${file.replace(DIST, "")}: missing anchor ${href}`);
      failed = true;
    }
  }
}

if (failed) process.exit(1);
console.log(
  `links ok: ${files.length} pages checked, ${external.size} external links (not fetched)`,
);
