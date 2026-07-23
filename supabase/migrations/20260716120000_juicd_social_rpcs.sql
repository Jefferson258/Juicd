-- Social RPCs + friend codes for multi-device beta testing.
-- Idempotent.

-- Short shareable code for friend search (in addition to display_name).
alter table public.juicd_profiles
  add column if not exists friend_code text;

create unique index if not exists juicd_profiles_friend_code_uidx
  on public.juicd_profiles (friend_code)
  where friend_code is not null;

create or replace function public.juicd_generate_friend_code()
  returns text language plpgsql as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  i int;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (
      select 1 from public.juicd_profiles p where p.friend_code = code
    );
  end loop;
  return code;
end;
$$;

create or replace function public.juicd_ensure_friend_code()
  returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.friend_code is null or length(trim(new.friend_code)) = 0 then
    new.friend_code := public.juicd_generate_friend_code();
  end if;
  return new;
end;
$$;

drop trigger if exists juicd_profiles_friend_code_bi on public.juicd_profiles;
create trigger juicd_profiles_friend_code_bi
  before insert on public.juicd_profiles
  for each row execute function public.juicd_ensure_friend_code();

-- Backfill existing profiles missing a code.
update public.juicd_profiles
set friend_code = public.juicd_generate_friend_code()
where friend_code is null;

-- Accept a pending request atomically.
create or replace function public.juicd_accept_friend_request(p_request_id uuid)
  returns boolean
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  r public.juicd_friend_requests%rowtype;
  lo uuid;
  hi uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into r
  from public.juicd_friend_requests
  where id = p_request_id
  for update;

  if not found then
    return false;
  end if;

  if r.to_id <> auth.uid() then
    raise exception 'only recipient can accept';
  end if;

  if r.from_id < r.to_id then
    lo := r.from_id; hi := r.to_id;
  else
    lo := r.to_id; hi := r.from_id;
  end if;

  insert into public.juicd_friendships (user_low, user_high)
  values (lo, hi)
  on conflict do nothing;

  delete from public.juicd_friend_requests where id = p_request_id;
  return true;
end;
$$;

-- Create a group + owner membership in one call.
create or replace function public.juicd_create_group(p_name text)
  returns public.juicd_groups
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  g public.juicd_groups%rowtype;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  i int;
  clean_name text := left(trim(coalesce(p_name, '')), 60);
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if length(clean_name) < 1 then
    raise exception 'name required';
  end if;

  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.juicd_groups where invite_code = code);
  end loop;

  insert into public.juicd_groups (name, invite_code, created_by)
  values (clean_name, code, auth.uid())
  returning * into g;

  insert into public.juicd_group_members (group_id, user_id, role)
  values (g.id, auth.uid(), 'owner');

  return g;
end;
$$;

grant execute on function public.juicd_accept_friend_request(uuid) to authenticated;
grant execute on function public.juicd_create_group(text) to authenticated;
grant execute on function public.juicd_join_group_by_code(text) to authenticated;
grant execute on function public.juicd_my_group_ids() to authenticated;

grant select on public.juicd_season_leaderboard to authenticated;
grant select on public.juicd_alltime_leaderboard to authenticated;
grant select on public.juicd_career_betting_stats to authenticated;
