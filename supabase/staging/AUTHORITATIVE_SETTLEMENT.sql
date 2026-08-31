-- STAGING ONLY — never apply to hwyxtklbffqwcbtuetit or any live project.
--
-- Atomic virtual-point settlement for a submitted slip. Gated by
-- juicd_runtime_config.staging_authoritative_settlement = 'on'.
-- Math must match supabase/functions/resolve-play-slip/settlement.ts
-- (stake 25 at combined odds 2.0 → debit 25, credit 50, season +25).
--
-- This does not flip outcome_mode. Live-event settlement remains an
-- owner/counsel decision.

begin;

insert into public.juicd_runtime_config (key, value)
values ('staging_authoritative_settlement', 'off')
on conflict (key) do nothing;

create or replace function public.juicd_staging_settle_slip(
  p_user_id uuid,
  p_slip_id uuid,
  p_outcomes jsonb,
  p_slate_key text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gate text;
  v_slip public.juicd_bet_slips%rowtype;
  v_did_win boolean;
  v_payout integer;
  v_season integer;
  v_available integer;
begin
  select value into v_gate
  from public.juicd_runtime_config
  where key = 'staging_authoritative_settlement';

  if v_gate is distinct from 'on' then
    raise exception 'authoritative settlement is staging-gated';
  end if;

  if p_user_id is null or p_slip_id is null then
    raise exception 'user and slip are required';
  end if;

  if jsonb_typeof(p_outcomes) is distinct from 'array' or jsonb_array_length(p_outcomes) = 0 then
    raise exception 'outcomes required';
  end if;

  select * into v_slip
  from public.juicd_bet_slips
  where id = p_slip_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'slip not found';
  end if;

  if v_slip.status = 'resolved' then
    return jsonb_build_object(
      'idempotent', true,
      'slipId', v_slip.id,
      'didWin', v_slip.did_win,
      'seasonPointsEarned', v_slip.season_points_earned
    );
  end if;

  if v_slip.status is distinct from 'submitted' then
    raise exception 'slip not submitted';
  end if;

  if v_slip.stake_points <= 0 then
    raise exception 'invalid stake';
  end if;

  v_did_win := not exists (
    select 1
    from jsonb_array_elements(p_outcomes) as o
    where coalesce((o->>'didWin')::boolean, false) = false
  );

  v_payout := case
    when v_did_win and v_slip.combined_odds > 1
      then floor(v_slip.stake_points * v_slip.combined_odds)::integer
    else 0
  end;
  v_season := case when v_did_win then v_slip.stake_points else 0 end;

  select available_daily_points into v_available
  from public.juicd_profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'profile not found';
  end if;

  if v_available < v_slip.stake_points then
    raise exception 'insufficient points';
  end if;

  insert into public.juicd_points_ledger (user_id, bet_slip_id, delta_points, reason)
  values (p_user_id, p_slip_id, -v_slip.stake_points, 'play stake');

  if v_payout > 0 then
    insert into public.juicd_points_ledger (user_id, bet_slip_id, delta_points, reason)
    values (p_user_id, p_slip_id, v_payout, 'play payout');
  end if;

  update public.juicd_profiles
  set available_daily_points = available_daily_points - v_slip.stake_points + v_payout,
      season_points_won = season_points_won + v_season,
      all_time_points_won = all_time_points_won + v_season,
      updated_at = now()
  where id = p_user_id;

  update public.juicd_bet_slips
  set status = 'resolved',
      did_win = v_did_win,
      season_points_earned = v_season,
      play_leg_wins = (
        select count(*) from jsonb_array_elements(p_outcomes) o
        where coalesce((o->>'didWin')::boolean, false)
      ),
      play_leg_losses = (
        select count(*) from jsonb_array_elements(p_outcomes) o
        where not coalesce((o->>'didWin')::boolean, false)
      ),
      resolved_at = now()
  where id = p_slip_id;

  return jsonb_build_object(
    'idempotent', false,
    'slipId', p_slip_id,
    'didWin', v_did_win,
    'payoutPoints', v_payout,
    'seasonPointsEarned', v_season,
    'slateKey', p_slate_key
  );
end;
$$;

revoke all on function public.juicd_staging_settle_slip(uuid, uuid, jsonb, text)
  from public, anon, authenticated;
-- Staging Edge Function calls this with the service role only.

commit;
