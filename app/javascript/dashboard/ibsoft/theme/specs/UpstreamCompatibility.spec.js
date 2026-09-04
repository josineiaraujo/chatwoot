import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const readSource = relativePath =>
  readFileSync(new URL(relativePath, import.meta.url), 'utf8');

describe('Ibsoft upstream visual compatibility', () => {
  it('keeps translated heatmap labels inside the fixed viz rows', () => {
    const source = readSource('../_dark-overrides.scss');

    expect(source).toContain('#app .cw-viz-heatmap');
    expect(source).toContain('--cw-viz-heatmap-row-title-font-size: 10px');
    expect(source).toContain(
      '--cw-viz-heatmap-row-description-font-size: 10px'
    );
    expect(source).toContain('#app .cw-viz-heatmap__row-label > strong');
    expect(source).toContain('line-height: 1.2');
  });
});
