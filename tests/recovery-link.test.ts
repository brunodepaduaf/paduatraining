import { describe, expect, it } from 'vitest';
import { recoveryTokens } from '../lib/recovery-link';

describe('link de recuperação', () => {
  it('aceita somente o retorno de recuperação com os dois tokens', () => {
    expect(recoveryTokens('paduatraining://reset-password#access_token=sintetico&refresh_token=renovacao&type=recovery')).toEqual({ access_token: 'sintetico', refresh_token: 'renovacao' });
    expect(recoveryTokens('paduatraining:///reset-password#access_token=sintetico&refresh_token=renovacao&type=recovery')).toEqual({ access_token: 'sintetico', refresh_token: 'renovacao' });
    expect(recoveryTokens('exp://127.0.0.1:8081/--/reset-password#access_token=sintetico&refresh_token=renovacao&type=recovery')).toEqual({ access_token: 'sintetico', refresh_token: 'renovacao' });
    expect(recoveryTokens('paduatraining://reset-password#access_token=sintetico&type=recovery')).toBeNull();
    expect(recoveryTokens('paduatraining://reset-password#access_token=sintetico&refresh_token=renovacao&type=signup')).toBeNull();
    expect(recoveryTokens('paduatraining://other#access_token=sintetico&refresh_token=renovacao&type=recovery')).toBeNull();
    expect(recoveryTokens('https://exemplo.invalid/reset-password#access_token=sintetico&refresh_token=renovacao&type=recovery')).toBeNull();
    expect(recoveryTokens('não é uma URL')).toBeNull();
  });
});
