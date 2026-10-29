/** Extract recovery tokens from a Supabase implicit-flow deep link. */
export function recoveryTokens(url: string): { access_token: string; refresh_token: string } | null {
  try {
    const parsed = new URL(url);
    const appLink = parsed.protocol === 'paduatraining:' && ((parsed.hostname === 'reset-password' && (parsed.pathname === '' || parsed.pathname === '/')) || (parsed.hostname === '' && parsed.pathname === '/reset-password'));
    const expoLink = (parsed.protocol === 'exp:' || parsed.protocol === 'exps:') && parsed.pathname.endsWith('/--/reset-password');
    if (!appLink && !expoLink) return null;
    const params = new URLSearchParams(parsed.hash.replace(/^#/, ''));
    if (params.get('type') !== 'recovery') return null;
    const access_token = params.get('access_token');
    const refresh_token = params.get('refresh_token');
    return access_token && refresh_token ? { access_token, refresh_token } : null;
  } catch { return null; }
}
