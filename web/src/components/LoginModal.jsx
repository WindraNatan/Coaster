import React, { useState, useEffect } from 'react';
import { X, LogIn, UserPlus, LogOut, Link2, Key, Search, CheckCircle2, AlertCircle } from 'lucide-react';
import {
  shcLogin,
  shcRegister,
  shcLogout,
  shcUid,
  shcDeviceUid,
  shcClaimDevice,
  shcFindOwnDevice,
  shcBaseUrl,
  shcApiKey,
  getCleanFbUrl
} from '../auth';

export default function LoginModal({ isOpen, onClose, onAuthChanged }) {
  const [tab, setTab] = useState('login'); // 'login' | 'register'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [claimCode, setClaimCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Stored state
  const [userEmail, setUserEmail] = useState('');
  const [uid, setUid] = useState('');
  const [deviceUid, setDeviceUid] = useState('');

  const refreshUser = () => {
    setUserEmail(localStorage.getItem('shc_auth_email') || '');
    setUid(shcUid());
    setDeviceUid(shcDeviceUid());
  };

  useEffect(() => {
    if (isOpen) {
      refreshUser();
      setErrorMsg('');
      setSuccessMsg('');
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleAuth = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');
    setLoading(true);
    try {
      if (tab === 'login') {
        const user = await shcLogin(email, password);
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
      setSuccessMsg(`Alat berhasil ditautkan: ${claimed}`);
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
      const code = await shcFindOwnDevice(base);
      if (!code) {
        setErrorMsg('Belum ada kode tersimpan untuk akun ini. Masukkan manual.');
      } else {
        setClaimCode(code);
        setSuccessMsg(`Kode alat ditemukan: ${code}. Tekan Tautkan Alat.`);
      }
    } catch (err) {
      setErrorMsg(err.message || 'Gagal mencari kode alat.');
    } finally {
      setLoading(false);
    }
  };

  const isLoggedIn = !!userEmail && !!uid;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white rounded-2xl border border-slate-200 shadow-soft-lg w-full max-w-md overflow-hidden transition-all">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <div>
            <h3 className="text-base font-bold text-slate-900 tracking-tight">
              Akun & Perangkat Coaster
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Autentikasi Firebase Cloud & Tautan Perangkat ESP32
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-5">
          {/* Notifications */}
          {errorMsg && (
            <div className="flex items-start gap-2 p-3 rounded-xl bg-rose-50 border border-rose-200 text-xs text-rose-700">
              <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-rose-500" />
              <span>{errorMsg}</span>
            </div>
          )}

          {successMsg && (
            <div className="flex items-start gap-2 p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-xs text-emerald-700">
              <CheckCircle2 className="w-4 h-4 flex-shrink-0 mt-0.5 text-emerald-500" />
              <span>{successMsg}</span>
            </div>
          )}

          {isLoggedIn ? (
            /* Logged in state */
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 space-y-2 text-xs">
                <div className="flex justify-between items-center">
                  <span className="text-slate-500">Email Akun:</span>
                  <span className="font-semibold text-slate-800">{userEmail}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-500">UID:</span>
                  <span className="font-mono text-slate-600 truncate max-w-[200px]">{uid}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-500">Perangkat Ditautkan:</span>
                  <span className="font-mono font-semibold text-water-700">
                    {deviceUid || 'Belum ada alat'}
                  </span>
                </div>
              </div>

              {/* Device claim form */}
              <form onSubmit={handleClaim} className="space-y-3 pt-2 border-t border-slate-100">
                <label htmlFor="claimCodeIn" className="text-xs font-semibold text-slate-700 block">
                  Klaim / Tautkan Kode Alat ESP32
                </label>
                <div className="flex gap-2">
                  <input
                    id="claimCodeIn"
                    type="text"
                    maxLength={8}
                    placeholder="Contoh: AB12CD34"
                    value={claimCode}
                    onChange={(e) => setClaimCode(e.target.value.toUpperCase())}
                    className="flex-1 px-3 py-2 rounded-xl border border-slate-200 text-xs font-mono uppercase tracking-wider text-slate-900 focus:outline-none focus:ring-2 focus:ring-water-500/20 focus:border-water-500"
                  />
                  <button
                    type="submit"
                    disabled={loading || claimCode.trim().length !== 8}
                    className="px-4 py-2 rounded-xl bg-water-600 hover:bg-water-700 disabled:opacity-50 text-white text-xs font-medium transition-colors shadow-sm whitespace-nowrap"
                  >
                    Tautkan
                  </button>
                </div>
                <button
                  type="button"
                  onClick={handleAutoFind}
                  disabled={loading}
                  className="w-full flex items-center justify-center gap-1.5 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-600 text-xs font-medium transition-colors"
                >
                  <Search className="w-3.5 h-3.5" />
                  <span>Cari Otomatis Kode Alat Saya</span>
                </button>
              </form>

              {/* Logout button */}
              <div className="pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={handleLogout}
                  className="w-full flex items-center justify-center gap-1.5 py-2 rounded-xl border border-rose-200 bg-white hover:bg-rose-50 text-rose-600 text-xs font-medium transition-colors shadow-sm"
                >
                  <LogOut className="w-3.5 h-3.5" />
                  <span>Keluar dari Akun Ini</span>
                </button>
              </div>
            </div>
          ) : (
            /* Not logged in form */
            <div className="space-y-4">
              {/* Tab Selector */}
              <div className="grid grid-cols-2 p-1 bg-slate-100 rounded-xl text-xs font-medium text-slate-600">
                <button
                  type="button"
                  onClick={() => setTab('login')}
                  className={`py-1.5 rounded-lg transition-all ${
                    tab === 'login' ? 'bg-white text-slate-900 font-semibold shadow-sm' : ''
                  }`}
                >
                  Masuk Akun
                </button>
                <button
                  type="button"
                  onClick={() => setTab('register')}
                  className={`py-1.5 rounded-lg transition-all ${
                    tab === 'register' ? 'bg-white text-slate-900 font-semibold shadow-sm' : ''
                  }`}
                >
                  Daftar Baru
                </button>
              </div>

              <form onSubmit={handleAuth} className="space-y-3">
                <div>
                  <label className="text-xs font-medium text-slate-700 block mb-1">
                    Alamat Email
                  </label>
                  <input
                    type="email"
                    required
                    placeholder="nama@email.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-xs text-slate-900 focus:outline-none focus:ring-2 focus:ring-water-500/20 focus:border-water-500"
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-slate-700 block mb-1">
                    Kata Sandi (Password)
                  </label>
                  <input
                    type="password"
                    required
                    minLength={6}
                    placeholder="Minimal 6 karakter"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-200 text-xs text-slate-900 focus:outline-none focus:ring-2 focus:ring-water-500/20 focus:border-water-500"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-water-600 hover:bg-water-700 disabled:opacity-50 text-white text-xs font-semibold transition-colors shadow-sm mt-4"
                >
                  {tab === 'login' ? (
                    <>
                      <LogIn className="w-3.5 h-3.5" />
                      <span>{loading ? 'Memproses...' : 'Masuk Sekarang'}</span>
                    </>
                  ) : (
                    <>
                      <UserPlus className="w-3.5 h-3.5" />
                      <span>{loading ? 'Mendaftarkan...' : 'Buat Akun Baru'}</span>
                    </>
                  )}
                </button>
              </form>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
