import { Link } from 'expo-router';
import { StyleSheet, Text, useColorScheme, View } from 'react-native';
import { Button, Screen, Surface } from '@/components/ui';
import { palette, space } from '@/lib/theme';

export default function Welcome() {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  return <Screen><Surface>
    <View style={{ gap: space.xs }}><Text style={[styles.title, { color: colors.textPrimary }]}>Seu treino, no seu ritmo.</Text><Text style={[styles.body, { color: colors.textSecondary }]}>Acompanhe sua jornada com clareza, privacidade e orientação do seu trainer.</Text></View>
    <Link href="/sign-in" asChild><Button>Entrar na minha conta</Button></Link>
    <Link href="/pending" asChild><Button variant="secondary">Entender meu acesso</Button></Link>
    <Text style={[styles.note, { color: colors.textSecondary }]}>Ambiente de demonstração — nenhum dado clínico é exibido.</Text>
  </Surface></Screen>;
}
const styles = StyleSheet.create({ title: { fontFamily: 'Lato_900Black', fontSize: 34, letterSpacing: -0.7, lineHeight: 39 }, body: { fontFamily: 'Lato_400Regular', fontSize: 17, lineHeight: 25 }, note: { fontFamily: 'Lato_400Regular', fontSize: 13, lineHeight: 18 } });
