import { describe, expect, it } from 'vitest';
import { endOfLocalDay } from '../lib/access-period';

describe('fim de período de acesso', () => {
  it('termina no começo do dia local seguinte', () => {
    const end = new Date(endOfLocalDay('2030-03-31')!);
    expect([end.getFullYear(), end.getMonth(), end.getDate(), end.getHours()]).toEqual([2030, 3, 1, 0]);
  });
  it('rejeita datas inexistentes ou ambíguas', () => {
    expect(endOfLocalDay('2030-02-30')).toBeNull();
    expect(endOfLocalDay('31/03/2030')).toBeNull();
    expect(endOfLocalDay('')).toBeNull();
    expect(endOfLocalDay('2030-13-01')).toBeNull();
  });
});
