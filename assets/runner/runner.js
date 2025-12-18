import { chromium } from 'playwright';
import readline from 'readline';

const rl = readline.createInterface({
    input: process.stdin,
    crlfDelay: Infinity,
});

async function runJob(job) {
    const browser = await chromium.launch({
        headless: job.options?.headless ?? false,
    });

    const context = await browser.newContext();

    // 쿠키 로그인
    if (job.account.authType === 'cookies') {
        await context.addCookies([
            {
                name: 'TSSESSION',
                value: job.account.cookies.TSSESSION,
                domain: '.tistory.com',
                path: '/',
            },
            {
                name: '_T_ANO',
                value: job.account.cookies._T_ANO,
                domain: '.tistory.com',
                path: '/',
            },
        ]);
    }

    const page = await context.newPage();

    // TODO (Step 7.5): 로그인 / 글쓰기 자동화
    log(job.jobId, '에디터 페이지 이동');

    await browser.close();
}

function log(jobId, message) {
    console.log(JSON.stringify({
        jobId,
        status: 'log',
        message,
    }));
}

function success(jobId) {
    console.log(JSON.stringify({
        jobId,
        status: 'success',
    }));
}

function fail(jobId, error) {
    console.log(JSON.stringify({
        jobId,
        status: 'failed',
        error,
    }));
}

rl.on('line', async (line) => {
    const job = JSON.parse(line);

    try {
        await runJob(job);
        success(job.jobId);
    } catch (e) {
        fail(job.jobId, e.message ?? String(e));
        process.exit(1);
    }
});
