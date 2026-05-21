# Masrofi Smart — Full Old UI Rebuilt

هذه نسخة كاملة بنفس واجهة المستخدم القديمة، مع إصلاحات صارمة للـ Supabase/Auth/RLS وحفظ الجلسة والمرتب.

## التشغيل

1. افتح Supabase > SQL Editor.
2. شغّل ملف واحد فقط:
   `01_RUN_THIS_FIRST_SUPABASE.sql`
3. ارفع كل ملفات المشروع على GitHub Pages أو أي استضافة Static.
4. افتح الموقع وسجّل دخول.

## مهم

- لا يوجد أكثر من ملف SQL مطلوب؛ شغّل `01_RUN_THIS_FIRST_SUPABASE.sql` فقط.
- ملف `js/config.js` يحتوي على Supabase URL و anon key القديمين بالفعل.
- لا تشغّل أي Reset يمسح الداتا.

## تم إصلاح

- حفظ Session بعد Refresh.
- مشكلة user.id عبر الاعتماد على `session.user.id` فقط.
- RLS و `ensure_current_household`.
- حفظ المرتب الشهري في `household_settings`.
- حساب المتبقي وقرار الشراء.
- الجداول الأساسية: المصاريف، الفواتير، الأقساط، الديون، الجمعية، الأهداف، الشات، الإشعارات.
