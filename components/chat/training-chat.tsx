import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Platform, StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { Button } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { palette } from '@/lib/theme';

type Contact = { person_id: string; full_name: string };
type Message = { id: string; sender_id: string; body: string; created_at: string };
export function TrainingChat({ org, user, onDraftChange }: { org: string; user: string; onDraftChange: (dirty: boolean) => void }) {
 const colors = palette[useColorScheme() === 'dark' ? 'dark' : 'light'];
 const requestRef = useRef(0); const [contacts, setContacts] = useState<Contact[]>([]); const [selected, setSelected] = useState<Contact | null>(null);
 const [messages, setMessages] = useState<Message[]>([]); const [draft, setDraft] = useState(''); const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState('');
 const loadContacts = useCallback(async () => { setLoading(true); setError(''); const r = await supabase!.rpc('get_training_chat_contacts', { target_organization: org }); if (r.error) setError('Não foi possível carregar seus contatos. Tente novamente.'); else setContacts(r.data as Contact[]); setLoading(false); }, [org]);
 useEffect(() => { void loadContacts(); }, [loadContacts]);
 const read = async (contact: Contact) => { const request = ++requestRef.current; setSelected(contact); setMessages([]); setBusy(true); setError(''); const r = await supabase!.rpc('get_training_chat_messages', { target_organization: org, other_person: contact.person_id }); if (request !== requestRef.current) return; setBusy(false); if (r.error) { setError('Não foi possível carregar as mensagens. O vínculo ou o acesso pode ter mudado.'); return; } setMessages(r.data as Message[]); };
 const send = async () => { if (!selected) return; const body = draft.trim(); if (!body || body.length > 2000) { setError('Escreva uma mensagem de até 2.000 caracteres.'); return; } setBusy(true); setError(''); const r = await supabase!.rpc('send_training_chat_message', { target_organization: org, other_person: selected.person_id, message_text: body }); setBusy(false); if (r.error) { setError('Não foi possível enviar. Confira sua conexão e tente novamente.'); return; } setDraft(''); onDraftChange(false); await read(selected); };
 const leave = () => { const exit = () => { requestRef.current++; setSelected(null); setMessages([]); setDraft(''); onDraftChange(false); setError(''); setBusy(false); }; if (!draft.trim()) return exit(); if (Platform.OS === 'web') { if (globalThis.confirm('Descartar a mensagem ainda não enviada?')) exit(); } else Alert.alert('Mensagem não enviada', 'Descartar o texto e voltar aos contatos?', [{ text: 'Continuar escrevendo', style: 'cancel' }, { text: 'Descartar', style: 'destructive', onPress: exit }]); };
 return <>
  <Text accessibilityRole="header" style={[styles.heading, { color: colors.textPrimary }]}>{selected ? selected.full_name || 'Contato' : 'Mensagens'}</Text>
  <Text style={[styles.body, { color: colors.textSecondary }]}>{selected ? 'Últimas 100 mensagens. Atualize para ver novas respostas.' : 'Converse com seus contatos de treino autorizados.'}</Text>
  {loading || busy ? <ActivityIndicator accessibilityLabel="Carregando mensagens" /> : null}{error ? <Text style={[styles.body, { color: colors.danger }]}>{error}</Text> : null}
  {!selected ? <>{!loading && !error && contacts.length === 0 ? <Text style={[styles.body, { color: colors.textSecondary }]}>Nenhum contato disponível no momento.</Text> : null}{contacts.map(contact => <Button key={contact.person_id} variant="secondary" disabled={busy} onPress={() => void read(contact)}>{contact.full_name || 'Contato'}</Button>)}{error ? <Button variant="secondary" disabled={loading} onPress={loadContacts}>Tentar novamente</Button> : null}</> : <>
   {!busy && !messages.length && !error ? <Text style={[styles.body, { color: colors.textSecondary }]}>Ainda não há mensagens nesta conversa.</Text> : null}
   {messages.map(message => <View key={message.id} style={styles.message}><Text style={[styles.label, { color: colors.textPrimary }]}>{message.sender_id === user ? 'Você' : selected.full_name || 'Contato'}</Text><Text style={[styles.body, { color: colors.textPrimary }]}>{message.body}</Text><Text style={[styles.date, { color: colors.textSecondary }]}>{new Date(message.created_at).toLocaleString('pt-BR')}</Text></View>)}
   <View style={styles.field}><Text style={[styles.label, { color: colors.textPrimary }]}>Mensagem</Text><TextInput accessibilityLabel="Mensagem" editable={!busy} multiline maxLength={2000} value={draft} onChangeText={value => { setDraft(value); onDraftChange(!!value.trim()); }} style={[styles.input, { color: colors.textPrimary, backgroundColor: colors.surfaceElevated, borderColor: colors.border }]} /></View>
   <Button disabled={busy} onPress={() => void send()}>Enviar mensagem</Button><Button variant="secondary" disabled={busy} onPress={() => void read(selected)}>Atualizar mensagens</Button><Button variant="secondary" disabled={busy} onPress={leave}>Voltar aos contatos</Button>
  </>}
 </>;
}
const styles = StyleSheet.create({ heading: { fontFamily: 'Lato_900Black', fontSize: 28, lineHeight: 34 }, body: { fontFamily: 'Lato_400Regular', fontSize: 16, lineHeight: 24 }, label: { fontFamily: 'Lato_700Bold', fontSize: 15, lineHeight: 22 }, date: { fontFamily: 'Lato_400Regular', fontSize: 13, lineHeight: 18 }, field: { gap: 8 }, input: { minHeight: 48, borderRadius: 12, borderWidth: 1, padding: 12, fontFamily: 'Lato_400Regular', fontSize: 16 }, message: { gap: 4, paddingVertical: 12 } });
