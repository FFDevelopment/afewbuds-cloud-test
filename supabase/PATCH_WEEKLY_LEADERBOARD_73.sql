begin;
alter table public.afb_leaderboard_state add column if not exists high_water jsonb not null default '{}'::jsonb;
update public.afb_leaderboard_state set high_water=jsonb_build_object('lifetime_revenue',lifetime_revenue,'sales',sales,'dealer_sales',dealer_sales,'harvests',harvests,'hybrids_created',hybrids_created,'raids_survived',raids_survived,'days_played',days_played) where high_water='{}'::jsonb;
create table if not exists public.afb_leaderboard_repair_archive (
 id bigint generated always as identity primary key,
 repaired_at timestamptz not null default now(),
 reason text not null,
 original_row jsonb not null
);
alter table public.afb_leaderboard_repair_archive enable row level security;
revoke all on public.afb_leaderboard_repair_archive from public,anon,authenticated;
create or replace function public.afb_leaderboard_report(p_session_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_account uuid := public.afb_account_from_token(p_session_token);
  v_save jsonb;
  v_week date := public.afb_leaderboard_week_start();
  v_old public.afb_leaderboard_state%rowtype;

  v_revenue bigint := 0;
  v_sales bigint := 0;
  v_dealer_sales bigint := 0;
  v_harvests bigint := 0;
  v_hybrids bigint := 0;
  v_raids bigint := 0;
  v_days bigint := 1;
  v_grower_level integer := 1;
  v_grower_xp bigint := 0;
  v_reputation integer := 0;
  v_customers_known integer := 0;
  v_milestones integer := 0;

  d_revenue bigint := 0;
  d_sales bigint := 0;
  d_dealer_sales bigint := 0;
  d_harvests bigint := 0;
  d_hybrids bigint := 0;
  d_raids bigint := 0;
  d_days bigint := 0;
begin
  if v_account is null then
    raise exception 'session_invalid';
  end if;

  -- Serialize reports before reading the latest saved snapshot.
  perform 1 from public.afb_player_accounts where id=v_account for update;

  select s.save_json
    into v_save
  from public.afb_player_saves s
  where s.account_id = v_account;

  if v_save is null or jsonb_typeof(v_save) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'save_missing');
  end if;

  v_revenue := public.afb_leaderboard_int(v_save, 'lifetime_revenue', 1000000000000);
  v_sales := public.afb_leaderboard_nested_int(v_save, 'advancement_stats', 'sales', 1000000000);
  v_dealer_sales := public.afb_leaderboard_nested_int(v_save, 'advancement_stats', 'dealer_sales', 1000000000);
  v_harvests := public.afb_leaderboard_nested_int(v_save, 'advancement_stats', 'harvests', 1000000000);
  v_hybrids := public.afb_leaderboard_nested_int(v_save, 'advancement_stats', 'hybrids_created', 1000000000);
  v_raids := greatest(
    public.afb_leaderboard_int(v_save, 'raids_survived', 100000000),
    public.afb_leaderboard_nested_int(v_save, 'advancement_stats', 'raids_survived', 100000000)
  );
  v_days := greatest(1, public.afb_leaderboard_int(v_save, 'game_day', 1000000));
  v_grower_level := greatest(1, public.afb_leaderboard_int(v_save, 'grower_level', 100000)::integer);
  v_grower_xp := public.afb_leaderboard_int(v_save, 'grower_xp', 1000000000);
  v_reputation := public.afb_leaderboard_int(v_save, 'reputation', 1000000000)::integer;
  v_customers_known := public.afb_leaderboard_nested_int(v_save, 'advancement_stats', 'customers_known', 1000000)::integer;

  if jsonb_typeof(v_save -> 'advancement_claimed') = 'object' then
    select count(*)::integer
      into v_milestones
    from jsonb_each(v_save -> 'advancement_claimed') e
    where e.value = 'true'::jsonb;
  end if;

  select *
    into v_old
  from public.afb_leaderboard_state
  where account_id = v_account
  for update;

  if not found then
    insert into public.afb_leaderboard_state (
      account_id, lifetime_revenue, sales, dealer_sales, harvests,
      hybrids_created, raids_survived, days_played, grower_level,
      grower_xp, reputation, customers_known, milestones_claimed, updated_at
    ) values (
      v_account, v_revenue, v_sales, v_dealer_sales, v_harvests,
      v_hybrids, v_raids, v_days, v_grower_level,
      v_grower_xp, v_reputation, v_customers_known, v_milestones, now()
    );
    return jsonb_build_object('ok', true, 'week_start', v_week, 'initialized', true);
  end if;

  d_revenue := greatest(v_revenue - coalesce((v_old.high_water->>'lifetime_revenue')::bigint,v_old.lifetime_revenue), 0);
  d_sales := greatest(v_sales - coalesce((v_old.high_water->>'sales')::bigint,v_old.sales), 0);
  d_dealer_sales := greatest(v_dealer_sales - coalesce((v_old.high_water->>'dealer_sales')::bigint,v_old.dealer_sales), 0);
  d_harvests := greatest(v_harvests - coalesce((v_old.high_water->>'harvests')::bigint,v_old.harvests), 0);
  d_hybrids := greatest(v_hybrids - coalesce((v_old.high_water->>'hybrids_created')::bigint,v_old.hybrids_created), 0);
  d_raids := greatest(v_raids - coalesce((v_old.high_water->>'raids_survived')::bigint,v_old.raids_survived), 0);
  d_days := greatest(v_days - coalesce((v_old.high_water->>'days_played')::bigint,v_old.days_played), 0);

  insert into public.afb_leaderboard_weekly (
    account_id, week_start, revenue, sales, dealer_sales,
    harvests, hybrids_created, raids_survived, days_played, updated_at
  ) values (
    v_account, v_week, d_revenue, d_sales, d_dealer_sales,
    d_harvests, d_hybrids, d_raids, d_days, now()
  )
  on conflict (account_id, week_start) do update
    set revenue = public.afb_leaderboard_weekly.revenue + excluded.revenue,
        sales = public.afb_leaderboard_weekly.sales + excluded.sales,
        dealer_sales = public.afb_leaderboard_weekly.dealer_sales + excluded.dealer_sales,
        harvests = public.afb_leaderboard_weekly.harvests + excluded.harvests,
        hybrids_created = public.afb_leaderboard_weekly.hybrids_created + excluded.hybrids_created,
        raids_survived = public.afb_leaderboard_weekly.raids_survived + excluded.raids_survived,
        days_played = public.afb_leaderboard_weekly.days_played + excluded.days_played,
        updated_at = now();

  update public.afb_leaderboard_state
     set high_water = jsonb_build_object(
       'lifetime_revenue', greatest(v_revenue,coalesce((v_old.high_water->>'lifetime_revenue')::bigint,v_old.lifetime_revenue)),
       'sales', greatest(v_sales,coalesce((v_old.high_water->>'sales')::bigint,v_old.sales)),
       'dealer_sales', greatest(v_dealer_sales,coalesce((v_old.high_water->>'dealer_sales')::bigint,v_old.dealer_sales)),
       'harvests', greatest(v_harvests,coalesce((v_old.high_water->>'harvests')::bigint,v_old.harvests)),
       'hybrids_created', greatest(v_hybrids,coalesce((v_old.high_water->>'hybrids_created')::bigint,v_old.hybrids_created)),
       'raids_survived', greatest(v_raids,coalesce((v_old.high_water->>'raids_survived')::bigint,v_old.raids_survived)),
       'days_played', greatest(v_days,coalesce((v_old.high_water->>'days_played')::bigint,v_old.days_played))
     ),
         lifetime_revenue = v_revenue,
         sales = v_sales,
         dealer_sales = v_dealer_sales,
         harvests = v_harvests,
         hybrids_created = v_hybrids,
         raids_survived = v_raids,
         days_played = v_days,
         grower_level = v_grower_level,
         grower_xp = v_grower_xp,
         reputation = v_reputation,
         customers_known = v_customers_known,
         milestones_claimed = v_milestones,
         updated_at = now()
   where account_id = v_account;

  return jsonb_build_object(
    'ok', true,
    'week_start', v_week,
    'delta', jsonb_build_object(
      'revenue', d_revenue,
      'sales', d_sales,
      'dealer_sales', d_dealer_sales,
      'harvests', d_harvests,
      'hybrids', d_hybrids,
      'raids', d_raids,
      'days', d_days
    )
  );
end;
$$;

revoke execute on function public.afb_leaderboard_report(text) from public;
grant execute on function public.afb_leaderboard_report(text) to anon, authenticated;

-- Public read endpoint. It returns username + one selected gameplay metric only.

insert into public.afb_leaderboard_repair_archive(reason,original_row)
select 'Weekly counters exceeded lifetime; reset only impossible counters',to_jsonb(w)
from public.afb_leaderboard_weekly w join public.afb_leaderboard_state st using(account_id)
where w.week_start=public.afb_leaderboard_week_start() and (w.revenue>st.lifetime_revenue or w.sales>st.sales or w.dealer_sales>st.dealer_sales or w.harvests>st.harvests or w.hybrids_created>st.hybrids_created or w.raids_survived>st.raids_survived or w.days_played>greatest(st.days_played-1,0));
update public.afb_leaderboard_weekly w set
 revenue=case when w.revenue>st.lifetime_revenue then 0 else w.revenue end,
 sales=case when w.sales>st.sales then 0 else w.sales end,
 dealer_sales=case when w.dealer_sales>st.dealer_sales then 0 else w.dealer_sales end,
 harvests=case when w.harvests>st.harvests then 0 else w.harvests end,
 hybrids_created=case when w.hybrids_created>st.hybrids_created then 0 else w.hybrids_created end,
 raids_survived=case when w.raids_survived>st.raids_survived then 0 else w.raids_survived end,
 days_played=case when w.days_played>greatest(st.days_played-1,0) then 0 else w.days_played end,
 updated_at=now()
from public.afb_leaderboard_state st
where w.account_id=st.account_id and w.week_start=public.afb_leaderboard_week_start() and (w.revenue>st.lifetime_revenue or w.sales>st.sales or w.dealer_sales>st.dealer_sales or w.harvests>st.harvests or w.hybrids_created>st.hybrids_created or w.raids_survived>st.raids_survived or w.days_played>greatest(st.days_played-1,0));
commit;
