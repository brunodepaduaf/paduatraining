import { describe, expect, it } from 'vitest';
import { palette } from '@/lib/theme';

describe('theme tokens', () => {
  it('keeps each semantic palette complete', () => {
    expect(Object.keys(palette.light)).toEqual(Object.keys(palette.dark));
    expect(palette.dark.background).toBe('#191719');
    expect(palette.light.brand).toBe('#9E365F');
  });
});
