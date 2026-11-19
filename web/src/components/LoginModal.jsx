import React, { useState, useEffect, useRef } from 'react';
import { X, LogOut, Search, CheckCircle2, AlertCircle, Settings2 } from 'lucide-react';
import {
  shcLogin,
  shcRegister,
  shcLogout,
  shcUid,
  shcDeviceUid,
  shcClaimDevice,
  shcFindOwnDevice,
  shcDiscoverDevice,
  shcCustomConfig,
  shcSaveCustomConfig,
  getCleanFbUrl
} from '../auth';

export default function LoginModal({ isOpen, onClose, onAuthChanged }) {
  const dialogRef = useRef(null);
  const [tab, setTab] = useState('login'); // 'login' | 'register'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [claimCode, setClaimCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const [userEmail, setUserEmail] = useState('');
  const [uid, setUid] = useState('');
  const [deviceUid, setDeviceUid] = useState('');

  const [showCustomCfg, setShowCustomCfg] = useState(false);
  const [customUrl, setCustomUrl] = useState('');
  const [customKey, setCustomKey] = useState('');

  const refreshUser = () => {
    setUserEmail(localStorage.getItem('shc_auth_email') || '');
    setUid(shcUid());
    setDeviceUid(shcDeviceUid());
    const cfg = shcCustomConfig();
    setCustomUrl(cfg.fbUrl);
    setCustomKey(cfg.apiKey);
  };

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (isOpen) {
      refreshUser();
      setErrorMsg('');
      setSuccessMsg('');
      if (!dialog.open) {
        dialog.showModal();
      }
    } else if (dialog.open) {
      dialog.close();
    }
  }, [isOpen]);

  // Fallback light-dismiss untuk browser yang belum mendukung atribut closedby="any"
  const handleBackdropPointerDown = (e) => {
    const dialog = dialogRef.current;
    if (!dialog || e.target !== dialog) return;
    const rect = dialog.getBoundingClientRect();
    const clickedOutside =
      e.clientX < rect.left ||
      e.clientX > rect.right ||
      e.clientY < rect.top ||
      e.clientY > rect.bottom;
    if (clickedOutside) {
      dialog.close('light-dismiss');
    }
  };

  const handleDialogClose = () => {
    if (isOpen && onClose) onClose();
  };

  const handleSaveCustomProject = (e) => {
    e.preventDefault();
    shcSaveCustomConfig(customUrl, customKey);
    setSuccessMsg('Konfigurasi proyek Firebase disimpan.');
  };

  const handleAuth = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');
    setLoading(true);
    try {
      if (tab === 'login') {
        const user = await shcLogin(email, password);
        await shcDiscoverDevice(getCleanFbUrl());
        setSuccessMsg(`Berhasil masuk sebagai ${user.email}`);
      } else {
        const user = await shcRegister(email, password);
        setSuccessMsg(`Akun berhasil dibuat untuk ${user.email}`);
      }
      refreshUser();
      if (onAuthChanged) onAuthChanged();
    } catch (err) {
      setErrorMsg(err.message || 'Gagal autentikasi.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    shcLogout();
    refreshUser();
    setSuccessMsg('Berhasil keluar akun.');
    if (onAuthChanged) onAuthChanged();
  };

  const handleClaim = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');
    setLoading(true);
    try {
      const base = getCleanFbUrl();
      const claimed = await shcClaimDevice(base, claimCode);
      setSuccessMsg(`Alat berhasil ditautkan (${claimed.slice(0, 8)}...)`);
      setClaimCode('');
      refreshUser();
      if (onAuthChanged) onAuthChanged();
    } catch (err) {
      setErrorMsg(err.message || 'Gagal menautkan kode alat.');
    } finally {
      setLoading(false);
    }
  };

  const handleAutoFind = async () => {
    setErrorMsg('');
    setSuccessMsg('');
    setLoading(true);
    try {
      const base = getCleanFbUrl();
      const linked = await shcDiscoverDevice(base);
      if (linked) {
        refreshUser();
        setSuccessMsg(`Tautan alat ditemukan otomatis (${linked.slice(0, 8)}...).`);
        if (onAuthChanged) onAuthChanged();
        return;
      }
      const code = await shcFindOwnDevice(base);
      if (!code) {
        setErrorMsg('Belum ada kode tersimpan untuk akun ini. Masukkan kode 8 karakter alat.');
      } else {
        setClaimCode(code);
        setSuccessMsg(`Kode alat ditemukan: ${code}. Tekan Tautkan.`);
      }
    } catch (err) {
      setErrorMsg(err.message || 'Gagal mencari kode alat.');
    } finally {
      setLoading(false);
    }
  };

  const isLoggedIn = !!userEmail && !!uid;

  return (
    <dialog
      ref={dialogRef}
      closedby="any"
      onClose={handleDialogClose}
      onPointerDown={handleBackdropPointerDown}
      aria-labelledby="auth-dialog-title"
      className="rounded-2xl border border-slate-200 bg-white text-slate-900 shadow-soft p-0 overflow-y-auto"
    >
      <div className="flex items-center justify-between px-5 py-4 border-b border-slate-200">
        <div>
          <h2 id="auth-dialog-title" className="font-display text-base font-bold text-slate-900 tracking-tight">
            Akun & Perangkat Coaster
          </h2>
          <p className="text-xs text-slate-600 mt-0.5">
            Sinkronisasi Firebase Cloud & penautan tatakan ESP32
          </p>
        </div>
        <button
          type="button"
          onClick={() => dialogRef.current?.close()}
          aria-label="Tutup dialog akun"
          className="p-1.5 rounded-lg text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
        >
          <X className="w-4 h-4" aria-hidden="true" />
        </button>
      </div>

      <div className="p-5 space-y-4">
        {errorMsg && (
          <div
            className="flex items-start gap-2 p-3 rounded-xl bg-rose-50 border border-rose-300 text-xs text-rose-900"
            role="alert"
          >
            <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-rose-700" aria-hidden="true" />
            <span>{errorMsg}</span>
          </div>
        )}

        {successMsg && (
          <div
            className="flex items-start gap-2 p-3 rounded-xl bg-emerald-50 border border-emerald-300 text-xs text-emerald-900"
            role="status"
          >
            <CheckCircle2 className="w-4 h-4 flex-shrink-0 mt-0.5 text-emerald-700" aria-hidden="true" />
            <span>{successMsg}</span>
          </div>
        )}

        {isLoggedIn ? (
          <div className="space-y-4">
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2 text-xs">
              <div className="flex justify-between items-center gap-2">
                <span className="text-slate-600">Email akun</span>
                <span className="font-semibold text-slate-900 truncate">{userEmail}</span>
              </div>
              <div className="flex justify-between items-center gap-2">
                <span className="text-slate-600">UID akun</span>
                <span className="font-mono text-slate-700 truncate max-w-[180px]">{uid}</span>
              </div>
              <div className="flex justify-between items-center gap-2">
                <span className="text-slate-600">Status alat</span>
                <span className="font-mono font-semibold text-water-800">
                  {deviceUid ? `Tertaut (${deviceUid.slice(0, 8)}...)` : 'Memakai node akun'}
                </span>
              </div>
            </div>

            <form onSubmit={handleClaim} className="space-y-3 pt-2 border-t border-slate-200">
              <label htmlFor="claimCodeIn" className="text-xs font-semibold text-slate-800 block">
                Tautkan kode alat 8 karakter
              </label>
              <div className="flex gap-2">
                <input
                  id="claimCodeIn"
                  type="text"
                  maxLength={8}
                  placeholder="Contoh: AB23CD45"
                  value={claimCode}
                  onChange={(e) => setClaimCode(e.target.value.toUpperCase())}
                  className="flex-1 px-3 py-2 rounded-xl border border-slate-300 text-xs font-mono uppercase tracking-wider text-slate-900"
                />
                <button
                  type="submit"
                  disabled={loading || claimCode.trim().length !== 8}
                  className="px-4 py-2 rounded-xl bg-water-700 hover:bg-water-800 disabled:opacity-50 text-white text-xs font-semibold transition-colors whitespace-nowrap"
                >
                  Tautkan
                </button>
              </div>
              <button
                type="button"
                onClick={handleAutoFind}
                disabled={loading}
                className="w-full flex items-center justify-center gap-1.5 py-2 rounded-xl border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-xs font-semibold transition-colors"
              >
                <Search className="w-3.5 h-3.5" aria-hidden="true" />
                <span>Temukan Alat Otomatis</span>
              </button>
            </form>

            <div className="pt-2 border-t border-slate-200">
              <button
                type="button"
                onClick={handleLogout}
                className="w-full flex items-center justify-center gap-1.5 py-2 rounded-xl border border-rose-300 bg-white hover:bg-rose-50 text-rose-800 text-xs font-semibold transition-colors"
              >
                <LogOut className="w-3.5 h-3.5" aria-hidden="true" />
                <span>Keluar dari Akun</span>
              </button>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="grid grid-cols-2 p-1 bg-slate-100 rounded-xl border border-slate-200 text-xs font-medium">
              <button
                type="button"
                aria-pressed={tab === 'login'}
                onClick={() => setTab('login')}
                className={`py-1.5 rounded-lg transition-colors ${
                  tab === 'login'
                    ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                    : 'text-slate-700 hover:text-slate-900'
                }`}
              >
                Masuk Akun
              </button>
              <button
                type="button"
                aria-pressed={tab === 'register'}
                onClick={() => setTab('register')}
                className={`py-1.5 rounded-lg transition-colors ${
                  tab === 'register'
                    ? 'bg-white text-slate-900 font-semibold shadow-sm border border-slate-200/80'
                    : 'text-slate-700 hover:text-slate-900'
                }`}
              >
                Daftar Baru
              </button>
            </div>

            <form onSubmit={handleAuth} className="space-y-3">
              <div>
                <label htmlFor="authEmailInput" className="text-xs font-semibold text-slate-800 block mb-1">
                  Alamat email
                </label>
                <input
                  id="authEmailInput"
                  type="email"
                  required
                  autoComplete="email"
                  placeholder="nama@email.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs text-slate-900"
                />
              </div>

              <div>
                <label htmlFor="authPassInput" className="text-xs font-semibold text-slate-800 block mb-1">
                  Kata sandi
                </label>
                <input
                  id="authPassInput"
                  type="password"
                  required
                  minLength={6}
                  autoComplete={tab === 'login' ? 'current-password' : 'new-password'}
                  placeholder="Minimal 6 karakter"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs text-slate-900"
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full py-2.5 rounded-xl bg-water-700 hover:bg-water-800 disabled:opacity-50 text-white text-xs font-semibold transition-colors"
              >
                {loading
                  ? 'Memproses...'
                  : tab === 'login'
                    ? 'Masuk ke Firebase Cloud'
                    : 'Buat Akun Baru'}
              </button>
            </form>
          </div>
        )}

        {/* Opsi Proyek Firebase Kustom */}
        <div className="pt-3 border-t border-slate-200">
          <button
            type="button"
            onClick={() => setShowCustomCfg((v) => !v)}
            aria-expanded={showCustomCfg}
            className="w-full flex items-center justify-between text-xs font-medium text-slate-600 hover:text-slate-900 py-1"
          >
            <span className="inline-flex items-center gap-1.5">
              <Settings2 className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Pengaturan proyek Firebase kustom</span>
            </span>
            <span>{showCustomCfg ? 'Sembunyikan' : 'Ubah'}</span>
          </button>

          {showCustomCfg && (
            <form onSubmit={handleSaveCustomProject} className="mt-2.5 space-y-2.5 p-3 rounded-xl bg-slate-50 border border-slate-200">
              <div>
                <label htmlFor="customFbUrl" className="text-[11px] font-semibold text-slate-700 block mb-1">
                  URL Realtime Database (kosongkan untuk default)
                </label>
                <input
                  id="customFbUrl"
                  type="url"
                  placeholder="https://proyek-anda.firebasedatabase.app"
                  value={customUrl}
                  onChange={(e) => setCustomUrl(e.target.value)}
                  className="w-full px-2.5 py-1.5 rounded-lg border border-slate-300 text-xs font-mono text-slate-900 bg-white"
                />
              </div>
              <div>
                <label htmlFor="customApiKey" className="text-[11px] font-semibold text-slate-700 block mb-1">
                  Web API Key Firebase (kosongkan untuk default)
                </label>
                <input
                  id="customApiKey"
                  type="text"
                  placeholder="AIzaSy..."
                  value={customKey}
                  onChange={(e) => setCustomKey(e.target.value)}
                  className="w-full px-2.5 py-1.5 rounded-lg border border-slate-300 text-xs font-mono text-slate-900 bg-white"
                />
              </div>
              <button
                type="submit"
                className="w-full py-1.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-100 text-slate-800 text-xs font-semibold"
              >
                Simpan Konfigurasi Proyek
              </button>
            </form>
          )}
        </div>
      </div>
    </dialog>
  );
}
