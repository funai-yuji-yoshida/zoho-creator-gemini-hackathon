-- =========================================================
-- 最終審査ボード  Supabase スキーマ
-- Supabase ダッシュボード > SQL Editor に貼り付けて実行してください。
-- 実行前に、最下部の「主催者PIN」を必ず書き換えてください。
-- =========================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- テーブル ----------
create table if not exists public.event (
  id         int primary key default 1 check (id = 1),
  title      text not null default 'Gemini × Zoho Creator AIハッカソン 最終審査',
  open       boolean not null default true,      -- 参加者に結果を表示するか
  rev        bigint not null default 0,          -- 変更通知用カウンタ
  updated_at timestamptz not null default now()
);
insert into public.event (id) values (1) on conflict (id) do nothing;

create table if not exists public.teams (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 100),
  product    text not null default '' check (char_length(product) <= 200),
  created_at timestamptz not null default now()
);

create table if not exists public.judges (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 60),
  created_at timestamptz not null default now()
);

create table if not exists public.judge_pins (
  judge_id uuid primary key references public.judges(id) on delete cascade,
  pin_hash text not null
);

create table if not exists public.admin_pin (
  id       int primary key default 1 check (id = 1),
  pin_hash text not null
);

create table if not exists public.scores (
  judge_id   uuid not null references public.judges(id) on delete cascade,
  team_id    uuid not null references public.teams(id)  on delete cascade,
  impact     int  not null check (impact between 1 and 10),
  tech       int  not null check (tech   between 1 and 10),
  ux         int  not null check (ux     between 1 and 10),
  comment    text not null default '' check (char_length(comment) <= 2000),
  updated_at timestamptz not null default now(),
  primary key (judge_id, team_id)
);

-- ---------- アクセス制御 ----------
-- 誰でも読める：イベント設定・チーム・審査員名
-- 直接は読めない：採点（get_scores 経由）・PIN
-- 書き込みはすべて PIN を確認する関数経由のみ
alter table public.event      enable row level security;
alter table public.teams      enable row level security;
alter table public.judges     enable row level security;
alter table public.judge_pins enable row level security;
alter table public.admin_pin  enable row level security;
alter table public.scores     enable row level security;

drop policy if exists "public read" on public.event;
drop policy if exists "public read" on public.teams;
drop policy if exists "public read" on public.judges;
create policy "public read" on public.event  for select to anon, authenticated using (true);
create policy "public read" on public.teams  for select to anon, authenticated using (true);
create policy "public read" on public.judges for select to anon, authenticated using (true);

revoke all on public.judge_pins, public.admin_pin, public.scores from anon, authenticated;
revoke insert, update, delete on public.event, public.teams, public.judges from anon, authenticated;

-- ---------- 内部ヘルパー（外部からは呼べない） ----------
create or replace function public._is_admin(p_pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from admin_pin where pin_hash = crypt(coalesce(p_pin, ''), pin_hash));
$$;

create or replace function public._is_judge(p_judge uuid, p_pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from judge_pins
                 where judge_id = p_judge and pin_hash = crypt(coalesce(p_pin, ''), pin_hash));
$$;

create or replace function public._bump() returns void
language sql security definer set search_path = public as $$
  update event set rev = rev + 1, updated_at = now() where id = 1;
$$;

create or replace function public._require_admin(p_pin text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not _is_admin(p_pin) then
    raise exception '主催者PINが正しくありません' using errcode = '42501';
  end if;
end $$;

revoke execute on function public._is_admin(text), public._is_judge(uuid, text),
  public._bump(), public._require_admin(text) from public, anon, authenticated;

-- ---------- 公開API ----------
create or replace function public.verify_login(p_role text, p_judge uuid, p_pin text) returns boolean
language sql stable security definer set search_path = public as $$
  select case when p_role = 'admin' then _is_admin(p_pin)
              when p_role = 'judge' then _is_judge(p_judge, p_pin)
              else false end;
$$;

-- 結果を公開中なら誰でも、非公開中は主催者・審査員のみ採点を取得できる
create or replace function public.get_scores(p_judge uuid default null, p_pin text default null)
returns setof public.scores
language plpgsql stable security definer set search_path = public as $$
begin
  if (select open from event where id = 1) or _is_admin(p_pin) or _is_judge(p_judge, p_pin) then
    return query select * from scores;
  end if;
end $$;

create or replace function public.submit_score(p_judge uuid, p_pin text, p_team uuid,
  p_impact int, p_tech int, p_ux int, p_comment text default '') returns void
language plpgsql security definer set search_path = public as $$
begin
  if not _is_judge(p_judge, p_pin) then
    raise exception '審査員PINが正しくありません' using errcode = '42501';
  end if;
  insert into scores (judge_id, team_id, impact, tech, ux, comment, updated_at)
  values (p_judge, p_team, p_impact, p_tech, p_ux, coalesce(trim(p_comment), ''), now())
  on conflict (judge_id, team_id) do update
    set impact = excluded.impact, tech = excluded.tech, ux = excluded.ux,
        comment = excluded.comment, updated_at = now();
  perform _bump();
end $$;

create or replace function public.admin_update_event(p_pin text, p_title text, p_open boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_admin(p_pin);
  update event set title = coalesce(nullif(trim(p_title), ''), title),
                   open  = coalesce(p_open, open) where id = 1;
  perform _bump();
end $$;

create or replace function public.admin_add_team(p_pin text, p_name text, p_product text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  perform _require_admin(p_pin);
  insert into teams (name, product) values (trim(p_name), coalesce(trim(p_product), '')) returning id into v;
  perform _bump();
  return v;
end $$;

create or replace function public.admin_delete_team(p_pin text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_admin(p_pin);
  delete from teams where id = p_id;
  perform _bump();
end $$;

create or replace function public.admin_add_judge(p_pin text, p_name text, p_judge_pin text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare v uuid;
begin
  perform _require_admin(p_pin);
  if p_judge_pin is null or char_length(p_judge_pin) < 4 then
    raise exception '審査員PINは4文字以上にしてください' using errcode = '22023';
  end if;
  insert into judges (name) values (trim(p_name)) returning id into v;
  insert into judge_pins (judge_id, pin_hash) values (v, crypt(p_judge_pin, gen_salt('bf')));
  perform _bump();
  return v;
end $$;

create or replace function public.admin_reset_judge_pin(p_pin text, p_id uuid, p_judge_pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _require_admin(p_pin);
  if p_judge_pin is null or char_length(p_judge_pin) < 4 then
    raise exception '審査員PINは4文字以上にしてください' using errcode = '22023';
  end if;
  update judge_pins set pin_hash = crypt(p_judge_pin, gen_salt('bf')) where judge_id = p_id;
end $$;

create or replace function public.admin_delete_judge(p_pin text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_admin(p_pin);
  delete from judges where id = p_id;
  perform _bump();
end $$;

create or replace function public.admin_wipe_scores(p_pin text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_admin(p_pin);
  delete from scores where true;
  perform _bump();
end $$;

grant execute on function
  public.verify_login(text, uuid, text),
  public.get_scores(uuid, text),
  public.submit_score(uuid, text, uuid, int, int, int, text),
  public.admin_update_event(text, text, boolean),
  public.admin_add_team(text, text, text),
  public.admin_delete_team(text, uuid),
  public.admin_add_judge(text, text, text),
  public.admin_reset_judge_pin(text, uuid, text),
  public.admin_delete_judge(text, uuid),
  public.admin_wipe_scores(text)
to anon, authenticated;

-- ---------- リアルタイム通知（event の更新を全画面に配信） ----------
do $$ begin
  alter publication supabase_realtime add table public.event;
exception when duplicate_object then null; end $$;

-- ---------- 主催者PIN（必ず書き換えてから実行） ----------
insert into public.admin_pin (id, pin_hash)
values (1, extensions.crypt('ここを主催者PINに書き換える', extensions.gen_salt('bf')))
on conflict (id) do update set pin_hash = excluded.pin_hash;
