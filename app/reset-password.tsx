import { useEffect, useState } from 'react';
import { StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { router } from 'expo-router';
import { Button, Screen, Surface } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { palette } from '@/lib/theme';

export default function ResetPassword() {
 const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
 const [ready, setReady] = useState(false); const [checking, setChecking] = useState(true); const [busy, setBusy] = useState(false);
 const [password, setPassword] = useState(''); const [confirmation, setConfirmation] = useState(''); const [message, setMessage] = useState(''); const [done, setDone] = useState(false);
 useEffect(() => {
  if (!supabase) { setChecking(false); return; }
  const { data } = supabase.auth.onAuthStateChange((_event, session) => { setReady(!!session); setChecking(false); });
  void supabase.auth.getSession().then(result => { setReady(!!result.data.session); setChecking(false); });
  return () => data.subscription.unsubscribe();
 }, []);
 const save = async () => {
  if (password.length < 8) { setMessage('A senha deve ter pelo menos 8 caracteres.'); return; }
  if (password !== confirmation) { setMessage('As senhas não coincidem.'); return; }
  if (!supabase) return;
  setMessage(''); setBusy(true); const { error } = await supabase.auth.updateUser({ password }); setBusy(false);
  if (error) { setMessage('Não foi possível atualizar a senha. Solicite um novo link e tente novamente.'); return; }
  setPassword(''); setConfirmation(''); setDone(true);
 };
 return <Screen><Surface><Text accessibilityRole="header" style={[styles.title, { color: colors.textPrimary }]}>Criar nova senha</Text>
  {checking ? <Text style={[styles.body, { color: colors.textSecondary }]}>Verificando o link…</Text> : done ? <><Text style={[styles.body, { color: colors.textSecondary }]}>Sua senha foi atualizada.</Text><Button onPress={() => router.replace('/sign-in')}>Voltar para entrar</Button></> : !ready ? <><Text style={[styles.body, { color: colors.textSecondary }]}>O link não é válido ou expirou. Solicite outro na tela de entrada.</Text><Button onPress={() => router.replace('/sign-in')}>Voltar para entrar</Button></> : <>
   <Text style={[styles.body, { color: colors.textSecondary }]}>Use pelo menos 8 caracteres.</Text>
   <View style={styles.field}><Text style={[styles.label, { color: colors.textPrimary }]}>Nova senha</Text><TextInput accessibilityLabel="Nova senha" secureTextEntry autoCapitalize="none" value={password} onChangeText={setPassword} style={[styles.input, { color: colors.textPrimary, backgroundColor: colors.surfaceElevated, borderColor: colors.border }]} /></View>
   <View style={styles.field}><Text style={[styles.label, { color: colors.textPrimary }]}>Confirmar nova senha</Text><TextInput accessibilityLabel="Confirmar nova senha" secureTextEntry autoCapitalize="none" value={confirmation} onChangeText={setConfirmation} style={[styles.input, { color: colors.textPrimary, backgroundColor: colors.surfaceElevated, borderColor: colors.border }]} /></View>
   {message ? <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.danger }]}>{message}</Text> : null}
   <Button disabled={busy} onPress={() => void save()}>{busy ? 'Salvando…' : 'Atualizar senha'}</Button>
  </>}
 </Surface></Screen>;
}
const styles = StyleSheet.create({ title: { fontFamily: 'Lato_900Black', fontSize: 28, lineHeight: 34 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15 }, field: { gap: 8 }, input: { minHeight: 48, borderRadius: 12, borderWidth: 1, padding: 12, fontFamily: 'Lato_400Regular', fontSize: 16 } });
