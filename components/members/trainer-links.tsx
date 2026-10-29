import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Platform, StyleSheet, Text, useColorScheme, View } from 'react-native';
import { Button } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { palette } from '@/lib/theme';

type Member = { profile_id: string; role: 'trainer' | 'student'; profiles: { full_name: string } | null };
type Link = { id: string; trainer_id: string; student_id: string; archived_at: string | null };
function label(member: Member) { return (member.profiles?.full_name || 'Pessoa') + ' · ' + member.profile_id.slice(0, 8); }
function confirmAction(title: string, action: () => void) {
 if (Platform.OS === 'web') { if (globalThis.confirm(title)) action(); }
 else Alert.alert('Confirmar vínculo', title, [{ text: 'Cancelar', style: 'cancel' }, { text: 'Confirmar', onPress: action }]);
}
export function TrainerLinks({ org, user }: { org: string; user: string }) {
 const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
 const [members, setMembers] = useState<Member[]>([]); const [links, setLinks] = useState<Link[]>([]);
 const [trainer, setTrainer] = useState(''); const [student, setStudent] = useState('');
 const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState(''); const [message, setMessage] = useState('');
 const load = useCallback(async () => {
  setLoading(true); setError('');
  const [m, l] = await Promise.all([
   supabase!.from('organization_members').select('profile_id,role,profiles(full_name)').eq('organization_id', org).in('role', ['student','trainer']).is('archived_at', null),
   supabase!.from('trainer_students').select('id,trainer_id,student_id,archived_at').eq('organization_id', org)
  ]);
  if (m.error || l.error) setError('Não foi possível carregar os vínculos. Tente novamente.');
  else { setMembers(m.data as unknown as Member[]); setLinks(l.data as Link[]); }
  setLoading(false);
 }, [org]);
 useEffect(() => { void load(); }, [load]);
 const trainerName = members.find(m => m.profile_id === trainer); const studentName = members.find(m => m.profile_id === student);
 const existing = links.find(link => link.trainer_id === trainer && link.student_id === student);
 const save = () => {
  if (!trainerName || !studentName) { setError('Escolha um trainer e um aluno.'); return; }
  if (existing && !existing.archived_at) { setError('Este vínculo já está ativo.'); return; }
  confirmAction('Vincular ' + label(trainerName) + ' a ' + label(studentName) + '?', () => { void (async () => {
   setBusy(true); setError(''); setMessage('');
   const r = existing ? await supabase!.from('trainer_students').update({ archived_at: null }).eq('id', existing.id).select('id').single()
    : await supabase!.from('trainer_students').insert({ organization_id: org, trainer_id: trainer, student_id: student, created_by: user }).select('id').single();
   setBusy(false); if (r.error) { setError('Não foi possível registrar o vínculo. Confira os papéis e tente novamente.'); return; }
   await load(); setMessage('Vínculo registrado.');
  })(); });
 };
 const archive = (link: Link) => {
  const t = members.find(m => m.profile_id === link.trainer_id); const s = members.find(m => m.profile_id === link.student_id);
  confirmAction('Encerrar o vínculo de ' + (t ? label(t) : 'trainer') + ' com ' + (s ? label(s) : 'aluno') + '? O trainer perderá acesso aos dados associados.', () => { void (async () => {
   setBusy(true); setError(''); setMessage('');
   const r = await supabase!.from('trainer_students').update({ archived_at: new Date().toISOString() }).eq('id', link.id).select('id').single();
   setBusy(false); if (r.error) { setError('Não foi possível encerrar o vínculo.'); return; }
   await load(); setMessage('Vínculo encerrado.');
  })(); });
 };
 return <>
  <Text accessibilityRole="header" style={[styles.heading, { color: colors.textPrimary }]}>Vínculos de treino</Text>
  <Text style={[styles.body, { color: colors.textSecondary }]}>O owner define quais trainers acompanham cada aluno. As alterações são auditadas.</Text>
  {loading || busy ? <ActivityIndicator accessibilityLabel="Carregando vínculos" /> : null}
  {error ? <Text style={[styles.body, { color: colors.danger }]}>{error}</Text> : null}
  {message ? <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.success }]}>{message}</Text> : null}
  <Text style={[styles.label, { color: colors.textPrimary }]}>Trainer</Text>
  {members.filter(m => m.role === 'trainer').map(m => <Button key={m.profile_id} disabled={busy} selected={trainer === m.profile_id} variant={trainer === m.profile_id ? 'primary' : 'secondary'} onPress={() => setTrainer(m.profile_id)}>{label(m)}</Button>)}
  <Text style={[styles.label, { color: colors.textPrimary }]}>Aluno</Text>
  {members.filter(m => m.role === 'student').map(m => <Button key={m.profile_id} disabled={busy} selected={student === m.profile_id} variant={student === m.profile_id ? 'primary' : 'secondary'} onPress={() => setStudent(m.profile_id)}>{label(m)}</Button>)}
  {!loading && (!members.some(m => m.role === 'trainer') || !members.some(m => m.role === 'student')) ? <Text style={[styles.body, { color: colors.textSecondary }]}>É necessário ter um trainer e um aluno cadastrados na organização.</Text> : null}
  <Button disabled={busy || loading} onPress={save}>{existing?.archived_at ? 'Reativar vínculo' : 'Criar vínculo'}</Button>
  <Text style={[styles.label, { color: colors.textPrimary }]}>Vínculos ativos</Text>
  {!loading && links.every(link => !!link.archived_at) ? <Text style={[styles.body, { color: colors.textSecondary }]}>Nenhum vínculo ativo.</Text> : null}
  {links.filter(link => !link.archived_at).map(link => {
   const t = members.find(m => m.profile_id === link.trainer_id); const s = members.find(m => m.profile_id === link.student_id);
   return <View key={link.id} style={styles.group}><Text style={[styles.body, { color: colors.textSecondary }]}>{t ? label(t) : 'Trainer · ' + link.trainer_id.slice(0, 8)} → {s ? label(s) : 'Aluno · ' + link.student_id.slice(0, 8)}</Text><Button variant="secondary" disabled={busy} onPress={() => archive(link)}>Encerrar vínculo</Button></View>;
  })}
  {error ? <Button variant="secondary" disabled={busy || loading} onPress={load}>Atualizar lista</Button> : null}
 </>;
}
const styles = StyleSheet.create({ heading: { fontFamily: 'Lato_900Black', fontSize: 28, lineHeight: 34 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15, lineHeight: 22 }, group: { gap: 8, paddingVertical: 8 } });
