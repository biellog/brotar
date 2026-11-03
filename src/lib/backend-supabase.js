// Backend Supabase: toda regra roda no banco (RPCs SECURITY DEFINER). O cliente só pede.
import { createClient } from '@supabase/supabase-js';
import { GameError } from './backend-local.js';

export function makeSupabase(url, anonKey, storage) {
  return createClient(url, anonKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce', storage },
  });
}

export class SupabaseBackend {
  constructor(client) {
    this.sb = client;
    this.kind = 'supabase';
  }

  async call(fn, args) {
    const { data, error } = await this.sb.rpc(fn, args);
    if (error) throw new GameError(error.message || 'erro no servidor');
    return data;
  }

  getState() { return this.call('get_state'); }
  startJourney(since) { return this.call('start_journey', { since }); }
  updateProfile(name, motivation, tz) {
    return this.call('update_profile', { new_name: name, new_motivation: motivation, new_tz: tz });
  }
  checkin() { return this.call('daily_checkin'); }
  submitGame(score) { return this.call('submit_game_score', { score }); }
  claimAdReward() { return this.call('claim_ad_reward'); }
  buy(item) { return this.call('buy_item', { item }); }
  equipTheme(themeId) { return this.call('equip_theme', { theme_id: themeId }); }
  resetSobriety() { return this.call('reset_sobriety'); }
  async deleteAccount() {
    await this.call('delete_my_account');
    await this.sb.auth.signOut({ scope: 'local' });
  }
  async exportData() {
    const tables = ['profiles', 'points_ledger', 'user_items', 'milestones_claimed', 'daily_actions', 'relapses'];
    const out = {};
    for (const t of tables) {
      const { data, error } = await this.sb.from(t).select('*');
      if (error) throw new GameError(error.message);
      out[t] = data;
    }
    return out;
  }
}
