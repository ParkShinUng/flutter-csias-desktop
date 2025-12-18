import { chromium } from 'playwright';
import readline from 'readline';

const rl = readline.createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

function out(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

function log(jobId, message) {
  out({ jobId, status: 'log', message });
}

function success(jobId, message = 'success') {
  out({ jobId, status: 'success', message });
}

function fail(jobId, error) {
  out({ jobId, status: 'failed', error });
}

async function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function ensureLoggedIn(page, job) {
  // 티스토리 로그인 상태 확인용
  // manage 페이지 접근이 안 되면 로그인 페이지로 튕김
  await page.goto('https://www.tistory.com/manage', { waitUntil: 'domcontentloaded' });

  // 로그인 페이지로 리다이렉트되면 로그인 필요
  const url = page.url();
  if (url.includes('kakao.com') || url.includes('login') || url.includes('accounts.kakao.com')) {
    if (job.account.authType === 'cookies') {
      throw new Error('쿠키 로그인 실패: manage 접근 불가 (쿠키 만료/도메인 불일치 가능)');
    }
    log(job.jobId, '로그인 필요 - Kakao 로그인 진행');
    await kakaoLogin(page, job);
  } else {
    log(job.jobId, '이미 로그인 상태');
  }
}

async function kakaoLogin(page, job) {
  // ⚠️ Kakao 로그인은 UI가 자주 바뀔 수 있음.
  // 아래 셀렉터는 “가장 흔한 패턴” 기준이므로 실제 DOM에 맞춰 조정 가능.
  const { loginId, password } = job.account;

  // 로그인 페이지로 이동
  // manage 접근 시 카카오 로그인으로 넘어갔을 수도 있음
  if (!page.url().includes('kakao.com')) {
    await page.goto('https://accounts.kakao.com/login', { waitUntil: 'domcontentloaded' });
  }

  // ID / PW 입력
  await page.waitForTimeout(300);

  // 이메일/전화번호 입력
  const idSelectorCandidates = ['input[name="loginId"]', 'input[type="text"]'];
  const pwSelectorCandidates = ['input[name="password"]', 'input[type="password"]'];

  const idSel = await pickFirstVisible(page, idSelectorCandidates);
  const pwSel = await pickFirstVisible(page, pwSelectorCandidates);

  if (!idSel || !pwSel) {
    throw new Error('Kakao 로그인 입력창 셀렉터를 찾지 못했습니다. (DOM 변경 가능)');
  }

  await page.fill(idSel, String(loginId ?? ''));
  await page.fill(pwSel, String(password ?? ''));

  // 로그인 버튼
  const loginBtn = await pickFirstVisible(page, [
    'button[type="submit"]',
    'button:has-text("로그인")',
    'button:has-text("Log in")',
  ]);

  if (!loginBtn) throw new Error('Kakao 로그인 버튼을 찾지 못했습니다.');

  await Promise.all([
    page.waitForNavigation({ waitUntil: 'domcontentloaded' }).catch(() => {}),
    page.click(loginBtn),
  ]);

  // 2FA/캡차/추가 인증이 뜰 수 있음 → 여기서는 감지해 에러로 처리
  await page.waitForTimeout(800);
  const url = page.url();

  if (url.includes('accounts.kakao.com')) {
    // 로그인 완료가 안 된 상태
    // 흔히 2단계 인증/추가 인증으로 남아있음
    throw new Error('Kakao 로그인 후 추가 인증이 필요합니다(2FA/캡차). 수동 로그인 후 쿠키 방식 권장.');
  }

  log(job.jobId, 'Kakao 로그인 완료');
}

async function pickFirstVisible(page, selectors) {
  for (const sel of selectors) {
    const loc = page.locator(sel);
    const count = await loc.count().catch(() => 0);
    if (count > 0) {
      // 첫 번째 요소가 visible인지 확인
      const first = loc.first();
      const visible = await first.isVisible().catch(() => false);
      if (visible) return sel;
    }
  }
  return null;
}

async function openNewPost(page) {
  // 가장 안정적인 방식: manage 페이지에서 "글쓰기" 버튼/URL 접근
  // 티스토리 UI는 변동이 있어 후보를 여러 개 둠.
  const candidates = [
    'https://www.tistory.com/manage/newpost/',
    'https://www.tistory.com/manage/post',
  ];

  for (const url of candidates) {
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(400);

    if (page.url().includes('/manage/newpost') || page.url().includes('/manage/post')) {
      return;
    }
  }
  // 여기까지 오면 접근 실패
  throw new Error('글쓰기 페이지로 이동 실패');
}

async function setTitle(page, title) {
  // 제목 입력칸은 보통 input/textarea로 존재. 후보 셀렉터.
  const titleSel = await pickFirstVisible(page, [
    'textarea[placeholder*="제목"]',
    'input[placeholder*="제목"]',
    'textarea[name="title"]',
    'input[name="title"]',
  ]);
  if (!titleSel) throw new Error('제목 입력칸을 찾지 못했습니다.');

  await page.fill(titleSel, title);
}

async function setTags(page, tags) {
  if (!tags || tags.length === 0) return;

  // 티스토리 태그 입력창 id=tagText (너가 공유한 힌트 기반)
  const tagSel = await pickFirstVisible(page, [
    '#tagText',
    'input[name="tagText"]',
    'input[placeholder*="태그"]',
  ]);
  if (!tagSel) {
    log('?', '태그 입력창을 찾지 못해 태그는 스킵합니다.');
    return;
  }

  // 태그는 기본적으로 엔터로 추가되는 구조가 많음
  // → 안정적으로는 한 개씩 입력 후 Enter.
  // “한 번에”는 내부 API가 막히는 경우가 많아서(405) 기본은 안전 모드.
  for (const t of tags) {
    await page.fill(tagSel, t);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(150);
  }
}

async function setBodyHtml(page, bodyHtml) {
  // 에디터가 iframe/ProseMirror/CodeMirror 등 다양해서 케이스가 많음
  // Step 7.5에서는 “HTML 모드로 붙여넣기”를 목표로,
  // 가능한 후보를 순차적으로 시도.

  // 1) HTML 입력 모드/HTML 버튼 찾기
  const htmlModeBtn = await pickFirstVisible(page, [
    'button:has-text("HTML")',
    'span:has-text("HTML")',
    '[data-ke-type="html"]',
  ]);

  if (htmlModeBtn) {
    await page.click(htmlModeBtn).catch(() => {});
    await page.waitForTimeout(300);
  }

  // 2) textarea / CodeMirror / contenteditable 후보에 삽입
  // - 가장 흔한 건 textarea 또는 contenteditable
  const bodySel = await pickFirstVisible(page, [
    'textarea',
    '[contenteditable="true"]',
    '.CodeMirror textarea',
  ]);

  if (!bodySel) {
    throw new Error('본문 입력 영역을 찾지 못했습니다.');
  }

  // contenteditable이면 fill이 안 먹을 수 있어 evaluate로 삽입
  const isEditable = bodySel.includes('contenteditable');
  if (isEditable) {
    await page.focus(bodySel);
    await page.keyboard.press('Control+A').catch(() => {});
    await page.keyboard.type(bodyHtml, { delay: 0 });
  } else {
    await page.fill(bodySel, bodyHtml);
  }
}

async function publish(page, job) {
  // 발행 버튼 후보
  const publishBtn = await pickFirstVisible(page, [
    'button:has-text("발행")',
    'button:has-text("공개")',
    'button:has-text("완료")',
  ]);

  if (!publishBtn) throw new Error('발행 버튼을 찾지 못했습니다.');

  await page.click(publishBtn);
  await page.waitForTimeout(800);

  // 발행 확인 모달이 뜨는 케이스 후보
  const confirmBtn = await pickFirstVisible(page, [
    'button:has-text("확인")',
    'button:has-text("발행")',
    'button:has-text("완료")',
  ]);

  if (confirmBtn) {
    await page.click(confirmBtn);
  }

  // 발행 완료를 확실히 체크하기는 UI 의존적이라
  // 최소한 URL 변화/토스트 등을 기다림
  await page.waitForTimeout(1200);

  log(job.jobId, '발행 시도 완료');
}

async function runJob(job) {
  const headless = job.options?.headless ?? false;
  const delayMs = job.options?.delayMs ?? 300;

  const browser = await chromium.launch({ headless });
  const context = await browser.newContext();

  // 쿠키 방식이면 먼저 쿠키 주입
  if (job.account.authType === 'cookies') {
    const c = job.account.cookies || {};
    await context.addCookies([
      {
        name: 'TSSESSION',
        value: c.TSSESSION,
        domain: '.tistory.com',
        path: '/',
      },
      {
        name: '_T_ANO',
        value: c._T_ANO,
        domain: '.tistory.com',
        path: '/',
      },
    ]);
  }

  const page = await context.newPage();

  // 1) 로그인 보장
  await ensureLoggedIn(page, job);
  await delay(delayMs);

  // 2) 글쓰기 페이지 이동
  log(job.jobId, '글쓰기 페이지 이동');
  await openNewPost(page);
  await delay(delayMs);

  // 3) 제목
  log(job.jobId, '제목 입력');
  await setTitle(page, job.post.title);
  await delay(delayMs);

  // 4) 본문(HTML)
  log(job.jobId, '본문(HTML) 입력');
  await setBodyHtml(page, job.post.bodyHtml);
  await delay(delayMs);

  // 5) 태그
  log(job.jobId, '태그 입력');
  await setTags(page, job.tags || []);
  await delay(delayMs);

  // 6) 발행
  log(job.jobId, '발행');
  await publish(page, job);

  await context.close();
  await browser.close();
}

/* ================= STDIN Listener ================= */

rl.on('line', async (line) => {
  const job = JSON.parse(line);

  try {
    await runJob(job);
    success(job.jobId, '게시 완료');
  } catch (e) {
    fail(job.jobId, e?.message ?? String(e));
    process.exit(1);
  }
});
