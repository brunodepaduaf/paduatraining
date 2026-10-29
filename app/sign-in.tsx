import { useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Alert, StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { router } from 'expo-router';
import { Button, Screen, Surface } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { palette, space } from '@/lib/theme';

const schema = z.object({ email: z.string().email('Informe um e-mail válido.'), password: z.string().min(8, 'A senha deve ter pelo menos 8 caracteres.') });
type Form = z.infer<typeof schema>;

export default function SignIn() {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  const { control, handleSubmit, formState: { errors } } = useForm<Form>({ resolver: zodResolver(schema), defaultValues: { email: '', password: '' } });
  const [loading, setLoading] = useState(false);
  const signIn = async (values: Form) => {
    if (!supabase) return Alert.alert('Configuração pendente', 'Adicione as chaves públicas do Supabase ao arquivo .env.');
    setLoading(true); const { error } = await supabase.auth.signInWithPassword(values); setLoading(false);
    if (error) return Alert.alert('Não foi possível entrar', 'Confira seus dados ou tente novamente.');
    router.replace('/pending');
  };
  return <Screen><Surface><View style={{ gap: space.xs }}><Text style={[styles.title, { color: colors.textPrimary }]}>Bem-vindo de volta</Text><Text style={[styles.body, { color: colors.textSecondary }]}>Entre para acessar seu espaço no Padua Training.</Text></View>
    <Controller control={control} name="email" render={({ field: { onChange, value } }) => <Field label="E-mail" value={value} onChangeText={onChange} error={errors.email?.message} keyboardType="email-address" />} />
    <Controller control={control} name="password" render={({ field: { onChange, value } }) => <Field label="Senha" value={value} onChangeText={onChange} error={errors.password?.message} secureTextEntry />} />
    <Button disabled={loading} onPress={handleSubmit(signIn)}>{loading ? 'Entrando…' : 'Entrar'}</Button>
    <Button variant="secondary" onPress={() => Alert.alert('Recuperar senha', 'Se o e-mail estiver cadastrado, enviaremos as instruções para ele.')}>Esqueci minha senha</Button>
  </Surface></Screen>;
}
function Field(props: { label: string; value: string; onChangeText: (value: string) => void; error?: string; secureTextEntry?: boolean; keyboardType?: 'email-address' }) {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  return <View style={{ gap: space.xs }}><Text style={[styles.label, { color: colors.textPrimary }]}>{props.label}</Text><TextInput accessibilityLabel={props.label} value={props.value} onChangeText={props.onChangeText} secureTextEntry={props.secureTextEntry} keyboardType={props.keyboardType} autoCapitalize="none" style={[styles.input, { color: colors.textPrimary, borderColor: props.error ? colors.danger : colors.border, backgroundColor: colors.surfaceElevated }]} />{props.error ? <Text style={[styles.error, { color: colors.danger }]}>{props.error}</Text> : null}</View>;
}
const styles = StyleSheet.create({ title: { fontFamily: 'Lato_900Black', fontSize: 28, letterSpacing: -0.4 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 23 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15 }, input: { minHeight: 48, borderRadius: 12, borderWidth: 1, paddingHorizontal: 14, fontFamily: 'Lato_400Regular', fontSize: 16 }, error: { fontFamily: 'Lato_400Regular', fontSize: 13 } });
