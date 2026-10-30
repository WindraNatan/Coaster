// Tetapan proyek Firebase, ditanam di build.
//
// Tujuannya supaya pengguna cukup mengetik email dan password. Dua nilai ini
// bukan rahasia: URL Realtime Database dan Web API Key memang dirancang untuk
// dipasang di aplikasi klien. Yang menjaga data adalah Firebase Rules, bukan
// kerahasiaan dua nilai ini.
//
// Ganti lewat build tanpa mengubah kode:
//   flutter build apk --dart-define=FB_URL=https://... --dart-define=FB_API_KEY=AIza...
const String kFirebaseUrl = String.fromEnvironment(
  'FB_URL',
  defaultValue: 'https://smart-coaster-64880-default-rtdb.asia-southeast1.firebasedatabase.app',
);

const String kFirebaseApiKey = String.fromEnvironment(
  'FB_API_KEY',
  defaultValue: '',
);
