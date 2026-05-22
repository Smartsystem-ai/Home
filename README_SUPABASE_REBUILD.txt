Masrofi Smart - Supabase notes

لو قاعدة البيانات موجودة وفيها بيانات:
1) افتح Supabase > SQL Editor.
2) شغّل الملف:
   supabase/02_SAFE_AUTH_SESSION_FIX.sql
3) اعمل Refresh للموقع وسجل دخول.

لو قاعدة البيانات جديدة وفاضية:
1) شغّل الملف:
   01_RUN_THIS_FIRST_SUPABASE.sql

تحذير:
- ملف 01_RUN_THIS_FIRST_SUPABASE.sql يمسح جداول التطبيق في public ويعيد بناءها.
- لا تشغله على بيانات مهمة إلا بعد Backup.

لو التطبيق بيعمل خروج بعد التنقل:
- تأكد أنك فاتحه من http/https وليس file://.
- تأكد أن SUPABASE_URL و SUPABASE_ANON_KEY في js/config.js لنفس مشروع Supabase.
