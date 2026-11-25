// Nilai default klien (bukan rahasia; akses dijaga Firebase Rules).
// Override build: flutter build apk --dart-define=FB_URL=... --dart-define=FB_API_KEY=...
const String kFirebaseUrl = String.fromEnvironment(
  'FB_URL',
  defaultValue: 'https://smart-coaster-64880-default-rtdb.asia-southeast1.firebasedatabase.app',
);

const String kFirebaseApiKey = String.fromEnvironment(
  'FB_API_KEY',
  defaultValue: 'AIzaSyAsJOK540P20E2KeOyB2BdXQj3dOARfyLA',
);
