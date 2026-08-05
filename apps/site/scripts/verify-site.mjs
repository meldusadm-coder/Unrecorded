import fs from "node:fs";
import path from "node:path";

const siteRoot = path.resolve("_site");
const host = "https://unrecorded.app";
const productTruth =
  "Unrecorded alerts you to possible nearby recording risk from Bluetooth signals that may match smart glasses or wearable patterns. It does not prove that someone is recording.";

const requiredFiles = [
  "index.html",
  "privacy.html",
  "privacy/index.html",
  "how-smart-glasses-broadcast-ble.html",
  "how-to-avoid-being-recorded-by-smart-glasses.html",
  "detection-limitations.html",
  "smart-glasses-ble-patterns.html",
  "what-unrecorded-is.html",
  "faq.html",
  "robots.txt",
  "app-ads.txt",
  "auth.md",
  "sitemap.xml",
  "llms.txt",
  "assets/styles.css",
  "assets/social-card.png",
];

const requiredPublicHtmlPaths = [
  "/",
  "/privacy.html",
  "/how-smart-glasses-broadcast-ble.html",
  "/how-to-avoid-being-recorded-by-smart-glasses.html",
  "/detection-limitations.html",
  "/smart-glasses-ble-patterns.html",
  "/what-unrecorded-is.html",
  "/faq.html",
];

const requiredSitemapPaths = [...requiredPublicHtmlPaths, "/auth.md"];
const assertiveClaimPatterns = [
  /\bproves that someone is recording\b/gi,
  /\bprove someone is recording\b/gi,
];

function fail(message) {
  console.error(`verify-site: ${message}`);
  process.exitCode = 1;
}

function readBuilt(relPath) {
  return fs.readFileSync(path.join(siteRoot, relPath), "utf8");
}

function isAllowedQuestion(text, matchIndex) {
  const before = text.slice(Math.max(0, matchIndex - 24), matchIndex);
  return /Can Unrecorded\s+$/i.test(before);
}

for (const relPath of requiredFiles) {
  if (!fs.existsSync(path.join(siteRoot, relPath))) {
    fail(`missing ${relPath}`);
  }
}

if (process.exitCode) {
  process.exit(process.exitCode);
}

const htmlFiles = requiredFiles.filter((relPath) => relPath.endsWith(".html"));
const llms = readBuilt("llms.txt");
const sitemap = readBuilt("sitemap.xml");
const home = readBuilt("index.html");

if (!home.includes(productTruth)) {
  fail("home page is missing the product truth text");
}

for (const htmlFile of htmlFiles) {
  const html = readBuilt(htmlFile);
  if (html.includes("/src/styles.css")) {
    fail(`${htmlFile} still references /src/styles.css`);
  }
}

for (const publicPath of requiredSitemapPaths) {
  const expectedUrl = publicPath === "/" ? `${host}/` : `${host}${publicPath}`;
  if (!sitemap.includes(`<loc>${expectedUrl}</loc>`)) {
    fail(`sitemap.xml is missing ${expectedUrl}`);
  }
}

for (const publicPath of requiredPublicHtmlPaths) {
  if (!llms.includes(publicPath)) {
    fail(`llms.txt is missing ${publicPath}`);
  }
}

if (!llms.includes("/auth.md")) {
  fail("llms.txt is missing /auth.md");
}

for (const relPath of [...htmlFiles, "llms.txt"]) {
  const text = readBuilt(relPath);
  for (const pattern of assertiveClaimPatterns) {
    pattern.lastIndex = 0;
    for (const match of text.matchAll(pattern)) {
      if (!isAllowedQuestion(text, match.index ?? 0)) {
        fail(`${relPath} contains assertive recording-proof claim: ${match[0]}`);
      }
    }
  }
}

if (!process.exitCode) {
  console.log("verify-site: all checks passed");
}
