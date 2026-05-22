# Masrofi Smart

تطبيق Static HTML/JS مربوط بـ Supabase.

## مهم قبل التشغيل

1. افتح `js/config.js` وتأكد أن:
   - `SUPABASE_URL` هو Project URL فقط، بدون `/rest/v1`.
   - `SUPABASE_ANON_KEY` من نفس مشروع Supabase.
2. لو عندك قاعدة بيانات موجودة وفيها داتا، شغّل:
   `supabase/02_SAFE_AUTH_SESSION_FIX.sql`
3. لو قاعدة البيانات جديدة وفاضية فقط، شغّل:
   `01_RUN_THIS_FIRST_SUPABASE.sql`

## ملاحظات

- ملف `02_SAFE_AUTH_SESSION_FIX.sql` لا يمسح الداتا. يصلح دوال الـ Auth/RLS ويضمن وجود `household_settings`.
- ملف `01_RUN_THIS_FIRST_SUPABASE.sql` يعيد بناء جداول التطبيق من الصفر، فلا تشغله على داتا مهمة إلا بعد Backup.
- التطبيق يحتاج تشغيله من `http://` أو `https://` حتى يتم حفظ الجلسة في `localStorage` بشكل ثابت.
