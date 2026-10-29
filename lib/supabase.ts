import 'react-native-url-polyfill/auto';
import * as SecureStore from 'expo-secure-store';
import { createClient } from '@supabase/supabase-js';
import { Platform } from 'react-native';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

const storage = Platform.OS === 'web'
  ? undefined
  : { getItem: (key: string) => SecureStore.getItemAsync(key), setItem: (key: string, value: string) => SecureStore.setItemAsync(key, value), removeItem: (key: string) => SecureStore.deleteItemAsync(key) };

// The client intentionally uses only the public anon key. Server authority belongs to RLS.
export const supabase = url && key ? createClient(url, key, { auth: { storage, autoRefreshToken: true, persistSession: true, detectSessionInUrl: Platform.OS === 'web' } }) : null;
