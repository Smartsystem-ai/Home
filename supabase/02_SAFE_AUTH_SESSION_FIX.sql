-- MASROFI SMART - SAFE AUTH / SESSION / RLS FIX
-- Run this on an existing database. It does not drop tables or delete data.
-- If you are creating a brand-new database, run 01_RUN_THIS_FIRST_SUPABASE.sql instead.

create extension if not exists pgcrypto;

do $$
begin
  if to_regclass('public.households') is null
     or to_regclass('public.household_users') is null then
    raise exception 'Masrofi base tables are missing. Run 01_RUN_THIS_FIRST_SUPABASE.sql on a new/empty database first.';
  end if;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'مستخدم',
  email text,
  created_at timestamptz not null default now()
);

create table if not exists public.household_settings (
  household_id uuid primary key references public.households(id) on delete cascade,
  monthly_salary numeric not null default 0,
  salary_day int not null default 1,
  emergency_target numeric not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.household_settings add column if not exists monthly_salary numeric not null default 0;
alter table public.household_settings add column if not exists salary_day int not null default 1;
alter table public.household_settings add column if not exists emergency_target numeric not null default 0;
alter table public.household_settings add column if not exists updated_at timestamptz not null default now();

create or replace function public.is_household_member(p_household_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_users hu
    where hu.household_id = p_household_id
      and hu.user_id = auth.uid()
      and hu.status = 'active'
  );
$$;

create or replace function public.is_household_admin(p_household_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_users hu
    where hu.household_id = p_household_id
      and hu.user_id = auth.uid()
      and hu.status = 'active'
      and hu.role in ('owner','admin')
  );
$$;

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
#variable_conflict use_column
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

  select u.email,
         coalesce(u.raw_user_meta_data->>'full_name', split_part(u.email,'@',1), 'مستخدم'),
         coalesce(u.raw_user_meta_data->>'house_name', 'بيتي')
  into v_email, v_full_name, v_house_name
  from auth.users u
  where u.id = v_uid;

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
    select h.id
    into v_household_id
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
      status = 'active',
      can_add_expenses = true,
      can_add_commitments = true,
      can_view_income = true,
      can_view_reports = true,
      can_manage_members = true;
  end if;

  insert into public.household_settings(household_id)
  values (v_household_id)
  on conflict (household_id) do nothing;

  return query
  select hu.household_id, h.name, hu.role, hu.member_id
  from public.household_users hu
  join public.households h on h.id = hu.household_id
  where hu.user_id = v_uid
    and hu.household_id = v_household_id
    and hu.status = 'active'
  limit 1;
end;
$$;

create or replace function public.handle_new_masrofi_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
#variable_conflict use_column
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

  insert into public.households(owner_id, name)
  values (new.id, v_house_name)
  returning id into v_household_id;

  insert into public.household_users(
    household_id, user_id, role,
    can_add_expenses, can_add_commitments,
    can_view_income, can_view_reports, can_manage_members,
    status
  ) values (
    v_household_id, new.id, 'owner',
    true, true, true, true, true,
    'active'
  )
  on conflict (household_id, user_id) do update set status = 'active';

  insert into public.household_settings(household_id)
  values (v_household_id)
  on conflict (household_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_masrofi on auth.users;
create trigger on_auth_user_created_masrofi
after insert on auth.users
for each row execute function public.handle_new_masrofi_user();

alter table public.profiles enable row level security;
alter table public.household_settings enable row level security;

drop policy if exists profiles_own_all on public.profiles;
create policy profiles_own_all on public.profiles
for all using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists household_settings_all on public.household_settings;
create policy household_settings_all on public.household_settings
for all using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.household_settings to authenticated;
grant execute on function public.ensure_current_household() to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.is_household_admin(uuid) to authenticated;

notify pgrst, 'reload schema';
