#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const cheerio = require("cheerio");
const http = require("http");

function emit(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

function readStdinOnce() {
  return new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => (data += chunk));
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", reject);
  });
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function parseHtmlToTitleAndBody(htmlString) {
  const $ = cheerio.load(htmlString, { decodeEntities: false });
  const firstH1 = $("h1").first();
  const title = (firstH1.text() || "").trim();

  if (firstH1.length) firstH1.remove();

  const bodyHtml = $.root().html();
  return { title, bodyHtml: (bodyHtml || "").trim() };
}

async function loginTistory(page, { id, pw }) {
  emit({ event: "log", message: "Go to Tistory login" });

  await page.goto("https://www.tistory.com/auth/login", { waitUntil: "domcontentloaded" });

  if ((await page.locator("a.btn_login").count()) > 0) {
    await page.click("a.btn_login");
    await page.waitForLoadState("domcontentloaded");

    await page.fill('input[name="loginId"]', id);
    await page.fill('input[name="password"]', pw);
    await page.click('button[type="submit"]');
    
    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(1000);

    while (!page.url().includes("www.tistory.com/")) {
      await page.waitForTimeout(1000);
    }
  }

  emit({ event: "log", message: "Login step done (verify selectors)" });
}

async function createPostHeaders(context, page, blogName) {
  const cookies = await context.cookies();
  const userAgent = await page.evaluate(() => navigator.userAgent);
  const userAgentData = await page.evaluate(
    () => navigator.userAgentData.getHighEntropyValues(["fullVersionList"])
  );
  const chromeVersion = userAgentData.brands.find(item => item.brand === "Google Chrome").version;
  const chromiumVersion = userAgentData.brands.find(item => item.brand === "Chromium").version;
  const notABrandVersion = userAgentData.brands.find(item => item.brand === "Not A(Brand").version;

  emit({ event: "log", message: 'Cookies loaded: ${cookies.length}' });

  const t = cookies.find(c => c.name === "__T_").value;
  const t_secure = cookies.find(c => c.name === "__T_SECURE").value;
  const is_tc = cookies.find(c => c.name === "IS_TC").value;
  const tsession = cookies.find(c => c.name === "TSSESSION").value;
  const t_ano = cookies.findLast(c => c.name === "_T_ANO").value;

  const cookieString = `__T_=${t}; __T_SECURE=${t_secure}; IS_TC=${is_tc}; TSSESSION=${tsession}; _T_ANO=${t_ano}`;
  const secChUaString = `"\"Google Chrome\";v=\"${chromeVersion}\", \"Chromium\";v=\"${chromiumVersion}\", \"Not A(Brand\";v=\"${notABrandVersion}\"`;
  
  const headers = {
      "Host": blogName,
      "Cookie": cookieString,
      "Sec-Ch-Ua": secChUaString,
      "Accept": "application/json, text/plain, */*",
      "Sec-Ch-Ua-Platform": "\"macOS\"",
      "Accept-Language": "ko-KR",
      "Sec-Ch-Ua-Mobile": "?0",
      "User-Agent": userAgent,
      "Content-Type": "application/json;charset=UTF-8",
      "Origin": "https://"+blogName,
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer": "https://"+blogName+"/manage/newpost/?type=post&returnURL=%2Fmanage%2Fposts%2F",
      "Accept-Encoding": "gzip, deflate, br",
      "Priority": "u=1, i"
  }

  return headers;
}

async function postByRequest(context, { blogName, title, bodyHtml, tags, extraHeaders }) {
  const payload = {
    "id": "0",
    "title": title,
    "content": bodyHtml,
    "slogan": "dd",
    "visibility": 0,            // 0: 비공개, 20: 공개
    "category": 1157903,
    "tag": tags.join(","),
    "published": 1,
    "password": "",
    "uselessMarginForEntry": 1,
    "daumLike": "401",
    "cclCommercial": 0,
    "cclDerive": 0,
    "thumbnail": null,
    "type": "post",
    "attachments": [],
    "recaptchaValue": "",
    "draftSequence": null
  }

  const postUrl = `https://${blogName}.tistory.com/manage/post.json`;

  const res = await context.request.post(postUrl, {
    headers: extraHeaders,
    data: payload,
  });

  const text = await res.text();
  return { ok: res.ok(), status: res.status(), text };
}

async function routeTistoryPost(payload) {
  const { account, storageStatePath, posts, options } = payload;
  const headless = options?.headless ?? true;
  const executablePath = options?.chromeExecutable;

  emit({ event: "log", message: `Post start. posts=${posts.length}` });

  // 동기 방식으로 파일 존재 여부 확인
  const realStorageState = fs.existsSync(storageStatePath) ? storageStatePath : undefined;

  const browser = await chromium.launch({ headless: headless, executablePath: executablePath });
  const context = await browser.newContext(realStorageState ? { storageState: realStorageState } : {});
  const page = await context.newPage();

  try {
    await loginTistory(page, { id: account.id, pw: account.pw });

    if (realStorageState === '') {
      await context.storageState({ path: storageStatePath });
    }

    const headers = await createPostHeaders(context, page, account.blogName);
    emit({ event: "log", message: "Extracted headers" });

    let success = 0;
    let failed = 0;

    for (let i = 0; i < posts.length; i++) {
      const post = posts[i];
      emit({
        event: "progress",
        current: i + 1,
        total: posts.length,
        file: path.basename(post.htmlFilePath),
      });

      const html = fs.readFileSync(post.htmlFilePath, "utf8");
      const { title, bodyHtml } = parseHtmlToTitleAndBody(html);

      const result = await postByRequest(context, {
        blogName: account.blogName,
        title,
        bodyHtml,
        tags: post.tags || [],
        extraHeaders: headers,
      });

      if (result.ok) {
        success++;
        emit({ event: "posted", title });
      } else {
        failed++;
        emit({ event: "post_failed", status: result.status, body: result.text.slice(0, 200) });
      }
    }

    emit({ event: "done", success, failed });
  } finally {
    await context.close().catch(() => {});
    await browser.close().catch(() => {});
  }
}

async function main() {
  try {
    const input = await readStdinOnce();
    const msg = JSON.parse(input);

    switch (msg.type) {
      case "tistory_post":
        await routeTistoryPost(msg.payload);
        break;
      default:
        emit({ event: "error", message: `Unknown type: ${msg.type}` });
        process.exitCode = 2;
    }
  }
  catch (e) {
    emit({ event: "error", message: String(e?.stack || e) });
    process.exitCode = 1;
  } finally {
    process.stdout.end();
  }
}

main();