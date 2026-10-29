import { describe, expect, it } from 'vitest';
import { formatResponse } from '../lib/anamnesis/format-response';

describe('apresentação de respostas', () => {
  it('preserva respostas sintéticas dos tipos suportados', () => {
    expect(formatResponse(false)).toBe('Não');
    expect(formatResponse(true)).toBe('Sim');
    expect(formatResponse(0)).toBe('0');
    expect(formatResponse(['A', 'B'])).toBe('A, B');
    expect(formatResponse('Resposta sintética')).toBe('Resposta sintética');
  });
  it('não exibe valores inesperados como conteúdo clínico', () => {
    expect(formatResponse(null)).toBe('Resposta indisponível');
    expect(formatResponse({ value: 'x' })).toBe('Resposta indisponível');
    expect(formatResponse([{}])).toBe('Resposta indisponível');
  });
});
