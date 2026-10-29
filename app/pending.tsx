import { Link } from 'expo-router';
import { StyleSheet, Text, useColorScheme, View } from 'react-native';
import { Button, Screen, Surface } from '@/components/ui';
import { palette, space } from '@/lib/theme';

export default function PendingAccess() {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  return <Screen><Surface><View style={{ gap: space.xs }}><Text style={[styles.title, { color: colors.textPrimary }]}>Seu acesso está sendo organizado</Text><Text style={[styles.body, { color: colors.textSecondary }]}>Quando seu trainer ou a equipe liberar o período de acesso, seus conteúdos aparecerão aqui.</Text></View><Text style={[styles.support, { color: colors.info }]}>Precisa de ajuda? Entre em contato com sua equipe de treino.</Text><Link href="/" asChild><Button variant="secondary">Voltar ao início</Button></Link></Surface></Screen>;
}
const styles = StyleSheet.create({ title: { fontFamily: 'Lato_900Black', fontSize: 28, letterSpacing: -0.4 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, support: { fontFamily: 'Lato_700Bold', fontSize: 15 } });
