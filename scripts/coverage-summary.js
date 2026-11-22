// Turns the coverage report of Jest into a Markdown table, so the numbers show on the page of a
// workflow run instead of being buried in the log.
//
//   node scripts/coverage-summary.js >> "$GITHUB_STEP_SUMMARY"
//
// It reads coverage/coverage-summary.json, which Jest writes through the "json-summary" reporter
// (see coverageReporters in jest.config.ts).
const fs = require('fs');
const path = require('path');

const COLUMNS = ['statements', 'branches', 'functions', 'lines'];

function percent(metric) {
  return `${metric.pct}%`;
}

function row(name, entry) {
  return `| ${name} | ${COLUMNS.map(column => percent(entry[column])).join(' | ')} |`;
}

// Jest records absolute paths; show them relative to the repository, with forward slashes.
function relative(file, root) {
  const slashed = file.replace(/\\/g, '/');
  const base = root.replace(/\\/g, '/').replace(/\/$/, '');
  // Windows shells disagree on the case of the drive letter (c:\ or C:\), so compare without case.
  return slashed.toLowerCase().startsWith(`${base.toLowerCase()}/`) ? slashed.slice(base.length + 1) : slashed;
}

function renderSummary(summary, root) {
  const files = Object.keys(summary).filter(key => key !== 'total');
  if (!summary.total || files.length === 0) {
    return '## Test coverage\n\nNo coverage data was found: the tests did not run with `--coverage`.\n';
  }

  const rows = files
    .map(file => ({ name: relative(file, root), entry: summary[file] }))
    .sort((a, b) => a.name.localeCompare(b.name))
    .map(({ name, entry }) => row(name, entry));

  return [
    '## Test coverage',
    '',
    'The build fails below the thresholds set in `jest.config.ts`.',
    '',
    '| File | Statements | Branches | Functions | Lines |',
    '|---|---|---|---|---|',
    row('All files', summary.total),
    ...rows,
    '',
  ].join('\n');
}

module.exports = { renderSummary };

if (require.main === module) {
  const file = path.join(__dirname, '..', 'coverage', 'coverage-summary.json');
  const summary = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
  process.stdout.write(renderSummary(summary, path.join(__dirname, '..')));
}
