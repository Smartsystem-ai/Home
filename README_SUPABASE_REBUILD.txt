مصروفي سمارت — Supabase Rebuild صارم

1) افتح Supabase > SQL Editor.
2) شغّل الملف: 01_RUN_THIS_FIRST_SUPABASE.sql كامل مرة واحدة.
3) هذا الملف يمسح جداول التطبيق القديمة في public ويبنيها من الصفر. لا يشطب auth.users.
4) بعد نجاح SQL اعمل Refresh للموقع وسجل دخول.
5) لو عندك بيانات قديمة مهمة اعمل Export من Supabase قبل التشغيل.

الملفات المتعدلة:
- 01_RUN_THIS_FIRST_SUPABASE.sql
- supabase/00_REBUILD_SUPABASE_FROM_ZERO.sql
- supabase/schema.sql
- supabase/01_RUN_THIS_FIRST_SUPABASE.sql
- js/app.js
