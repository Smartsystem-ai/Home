// بيانات مشروع Supabase من Project Settings > API
// مهم: Project URL فقط بدون /rest/v1
const SUPABASE_URL = 'https://rgpywaldinfxsseephzc.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJncHl3YWxkaW5meHNzZWVwaHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzMDQwMjgsImV4cCI6MjA5NDg4MDAyOH0.nn96E-ZEwRBj3uQAL_B_DosLktHMUcuKLrHgtSpY1J4';

function readProjectRefFromUrl(url) {
  try {
    return new URL(url).hostname.split('.')[0] || null;
  } catch {
    return null;
  }
}

function readProjectRefFromAnonKey(key) {
  try {
    const part = String(key || '').split('.')[1];
    if (!part) return null;
    const normalized = part.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(part.length / 4) * 4, '=');
    const payload = JSON.parse(atob(normalized));
    return payload.ref || null;
  } catch {
    return null;
  }
}

const configIssues = [];
const urlProjectRef = readProjectRefFromUrl(SUPABASE_URL);
const keyProjectRef = readProjectRefFromAnonKey(SUPABASE_ANON_KEY);

if (!SUPABASE_URL || SUPABASE_URL.includes('YOUR_')) configIssues.push('SUPABASE_URL missing.');
if (!SUPABASE_ANON_KEY || SUPABASE_ANON_KEY.includes('YOUR_')) configIssues.push('SUPABASE_ANON_KEY missing.');
if (SUPABASE_URL && !SUPABASE_URL.startsWith('https://')) configIssues.push('SUPABASE_URL must start with https://.');
if (SUPABASE_URL && !SUPABASE_URL.includes('.supabase.co')) configIssues.push('SUPABASE_URL must be the project URL from Supabase.');
if (SUPABASE_URL && SUPABASE_URL.includes('/rest/v1')) configIssues.push('SUPABASE_URL must not include /rest/v1.');
if (urlProjectRef && keyProjectRef && urlProjectRef !== keyProjectRef) {
  configIssues.push('SUPABASE_URL and SUPABASE_ANON_KEY are for different Supabase projects.');
}

let authStorage = null;
if (!configIssues.length) {
  try {
    const testKey = 'masrofi-storage-check';
    window.localStorage.setItem(testKey, '1');
    window.localStorage.removeItem(testKey);
    authStorage = window.localStorage;
  } catch {
    configIssues.push('Browser localStorage is blocked, so the login session cannot be saved.');
  }
}

const isSupabaseConfigured = configIssues.length === 0;

window.masrofiConfig = {
  projectRef: urlProjectRef,
  keyProjectRef,
  issues: configIssues
};

window.sb = isSupabaseConfigured
  ? supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
        storage: authStorage,
        storageKey: 'masrofi-smart-auth'
      },
      global: { headers: { 'x-client-info': 'masrofi-smart-fixed' } }
    })
  : null;
