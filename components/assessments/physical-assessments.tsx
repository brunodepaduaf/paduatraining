import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Platform, StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { Button } from '@/components/ui';
import { prepareAnswers } from '@/lib/anamnesis/validation';
import { supabase } from '@/lib/supabase';
import { palette } from '@/lib/theme';

type Member = { profile_id: string; profiles: { full_name: string } | null };
type Assessment = { id: string; measured_at: string; weight_kg: number | string | null; height_cm: number | string | null; waist_cm: number | string | null };
const measures = [{ id: 'weight', label: 'Peso (kg)' }, { id: 'height', label: 'Altura (cm)' }, { id: 'waist', label: 'Cintura (cm)' }] as const;

export function PhysicalAssessments({ org, user, student }: { org: string; user: string; student: boolean }) {
 const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
 const requestRef = useRef(0);
 const [members, setMembers] = useState<Member[]>([]); const [selected, setSelected] = useState(''); const [rows, setRows] = useState<Assessment[]>([]);
 const [values, setValues] = useState<Record<string, string>>({ weight: '', height: '', waist: '' }); const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState(''); const [message, setMessage] = useState('');
 const load = useCallback(async () => { setLoading(true); setError('');
  if (student) { const r = await supabase!.from('physical_assessments').select('id,measured_at,weight_kg,height_cm,waist_cm').eq('organization_id', org).eq('student_id', user).order('measured_at', { ascending: false }); if (r.error) setError('Não foi possível carregar suas avaliações.'); else setRows(r.data as Assessment[]); }
  else { const r = await supabase!.from('organization_members').select('profile_id,profiles(full_name)').eq('organization_id', org).eq('role', 'student').is('archived_at', null); if (r.error) setError('Não foi possível carregar os alunos.'); else setMembers(r.data as unknown as Member[]); }
  setLoading(false);
 }, [org, student, user]);
 useEffect(() => { void load(); }, [load]);
 const review = async (target: string) => { const request = ++requestRef.current; if (target !== selected) setValues({ weight: '', height: '', waist: '' }); setSelected(target); setRows([]); setMessage(''); setError(''); setBusy(true); const r = await supabase!.rpc('get_physical_assessments', { target_organization: org, target_student: target }); if (request !== requestRef.current) return; setBusy(false); if (r.error) { setError('Não foi possível consultar as avaliações. Confira o vínculo e o acesso do aluno.'); return; } setRows(r.data as Assessment[]); };
 const save = async () => {
  if (!selected) { setError('Escolha um aluno.'); return; }
  const questions = measures.map(m => ({ id: m.id, prompt: m.label, kind: 'number' as const, required: false, options: [] }));
  const parsed = prepareAnswers(questions, values); const result = measures.map(m => parsed[m.id]);
  if (result.every(v => v == null) || result.some(v => v != null && (typeof v !== 'number' || !Number.isFinite(v) || v <= 0 || v >= 1000000))) { setError('Informe ao menos uma medida numérica maior que zero. Use ponto ou vírgula decimal.'); return; }
  setBusy(true); setError(''); setMessage('');
  const r = await supabase!.rpc('create_physical_assessment', { target_organization: org, target_student: selected, weight: result[0], height: result[1], waist: result[2] });
  setBusy(false); if (r.error) { setError('Não foi possível registrar a avaliação. Tente novamente.'); return; }
  setValues({ weight: '', height: '', waist: '' }); await review(selected); setMessage('Avaliação registrada.');
 };
 const confirmSave = () => { const name = members.find(member => member.profile_id === selected)?.profiles?.full_name || 'este aluno'; const prompt = `Registrar avaliação para ${name}? Após salvar, ela não poderá ser editada.`; if (Platform.OS === 'web') { if (globalThis.confirm(prompt)) void save(); } else Alert.alert('Registrar avaliação?', prompt, [{ text: 'Cancelar', style: 'cancel' }, { text: 'Registrar', onPress: () => void save() }]); };
 const body = (text: string) => <Text style={[styles.body, { color: colors.textSecondary }]}>{text}</Text>;
 const measure = (label: string, value: number | string | null, unit: string) => value == null ? null : body(`${label}: ${value} ${unit}`);
 return <>
  <Text accessibilityRole="header" style={[styles.heading, { color: colors.textPrimary }]}>Avaliações físicas</Text>
  {body(student ? 'Suas medidas registradas aparecem aqui.' : 'Registre e consulte medidas dos alunos autorizados. As consultas são auditadas.')}
  {loading || busy ? <ActivityIndicator accessibilityLabel="Carregando avaliações" /> : null}{error ? <Text style={[styles.body, { color: colors.danger }]}>{error}</Text> : null}{message ? <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.success }]}>{message}</Text> : null}
  {!student && <>{members.length === 0 && !loading ? body('Nenhum aluno disponível para consulta.') : null}{members.map(m => <Button key={m.profile_id} disabled={busy} selected={selected === m.profile_id} variant={selected === m.profile_id ? 'primary' : 'secondary'} onPress={() => void review(m.profile_id)}>{m.profiles?.full_name || 'Aluno'}</Button>)}</>}
  {(student || selected) && !loading && !busy && rows.length === 0 && !error ? body('Nenhuma avaliação registrada.') : null}
  {rows.map(row => <View key={row.id} style={styles.group}><Text style={[styles.label, { color: colors.textPrimary }]}>{new Date(row.measured_at).toLocaleDateString('pt-BR')}</Text>{measure('Peso', row.weight_kg, 'kg')}{measure('Altura', row.height_cm, 'cm')}{measure('Cintura', row.waist_cm, 'cm')}</View>)}
  {!student && selected ? <>{body(`Aluno: ${members.find(member => member.profile_id === selected)?.profiles?.full_name || 'Aluno'}`)}{body('Informe ao menos uma medida. Os registros não podem ser editados após salvar.')}{measures.map(m => <View key={m.id} style={styles.field}><Text style={[styles.label, { color: colors.textPrimary }]}>{m.label}</Text><TextInput accessibilityLabel={m.label} editable={!busy} value={values[m.id]} onChangeText={value => setValues(previous => ({ ...previous, [m.id]: value }))} style={[styles.input, { color: colors.textPrimary, backgroundColor: colors.surfaceElevated, borderColor: colors.border }]} /></View>)}<Button disabled={busy} onPress={confirmSave}>Registrar avaliação</Button></> : null}
  {error ? <Button variant="secondary" disabled={loading || busy} onPress={() => student || !selected ? void load() : void review(selected)}>Tentar novamente</Button> : null}
 </>;
}
const styles = StyleSheet.create({ heading: { fontFamily: 'Lato_900Black', fontSize: 28, lineHeight: 34 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15, lineHeight: 22 }, input: { minHeight: 48, borderRadius: 12, borderWidth: 1, padding: 12, fontFamily: 'Lato_400Regular', fontSize: 16 }, field: { gap: 8 }, group: { gap: 6, paddingVertical: 12 } });
