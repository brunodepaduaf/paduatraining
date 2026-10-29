import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, useColorScheme, View } from 'react-native';
import { Button } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { formatResponse } from '@/lib/anamnesis/format-response';
import { palette } from '@/lib/theme';

type Summary = { submission_id: string; student_name: string; title: string; version: number; status: 'draft' | 'submitted'; submitted_at: string | null };
type ReviewedAnswer = { question_id: string; prompt: string; question_type: string; response: unknown };
type Submission = { student_name: string; title: string; version: number; answers: ReviewedAnswer[] };
type ReviewRole = 'owner' | 'trainer';

/** Details are obtained only through the database's audited, role-scoped RPC. */
export function StaffReview({ org, role, onBack }: { org: string; role: ReviewRole; onBack?: () => void }) {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  const [rows, setRows] = useState<Summary[]>([]);
  const [selected, setSelected] = useState<Submission | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setLoading(true); setError('');
    const result = await supabase!.rpc(role === 'owner' ? 'get_anamnesis_owner_summary' : 'get_anamnesis_trainer_summary', { target_organization: org });
    if (result.error) setError('Não foi possível carregar as anamneses. Confira sua conexão e tente novamente.');
    else setRows((result.data as Summary[]).filter(row => row.status === 'submitted'));
    setLoading(false);
  }, [org, role]);
  useEffect(() => { void load(); }, [load]);
  const open = async (id: string) => {
    setLoading(true); setError('');
    const result = await supabase!.rpc(role === 'owner' ? 'get_anamnesis_submission_for_owner' : 'get_anamnesis_submission_for_trainer', { target_submission: id });
    if (result.error || !result.data) setError('Não foi possível abrir esta anamnese. O acesso pode ter mudado; atualize a lista e tente novamente.');
    else setSelected(result.data as Submission);
    setLoading(false);
  };
  return <>
    <Text accessibilityRole="header" style={[styles.heading, { color: colors.textPrimary }]}>{selected ? selected.student_name || 'Aluno' : 'Anamneses enviadas'}</Text>
    {loading ? <ActivityIndicator accessibilityLabel="Carregando anamneses" /> : null}
    {error ? <><Text style={[styles.body, { color: colors.danger }]}>{error}</Text><Button variant="secondary" onPress={load}>Atualizar lista</Button></> : null}
    {selected ? <>
      <Text style={[styles.body, { color: colors.textSecondary }]}>{selected.title} · versão {selected.version}</Text>
      <Text style={[styles.body, { color: colors.textSecondary }]}>A consulta desta anamnese é registrada para proteger a privacidade do aluno.</Text>
      {selected.answers.length ? selected.answers.map(answer => <View key={answer.question_id} style={styles.answer}><Text style={[styles.label, { color: colors.textPrimary }]}>{answer.prompt}</Text><Text style={[styles.body, { color: colors.textSecondary }]}>{formatResponse(answer.response)}</Text></View>) : <Text style={[styles.body, { color: colors.textSecondary }]}>Nenhuma resposta foi registrada.</Text>}
      <Button variant="secondary" onPress={() => { setSelected(null); setError(''); }}>Voltar às anamneses</Button>
    </> : <>
      {!loading && !error && rows.length === 0 ? <Text style={[styles.body, { color: colors.textSecondary }]}>Ainda não há anamneses enviadas disponíveis.</Text> : null}
      {rows.map(row => <Button key={row.submission_id} variant="secondary" disabled={loading} onPress={() => void open(row.submission_id)}>{row.student_name || 'Aluno'} · {row.title} · v{row.version}</Button>)}
      {onBack ? <Button variant="secondary" onPress={onBack}>Voltar aos formulários</Button> : null}
    </>}
  </>;
}
const styles = StyleSheet.create({ heading: { fontFamily: 'Lato_900Black', fontSize: 28, lineHeight: 34 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15, lineHeight: 22 }, answer: { gap: 8, paddingVertical: 8 } });
