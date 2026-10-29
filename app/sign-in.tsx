import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { router, type Href } from 'expo-router';
import * as Linking from 'expo-linking';
import { Button, Screen, Surface } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { palette, space } from '@/lib/theme';

const schema = z.object({ email: z.string().email('Informe um e-mail válido.'), password: z.string().min(8, 'A senha deve ter pelo menos 8 caracteres.') });
type Form = z.infer<typeof schema>;

export default function SignIn() {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  const { control, handleSubmit, getValues, formState: { errors } } = useForm<Form>({ resolver: zodResolver(schema), defaultValues: { email: '', password: '' } });
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState('');
  const signIn = async (values: Form) => {
    if (!supabase) { setNotice('Configure o Supabase para entrar.'); return; }
    setNotice(''); setLoading(true); const { error } = await supabase.auth.signInWithPassword(values); setLoading(false);
    if (error) { setNotice('Não foi possível entrar. Confira seus dados ou tente novamente.'); return; }
    router.replace('/workspace' as Href);
  };
  const recover = async () => {
    const email = schema.shape.email.safeParse(getValues('email').trim());
    if (!email.success) { setNotice('Informe um e-mail válido para recuperar o acesso.'); return; }
    if (!supabase) { setNotice('Configure o Supabase para recuperar o acesso.'); return; }
    setNotice(''); setLoading(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email.data, { redirectTo: Linking.createURL('/reset-password') });
    setLoading(false);
    setNotice(error ? 'Não foi possível solicitar a recuperação. Tente novamente.' : 'Se o e-mail estiver cadastrado, você receberá as instruções.');
  };
  return <Screen><Surface><View style={{ gap: space.xs }}><Text style={[styles.title, { color: colors.textPrimary }]}>Bem-vindo de volta</Text><Text style={[styles.body, { color: colors.textSecondary }]}>Entre para acessar seu espaço no Padua Training.</Text></View>
    <Controller control={control} name="email" render={({ field: { onChange, value } }) => <Field label="E-mail" value={value} onChangeText={onChange} error={errors.email?.message} keyboardType="email-address" />} />
    <Controller control={control} name="password" render={({ field: { onChange, value } }) => <Field label="Senha" value={value} onChangeText={onChange} error={errors.password?.message} secureTextEntry />} />
    <Button disabled={loading} onPress={handleSubmit(signIn)}>{loading ? 'Entrando…' : 'Entrar'}</Button>
    {notice ? <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.textSecondary }]}>{notice}</Text> : null}
    <Button variant="secondary" disabled={loading} onPress={recover}>Esqueci minha senha</Button>
  </Surface></Screen>;
}
function Field(props: { label: string; value: string; onChangeText: (value: string) => void; error?: string; secureTextEntry?: boolean; keyboardType?: 'email-address' }) {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  return <View style={{ gap: space.xs }}><Text style={[styles.label, { color: colors.textPrimary }]}>{props.label}</Text><TextInput accessibilityLabel={props.label} value={props.value} onChangeText={props.onChangeText} secureTextEntry={props.secureTextEntry} keyboardType={props.keyboardType} autoCapitalize="none" style={[styles.input, { color: colors.textPrimary, borderColor: props.error ? colors.danger : colors.border, backgroundColor: colors.surfaceElevated }]} />{props.error ? <Text style={[styles.error, { color: colors.danger }]}>{props.error}</Text> : null}</View>;
}
const styles = StyleSheet.create({ title: { fontFamily: 'Lato_900Black', fontSize: 28, letterSpacing: -0.4 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 23 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15 }, input: { minHeight: 48, borderRadius: 12, borderWidth: 1, paddingHorizontal: 14, fontFamily: 'Lato_400Regular', fontSize: 16 }, error: { fontFamily: 'Lato_400Regular', fontSize: 13 } });
