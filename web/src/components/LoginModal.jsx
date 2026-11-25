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
  const [tab, setTab] = useState('login');
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
    setSuccessMsg('Pengaturan server tersimpan.');
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
        setSuccessMsg(`Berhasil masuk sebagai ${user.email}.`);
      } else {
        const user = await shcRegister(email, password);
        setSuccessMsg(`Akun berhasil dibuat untuk ${user.email}.`);
      }
      refreshUser();
      if (onAuthChanged) onAuthChanged();
    } catch (err) {
      setErrorMsg(err.message || 'Gagal masuk ke akun.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    shcLogout();
    refreshUser();
    setSuccessMsg('Kamu telah keluar dari akun.');
    if (onAuthChanged) onAuthChanged();
  };

  const handleClaim = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');
    setLoading(true);
    try {
      const base = getCleanFbUrl();
      await shcClaimDevice(base, claimCode);
      setSuccessMsg('Tatakan berhasil ditautkan ke akunmu.');
      setClaimCode('');
      refreshUser();
      if (onAuthChanged) onAuthChanged();
    } catch (err) {
      setErrorMsg(err.message || 'Gagal menautkan tatakan.');
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
        setSuccessMsg('Tatakan yang sudah terdaftar berhasil ditemukan otomatis.');
        if (onAuthChanged) onAuthChanged();
        return;
      }
      const code = await shcFindOwnDevice(base);
      if (!code) {
        setErrorMsg('Belum ada tatakan tersimpan di akun ini. Masukkan kode 8 karakter dari panduan alat.');
      } else {
        setClaimCode(code);
        setSuccessMsg(`Kode tatakan ditemukan: ${code}. Tekan tombol Tautkan.`);
      }
    } catch (err) {
      setErrorMsg(err.message || 'Gagal mencari kode tatakan.');
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
      className="rounded-2xl border border-hairline bg-surface text-ink p-0 overflow-y-auto"
    >
      <div className="flex items-center justify-between px-5 py-4 border-b border-hairline">
        <div>
          <h2 id="auth-dialog-title" className="text-base font-semibold text-ink tracking-tight">
            Akun & tatakan
          </h2>
          <p className="text-xs text-ink-soft mt-0.5">
            Masuk untuk memantau tatakanmu dari mana saja
          </p>
        </div>
        <button
          type="button"
          onClick={() => dialogRef.current?.close()}
          aria-label="Tutup jendela akun"
          className="p-1.5 rounded-lg text-ink-soft hover:text-ink hover:bg-subtle transition-colors duration-150"
        >
          <X className="w-4 h-4" strokeWidth={1.75} aria-hidden="true" />
        </button>
      </div>

      <div className="p-5 space-y-4">
        {errorMsg && (
          <div
            className="flex items-start gap-2 p-3 rounded-xl bg-danger-bg border border-danger-border text-xs text-danger"
            role="alert"
          >
            <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-danger" strokeWidth={1.75} aria-hidden="true" />
            <span>{errorMsg}</span>
          </div>
        )}

        {successMsg && (
          <div
            className="flex items-start gap-2 p-3 rounded-xl bg-ok-bg border border-ok-border text-xs text-ok"
            role="status"
          >
            <CheckCircle2 className="w-4 h-4 flex-shrink-0 mt-0.5 text-ok" strokeWidth={1.75} aria-hidden="true" />
            <span>{successMsg}</span>
          </div>
        )}

        {isLoggedIn ? (
          <div className="space-y-4">
            <div className="p-3.5 rounded-xl bg-subtle space-y-2 text-xs">
              <div className="flex justify-between items-center gap-2">
                <span className="text-ink-soft">Email akun</span>
                <span className="font-semibold text-ink truncate">{userEmail}</span>
              </div>
              <div className="flex justify-between items-center gap-2">
                <span className="text-ink-soft">Status tatakan</span>
                <span className="font-semibold text-accent">
                  {deviceUid ? 'Sudah tertaut' : 'Memakai akun pribadi'}
                </span>
              </div>
            </div>

            <form onSubmit={handleClaim} className="space-y-3 pt-2 border-t border-hairline">
              <label htmlFor="claimCodeIn" className="text-xs font-semibold text-ink block">
                Masukkan kode tatakan (8 karakter)
              </label>
              <div className="flex gap-2">
                <input
                  id="claimCodeIn"
                  type="text"
                  maxLength={8}
                  placeholder="Contoh: AB23CD45"
                  value={claimCode}
                  onChange={(e) => setClaimCode(e.target.value.toUpperCase())}
                  className="flex-1 px-3 py-2 rounded-xl border border-control bg-surface text-xs font-mono text-ink"
                />
                <button
                  type="submit"
                  disabled={loading || claimCode.trim().length !== 8}
                  className="px-4 py-2 rounded-xl bg-accent hover:bg-accent-hover disabled:opacity-50 text-accent-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
                >
                  Tautkan
                </button>
              </div>
              <button
                type="button"
                onClick={handleAutoFind}
                disabled={loading}
                className="w-full flex items-center justify-center gap-1.5 py-2 rounded-xl border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
              >
                <Search className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
                <span>Cari tatakan saya</span>
              </button>
            </form>

            <div className="pt-2 border-t border-hairline">
              <button
                type="button"
                onClick={handleLogout}
                className="w-full flex items-center justify-center gap-1.5 py-2 rounded-xl border border-danger-border bg-surface hover:bg-danger-bg text-danger text-xs font-semibold whitespace-nowrap transition-colors duration-150"
              >
                <LogOut className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
                <span>Keluar akun</span>
              </button>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="grid grid-cols-2 p-1 bg-subtle rounded-xl border border-hairline text-xs font-medium">
              <button
                type="button"
                aria-pressed={tab === 'login'}
                onClick={() => setTab('login')}
                className={`py-1.5 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                  tab === 'login'
                    ? 'bg-surface text-ink font-semibold border border-hairline'
                    : 'text-ink-soft hover:text-ink'
                }`}
              >
                Masuk
              </button>
              <button
                type="button"
                aria-pressed={tab === 'register'}
                onClick={() => setTab('register')}
                className={`py-1.5 rounded-lg whitespace-nowrap transition-colors duration-150 ${
                  tab === 'register'
                    ? 'bg-surface text-ink font-semibold border border-hairline'
                    : 'text-ink-soft hover:text-ink'
                }`}
              >
                Daftar baru
              </button>
            </div>

            <form onSubmit={handleAuth} className="space-y-3">
              <div>
                <label htmlFor="authEmailInput" className="text-xs font-semibold text-ink block mb-1">
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
                  className="w-full px-3 py-2 rounded-xl border border-control bg-surface text-xs text-ink"
                />
              </div>

              <div>
                <label htmlFor="authPassInput" className="text-xs font-semibold text-ink block mb-1">
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
                  className="w-full px-3 py-2 rounded-xl border border-control bg-surface text-xs text-ink"
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full py-2.5 rounded-xl bg-accent hover:bg-accent-hover disabled:opacity-50 text-accent-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
              >
                {loading
                  ? 'Memproses...'
                  : tab === 'login'
                    ? 'Masuk sekarang'
                    : 'Buat akun'}
              </button>
            </form>
          </div>
        )}

        <div className="pt-3 border-t border-hairline">
          <button
            type="button"
            onClick={() => setShowCustomCfg((v) => !v)}
            aria-expanded={showCustomCfg}
            className="w-full flex items-center justify-between text-xs font-medium text-ink-soft hover:text-ink py-1 whitespace-nowrap"
          >
            <span className="inline-flex items-center gap-1.5">
              <Settings2 className="w-3.5 h-3.5" strokeWidth={1.75} aria-hidden="true" />
              <span>Pengaturan server</span>
            </span>
            <span>{showCustomCfg ? 'Tutup' : 'Ubah'}</span>
          </button>

          {showCustomCfg && (
            <form onSubmit={handleSaveCustomProject} className="mt-2.5 space-y-2.5 p-3 rounded-xl bg-subtle">
              <div>
                <label htmlFor="customFbUrl" className="text-xs font-medium text-ink-soft block mb-1">
                  Alamat server database (kosongkan untuk bawaan)
                </label>
                <input
                  id="customFbUrl"
                  type="url"
                  placeholder="https://proyek-anda.firebasedatabase.app"
                  value={customUrl}
                  onChange={(e) => setCustomUrl(e.target.value)}
                  className="w-full px-2.5 py-1.5 rounded-lg border border-control text-xs font-mono text-ink bg-surface"
                />
              </div>
              <div>
                <label htmlFor="customApiKey" className="text-xs font-medium text-ink-soft block mb-1">
                  Kunci akses server (kosongkan untuk bawaan)
                </label>
                <input
                  id="customApiKey"
                  type="text"
                  placeholder="AIzaSy..."
                  value={customKey}
                  onChange={(e) => setCustomKey(e.target.value)}
                  className="w-full px-2.5 py-1.5 rounded-lg border border-control text-xs font-mono text-ink bg-surface"
                />
              </div>
              <button
                type="submit"
                className="w-full py-1.5 rounded-lg border border-control bg-surface hover:bg-subtle text-ink text-xs font-semibold whitespace-nowrap transition-colors duration-150"
              >
                Simpan server
              </button>
            </form>
          )}
        </div>
      </div>
    </dialog>
  );
}
