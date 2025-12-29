#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright-core");
const cheerio = require("cheerio");

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

async function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseHtmlToTitleAndBody(htmlString) {
  const $ = cheerio.load(htmlString, { decodeEntities: false });
  const firstH1 = $("h1").first();
  const title = (firstH1.text() || "").trim();

  if (firstH1.length) firstH1.remove();

  const bodyHtml = $.root().html();
  return { title, bodyHtml: (bodyHtml || "").trim() };
}

async function loginTistory(context, page, { id, pw, storageStatePath }) {
  emit({ event: "log", message: "Go to Tistory login" });

  await page.goto("https://www.tistory.com/auth/login", { waitUntil: "domcontentloaded" });

  if ((await page.locator("a.btn_login").count()) > 0) {
    await page.click("a.btn_login");
    await page.waitForLoadState("domcontentloaded");

    await page.fill('input[name="loginId"]', id);
    await page.fill('input[name="password"]', pw);
    await page.click('button[type="submit"]');

    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(3000);

    const descLogin = await page.locator('p.desc_login', { hasText: '카카오톡으로 로그인 확인 메세지가 전송되었습니다.' });
    if (await descLogin.count() > 0) {
      emit({ event: "log", message: "Request Login Auth" });
    }

    while (!page.url().includes("www.tistory.com/")) {
      await page.waitForTimeout(100);
    }

    // storageState 저장 전 디렉토리 생성
    const dir = path.dirname(storageStatePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    await context.storageState({ path: storageStatePath });
  }

  await page.waitForTimeout(1000);

  emit({ event: "log", message: "Login step done (verify selectors)" });
}

async function createPostHeaders(page, blogName) {
  const userAgent = await page.evaluate(() => navigator.userAgent);
  const fullDomain = `${blogName}.tistory.com`;

  // Playwright context.request는 쿠키를 자동으로 포함하므로 Cookie 헤더 불필요
  // Host 헤더도 URL에서 자동 설정되므로 제거 (수동 설정 시 404 발생)
  const headers = {
      "Accept": "application/json, text/plain, */*",
      "Accept-Language": "ko-KR",
      "User-Agent": userAgent,
      "Content-Type": "application/json;charset=UTF-8",
      "Origin": `https://${fullDomain}`,
      "Referer": `https://${fullDomain}/manage/newpost/?type=post&returnURL=%2Fmanage%2Fposts%2F`,
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
  };

  emit({ event: "log", message: `Headers created for ${fullDomain}` });

  return headers;
}

async function postByRequest(context, { blogName, title, bodyHtml, tags, extraHeaders }) {
  const payload = {
    "id": "0",
    "title": title,
    "content": bodyHtml,
    "slogan": title,
    "visibility": 20,            // 0: 비공개, 20: 공개
    "category": 0,
    "tag": tags.join(","),
    "published": 1,
    "password": "",
    "uselessMarginForEntry": 1,
    "daumLike": "401",
    "cclCommercial": 0,
    "cclDerive": 0,
    "type": "post",
    "attachments": [],
    "recaptchaValue": "",
    "draftSequence": null
  }

  const postUrl = `https://${blogName}.tistory.com/manage/post.json`;

  const res = await context.request.post(postUrl, {
    headers: {
      "content-type": "application/json; charset=utf-8",
      "accept": "application/json, text/plain, */*",
      ...extraHeaders,
    },
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

  const browser = await chromium.launch({
    headless: headless,
    executablePath: executablePath,
    args: [
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-infobars',
    ],
  });
  const context = await browser.newContext(realStorageState ? { storageState: realStorageState } : {});
  const page = await context.newPage();
  await page.waitForLoadState("domcontentloaded");

  try {
    await loginTistory(context, page, {
      id: account.id,
      pw: account.pw,
      storageStatePath: storageStatePath,
    });

    const headers = await createPostHeaders(page, account.blogName);
    emit({ event: "log", message: "Extracted headers" });

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

      await delay(100);
    }

    emit({ event: "done", message: "All posts processed." });
  } finally {
    // 브라우저 종료 전 잠시 대기 (macOS Dock 정리용)
    await delay(500);

    // 모든 페이지 닫기
    const pages = context.pages();
    for (const p of pages) {
      await p.close().catch(() => {});
    }

    await context.close().catch(() => {});
    await browser.close().catch(() => {});

    // 브라우저 프로세스 완전 종료 대기
    await delay(300);
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