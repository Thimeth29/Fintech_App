-- supabase_schema.sql
-- Run this once in your Supabase project's SQL Editor
-- (https://supabase.com/dashboard/project/zgpvwddcduemjkldzcvl/sql/new)
-- before using the app. It creates the four tables the app reads/writes
-- and locks each one down with Row Level Security so a user can only
-- see and edit their own rows.

-- 1. Profiles ---------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  mobile text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Auto-create a profile row whenever someone signs up, from the
-- name/mobile metadata passed to supabase.auth.signUp(). The app also
-- upserts this directly as a fallback, so this trigger is optional but
-- recommended.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, email, mobile)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    new.email,
    new.raw_user_meta_data->>'mobile'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. Expenses ----------------------------------------------------------
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null check (amount > 0),
  category text not null,
  note text,
  created_at timestamptz not null default now()
);

alter table public.expenses enable row level security;

create policy "Users can manage own expenses"
  on public.expenses for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 3. Investment actions (history) --------------------------------------
create table if not exists public.investment_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  asset_type text not null,   -- 'CSE' | 'SEC' | 'FD' | 'GOLD'
  symbol text not null,
  action text not null,       -- 'buy' | 'sell' | 'considered'
  amount numeric not null default 0,
  created_at timestamptz not null default now()
);

alter table public.investment_actions enable row level security;

create policy "Users can manage own investment actions"
  on public.investment_actions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 4. Chat history (optional persistence for the AI Analyst / Ask the Bot) ---
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,   -- 'user' | 'bot'
  content text not null,
  created_at timestamptz not null default now()
);

alter table public.chat_messages enable row level security;

create policy "Users can manage own chat messages"
  on public.chat_messages for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
