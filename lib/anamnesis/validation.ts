/** The values stored in anamnesis_answers.answer. */
export type Answer = string | number | boolean | string[] | null;
export type QuestionKind = 'text' | 'number' | 'single_choice' | 'multiple_choice' | 'boolean';
export type Question = { id: string; prompt: string; kind: QuestionKind; required: boolean; options: string[] };

/** Validate both completeness and shape; false and zero are valid answers. */
export function validateAnswer(question: Question, answer: unknown): string | null {
  const empty = answer == null || (typeof answer === 'string' && answer.trim() === '') || (Array.isArray(answer) && answer.length === 0);
  if (empty) return question.required ? 'Esta resposta é obrigatória.' : null;
  switch (question.kind) {
    case 'text':
      return typeof answer === 'string' ? null : 'Informe um texto válido.';
    case 'number':
      return typeof answer === 'number' && Number.isFinite(answer) ? null : 'Informe um número válido.';
    case 'boolean':
      return typeof answer === 'boolean' ? null : 'Escolha sim ou não.';
    case 'single_choice':
      return typeof answer === 'string' && question.options.includes(answer) ? null : 'Escolha uma opção válida.';
    case 'multiple_choice':
      return Array.isArray(answer) && answer.every(value => typeof value === 'string' && question.options.includes(value)) && new Set(answer).size === answer.length
        ? null : 'Escolha opções válidas.';
  }
}

export function validateAnswers(questions: Question[], answers: Record<string, unknown>): Record<string, string> {
  const errors: Record<string, string> = {};
  for (const question of questions) {
    const error = validateAnswer(question, answers[question.id]);
    if (error) errors[question.id] = error;
  }
  return errors;
}
