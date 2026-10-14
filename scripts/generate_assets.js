import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');
const assetsDir = path.join(projectRoot, 'assets');

if (!fs.existsSync(assetsDir)) {
  fs.mkdirSync(assetsDir, { recursive: true });
}

const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// 1. Create App Icon HTML
const iconHtml = `
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { margin: 0; padding: 0; width: 512px; height: 512px; display: flex; align-items: center; justify-content: center; background: transparent; }
  .icon-box {
    width: 512px; height: 512px; border-radius: 110px;
    background: linear-gradient(135deg, #008060 0%, #004c3f 40%, #0176d3 80%, #014486 100%);
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    box-shadow: 0 20px 40px rgba(0,0,0,0.3); position: relative; overflow: hidden;
  }
  .sync-arrows { font-size: 160px; color: #ffffff; line-height: 1; filter: drop-shadow(0 10px 20px rgba(0,0,0,0.3)); }
  .badge-text { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; font-size: 40px; font-weight: 800; color: #ffffff; margin-top: 10px; letter-spacing: -1px; text-shadow: 0 4px 10px rgba(0,0,0,0.3); }
</style>
</head>
<body>
  <div class="icon-box">
    <div class="sync-arrows">⚡</div>
    <div class="badge-text">SHOPIFY ↔ SF</div>
  </div>
</body>
</html>
`;

fs.writeFileSync(path.join(assetsDir, '_icon.html'), iconHtml);

// 2. Create Banner HTML (16:9, 1280x720)
const bannerHtml = `
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { margin: 0; padding: 0; width: 1280px; height: 720px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  .banner {
    width: 1280px; height: 720px; box-sizing: border-box;
    background: linear-gradient(135deg, #003328 0%, #008060 35%, #0176d3 70%, #012b54 100%);
    color: #ffffff; padding: 60px 80px; display: flex; flex-direction: column; justify-content: space-between; position: relative; overflow: hidden;
  }
  .tag { background: rgba(255,255,255,0.2); backdrop-filter: blur(10px); padding: 8px 18px; border-radius: 9999px; font-size: 16px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; display: inline-block; margin-bottom: 20px; }
  .headline { font-size: 56px; font-weight: 900; line-height: 1.1; margin: 0 0 16px; letter-spacing: -1.5px; }
  .headline span { color: #86efac; }
  .subtext { font-size: 22px; max-width: 820px; line-height: 1.5; color: #e2e8f0; margin: 0; }
  .feature-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-top: 40px; }
  .feature-pill { background: rgba(255,255,255,0.12); backdrop-filter: blur(8px); border: 1px solid rgba(255,255,255,0.2); border-radius: 12px; padding: 18px 20px; }
  .feature-icon { font-size: 28px; margin-bottom: 8px; }
  .feature-title { font-size: 16px; font-weight: 800; color: #ffffff; }
  .feature-desc { font-size: 13px; color: #cbd5e1; margin-top: 4px; }
  .brand-footer { display: flex; justify-content: space-between; align-items: center; border-top: 1px solid rgba(255,255,255,0.2); padding-top: 20px; }
  .author { font-size: 16px; font-weight: 600; color: #94a3b8; }
</style>
</head>
<body>
  <div class="banner">
    <div>
      <div class="tag">⚡ 100% Free Open-Source &bull; AppExchange Ready</div>
      <h1 class="headline">Universal <span>Shopify ↔ Salesforce</span> Connector</h1>
      <p class="subtext">
        Zero-fee enterprise horizontal integration. Real-time HMAC-verified webhook sync for Customers, Orders, High-Value Abandoned Cart Leads, and Bi-directional Fulfillment.
      </p>
    </div>
    <div class="feature-grid">
      <div class="feature-pill">
        <div class="feature-icon">👤</div>
        <div class="feature-title">Customer Dedupe</div>
        <div class="feature-desc">Email &amp; phone matching with lifetime spend &amp; tags.</div>
      </div>
      <div class="feature-pill">
        <div class="feature-icon">🛍️</div>
        <div class="feature-title">Order Ingestion</div>
        <div class="feature-desc">Orders, line items &amp; closed-won Opportunity sync.</div>
      </div>
      <div class="feature-pill">
        <div class="feature-icon">🚨</div>
        <div class="feature-title">Cart Lead Recovery</div>
        <div class="feature-desc">High-value carts (&gt;$200) spawn Lead + Priority Task.</div>
      </div>
      <div class="feature-pill">
        <div class="feature-icon">🛡️</div>
        <div class="feature-title">DLQ Replay Engine</div>
        <div class="feature-desc">Custom sync logs with 1-click zero data loss replay.</div>
      </div>
    </div>
    <div class="brand-footer">
      <div class="author">Built by Arsalan Arshad &bull; Salesforce Open-Source Ecosystem Portfolio</div>
      <div style="font-weight: 800; font-size: 18px; color: #86efac;">Package 04tg7000000XZWrAAO</div>
    </div>
  </div>
</body>
</html>
`;

fs.writeFileSync(path.join(assetsDir, '_banner.html'), bannerHtml);

console.log('Capturing screenshots with Chrome Headless...');

function capture(url, outPath, width, height) {
  const cmd = `"${chromePath}" --headless --disable-gpu --window-size=${width},${height} --screenshot="${outPath}" "${url}"`;
  execSync(cmd, { stdio: 'inherit' });
}

const iconHtmlUrl = 'file://' + path.join(assetsDir, '_icon.html');
const bannerHtmlUrl = 'file://' + path.join(assetsDir, '_banner.html');
const demoHtml = 'file://' + path.join(projectRoot, 'interactive_demo.html');

// 1. Capture App Icon & Banner
capture(iconHtmlUrl, path.join(assetsDir, 'app_icon.png'), 512, 512);
capture(bannerHtmlUrl, path.join(assetsDir, 'app_banner.png'), 1280, 720);

// 2. Resize to 120x120 for AppExchange app_icon_120.png
execSync(
  `sips -z 120 120 "${path.join(assetsDir, 'app_icon.png')}" --out "${path.join(assetsDir, 'app_icon_120.png')}"`,
  { stdio: 'inherit' }
);
execSync(
  `sips -s format jpeg "${path.join(assetsDir, 'app_icon.png')}" --out "${path.join(assetsDir, 'app_icon.jpg')}"`,
  { stdio: 'inherit' }
);
execSync(
  `sips -s format jpeg "${path.join(assetsDir, 'app_banner.png')}" --out "${path.join(assetsDir, 'app_banner.jpg')}"`,
  { stdio: 'inherit' }
);

// 3. Capture 4 UI Walkthrough Screenshots
capture(demoHtml + '?view=setup', path.join(assetsDir, 'screenshot1_setup_dashboard.png'), 1280, 850);
capture(demoHtml + '?view=lead', path.join(assetsDir, 'screenshot2_abandoned_cart_lead.png'), 1280, 850);
capture(demoHtml + '?view=order', path.join(assetsDir, 'screenshot3_order_customer_sync.png'), 1280, 850);
capture(demoHtml + '?view=fulfillment', path.join(assetsDir, 'screenshot4_fulfillment_push.png'), 1280, 850);

// Clean up temporary HTML files
fs.unlinkSync(path.join(assetsDir, '_icon.html'));
fs.unlinkSync(path.join(assetsDir, '_banner.html'));

console.log('✅ All 7 visual assets successfully generated in assets/');
