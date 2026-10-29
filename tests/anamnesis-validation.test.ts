import { describe, expect, it } from 'vitest';
import { prepareAnswers, validateAnswer, validateAnswers, type Question } from '../lib/anamnesis/validation';

const question = (kind: Question['kind'], required = true): Question => ({ id: kind, prompt: 'Pergunta sintética', kind, required, options: ['A', 'B'] });

describe('validação de anamnese', () => {
  it('identifica respostas obrigatórias ausentes sem rejeitar zero ou falso', () => {
    expect(validateAnswer(question('text'), '  ')).toBeTruthy();
    expect(validateAnswer(question('multiple_choice'), [])).toBeTruthy();
    expect(validateAnswer(question('number'), 0)).toBeNull();
    expect(validateAnswer(question('boolean'), false)).toBeNull();
    expect(validateAnswer(question('text', false), null)).toBeNull();
  });
  it('rejeita valores incompatíveis e opções inexistentes ou duplicadas', () => {
    expect(validateAnswer(question('number'), NaN)).toBeTruthy();
    expect(validateAnswer(question('number'), '2')).toBeTruthy();
    expect(validateAnswer(question('boolean'), 'false')).toBeTruthy();
    expect(validateAnswer(question('single_choice'), 'C')).toBeTruthy();
    expect(validateAnswer(question('multiple_choice'), ['A', 'A'])).toBeTruthy();
    expect(validateAnswer(question('multiple_choice'), ['A', 'C'])).toBeTruthy();
    expect(validateAnswer(question('multiple_choice'), ['A', 'B'])).toBeNull();
  });
  it('associa mensagens aos identificadores das perguntas', () => {
    expect(validateAnswers([question('text'), question('boolean')], { boolean: false })).toEqual({ text: 'Esta resposta é obrigatória.' });
  });
  it('converte números completos ao salvar, mantendo entradas incompletas para exibir erro', () => {
    const questions = [question('number')];
    for (const [input, expected] of [['-1,25', -1.25], ['0', 0], ['.5', 0.5], ['  ', null]] as const) {
      expect(prepareAnswers(questions, { number: input }).number).toBe(expected);
    }
    for (const input of ['-', '1,', '1.2.3', 'Infinity', '1e3']) {
      const prepared = prepareAnswers(questions, { number: input });
      expect(prepared.number).toBe(input);
      expect(validateAnswers(questions, prepared).number).toBeTruthy();
    }
    expect(prepareAnswers(questions, { number: 2 }).number).toBe(2);
  });

});
