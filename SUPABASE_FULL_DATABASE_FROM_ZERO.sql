-- =========================================================
-- MASROFI SMART — SUPABASE FULL REBUILD FROM ZERO
-- شغّل الملف ده كامل في Supabase SQL Editor لو عايز تبني الداتابيز من الأول.
-- WARNING: هذا الملف يمسح جداول التطبيق من public فقط. اعمل Backup قبل التشغيل لو عندك بيانات مهمة.
-- =========================================================

create extension if not exists pgcrypto;

-- 1) Clean old public schema app objects
DROP TRIGGER IF EXISTS on_auth_user_created_masrofi ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_masrofi_user() CASCADE;
DROP FUNCTION IF EXISTS public.ensure_current_household() CASCADE;
DROP FUNCTION IF EXISTS public.is_household_member(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.is_household_admin(uuid) CASCADE;

DROP TABLE IF EXISTS public.ai_chats CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.challenges CASCADE;
DROP TABLE IF EXISTS public.gam3eya_payments CASCADE;
DROP TABLE IF EXISTS public.gam3eya_members CASCADE;
DROP TABLE IF EXISTS public.gam3eyas CASCADE;
DROP TABLE IF EXISTS public.goals CASCADE;
DROP TABLE IF EXISTS public.budgets CASCADE;
DROP TABLE IF EXISTS public.debts CASCADE;
DROP TABLE IF EXISTS public.installments CASCADE;
DROP TABLE IF EXISTS public.bills CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.household_settings CASCADE;
DROP TABLE IF EXISTS public.household_users CASCADE;
DROP TABLE IF EXISTS public.household_members CASCADE;
DROP TABLE IF EXISTS public.households CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2) Tables
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL DEFAULT 'مستخدم',
  email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.households (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'بيتي',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.household_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  name text NOT NULL,
  relation text,
  monthly_allowance numeric NOT NULL DEFAULT 0,
  linked_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.household_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id uuid REFERENCES public.household_members(id) ON DELETE SET NULL,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('owner','admin','member','viewer')),
  can_add_expenses boolean NOT NULL DEFAULT true,
  can_add_commitments boolean NOT NULL DEFAULT true,
  can_view_income boolean NOT NULL DEFAULT false,
  can_view_reports boolean NOT NULL DEFAULT false,
  can_manage_members boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','invited','disabled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(household_id, user_id)
);

CREATE TABLE public.household_settings (
  household_id uuid PRIMARY KEY REFERENCES public.households(id) ON DELETE CASCADE,
  monthly_salary numeric NOT NULL DEFAULT 0,
  salary_day int NOT NULL DEFAULT 1,
  emergency_target numeric NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid REFERENCES public.households(id) ON DELETE CASCADE,
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('income','expense','bill','installment','debt')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_to_member_id uuid REFERENCES public.household_members(id) ON DELETE SET NULL,
  type text NOT NULL CHECK (type IN ('income','expense')),
  category text NOT NULL DEFAULT 'عام',
  amount numeric NOT NULL DEFAULT 0 CHECK (amount >= 0),
  note text,
  date date NOT NULL DEFAULT current_date,
  status text NOT NULL DEFAULT 'approved' CHECK (status IN ('pending','approved','rejected')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bill_name text NOT NULL DEFAULT 'فاتورة',
  amount numeric NOT NULL DEFAULT 0,
  due_date date,
  status text NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','paid','late')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.installments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT 'قسط',
  total_amount numeric NOT NULL DEFAULT 0,
  monthly_amount numeric NOT NULL DEFAULT 0,
  total_months int NOT NULL DEFAULT 1,
  paid_months int NOT NULL DEFAULT 0,
  next_due_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','finished','late')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.debts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  person_name text NOT NULL DEFAULT 'غير محدد',
  direction text NOT NULL CHECK (direction IN ('i_owe','owes_me')),
  amount numeric NOT NULL DEFAULT 0,
  paid_amount numeric NOT NULL DEFAULT 0,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','partial','paid','late')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  category text NOT NULL,
  month text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(household_id, category, month)
);

CREATE TABLE public.goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT 'هدف جديد',
  target_amount numeric NOT NULL DEFAULT 0,
  saved_amount numeric NOT NULL DEFAULT 0,
  deadline_months int NOT NULL DEFAULT 1,
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','done','paused')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.gam3eyas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT 'جمعية شهرية',
  monthly_amount numeric NOT NULL DEFAULT 0,
  total_members int,
  current_turn int NOT NULL DEFAULT 1,
  my_turn int,
  start_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','finished')),
  note text,
  role_mode text NOT NULL DEFAULT 'subscriber' CHECK (role_mode IN ('subscriber','founder')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.gam3eya_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  gam3eya_id uuid NOT NULL REFERENCES public.gam3eyas(id) ON DELETE CASCADE,
  member_name text NOT NULL,
  turn_number int,
  phone text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(gam3eya_id, member_name)
);

CREATE TABLE public.gam3eya_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  gam3eya_id uuid NOT NULL REFERENCES public.gam3eyas(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES public.gam3eya_members(id) ON DELETE CASCADE,
  payment_month text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  is_paid boolean NOT NULL DEFAULT false,
  paid_at timestamptz,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(gam3eya_id, member_id, payment_month)
);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text,
  type text NOT NULL DEFAULT 'system',
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.ai_chats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('user','assistant','system')),
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  type text NOT NULL DEFAULT 'save_amount',
  target_amount numeric NOT NULL DEFAULT 0,
  note text,
  status text NOT NULL DEFAULT 'active',
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 3) Indexes
CREATE INDEX idx_households_owner ON public.households(owner_id);
CREATE INDEX idx_household_users_user_status ON public.household_users(user_id, status);
CREATE INDEX idx_household_users_household ON public.household_users(household_id);
CREATE INDEX idx_transactions_household_date ON public.transactions(household_id, date DESC);
CREATE INDEX idx_bills_household_due ON public.bills(household_id, due_date);
CREATE INDEX idx_installments_household_due ON public.installments(household_id, next_due_date);
CREATE INDEX idx_debts_household ON public.debts(household_id);
CREATE INDEX idx_notifications_household_created ON public.notifications(household_id, created_at DESC);
CREATE INDEX idx_ai_chats_household_created ON public.ai_chats(household_id, created_at ASC);

-- 4) Security helper functions
CREATE OR REPLACE FUNCTION public.is_household_member(p_household_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.household_users hu
    WHERE hu.household_id = p_household_id
      AND hu.user_id = auth.uid()
      AND hu.status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_household_admin(p_household_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.household_users hu
    WHERE hu.household_id = p_household_id
      AND hu.user_id = auth.uid()
      AND hu.status = 'active'
      AND hu.role IN ('owner','admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.ensure_current_household()
RETURNS TABLE (
  household_id uuid,
  household_name text,
  role text,
  member_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_full_name text;
  v_house_name text;
  v_household_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT u.email,
         COALESCE(u.raw_user_meta_data->>'full_name', split_part(u.email,'@',1), 'مستخدم'),
         COALESCE(u.raw_user_meta_data->>'house_name', 'بيتي')
  INTO v_email, v_full_name, v_house_name
  FROM auth.users u
  WHERE u.id = v_uid;

  INSERT INTO public.profiles(id, full_name, email)
  VALUES (v_uid, COALESCE(v_full_name,'مستخدم'), v_email)
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email;

  SELECT hu.household_id
  INTO v_household_id
  FROM public.household_users hu
  WHERE hu.user_id = v_uid AND hu.status = 'active'
  ORDER BY hu.created_at ASC
  LIMIT 1;

  IF v_household_id IS NULL THEN
    SELECT h.id
    INTO v_household_id
    FROM public.households h
    WHERE h.owner_id = v_uid
    ORDER BY h.created_at ASC
    LIMIT 1;

    IF v_household_id IS NULL THEN
      INSERT INTO public.households(owner_id, name)
      VALUES (v_uid, COALESCE(v_house_name,'بيتي'))
      RETURNING id INTO v_household_id;
    END IF;

    INSERT INTO public.household_users(
      household_id, user_id, role,
      can_add_expenses, can_add_commitments,
      can_view_income, can_view_reports, can_manage_members,
      status
    ) VALUES (
      v_household_id, v_uid, 'owner',
      true, true, true, true, true,
      'active'
    )
    ON CONFLICT (household_id, user_id) DO UPDATE SET
      role = CASE WHEN public.household_users.role IS NULL THEN 'owner' ELSE public.household_users.role END,
      status = 'active',
      can_add_expenses = true,
      can_add_commitments = true,
      can_view_income = true,
      can_view_reports = true,
      can_manage_members = true;
  END IF;

  INSERT INTO public.household_settings(household_id)
  VALUES (v_household_id)
  ON CONFLICT (household_id) DO NOTHING;

  RETURN QUERY
  SELECT hu.household_id, h.name, hu.role, hu.member_id
  FROM public.household_users hu
  JOIN public.households h ON h.id = hu.household_id
  WHERE hu.user_id = v_uid
    AND hu.household_id = v_household_id
    AND hu.status = 'active'
  LIMIT 1;
END;
$$;

-- 5) New user trigger
CREATE OR REPLACE FUNCTION public.handle_new_masrofi_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
#variable_conflict use_column
DECLARE
  v_household_id uuid;
  v_full_name text;
  v_house_name text;
BEGIN
  v_full_name := COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1), 'مستخدم');
  v_house_name := COALESCE(new.raw_user_meta_data->>'house_name', 'بيتي');

  INSERT INTO public.profiles(id, full_name, email)
  VALUES (new.id, v_full_name, new.email)
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email;

  INSERT INTO public.households(owner_id, name)
  VALUES (new.id, v_house_name)
  RETURNING id INTO v_household_id;

  INSERT INTO public.household_users(
    household_id, user_id, role,
    can_add_expenses, can_add_commitments,
    can_view_income, can_view_reports, can_manage_members,
    status
  ) VALUES (
    v_household_id, new.id, 'owner',
    true, true, true, true, true,
    'active'
  );

  INSERT INTO public.household_settings(household_id)
  VALUES (v_household_id)
  ON CONFLICT (household_id) DO NOTHING;

  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created_masrofi
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_masrofi_user();

-- 6) RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.households ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.household_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.household_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gam3eyas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gam3eya_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gam3eya_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_own_all ON public.profiles
FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY households_select ON public.households
FOR SELECT USING (owner_id = auth.uid() OR public.is_household_member(id));
CREATE POLICY households_insert ON public.households
FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY households_update ON public.households
FOR UPDATE USING (owner_id = auth.uid() OR public.is_household_admin(id))
WITH CHECK (owner_id = auth.uid() OR public.is_household_admin(id));
CREATE POLICY households_delete ON public.households
FOR DELETE USING (owner_id = auth.uid());

CREATE POLICY household_users_select ON public.household_users
FOR SELECT USING (public.household_users.user_id = auth.uid() OR public.is_household_admin(public.household_users.household_id));
CREATE POLICY household_users_insert ON public.household_users
FOR INSERT WITH CHECK (
  public.household_users.user_id = auth.uid()
  OR public.is_household_admin(public.household_users.household_id)
  OR EXISTS (SELECT 1 FROM public.households h WHERE h.id = public.household_users.household_id AND h.owner_id = auth.uid())
);
CREATE POLICY household_users_update ON public.household_users
FOR UPDATE USING (public.is_household_admin(public.household_users.household_id))
WITH CHECK (public.is_household_admin(public.household_users.household_id));
CREATE POLICY household_users_delete ON public.household_users
FOR DELETE USING (public.is_household_admin(public.household_users.household_id));

CREATE POLICY household_members_all ON public.household_members
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY household_settings_all ON public.household_settings
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY categories_all ON public.categories
FOR ALL USING (household_id IS NULL OR public.is_household_member(household_id))
WITH CHECK (household_id IS NULL OR public.is_household_member(household_id));

CREATE POLICY transactions_select ON public.transactions
FOR SELECT USING (public.is_household_member(household_id));
CREATE POLICY transactions_insert ON public.transactions
FOR INSERT WITH CHECK (public.is_household_member(household_id) AND created_by = auth.uid());
CREATE POLICY transactions_update ON public.transactions
FOR UPDATE USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));
CREATE POLICY transactions_delete ON public.transactions
FOR DELETE USING (public.is_household_member(household_id));

CREATE POLICY bills_all ON public.bills
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY installments_all ON public.installments
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY debts_all ON public.debts
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY budgets_all ON public.budgets
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY goals_all ON public.goals
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY gam3eyas_all ON public.gam3eyas
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY gam3eya_members_all ON public.gam3eya_members
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY gam3eya_payments_all ON public.gam3eya_payments
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY notifications_select ON public.notifications
FOR SELECT USING (public.is_household_member(household_id) AND (user_id = auth.uid() OR user_id IS NULL OR public.is_household_admin(household_id)));
CREATE POLICY notifications_insert ON public.notifications
FOR INSERT WITH CHECK (public.is_household_member(household_id) AND (user_id = auth.uid() OR user_id IS NULL));
CREATE POLICY notifications_update ON public.notifications
FOR UPDATE USING (public.is_household_member(household_id) AND (user_id = auth.uid() OR user_id IS NULL OR public.is_household_admin(household_id)))
WITH CHECK (public.is_household_member(household_id));
CREATE POLICY notifications_delete ON public.notifications
FOR DELETE USING (public.is_household_admin(household_id) OR user_id = auth.uid());

CREATE POLICY ai_chats_all ON public.ai_chats
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

CREATE POLICY challenges_all ON public.challenges
FOR ALL USING (public.is_household_member(household_id))
WITH CHECK (public.is_household_member(household_id));

-- 7) Grants
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_current_household() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_household_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_household_admin(uuid) TO authenticated;

-- 8) Reload PostgREST cache
NOTIFY pgrst, 'reload schema';
