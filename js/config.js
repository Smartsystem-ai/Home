// بيانات مشروع Supabase من Project Settings > API
// مهم: Project URL فقط بدون /rest/v1
const SUPABASE_URL = 'https://rgpywaldinfxsseephzc.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJncHl3YWxkaW5meHNzZWVwaHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzMDQwMjgsImV4cCI6MjA5NDg4MDAyOH0.nn96E-ZEwRBj3uQAL_B_DosLktHMUcuKLrHgtSpY1J4';

const isSupabaseConfigured =
  SUPABASE_URL &&
  SUPABASE_ANON_KEY &&
  SUPABASE_URL.startsWith('https://') &&
  SUPABASE_URL.includes('.supabase.co') &&
  !SUPABASE_URL.includes('/rest/v1') &&
  !SUPABASE_URL.includes('YOUR_') &&
  !SUPABASE_ANON_KEY.includes('YOUR_');

window.sb = isSupabaseConfigured
  ? supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
        flowType: 'pkce',
        storageKey: 'masrofi-smart-auth'
      },
      global: { headers: { 'x-client-info': 'masrofi-smart-fixed' } }
    })
  : null;
