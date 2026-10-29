import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Platform, StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { Button } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { palette } from '@/lib/theme';

type Exercise = { id: string; name: string; instructions: string; archived_at: string | null };
export function ExerciseCatalog({ org, user }: { org: string; user: string }) {
 const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
 const [items, setItems] = useState<Exercise[]>([]); const [selected, setSelected] = useState<Exercise | null>(null);
 const [name, setName] = useState(''); const [instructions, setInstructions] = useState('');
 const [loading, setLoading] = useState(true); const [saving, setSaving] = useState(false); const [error, setError] = useState(''); const [message, setMessage] = useState('');
 const load = useCallback(async () => { setLoading(true); setError(''); const { data, error: e } = await supabase!.from('exercises').select('id,name,instructions,archived_at').eq('organization_id', org).order('name'); if (e) setError('Não foi possível carregar os exercícios. Tente novamente.'); else setItems(data as Exercise[]); setLoading(false); }, [org]);
 useEffect(() => { void load(); }, [load]);
 const clear = () => { setSelected(null); setName(''); setInstructions(''); };
 const save = async () => {
  if (name.trim().length < 2 || name.trim().length > 160) { setError('O nome deve ter entre 2 e 160 caracteres.'); return; }
  if (instructions.length > 4000) { setError('As instruções devem ter até 4.000 caracteres.'); return; }
  setSaving(true); setError(''); setMessage('');
  const values = { name: name.trim(), instructions: instructions.trim() };
  const result = selected ? await supabase!.from('exercises').update(values).eq('id', selected.id).select('id').single() : await supabase!.from('exercises').insert({ ...values, organization_id: org, created_by: user }).select('id').single();
  setSaving(false);
  if (result.error) { setError(result.error.code === '23505' ? 'Já existe um exercício ativo com esse nome.' : 'Não foi possível salvar. Confira sua conexão e tente novamente.'); return; }
  clear(); await load(); setMessage('Exercício salvo.');
 };
 const archive = async () => { if (!selected) return; setSaving(true); setError(''); setMessage(''); const result = await supabase!.from('exercises').update({ archived_at: new Date().toISOString() }).eq('id', selected.id).select('id').single(); setSaving(false); if (result.error) { setError('Não foi possível arquivar. Tente novamente.'); return; } clear(); await load(); setMessage('Exercício arquivado.'); };
 const confirmArchive = () => { const action = () => void archive(); if (Platform.OS === 'web') { if (globalThis.confirm('Arquivar este exercício? Ele não poderá mais ser editado.')) action(); } else Alert.alert('Arquivar exercício?', 'Ele será preservado e não poderá mais ser editado.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Arquivar', onPress: action }]); };
 return <>
  <Text accessibilityRole="header" style={[styles.heading, { color: colors.textPrimary }]}>Exercícios</Text>
  <Text style={[styles.body, { color: colors.textSecondary }]}>Organize os movimentos da sua equipe para usar em futuras prescrições.</Text>
  {loading || saving ? <ActivityIndicator accessibilityLabel="Carregando exercícios" /> : null}
  {error ? <Text style={[styles.body, { color: colors.danger }]}>{error}</Text> : null}
  {message ? <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.success }]}>{message}</Text> : null}
  {!loading && !items.length && !error ? <Text style={[styles.body, { color: colors.textSecondary }]}>Nenhum exercício cadastrado ainda.</Text> : null}
  {items.map(item => <Button key={item.id} variant="secondary" disabled={saving} onPress={() => { setSelected(item); setName(item.name); setInstructions(item.instructions); setError(''); setMessage(''); }}>{item.name}{item.archived_at ? ' · Arquivado' : ''}</Button>)}
  <Text accessibilityRole="header" style={[styles.subheading, { color: colors.textPrimary }]}>{selected ? selected.archived_at ? 'Exercício arquivado' : 'Editar exercício' : 'Novo exercício'}</Text>
  <View style={styles.field}><Text style={[styles.label, { color: colors.textPrimary }]}>Nome</Text><TextInput accessibilityLabel="Nome do exercício" editable={!saving && !selected?.archived_at} value={name} onChangeText={setName} maxLength={160} style={[styles.input, { color: colors.textPrimary, backgroundColor: colors.surfaceElevated, borderColor: colors.border }]} /></View>
  <View style={styles.field}><Text style={[styles.label, { color: colors.textPrimary }]}>Instruções (opcional)</Text><TextInput accessibilityLabel="Instruções do exercício" editable={!saving && !selected?.archived_at} value={instructions} onChangeText={setInstructions} maxLength={4000} multiline style={[styles.input, { color: colors.textPrimary, backgroundColor: colors.surfaceElevated, borderColor: colors.border }]} /></View>
  {!selected?.archived_at ? <Button disabled={saving || loading} onPress={() => void save()}>{selected ? 'Salvar alterações' : 'Adicionar exercício'}</Button> : <Text style={[styles.body, { color: colors.textSecondary }]}>Este exercício foi preservado no histórico e não pode ser alterado.</Text>}
  {selected && !selected.archived_at ? <Button variant="secondary" disabled={saving} onPress={confirmArchive}>Arquivar exercício</Button> : null}
  {selected ? <Button variant="secondary" disabled={saving} onPress={clear}>Novo exercício</Button> : null}
  {error && !selected ? <Button variant="secondary" disabled={loading || saving} onPress={load}>Atualizar lista</Button> : null}
 </>;
}
const styles = StyleSheet.create({ heading: { fontFamily: 'Lato_900Black', fontSize: 28, lineHeight: 34 }, subheading: { fontFamily: 'Lato_900Black', fontSize: 22, lineHeight: 28, marginTop: 8 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15 }, field: { gap: 8 }, input: { minHeight: 48, borderRadius: 12, borderWidth: 1, padding: 12, fontFamily: 'Lato_400Regular', fontSize: 16 } });
