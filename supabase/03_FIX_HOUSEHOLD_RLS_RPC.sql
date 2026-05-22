-- MASROFI SMART - Fix household creation RLS/RPC
-- Run this if the app shows:
-- "new row violates row-level security policy for table households"
--
-- This file does not delete data.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'مستخدم',
  email text,
  created_at timestamptz not null default now()
);

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'بيتي',
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  relation text,
  monthly_allowance numeric not null default 0,
  linked_user_id uuid references auth.users(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.household_users (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  member_id uuid references public.household_members(id) on delete set null,
  role text not null default 'member' check (role in ('owner','admin','member','viewer')),
  can_add_expenses boolean not null default true,
  can_add_commitments boolean not null default true,
  can_view_income boolean not null default false,
  can_view_reports boolean not null default false,
  can_manage_members boolean not null default false,
  status text not null default 'active' check (status in ('active','invited','disabled')),
  created_at timestamptz not null default now(),
  unique(household_id, user_id)
);

create table if not exists public.household_settings (
  household_id uuid primary key references public.households(id) on delete cascade,
  monthly_salary numeric not null default 0,
  salary_day int not null default 1,
  emergency_target numeric not null default 0,
  updated_at timestamptz not null default now()
);

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
      role = 'owner',
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

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_users enable row level security;
alter table public.household_settings enable row level security;

drop policy if exists profiles_own_all on public.profiles;
create policy profiles_own_all on public.profiles
for all using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists households_select on public.households;
drop policy if exists households_insert on public.households;
drop policy if exists households_update on public.households;
drop policy if exists households_delete on public.households;

create policy households_select on public.households
for select using (owner_id = auth.uid() or public.is_household_member(id));
create policy households_insert on public.households
for insert with check (owner_id = auth.uid());
create policy households_update on public.households
for update using (owner_id = auth.uid() or public.is_household_admin(id))
with check (owner_id = auth.uid() or public.is_household_admin(id));
create policy households_delete on public.households
for delete using (owner_id = auth.uid());

drop policy if exists household_users_select on public.household_users;
drop policy if exists household_users_insert on public.household_users;
drop policy if exists household_users_update on public.household_users;
drop policy if exists household_users_delete on public.household_users;

create policy household_users_select on public.household_users
for select using (public.household_users.user_id = auth.uid() or public.is_household_admin(public.household_users.household_id));
create policy household_users_insert on public.household_users
for insert with check (
  public.household_users.user_id = auth.uid()
  or public.is_household_admin(public.household_users.household_id)
  or exists (select 1 from public.households h where h.id = public.household_users.household_id and h.owner_id = auth.uid())
);
create policy household_users_update on public.household_users
for update using (public.is_household_admin(public.household_users.household_id))
with check (public.is_household_admin(public.household_users.household_id));
create policy household_users_delete on public.household_users
for delete using (public.is_household_admin(public.household_users.household_id));

drop policy if exists household_members_all on public.household_members;
create policy household_members_all on public.household_members
for all using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

drop policy if exists household_settings_all on public.household_settings;
create policy household_settings_all on public.household_settings
for all using (public.is_household_member(household_id))
with check (public.is_household_member(household_id));

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.households to authenticated;
grant select, insert, update, delete on public.household_members to authenticated;
grant select, insert, update, delete on public.household_users to authenticated;
grant select, insert, update, delete on public.household_settings to authenticated;
grant execute on function public.ensure_current_household() to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.is_household_admin(uuid) to authenticated;

notify pgrst, 'reload schema';
