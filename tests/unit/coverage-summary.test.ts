// eslint-disable-next-line @typescript-eslint/no-require-imports
const { renderSummary } = require('../../scripts/coverage-summary');

const pct = (value: number) => ({ total: 10, covered: value / 10, skipped: 0, pct: value });
const entry = (s: number, b: number, f: number, l: number) => ({
  statements: pct(s),
  branches: pct(b),
  functions: pct(f),
  lines: pct(l),
});

// The shape of coverage/coverage-summary.json: absolute paths, plus a "total" entry.
const root = '/work/repo';
const summary = {
  total: entry(99.31, 98.07, 100, 100),
  [`${root}/src/utils/distance.ts`]: entry(100, 100, 100, 100),
  [`${root}/src/handlers/rest-handler.ts`]: entry(97.5, 94, 100, 100),
};

describe('renderSummary', () => {
  it('starts with the totals, so the number that matters is the first thing read', () => {
    const md = renderSummary(summary, root);
    const lines = md.split('\n');
    expect(lines[0]).toMatch(/^## .*coverage/i);
    expect(md.indexOf('All files')).toBeLessThan(md.indexOf('src/utils/distance.ts'));
    expect(md).toMatch(/\| All files \| 99\.31% \| 98\.07% \| 100% \| 100% \|/);
  });

  it('lists each file with a path relative to the repository, in order', () => {
    const md = renderSummary(summary, root);
    expect(md).toContain('| src/handlers/rest-handler.ts | 97.5% | 94% | 100% | 100% |');
    expect(md).toContain('| src/utils/distance.ts | 100% | 100% | 100% | 100% |');
    expect(md.indexOf('src/handlers/')).toBeLessThan(md.indexOf('src/utils/'));
    expect(md).not.toContain(root);
  });

  it('understands Windows paths so it also works when run locally', () => {
    const win = { total: summary.total, [String.raw`C:\repo\src\utils\geo-cells.ts`]: entry(90, 80, 100, 90) };
    expect(renderSummary(win, String.raw`C:\repo`)).toContain('| src/utils/geo-cells.ts | 90% |');
  });

  it('ignores the case of the drive letter, which differs between Windows shells', () => {
    const win = { total: summary.total, [String.raw`C:\repo\src\utils\geo-cells.ts`]: entry(90, 80, 100, 90) };
    expect(renderSummary(win, String.raw`c:\repo`)).toContain('| src/utils/geo-cells.ts | 90% |');
  });

  it('points to where the thresholds are defined instead of repeating them', () => {
    expect(renderSummary(summary, root)).toContain('jest.config.ts');
  });

  it('says so when there is no coverage data, rather than printing an empty table', () => {
    expect(renderSummary({}, root)).toMatch(/no coverage data/i);
  });
});
