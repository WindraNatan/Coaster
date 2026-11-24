const SHC_DEFAULT_URL = 'https://smart-coaster-64880-default-rtdb.asia-southeast1.firebasedatabase.app';
const SHC_DEFAULT_API_KEY = 'AIzaSyAsJOK540P20E2KeOyB2BdXQj3dOARfyLA';

export const SHC_AUTH_KEY = 'shc_id_token';
export const SHC_EMAIL_KEY = 'shc_auth_email';
export const SHC_UID_KEY = 'shc_uid';
export const SHC_REFRESH_KEY = 'shc_refresh_token';

export const SHC_AUTH_ERRORS = {
  EMAIL_NOT_FOUND: 'Email belum terdaftar.',
  INVALID_PASSWORD: 'Password salah.',
  INVALID_LOGIN_CREDENTIALS: 'Email atau password salah.',
  INVALID_EMAIL: 'Format email tidak valid.',
  USER_DISABLED: 'Akun ini dinonaktifkan.',
  EMAIL_EXISTS: 'Email ini sudah terdaftar. Pakai tombol Masuk.',
  WEAK_PASSWORD: 'Password minimal 6 karakter.',
  MISSING_PASSWORD: 'Password wajib diisi.',
  TOO_MANY_ATTEMPTS_TRY_LATER: 'Terlalu banyak percobaan. Coba lagi nanti.',
  CONFIGURATION_NOT_FOUND: 'API key salah atau Authentication belum diaktifkan.'
};

export function shcToken() {
  const raw = localStorage.getItem(SHC_AUTH_KEY);
  if (!raw) return '';
  try {
    const o = JSON.parse(raw);
    if (!o.token) return '';
    if (!o.exp || Date.now() > o.exp - 300000) return '';
    return o.token;
  } catch (_) {
    return '';
  }
}

export function shcAuthSuffix() {
  const t = shcToken();
  return t ? '?auth=' + encodeURIComponent(t) : '';
}

export function shcUid() {
  return localStorage.getItem(SHC_UID_KEY) || '';
}

export function shcDeviceUid() {
  return localStorage.getItem('shc_device_uid') || '';
}

export function shcCoasterUrl(base) {
  const uid = shcDeviceUid() || shcUid();
  if (!uid || !base) return '';
  return base + '/users/' + encodeURIComponent(uid) + '/smart_coaster';
}

export function shcApiKey() {
  return (localStorage.getItem('shc_api_key') || '').trim() || SHC_DEFAULT_API_KEY;
}

export function shcBaseUrl() {
  return (localStorage.getItem('shc_fb_url') || '').trim() || SHC_DEFAULT_URL;
}

export function shcCustomConfig() {
  return {
    fbUrl: localStorage.getItem('shc_fb_url') || '',
    apiKey: localStorage.getItem('shc_api_key') || ''
  };
}

export function shcSaveCustomConfig(fbUrl, apiKey) {
  const cleanUrl = (fbUrl || '').trim().replace(/\/+$/, '');
  const cleanKey = (apiKey || '').trim();
  if (cleanUrl) localStorage.setItem('shc_fb_url', cleanUrl);
  else localStorage.removeItem('shc_fb_url');
  if (cleanKey) localStorage.setItem('shc_api_key', cleanKey);
  else localStorage.removeItem('shc_api_key');
}

export function getCleanFbUrl() {
  let url = shcBaseUrl();
  while (url.endsWith('/')) url = url.slice(0, -1);
  return url;
}

export async function shcEnsureToken(force = false) {
  if (!force && shcToken()) return true;
  const rt = localStorage.getItem(SHC_REFRESH_KEY) || '';
  const key = shcApiKey();
  if (!rt || !key) return false;
  try {
    const res = await fetch(
      'https://securetoken.googleapis.com/v1/token?key=' + encodeURIComponent(key),
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'grant_type=refresh_token&refresh_token=' + encodeURIComponent(rt)
      }
    );
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.id_token) return false;
    localStorage.setItem(SHC_AUTH_KEY, JSON.stringify({
      token: data.id_token,
      exp: Date.now() + (parseInt(data.expires_in, 10) || 3600) * 1000
    }));
    if (data.refresh_token) localStorage.setItem(SHC_REFRESH_KEY, data.refresh_token);
    return true;
  } catch (_) {
    return false;
  }
}

export async function shcDiscoverDevice(base) {
  if (!(await shcEnsureToken())) return '';
  const uid = shcUid();
  if (!uid || !base) return '';
  try {
    const res = await fetch(
      base + '/links/' + encodeURIComponent(uid) + '.json' + shcAuthSuffix()
    );
    if (!res.ok) return '';
    const data = await res.json();
    if (!data || typeof data !== 'object') return '';
    let best = '';
    let bestAt = -1;
    Object.entries(data).forEach(([devUid, meta]) => {
      if (!devUid) return;
      const at = meta && typeof meta === 'object' && Number.isFinite(Number(meta.at))
        ? Number(meta.at)
        : 0;
      if (at >= bestAt) {
        bestAt = at;
        best = devUid;
      }
    });
    if (best) {
      localStorage.setItem('shc_device_uid', best);
    }
    return best;
  } catch (_) {
    return '';
  }
}

export async function shcAuth(mode, email, password) {
  const key = shcApiKey();
  if (!key) throw new Error('Isi kunci server terlebih dahulu.');
  const action = mode === 'signUp' ? 'accounts:signUp' : 'accounts:signInWithPassword';
  const res = await fetch(
    'https://identitytoolkit.googleapis.com/v1/' + action + '?key=' + encodeURIComponent(key),
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: email.trim(), password, returnSecureToken: true })
    }
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = (data && data.error && data.error.message) || ('HTTP ' + res.status);
    throw new Error(SHC_AUTH_ERRORS[code] || code);
  }
  if (!data.localId) throw new Error('Server belum mengirimkan identitas akun.');
  localStorage.setItem(SHC_AUTH_KEY, JSON.stringify({
    token: data.idToken,
    exp: Date.now() + (parseInt(data.expiresIn, 10) || 3600) * 1000
  }));
  localStorage.setItem(SHC_EMAIL_KEY, data.email || email.trim());
  localStorage.setItem(SHC_UID_KEY, data.localId);
  if (data.refreshToken) localStorage.setItem(SHC_REFRESH_KEY, data.refreshToken);
  return { email: data.email || email.trim(), uid: data.localId };
}

export function shcLogin(email, password) {
  return shcAuth('signIn', email, password);
}

export function shcRegister(email, password) {
  return shcAuth('signUp', email, password);
}

export function shcLogout() {
  localStorage.removeItem(SHC_AUTH_KEY);
  localStorage.removeItem(SHC_EMAIL_KEY);
  localStorage.removeItem(SHC_UID_KEY);
  localStorage.removeItem(SHC_REFRESH_KEY);
  localStorage.removeItem('shc_device_uid');
}

export async function shcClaimDevice(base, code) {
  if (!(await shcEnsureToken())) throw new Error('Sesi akun berakhir. Silakan masuk ulang.');
  const clean = (code || '').trim().toUpperCase();
  if (clean.length !== 8) throw new Error('Kode tatakan harus 8 karakter.');
  const res = await fetch(base + '/claims/' + encodeURIComponent(clean) + '.json' + shcAuthSuffix());
  if (!res.ok) throw new Error('Gagal memeriksa kode tatakan (HTTP ' + res.status + ').');
  const deviceUid = await res.json();
  if (!deviceUid || typeof deviceUid !== 'string') {
    throw new Error('Kode tatakan tidak ditemukan. Pastikan tatakan sudah tersambung ke Wi-Fi dan kode 8 karakter sudah benar.');
  }
  const put = await fetch(base + '/links/' + encodeURIComponent(shcUid()) + '/' +
      encodeURIComponent(deviceUid) + '.json' + shcAuthSuffix(), {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: clean, at: Date.now() })
  });
  if (!put.ok) throw new Error('Gagal menautkan tatakan (HTTP ' + put.status + ').');
  localStorage.setItem('shc_device_uid', deviceUid);
  return deviceUid;
}

export async function shcFindOwnDevice(base) {
  if (!(await shcEnsureToken())) throw new Error('Sesi akun berakhir. Silakan masuk ulang.');
  if (!shcUid()) throw new Error('Akun belum terbaca. Silakan masuk ulang.');
  const paths = [
    '/users/' + encodeURIComponent(shcUid()) + '/private/claimCode.json',
    '/users/' + encodeURIComponent(shcUid()) + '/smart_coaster/claimCode.json'
  ];
  for (const p of paths) {
    const res = await fetch(base + p + shcAuthSuffix());
    if (res.ok) {
      const value = await res.json();
      if (typeof value === 'string' && value.trim()) {
        return value.trim().toUpperCase();
      }
    }
  }
  return '';
}

export async function shcSetSession(base, ownerUid, active = true) {
  if (!(await shcEnsureToken())) return false;
  const url = shcCoasterUrl(base);
  if (!url || !shcToken()) return false;
  const res = await fetch(url + '/session.json' + shcAuthSuffix(), {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ owner: ownerUid || '', active: !!active, at: Date.now() })
  });
  return res.ok;
}
