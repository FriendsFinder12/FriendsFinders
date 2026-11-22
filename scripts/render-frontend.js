// Builds the page that is published to S3: frontend/index.html with the settings of one deployed
// environment (Cognito, API endpoints) injected, so the same file works in dev and in prod.
//
//   node scripts/render-frontend.js <terraform-output.json> <out-dir>
//
// <terraform-output.json> is the result of `terraform output -json`.
const fs = require('fs');
const path = require('path');

// page key -> Terraform output that holds its value
const OUTPUTS = {
  cognitoDomain: 'cognito_hosted_ui_url',
  webClientId: 'cognito_web_client_id',
  httpApi: 'http_api_endpoint',
  wsApi: 'websocket_api_endpoint',
  region: 'aws_region',
};

function readConfig(outputs) {
  const config = {};
  for (const [key, output] of Object.entries(OUTPUTS)) {
    if (!outputs[output] || typeof outputs[output].value !== 'string' || outputs[output].value === '') {
      throw new Error(`Terraform output "${output}" is missing; the page would not work without it`);
    }
    config[key] = outputs[output].value;
  }
  return config;
}

function renderIndex(html, outputs) {
  if (!html.includes('</head>')) throw new Error('index.html has no </head> to put the config before');
  // "<" is escaped so a value can never close the script tag.
  const json = JSON.stringify(readConfig(outputs)).replace(/</g, '\\u003c');
  return html.replace('</head>', `<script>window.__APP_CONFIG__ = ${json};</script></head>`);
}

module.exports = { renderIndex, readConfig };

if (require.main === module) {
  const [outputsFile, outDir] = process.argv.slice(2);
  if (!outputsFile || !outDir) {
    console.error('usage: node scripts/render-frontend.js <terraform-output.json> <out-dir>');
    process.exit(1);
  }
  const outputs = JSON.parse(fs.readFileSync(outputsFile, 'utf8'));
  const html = fs.readFileSync(path.join(__dirname, '..', 'frontend', 'index.html'), 'utf8');
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, 'index.html'), renderIndex(html, outputs));
  console.log(`Wrote ${path.join(outDir, 'index.html')}`);
}
