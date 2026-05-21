-- Masrofi Smart Supabase Schema - UPDATED SAFE VERSION
-- شغل الملف ده كامل في Supabase SQL Editor.
-- مهم: لو Email Confirmations مفعلة، التسجيل سيطلب تأكيد الإيميل قبل إنشاء بيانات البيت من الواجهة.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  created_at timestamptz default now()
);

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz default now()
);

create table if not exists public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  relation text,
  monthly_allowance numeric default 0,
  linked_user_id uuid references auth.users(id) on delete set null,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.household_users (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  member_id uuid references public.household_members(id) on delete set null,
  role text not null default 'member' check (role in ('owner','admin','member','viewer')),
  can_add_expenses boolean default true,
  can_add_commitments boolean default true,
  can_view_income boolean default false,
  can_view_reports boolean default false,
  can_manage_members boolean default false,
  status text default 'active' check (status in ('active','invited','disabled')),
  created_at timestamptz default now(),
  unique(household_id, user_id)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households(id) on delete cascade,
  name text not null,
  type text not null check (type in ('income','expense','bill','installment','debt')),
  created_at timestamptz default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  assigned_to_member_id uuid references public.household_members(id) on delete set null,
  type text not null check (type in ('income','expense')),
  category text not null,
  amount numeric not null check (amount >= 0),
  note text,
  date date not null default current_date,
  status text default 'approved' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now()
);

create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  bill_name text not null,
  amount numeric not null default 0,
  due_date date,
  status text default 'unpaid' check (status in ('unpaid','paid','late')),
  created_at timestamptz default now()
);

create table if not exists public.installments (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null,
  total_amount numeric not null default 0,
  monthly_amount numeric not null default 0,
  total_months int not null default 1,
  paid_months int not null default 0,
  next_due_date date,
  status text default 'active' check (status in ('active','finished','late')),
  created_at timestamptz default now()
);

create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  person_name text not null,
  direction text not null check (direction in ('i_owe','owes_me')),
  amount numeric not null default 0,
  paid_amount numeric not null default 0,
  due_date date,
  status text default 'open' check (status in ('open','partial','paid','late')),
  created_at timestamptz default now()
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null,
  month text not null,
  amount numeric not null default 0,
  created_at timestamptz default now(),
  unique(household_id, category, month)
);

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null,
  target_amount numeric not null default 0,
  saved_amount numeric not null default 0,
  deadline_months int not null default 1,
  priority text default 'medium' check (priority in ('low','medium','high')),
  status text default 'active' check (status in ('active','done','paused')),
  note text,
  created_at timestamptz default now()
);


create table if not exists public.gam3eyas (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  name text not null default 'جمعية شهرية',
  monthly_amount numeric not null default 0,
  total_members int,
  current_turn int default 1,
  my_turn int,
  start_date date,
  status text default 'active' check (status in ('active','finished')),
  note text,
  role_mode text not null default 'subscriber' check (role_mode in ('subscriber','founder')),
  created_at timestamptz default now()
);

alter table public.gam3eyas add column if not exists role_mode text not null default 'subscriber';
alter table public.gam3eyas drop constraint if exists gam3eyas_role_mode_check;
alter table public.gam3eyas add constraint gam3eyas_role_mode_check check (role_mode in ('subscriber','founder'));

create table if not exists public.gam3eya_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  gam3eya_id uuid not null references public.gam3eyas(id) on delete cascade,
  member_name text not null,
  turn_number int,
  phone text,
  note text,
  created_at timestamptz default now(),
  unique(gam3eya_id, member_name)
);

create table if not exists public.gam3eya_payments (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  gam3eya_id uuid not null references public.gam3eyas(id) on delete cascade,
  member_id uuid not null references public.gam3eya_members(id) on delete cascade,
  payment_month text not null,
  amount numeric not null default 0,
  is_paid boolean not null default false,
  paid_at timestamptz,
  note text,
  created_at timestamptz default now(),
  unique(gam3eya_id, member_id, payment_month)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text,
  type text default 'system',
  is_read boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.ai_chats (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','assistant','system')),
  message text not null,
  created_at timestamptz default now()
);

create or replace function public.is_household_member(hid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.household_users hu
    where hu.household_id = hid and hu.user_id = auth.uid() and hu.status = 'active'
  );
$$;

create or replace function public.is_household_admin(hid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.household_users hu
    where hu.household_id = hid and hu.user_id = auth.uid() and hu.status = 'active' and hu.role in ('owner','admin')
  );
$$;

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_users enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.bills enable row level security;
alter table public.installments enable row level security;
alter table public.debts enable row level security;
alter table public.budgets enable row level security;
alter table public.goals enable row level security;
alter table public.gam3eyas enable row level security;
alter table public.gam3eya_members enable row level security;
alter table public.gam3eya_payments enable row level security;
alter table public.notifications enable row level security;
alter table public.ai_chats enable row level security;

-- حذف السياسات القديمة لتشغيل الملف أكثر من مرة بدون أخطاء
drop policy if exists "profile own" on public.profiles;
drop policy if exists "household member select" on public.households;
drop policy if exists "household owner insert" on public.households;
drop policy if exists "household owner update" on public.households;
drop policy if exists "household_users select" on public.household_users;
drop policy if exists "household_users admin insert" on public.household_users;
drop policy if exists "household_users admin update" on public.household_users;
drop policy if exists "members access" on public.household_members;
drop policy if exists "categories access" on public.categories;
drop policy if exists "transactions access" on public.transactions;
drop policy if exists "transactions insert" on public.transactions;
drop policy if exists "transactions update" on public.transactions;
drop policy if exists "bills access" on public.bills;
drop policy if exists "installments access" on public.installments;
drop policy if exists "debts access" on public.debts;
drop policy if exists "budgets access" on public.budgets;
drop policy if exists "goals access" on public.goals;
drop policy if exists "gam3eyas access" on public.gam3eyas;
drop policy if exists "gam3eya_members access" on public.gam3eya_members;
drop policy if exists "gam3eya_payments access" on public.gam3eya_payments;
drop policy if exists "notifications access" on public.notifications;
drop policy if exists "ai_chats access" on public.ai_chats;

create policy "profile own" on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());

-- الإصلاح الأساسي: صاحب البيت يقدر يعمل select للبيت فور إنشائه قبل إنشاء household_users
create policy "household member select" on public.households for select using (owner_id = auth.uid() or public.is_household_member(id));
create policy "household owner insert" on public.households for insert with check (owner_id = auth.uid());
create policy "household owner update" on public.households for update using (owner_id = auth.uid() or public.is_household_admin(id));

create policy "household_users select" on public.household_users for select using (user_id = auth.uid() or public.is_household_admin(household_id));
-- يسمح لصاحب البيت بإنشاء أول ربط owner بعد إنشاء البيت
create policy "household_users admin insert" on public.household_users for insert with check (
  public.is_household_admin(household_id)
  or user_id = auth.uid()
  or exists (select 1 from public.households h where h.id = household_id and h.owner_id = auth.uid())
);
create policy "household_users admin update" on public.household_users for update using (public.is_household_admin(household_id));

create policy "members access" on public.household_members for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "categories access" on public.categories for all using (household_id is null or public.is_household_member(household_id)) with check (household_id is null or public.is_household_member(household_id));

create policy "transactions access" on public.transactions for select using (
  public.is_household_admin(household_id) or created_by = auth.uid() or assigned_to_member_id in (select member_id from public.household_users where user_id = auth.uid())
);
create policy "transactions insert" on public.transactions for insert with check (public.is_household_member(household_id) and created_by = auth.uid());
create policy "transactions update" on public.transactions for update using (public.is_household_admin(household_id) or created_by = auth.uid());

create policy "bills access" on public.bills for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "installments access" on public.installments for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "debts access" on public.debts for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "budgets access" on public.budgets for all using (public.is_household_admin(household_id)) with check (public.is_household_admin(household_id));
create policy "goals access" on public.goals for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "gam3eyas access" on public.gam3eyas for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "gam3eya_members access" on public.gam3eya_members for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "gam3eya_payments access" on public.gam3eya_payments for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

create policy "notifications access" on public.notifications for all using (user_id = auth.uid() or user_id is null or public.is_household_admin(household_id)) with check (public.is_household_member(household_id));
create policy "ai_chats access" on public.ai_chats for all using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

-- إنشاء بيانات البيت تلقائيًا عند إنشاء حساب جديد حتى لو Email Confirmation مفعلة
create or replace function public.handle_new_masrofi_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_household_id uuid;
  v_full_name text;
  v_house_name text;
begin
  v_full_name := coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1), 'مستخدم');
  v_house_name := coalesce(new.raw_user_meta_data->>'house_name', 'بيتي');

  insert into public.profiles(id, full_name, email)
  values (new.id, v_full_name, new.email)
  on conflict (id) do update set
    full_name = excluded.full_name,
    email = excluded.email;

  select hu.household_id into v_household_id
  from public.household_users hu
  where hu.user_id = new.id
  limit 1;

  if v_household_id is null then
    insert into public.households(owner_id, name)
    values (new.id, v_house_name)
    returning id into v_household_id;

    insert into public.household_users(
      household_id,
      user_id,
      role,
      can_add_expenses,
      can_add_commitments,
      can_view_income,
      can_view_reports,
      can_manage_members,
      status
    ) values (
      v_household_id,
      new.id,
      'owner',
      true,
      true,
      true,
      true,
      true,
      'active'
    ) on conflict (household_id, user_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_masrofi on auth.users;
create trigger on_auth_user_created_masrofi
after insert on auth.users
for each row execute function public.handle_new_masrofi_user();

-- تحديثات النسخة الذكية: إعداد المرتب + صلاحيات الحذف والتعديل
create table if not exists public.household_settings (
  household_id uuid primary key references public.households(id) on delete cascade,
  monthly_salary numeric not null default 0,
  salary_day int not null default 1,
  emergency_target numeric not null default 0,
  updated_at timestamptz default now()
);

alter table public.household_settings enable row level security;
drop policy if exists "household_settings access" on public.household_settings;
create policy "household_settings access" on public.household_settings
for all using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

drop policy if exists "transactions delete" on public.transactions;
create policy "transactions delete" on public.transactions for delete using (public.is_household_admin(household_id) or created_by = auth.uid());

drop policy if exists "transactions full update" on public.transactions;
create policy "transactions full update" on public.transactions for update using (public.is_household_admin(household_id) or created_by = auth.uid()) with check (public.is_household_admin(household_id) or created_by = auth.uid());


-- Creative V4: financial challenges
create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  type text not null default 'save_amount',
  target_amount numeric not null default 0,
  note text,
  status text not null default 'active',
  completed_at timestamptz,
  created_at timestamptz default now()
);
alter table public.challenges enable row level security;
drop policy if exists "challenges access" on public.challenges;
create policy "challenges access" on public.challenges for all
using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

-- =========================================================
-- STRICT FIX LAYER — Auth/RLS/User ID stability
-- Safe to run multiple times after the base schema above.
-- =========================================================

-- Ensure extensions exist
create extension if not exists pgcrypto;

-- Stable helper: returns/creates the current user's household safely without RLS glitches.
drop function if exists public.ensure_current_household() cascade;
create or replace function public.ensure_current_household()
returns table (
  household_id uuid,
  household_name text,
  role text,
  member_id uuid
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_full_name text;
  v_house_name text;
  v_household_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select email, coalesce(raw_user_meta_data->>'full_name', split_part(email,'@',1), 'مستخدم'), coalesce(raw_user_meta_data->>'house_name','بيتي')
  into v_email, v_full_name, v_house_name
  from auth.users
  where id = v_uid;

  insert into public.profiles(id, full_name, email)
  values (v_uid, coalesce(v_full_name,'مستخدم'), v_email)
  on conflict (id) do update set
    full_name = excluded.full_name,
    email = excluded.email;

  select hu.household_id
  into v_household_id
  from public.household_users hu
  where hu.user_id = v_uid and hu.status = 'active'
  order by hu.created_at asc
  limit 1;

  if v_household_id is null then
    select h.id into v_household_id
    from public.households h
    where h.owner_id = v_uid
    order by h.created_at asc
    limit 1;

    if v_household_id is null then
      insert into public.households(owner_id, name)
      values (v_uid, coalesce(v_house_name,'بيتي'))
      returning id into v_household_id;
    end if;

    insert into public.household_users(
      household_id, user_id, role,
      can_add_expenses, can_add_commitments,
      can_view_income, can_view_reports, can_manage_members,
      status
    ) values (
      v_household_id, v_uid, 'owner',
      true, true, true, true, true,
      'active'
    )
    on conflict (household_id, user_id) do update set
      role = case when public.household_users.role is null then 'owner' else public.household_users.role end,
      status = 'active',
      can_add_expenses = true,
      can_add_commitments = true,
      can_view_income = true,
      can_view_reports = true,
      can_manage_members = true;
  end if;

  return query
  select hu.household_id, h.name, hu.role, hu.member_id
  from public.household_users hu
  join public.households h on h.id = hu.household_id
  where hu.user_id = v_uid and hu.household_id = v_household_id and hu.status = 'active'
  limit 1;
end;
$$;

grant execute on function public.ensure_current_household() to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.is_household_admin(uuid) to authenticated;

-- Make notification inserts stable: no anonymous/global user_id=null rows needed.
drop policy if exists "notifications access" on public.notifications;
create policy "notifications select" on public.notifications for select
using (public.is_household_member(household_id) and (user_id = auth.uid() or user_id is null or public.is_household_admin(household_id)));
create policy "notifications insert" on public.notifications for insert
with check (public.is_household_member(household_id) and (user_id = auth.uid() or user_id is null));
create policy "notifications update" on public.notifications for update
using (public.is_household_member(household_id) and (user_id = auth.uid() or public.is_household_admin(household_id)))
with check (public.is_household_member(household_id));
create policy "notifications delete" on public.notifications for delete
using (public.is_household_admin(household_id) or user_id = auth.uid());

-- Delete policies for tables that had all/update ambiguity in some Supabase projects.
drop policy if exists "bills delete" on public.bills;
create policy "bills delete" on public.bills for delete using (public.is_household_member(household_id));

drop policy if exists "installments delete" on public.installments;
create policy "installments delete" on public.installments for delete using (public.is_household_member(household_id));

drop policy if exists "debts delete" on public.debts;
create policy "debts delete" on public.debts for delete using (public.is_household_member(household_id));

drop policy if exists "goals delete" on public.goals;
create policy "goals delete" on public.goals for delete using (public.is_household_member(household_id));

drop policy if exists "gam3eyas delete" on public.gam3eyas;
create policy "gam3eyas delete" on public.gam3eyas for delete using (public.is_household_member(household_id));

drop policy if exists "gam3eya_members delete" on public.gam3eya_members;
create policy "gam3eya_members delete" on public.gam3eya_members for delete using (public.is_household_member(household_id));

drop policy if exists "gam3eya_payments delete" on public.gam3eya_payments;
create policy "gam3eya_payments delete" on public.gam3eya_payments for delete using (public.is_household_member(household_id));

drop policy if exists "challenges delete" on public.challenges;
create policy "challenges delete" on public.challenges for delete using (public.is_household_member(household_id));

-- Authenticated role grants; RLS still controls rows.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;



-- =========================================================
-- FINAL HARDENING LAYER V4 — safe to run multiple times
-- =========================================================

grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

create index if not exists idx_household_users_user_status on public.household_users(user_id, status);
create index if not exists idx_household_users_household on public.household_users(household_id);
create index if not exists idx_transactions_household_date on public.transactions(household_id, date desc);
create index if not exists idx_bills_household_due on public.bills(household_id, due_date);
create index if not exists idx_installments_household_due on public.installments(household_id, next_due_date);
create index if not exists idx_debts_household on public.debts(household_id);
create index if not exists idx_notifications_household_created on public.notifications(household_id, created_at desc);
create index if not exists idx_ai_chats_household_created on public.ai_chats(household_id, created_at asc);

-- Keep monthly salary row always writable by any active household member.
alter table if exists public.household_settings enable row level security;
drop policy if exists "household_settings access" on public.household_settings;
create policy "household_settings access" on public.household_settings
for all using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

-- Make delete/update policies explicit for core tables.
drop policy if exists "bills delete" on public.bills;
create policy "bills delete" on public.bills for delete using (public.is_household_member(household_id));
drop policy if exists "installments delete" on public.installments;
create policy "installments delete" on public.installments for delete using (public.is_household_member(household_id));
drop policy if exists "debts delete" on public.debts;
create policy "debts delete" on public.debts for delete using (public.is_household_member(household_id));
drop policy if exists "goals delete" on public.goals;
create policy "goals delete" on public.goals for delete using (public.is_household_member(household_id));
drop policy if exists "gam3eyas delete" on public.gam3eyas;
create policy "gam3eyas delete" on public.gam3eyas for delete using (public.is_household_member(household_id));
drop policy if exists "challenges delete" on public.challenges;
create policy "challenges delete" on public.challenges for delete using (public.is_household_member(household_id));

notify pgrst, 'reload schema';
