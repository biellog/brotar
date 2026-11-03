// Integração AdMob (somente no app Android via Capacitor). No site, tudo vira no-op.
import { Capacitor } from '@capacitor/core';
import { ADMOB } from './config.js';

let admob = null;
let ready = false;

export const adsAvailable = () => Capacitor.isNativePlatform();

export async function initAds() {
  if (!adsAvailable() || ready) return ready;
  try {
    ({ AdMob: admob } = await import('@capacitor-community/admob'));
    await admob.initialize({ initializeForTesting: ADMOB.testing });
    // Consentimento (UMP) — exigido na UE/Reino Unido; inofensivo no Brasil.
    const info = await admob.requestConsentInfo();
    if (info.isConsentFormAvailable && info.status === 'REQUIRED') await admob.showConsentForm();
    ready = true;
  } catch (e) {
    console.warn('AdMob indisponível', e);
  }
  return ready;
}

export async function showBanner() {
  if (!(await initAds())) return;
  try {
    const { BannerAdPosition, BannerAdSize } = await import('@capacitor-community/admob');
    await admob.showBanner({
      adId: ADMOB.banner, adSize: BannerAdSize.ADAPTIVE_BANNER,
      position: BannerAdPosition.BOTTOM_CENTER, margin: 64, isTesting: ADMOB.testing,
    });
  } catch (e) { console.warn('banner', e); }
}

export async function hideBanner() {
  if (ready) try { await admob.hideBanner(); } catch { /* ignore */ }
}

/** Mostra anúncio premiado. Resolve true só se o usuário assistiu até o fim. */
export async function showRewarded() {
  if (!(await initAds())) return false;
  const { RewardAdPluginEvents } = await import('@capacitor-community/admob');
  return new Promise(async (resolve) => {
    let rewarded = false;
    const subs = [];
    const done = (v) => { subs.forEach((s) => s.remove?.()); resolve(v); };
    subs.push(await admob.addListener(RewardAdPluginEvents.Rewarded, () => { rewarded = true; }));
    subs.push(await admob.addListener(RewardAdPluginEvents.Dismissed, () => done(rewarded)));
    subs.push(await admob.addListener(RewardAdPluginEvents.FailedToShow, () => done(false)));
    subs.push(await admob.addListener(RewardAdPluginEvents.FailedToLoad, () => done(false)));
    try {
      await admob.prepareRewardVideoAd({ adId: ADMOB.rewarded, isTesting: ADMOB.testing });
      await admob.showRewardVideoAd();
    } catch { done(false); }
  });
}
