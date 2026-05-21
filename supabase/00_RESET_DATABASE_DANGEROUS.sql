-- خطر: يمسح جداول مصروفي القديمة ثم يعيد بناءها من الصفر
-- شغّله فقط لو عايز Reset كامل وموافق إن بيانات الجداول دي تتمسح.
drop table if exists public.chat_messages cascade;
drop table if exists public.goals cascade;
drop table if exists public.debts cascade;
drop table if exists public.bills cascade;
drop table if exists public.transactions cascade;
drop table if exists public.profiles cascade;
\i 01_CLEAN_INSTALL_SAFE.sql
