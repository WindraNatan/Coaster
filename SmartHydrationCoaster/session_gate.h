#ifndef SESSION_GATE_H
#define SESSION_GATE_H

// Menengahi mode istirahat antara Serial (z/x) dan session.json cloud.
// Cloud hanya menimpa perintah lokal saat nilainya berubah.
struct SessionGate {
    bool sleep = false;
    bool localHold = false;
    bool cloudLast = false;

    void local(bool s) {
        sleep = s;
        localHold = true;
    }

    /// Ketiadaan field "active" pada klien lama dipetakan ke wantSleep=false.
    void fromCloud(bool wantSleep) {
        if (!localHold || wantSleep != cloudLast) {
            sleep = wantSleep;
            localHold = false;
        }
        cloudLast = wantSleep;
    }
};

#endif
