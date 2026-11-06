#ifndef SESSION_GATE_H
#define SESSION_GATE_H

// Siapa yang menentukan alat tidur: perintah lokal dari Serial (z = tidur,
// x = bangun) atau nilai session.json yang dibaca cloudTask tiap 10 detik.
//
// Kenapa perlu aturan: poll sesi membaca field yang sama, jadi perintah lokal
// akan dibatalkan poll berikutnya kalau nilainya dibiarkan menang. Aturannya,
// cloud hanya menimpa perintah lokal saat nilainya benar-benar BERUBAH, karena
// perubahan itulah tanda pengguna baru menekan tombol di klien. Selama nilainya
// diam, perintah lokal dari kabel yang berlaku.
//
// Dipisah dari cloud_sync.h supaya bisa diuji di PC: cloud_sync.h menarik
// WiFi.h/HTTPClient.h yang tidak ada di luar ESP32. Diuji tools/uji_fsm.
struct SessionGate {
    bool sleep = false;      // keadaan yang berlaku
    bool localHold = false;  // perintah lokal, belum dibatalkan cloud
    bool cloudLast = false;  // nilai session.json terakhir yang dibaca

    /// Perintah dari Serial: langsung berlaku dan mengunci nilai cloud yang diam.
    void local(bool s) {
        sleep = s;
        localHold = true;
    }

    /// Nilai session.json. Field "active" tidak ada di klien lama; ketiadaannya
    /// berarti sesi aktif, jadi pemanggil sudah memetakannya ke wantSleep=false.
    void fromCloud(bool wantSleep) {
        if (!localHold || wantSleep != cloudLast) {
            sleep = wantSleep;
            localHold = false;
        }
        cloudLast = wantSleep;
    }
};

#endif
