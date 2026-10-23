// Login Firebase (Email/Password) lewat REST, tanpa SDK. Token dan UID disimpan di
// localStorage, lalu request RTDB memakai ?auth=... ke path /users/<uid>/smart_coaster.
// Tiap akun hanya bisa menyentuh node miliknya sendiri; itu yang dijaga rules.
// ponytail: token disimpan apa adanya di localStorage. Kalau nanti perlu tahan XSS,
// pindah ke httpOnly cookie lewat proxy sendiri. Untuk PWA statis ini cukup.
const SHC_AUTH_KEY = 'shc_id_token';
const SHC_EMAIL_KEY = 'shc_auth_email';
const SHC_UID_KEY = 'shc_uid';
const SHC_REFRESH_KEY = 'shc_refresh_token';

const SHC_AUTH_ERRORS = {
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

function shcToken(){
  const raw = localStorage.getItem(SHC_AUTH_KEY);
  if (!raw) return '';
  try {
    const o = JSON.parse(raw);
    if (!o.token) return '';
    if (!o.exp || Date.now() > o.exp - 300000) return '';
    return o.token;
  } catch(_){ return ''; }
}

function shcAuthSuffix(){
  const t = shcToken();
  return t ? '?auth=' + encodeURIComponent(t) : '';
}

function shcUid(){
  return localStorage.getItem(SHC_UID_KEY) || '';
}

// Basis node milik user yang sedang masuk. Kosong berarti belum login atau UID hilang,
// dan pemanggil wajib berhenti: menulis ke path kosong akan ditolak rules.
function shcCoasterUrl(base){
  const uid = shcUid();
  if (!uid) return '';
  return base + '/users/' + encodeURIComponent(uid) + '/smart_coaster';
}

function shcApiKey(){
  return (localStorage.getItem('shc_api_key') || '').trim();
}

async function shcAuth(mode, email, password){
  const key = shcApiKey();
  if (!key) throw new Error('Isi API key proyek Firebase dulu.');
  const action = mode === 'signUp' ? 'accounts:signUp' : 'accounts:signInWithPassword';
  const res = await fetch(
    'https://identitytoolkit.googleapis.com/v1/' + action + '?key=' + encodeURIComponent(key),
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: email.trim(), password, returnSecureToken: true }) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = (data && data.error && data.error.message) || ('HTTP ' + res.status);
    throw new Error(SHC_AUTH_ERRORS[code] || code);
  }
  if (!data.localId) throw new Error('Respons Firebase tidak memuat UID.');
  localStorage.setItem(SHC_AUTH_KEY, JSON.stringify({
    token: data.idToken,
    exp: Date.now() + (parseInt(data.expiresIn, 10) || 3600) * 1000
  }));
  localStorage.setItem(SHC_EMAIL_KEY, data.email || email.trim());
  localStorage.setItem(SHC_UID_KEY, data.localId);
  if (data.refreshToken) localStorage.setItem(SHC_REFRESH_KEY, data.refreshToken);
  return { email: data.email || email.trim(), uid: data.localId };
}

function shcLogin(email, password){ return shcAuth('signIn', email, password); }
function shcRegister(email, password){ return shcAuth('signUp', email, password); }

// ID token berlaku satu jam. Daripada minta password lagi, tukar refreshToken yang
// disimpan saat login. Return true kalau sekarang ada token yang masih berlaku.
async function shcEnsureToken(){
  if (shcToken()) return true;
  const rt = localStorage.getItem(SHC_REFRESH_KEY) || '';
  const key = shcApiKey();
  if (!rt || !key) return false;
  try {
    const res = await fetch(
      'https://securetoken.googleapis.com/v1/token?key=' + encodeURIComponent(key),
      { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'grant_type=refresh_token&refresh_token=' + encodeURIComponent(rt) });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.id_token) return false;
    localStorage.setItem(SHC_AUTH_KEY, JSON.stringify({
      token: data.id_token,
      exp: Date.now() + (parseInt(data.expires_in, 10) || 3600) * 1000
    }));
    if (data.refresh_token) localStorage.setItem(SHC_REFRESH_KEY, data.refresh_token);
    return true;
  } catch(_){ return false; }
}

function shcLogout(){
  localStorage.removeItem(SHC_AUTH_KEY);
  localStorage.removeItem(SHC_EMAIL_KEY);
  localStorage.removeItem(SHC_UID_KEY);
  localStorage.removeItem(SHC_REFRESH_KEY);
}
