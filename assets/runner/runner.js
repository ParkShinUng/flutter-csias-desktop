#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
// const cheerio = require("cheerio");
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

function parseHtmlToTitleAndBody(htmlString) {
  const $ = cheerio.load(htmlString, { decodeEntities: false });
  const firstH1 = $("h1").first();
  const title = (firstH1.text() || "").trim();

  if (firstH1.length) firstH1.remove();

  const bodyHtml = $("body").length ? $("body").html() : $.root().html();
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
  }

  await page.waitForLoadState("domcontentloaded");
  await page.waitForTimeout(1000);

  emit({ event: "log", message: "Login step done (verify selectors)" });
}

async function createPosttHeader(context, page) {
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
      "Origin": "https://"+blog,
      "Sec-Fetch-Site": "same-origin",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Dest": "empty",
      "Referer": "https://"+blog+"/manage/newpost/?type=post&returnURL=%2Fmanage%2Fposts%2F",
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

  const postUrl = `https://${blogName}.tistory.com/manage/post.json`; // <- 예시, 실제로는 캡처 필요

  const res = await context.request.post(postUrl, {
    headers: {
      ...extraHeaders,
      "content-type": "application/json",
      "referer": `https://${blogName}.tistory.com/manage/newpost/`,
    },
    data: payload,
  });

  const text = await res.text();
  return { ok: res.ok(), status: res.status(), text };
}

async function main() {
  // const input = await readStdinOnce();
  // const msg = JSON.parse(input);

  const msg = {
    "type": "tistory_post",
    "payload": {
      "account": { "id": "01036946290", "pw": "rla156", "blogName": "korea-beauty-editor-best" },
      "posts": [
        { "htmlFilePath": "/abs/path/a.html", "tags": ["tag1", "tag2"] },
        { "htmlFilePath": "/abs/path/b.html", "tags": ["tag3"] }
      ],
      "options": {
        "headless": false,
        "chromeExecutable": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
      }
    }
  }

  if (msg.type !== "tistory_post") {
    emit({ event: "error", message: "Unknown message type" });
    process.exit(2);
  }

  const { account, posts, options } = msg.payload;
  const headless = options?.headless ?? false;
  const executablePath = options?.chromeExecutable || undefined;

  emit({ event: "log", message: "Launching Chrome..." });

  const user_info_dir_path = path.join("user_data", `${account.id}_tistory_user_data`);

  if (!fs.existsSync(user_info_dir_path)) {
    fs.mkdirSync(user_info_dir_path, { recursive: true });
  }

  const context = await chromium.launchPersistentContext(
    user_info_dir_path,
    {
      headless,
      executablePath,
    }
  );
  const page = await context.newPage();

  try {
    await loginTistory(page, { id: account.id, pw: account.pw });

    const headers = await createPosttHeader(context, page);
    emit({ event: "log", message: "Extracted headers" });

    let success = 0;
    let failed = 0;

    for (let i = 0; i < posts.length; i++) {
      const p = posts[i];
      emit({ event: "progress", current: i + 1, total: posts.length, file: path.basename(p.htmlFilePath) });

      const html = fs.readFileSync(p.htmlFilePath, "utf8");
      const { title, bodyHtml } = parseHtmlToTitleAndBody(html);

      if (!title) {
        failed++;
        emit({ event: "log", level: "warn", message: `No <h1> title in ${p.htmlFilePath}` });
        continue;
      }

      const result = await postByRequest(context, {
        blogName: account.blogName,
        title,
        bodyHtml,
        tags: p.tags || [],
        extraHeaders: headers,
      });

      if (result.ok) {
        success++;
        emit({ event: "log", message: `Posted OK: ${title}` });
      } else {
        failed++;
        emit({ event: "log", level: "error", message: `Post FAIL status=${result.status} body=${result.text.slice(0, 200)}` });
      }
    }

    emit({ event: "done", success, failed });
  } catch (e) {
    emit({ event: "error", message: String(e?.stack || e) });
    process.exitCode = 1;
  } finally {
    await context.close().catch(() => {});
    await browser.close().catch(() => {});
  }
}

main();
