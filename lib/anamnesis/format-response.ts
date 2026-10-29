/** Present stored answer values without interpreting them as markup. */
export function formatResponse(value: unknown): string {
  if (typeof value === 'boolean') return value ? 'Sim' : 'Não';
  if (Array.isArray(value) && value.every(item => typeof item === 'string')) return value.join(', ');
  if (typeof value === 'string' || typeof value === 'number') return String(value);
  return 'Resposta indisponível';
}
