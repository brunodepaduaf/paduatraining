import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Platform, StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { Button } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { palette } from '@/lib/theme';

type Plan = { id: string; student_id: string; title: string; version: number; status: 'draft' | 'published' | 'archived' };
type Item = { id: string; exercise_name: string; exercise_instructions: string; position: number; sets: number; repetitions: string };
type Member = { profile_id: string; profiles: { full_name: string } | null };
type Exercise = { id: string; name: string };
function confirmAction(title: string, action: () => void) { if (Platform.OS === 'web') { if (globalThis.confirm(title)) action(); } else Alert.alert(title, undefined, [{ text: 'Cancelar', style: 'cancel' }, { text: 'Confirmar', onPress: action }]); }

export function TrainingPlans({ org, user, student }: { org: string; user: string; student: boolean }) {
 const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
 const [plans, setPlans] = useState<Plan[]>([]); const [members, setMembers] = useState<Member[]>([]); const [exercises, setExercises] = useState<Exercise[]>([]);
 const [plan, setPlan] = useState<Plan | null>(null); const [items, setItems] = useState<Item[]>([]); const [target, setTarget] = useState(''); const [title, setTitle] = useState('');
 const [exercise, setExercise] = useState(''); const [sets, setSets] = useState('3'); const [repetitions, setRepetitions] = useState('');
 const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState(''); const [message, setMessage] = useState('');
 const load = useCallback(async () => {
  setLoading(true); setError('');
  const query = supabase!.from('training_plans').select('id,student_id,title,version,status').eq('organization_id', org).order('created_at', { ascending: false });
  const requests = await Promise.all([student ? query.eq('student_id', user).eq('status', 'published') : query,
   student ? Promise.resolve(null) : supabase!.from('organization_members').select('profile_id,profiles(full_name)').eq('organization_id', org).eq('role', 'student').is('archived_at', null),
   student ? Promise.resolve(null) : supabase!.from('exercises').select('id,name').eq('organization_id', org).is('archived_at', null).order('name')]);
  if (requests.some(r => r?.error)) setError('Não foi possível carregar os treinos. Tente novamente.');
  else { setPlans(requests[0].data as Plan[]); if (!student) { setMembers((requests[1]?.data ?? []) as unknown as Member[]); setExercises((requests[2]?.data ?? []) as Exercise[]); } }
  setLoading(false);
 }, [org, student, user]);
 useEffect(() => { void load(); }, [load]);
 const open = async (p: Plan) => { setBusy(true); setError(''); const r = await supabase!.from('training_plan_items').select('id,exercise_name,exercise_instructions,position,sets,repetitions').eq('plan_id', p.id).order('position'); setBusy(false); if (r.error) { setError('Não foi possível abrir a ficha. Tente novamente.'); return; } setPlan(p); setItems(r.data as Item[]); setMessage(''); };
 const create = async () => { if (!target || title.trim().length < 2 || title.trim().length > 160) { setError('Escolha um aluno e informe um título com 2 a 160 caracteres.'); return; } setBusy(true); setError(''); const version = Math.max(0, ...plans.filter(p => p.student_id === target).map(p => p.version)) + 1; const r = await supabase!.from('training_plans').insert({ organization_id: org, student_id: target, created_by: user, title: title.trim(), version }).select('id,student_id,title,version,status').single(); setBusy(false); if (r.error) { setError('Não foi possível criar a ficha. Confira o vínculo e o acesso do aluno e tente novamente.'); return; } setTitle(''); await load(); await open(r.data as Plan); };
 const add = async () => { const n = Number(sets); if (!plan || !exercise || !/^\d+$/.test(sets) || !Number.isInteger(n) || n < 1 || n > 100 || !repetitions.trim() || repetitions.trim().length > 80) { setError('Escolha um exercício, informe de 1 a 100 séries e até 80 caracteres de repetições.'); return; } setBusy(true); setError(''); const r = await supabase!.from('training_plan_items').insert({ plan_id: plan.id, exercise_id: exercise, position: Math.max(0, ...items.map(i => i.position)) + 1, sets: n, repetitions: repetitions.trim() }); setBusy(false); if (r.error) { setError('Não foi possível adicionar o exercício. Ele pode ter sido arquivado.'); return; } setExercise(''); setRepetitions(''); await open(plan); };
 const changeStatus = (status: 'published' | 'archived') => { if (!plan) return; confirmAction(status === 'published' ? 'Publicar esta ficha? Ela não poderá mais ser editada.' : 'Arquivar esta ficha? Ela deixará de aparecer para o aluno.', () => { void (async () => { setBusy(true); setError(''); const r = await supabase!.from('training_plans').update({ status }).eq('id', plan.id).select('id,student_id,title,version,status').single(); setBusy(false); if (r.error) { setError('Não foi possível atualizar a ficha. Tente novamente.'); return; } setPlan(r.data as Plan); await load(); setMessage(status === 'published' ? 'Ficha publicada.' : 'Ficha arquivada.'); })(); }); };
 const removePlan = () => { if (!plan) return; confirmAction('Excluir este rascunho e seus exercícios?', () => { void (async () => { setBusy(true); setError(''); const r = await supabase!.from('training_plans').delete().eq('id', plan.id).select('id').single(); setBusy(false); if (r.error) { setError('Não foi possível excluir o rascunho.'); return; } setPlan(null); await load(); setMessage('Rascunho excluído.'); })(); }); };
 const removeItem = async (id: string) => { if (!plan) return; setBusy(true); const r = await supabase!.from('training_plan_items').delete().eq('id', id); setBusy(false); if (r.error) { setError('Não foi possível remover o exercício.'); return; } await open(plan); };
 const text = (children: string) => <Text style={[styles.body, { color: colors.textSecondary }]}>{children}</Text>;
 const field = (label: string, value: string, change: (value: string) => void) => <View style={styles.field}><Text style={[styles.label, { color: colors.textPrimary }]}>{label}</Text><TextInput accessibilityLabel={label} editable={!busy} value={value} onChangeText={change} style={[styles.input, { color: colors.textPrimary, borderColor: colors.border, backgroundColor: colors.surfaceElevated }]} /></View>;
 return <>
  <Text accessibilityRole="header" style={[styles.heading, { color: colors.textPrimary }]}>{plan ? plan.title : student ? 'Meus treinos' : 'Prescrições'}</Text>
  {loading || busy ? <ActivityIndicator accessibilityLabel="Carregando treinos" /> : null}
  {error ? <Text style={[styles.body, { color: colors.danger }]}>{error}</Text> : null}{message ? <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.success }]}>{message}</Text> : null}
  {!plan ? <>{!loading && plans.length === 0 && !error ? text(student ? 'Nenhum treino publicado está disponível.' : 'Nenhuma ficha disponível ainda.') : null}{plans.map(p => <Button key={p.id} variant="secondary" disabled={busy} onPress={() => void open(p)}>{!student ? `${members.find(m => m.profile_id === p.student_id)?.profiles?.full_name || 'Aluno'} · ` : ''}{p.title} · v{p.version} · {p.status === 'draft' ? 'Rascunho' : p.status === 'published' ? 'Publicado' : 'Arquivado'}</Button>)}
   {!student && <>{text('Escolha o aluno para criar uma ficha em rascunho.')}{members.length === 0 && !loading ? text('Nenhum aluno disponível para prescrição.') : null}{members.map(m => <Button key={m.profile_id} selected={target === m.profile_id} variant={target === m.profile_id ? 'primary' : 'secondary'} onPress={() => setTarget(m.profile_id)}>{m.profiles?.full_name || 'Aluno'}</Button>)}{field('Título da ficha', title, setTitle)}<Button disabled={busy || loading} onPress={() => void create()}>Criar ficha</Button></>}</> : <>
   {text(`Versão ${plan.version} · ${plan.status === 'draft' ? 'Rascunho' : plan.status === 'published' ? 'Publicado' : 'Arquivado'}`)}
   {items.length === 0 ? text('Esta ficha ainda não tem exercícios.') : null}{items.map(item => <View key={item.id} style={styles.group}><Text style={[styles.label, { color: colors.textPrimary }]}>{item.position}. {item.exercise_name}</Text>{text(`${item.sets} séries · ${item.repetitions} repetições`)}{item.exercise_instructions ? text(item.exercise_instructions) : null}{!student && plan.status === 'draft' ? <Button variant="secondary" disabled={busy} onPress={() => void removeItem(item.id)}>Remover exercício</Button> : null}</View>)}
   {!student && plan.status === 'draft' ? <>{text('Escolha um exercício ativo e informe as séries e repetições.')}{exercises.length === 0 ? text('Cadastre um exercício antes de montar a ficha.') : null}{exercises.map(e => <Button key={e.id} selected={exercise === e.id} variant={exercise === e.id ? 'primary' : 'secondary'} onPress={() => setExercise(e.id)}>{e.name}</Button>)}{field('Séries', sets, setSets)}{field('Repetições', repetitions, setRepetitions)}<Button disabled={busy} onPress={() => void add()}>Adicionar à ficha</Button><Button disabled={busy || items.length === 0} onPress={() => changeStatus('published')}>Publicar ficha</Button><Button variant="secondary" disabled={busy} onPress={removePlan}>Excluir rascunho</Button></> : null}
   {!student && plan.status === 'published' ? <Button variant="secondary" disabled={busy} onPress={() => changeStatus('archived')}>Arquivar ficha</Button> : null}
   <Button variant="secondary" disabled={busy} onPress={() => { setPlan(null); setMessage(''); }}>Voltar aos treinos</Button>
  </>}
  {error && !plan ? <Button variant="secondary" disabled={loading || busy} onPress={load}>Atualizar lista</Button> : null}
 </>;
}
const styles = StyleSheet.create({ heading: { fontFamily: 'Lato_900Black', fontSize: 28, lineHeight: 34 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15, lineHeight: 22 }, input: { minHeight: 48, borderRadius: 12, borderWidth: 1, padding: 12, fontFamily: 'Lato_400Regular', fontSize: 16 }, field: { gap: 8 }, group: { gap: 8, paddingVertical: 12 } });
