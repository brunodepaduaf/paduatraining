import { PropsWithChildren } from 'react';
import { Pressable, StyleSheet, Text, View, useColorScheme } from 'react-native';
import { palette, radius, space } from '@/lib/theme';

type ButtonProps = PropsWithChildren<{ onPress?: () => void; variant?: 'primary' | 'secondary'; disabled?: boolean; selected?: boolean }>;

export function Screen({ children }: PropsWithChildren) {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  return <View style={[styles.screen, { backgroundColor: colors.background }]}>{children}</View>;
}

export function Button({ children, onPress, variant = 'primary', disabled, selected }: ButtonProps) {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  const secondary = variant === 'secondary';
  return <Pressable accessibilityRole="button" accessibilityState={{ disabled, selected }} disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.button, { backgroundColor: secondary ? colors.surfaceElevated : colors.brand, borderColor: colors.border, opacity: disabled ? .5 : pressed ? .85 : 1 }, secondary && styles.secondary]}>
    <Text style={[styles.buttonText, { color: secondary ? colors.textPrimary : '#FFF8FB' }]}>{children}</Text>
  </Pressable>;
}

export function Surface({ children }: PropsWithChildren) {
  const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
  return <View style={[styles.surface, { backgroundColor: colors.surface, borderColor: colors.border }]}>{children}</View>;
}

const styles = StyleSheet.create({
  screen: { flex: 1, justifyContent: 'center', padding: space.lg },
  surface: { borderWidth: 1, borderRadius: radius.surface, padding: space.lg, gap: space.md, maxWidth: 480, width: '100%', alignSelf: 'center' },
  button: { minHeight: 48, paddingHorizontal: space.md, borderRadius: radius.control, justifyContent: 'center', alignItems: 'center' },
  secondary: { borderWidth: 1 }, buttonText: { fontFamily: 'Lato_700Bold', fontSize: 16 }
});
