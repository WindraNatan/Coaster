// Login Firebase (Email/Password) lewat REST, tanpa SDK. Token dan UID disimpan di
// localStorage, lalu request RTDB memakai ?auth=... ke path /users/<uid>/smart_coaster.
// Tiap akun hanya bisa menyentuh node miliknya sendiri; itu yang dijaga rules.
// ponytail: token disimpan apa adanya di localStorage. Kalau nanti perlu tahan XSS,
// pindah ke httpOnly cookie lewat proxy sendiri. Untuk PWA statis ini cukup.
// Tetapan proyek, ditanam di sini supaya pengguna hanya mengetik email dan
// password. Keduanya bukan rahasia: URL RTDB dan Web API Key memang dirancang
// untuk klien. Yang menjaga data adalah Firebase Rules.
// Ganti dengan menyunting dua baris ini; nilai tersimpan di localStorage
// (shc_fb_url / shc_api_key) tetap dipakai lebih dulu.
const SHC_DEFAULT_URL = 'https://smart-coaster-64880-default-rtdb.asia-southeast1.firebasedatabase.app';
const SHC_DEFAULT_API_KEY = '';

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

// Perangkat yang sedang dipakai akun ini. Kosong berarti belum ada tautan; pemanggil
// wajib berhenti daripada menulis ke node milik orang lain.
function shcDeviceUid(){
  return localStorage.getItem('shc_device_uid') || '';
}

function shcCoasterUrl(base){
  const uid = shcDeviceUid();
  if (!uid) return '';
  return base + '/users/' + encodeURIComponent(uid) + '/smart_coaster';
}

// Klaim kode alat: baca /claims/<kode>, lalu tulis tautan milik sendiri. Rules menolak
// tautan kalau kode tidak menunjuk ke perangkat yang dimaksud.
async function shcClaimDevice(base, code){
  if (!shcToken()) throw new Error('Masuk dulu sebelum mengklaim alat.');
  const clean = (code || '').trim().toUpperCase();
  if (clean.length !== 8) throw new Error('Kode alat harus 8 karakter.');
  const res = await fetch(base + '/claims/' + encodeURIComponent(clean) + '.json' + shcAuthSuffix());
  if (!res.ok) throw new Error('Gagal membaca kode (HTTP ' + res.status + ').');
  const deviceUid = await res.json();
  if (!deviceUid || typeof deviceUid !== 'string') throw new Error('Kode tidak dikenali. Cek lagi di layar alat.');
  const put = await fetch(base + '/links/' + encodeURIComponent(shcUid()) + '/' +
      encodeURIComponent(deviceUid) + '.json' + shcAuthSuffix(), {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: clean, at: Date.now() })
  });
  if (!put.ok) throw new Error('Gagal menautkan alat (HTTP ' + put.status + ').');
  localStorage.setItem('shc_device_uid', deviceUid);
  return deviceUid;
}

// Sesi bergiliran: menulis siapa yang sedang memakai. Perangkat membaca node ini dan
// me-reset statistiknya saat nilainya berubah.
async function shcSetSession(base, ownerUid){
  const url = shcCoasterUrl(base);
  if (!url || !shcToken()) return false;
  const res = await fetch(url + '/session.json' + shcAuthSuffix(), {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ owner: ownerUid || '', at: Date.now() })
  });
  return res.ok;
}

function shcApiKey(){
  return (localStorage.getItem('shc_api_key') || '').trim() || SHC_DEFAULT_API_KEY;
}

// URL database: isian pengguna menang, lalu tetapan di atas.
function shcBaseUrl(){
  return (localStorage.getItem('shc_fb_url') || '').trim() || SHC_DEFAULT_URL;
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
  localStorage.removeItem('shc_device_uid');
}
