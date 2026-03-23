-- Juicd — friends & requests (production sketch; client prototype mirrors this in memory)
-- Run in Supabase SQL editor or via CLI after `juicd` project is linked.

-- Canonical friendship edge: lexicographic UUID order prevents duplicate rows (A,B) vs (B,A).
create table if not exists public.juicd_friendships (
  user_low uuid not null references auth.users (id) on delete cascade,
  user_high uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low, user_high),
  constraint juicd_friendships_order check (user_low < user_high)
);

create index if not exists juicd_friendships_low on public.juicd_friendships (user_low);
create index if not exists juicd_friendships_high on public.juicd_friendships (user_high);

-- Pending invites; delete row on accept (insert friendship) or reject/cancel.
create table if not exists public.juicd_friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null references auth.users (id) on delete cascade,
  to_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint juicd_friend_requests_no_self check (from_id <> to_id),
  constraint juicd_friend_requests_unique_pending unique (from_id, to_id)
);

create index if not exists juicd_friend_requests_to on public.juicd_friend_requests (to_id);
create index if not exists juicd_friend_requests_from on public.juicd_friend_requests (from_id);

-- Public profile fields for leaderboard / search (if not already on `profiles`).
-- Ensure `mmr` and `display_name` exist on your profiles table; add if missing:
-- alter table public.profiles add column if not exists mmr double precision;
-- alter table public.profiles add column if not exists display_name text;

alter table public.juicd_friendships enable row level security;
alter table public.juicd_friend_requests enable row level security;

-- RLS: users read/write only their edges (friendships).
create policy "friendships_select_own"
  on public.juicd_friendships for select
  using (auth.uid() = user_low or auth.uid() = user_high);

-- Inserts/deletes should be done via RPC or service role in production; minimal policy for dev:
create policy "friendships_insert_own_edge"
  on public.juicd_friendships for insert
  with check (auth.uid() = user_low or auth.uid() = user_high);

create policy "friendships_delete_own_edge"
  on public.juicd_friendships for delete
  using (auth.uid() = user_low or auth.uid() = user_high);

-- Requests: participants only.
create policy "friend_requests_select_participant"
  on public.juicd_friend_requests for select
  using (auth.uid() = from_id or auth.uid() = to_id);

create policy "friend_requests_insert_sender"
  on public.juicd_friend_requests for insert
  with check (auth.uid() = from_id);

create policy "friend_requests_delete_participant"
  on public.juicd_friend_requests for delete
  using (auth.uid() = from_id or auth.uid() = to_id);

comment on table public.juicd_friendships is 'Undirected friend edges; ordered UUID pair.';
comment on table public.juicd_friend_requests is 'Pending friend requests; remove on accept/reject.';
