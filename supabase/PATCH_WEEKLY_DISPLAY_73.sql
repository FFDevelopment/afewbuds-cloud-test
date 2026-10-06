CREATE OR REPLACE FUNCTION public.afb_leaderboard_get(p_metric text DEFAULT 'revenue'::text, p_range text DEFAULT 'lifetime'::text, p_limit integer DEFAULT 5, p_session_token text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_metric text := lower(trim(coalesce(p_metric, 'revenue')));
  v_range text := lower(trim(coalesce(p_range, 'lifetime')));
  v_limit integer := least(50, greatest(1, coalesce(p_limit, 5)));
  v_account uuid := null;
  v_week date := public.afb_leaderboard_week_start();
  v_top jsonb := '[]'::jsonb;
  v_me jsonb := null;
  v_count integer := 0;
begin
  if v_metric not in ('revenue','sales','dealer_sales','harvests','hybrids','raids','days','career_score') then
    raise exception 'leaderboard_metric_invalid';
  end if;
  if v_range not in ('lifetime','weekly') then
    raise exception 'leaderboard_range_invalid';
  end if;

  if nullif(coalesce(p_session_token,''),'') is not null then
    v_account := public.afb_account_from_token(p_session_token);
  end if;

  if v_range = 'weekly' then
    with valueset as (
      select
        st.account_id,
        a.username,
        case v_metric
          when 'revenue' then least(coalesce(w.revenue,0),st.lifetime_revenue)
          when 'sales' then least(coalesce(w.sales,0),st.sales)
          when 'dealer_sales' then least(coalesce(w.dealer_sales,0),st.dealer_sales)
          when 'harvests' then least(coalesce(w.harvests,0),st.harvests)
          when 'hybrids' then least(coalesce(w.hybrids_created,0),st.hybrids_created)
          when 'raids' then least(coalesce(w.raids_survived,0),st.raids_survived)
          when 'days' then least(coalesce(w.days_played,0),greatest(st.days_played-1,0))
          when 'career_score' then
            (least(coalesce(w.revenue,0),st.lifetime_revenue) / 10)
            + least(coalesce(w.sales,0),st.sales) * 20
            + least(coalesce(w.dealer_sales,0),st.dealer_sales) * 15
            + least(coalesce(w.harvests,0),st.harvests) * 50
            + least(coalesce(w.hybrids_created,0),st.hybrids_created) * 100
            + least(coalesce(w.raids_survived,0),st.raids_survived) * 250
            + least(coalesce(w.days_played,0),greatest(st.days_played-1,0)) * 25
        end::bigint as value
      from public.afb_leaderboard_state st
      join public.afb_player_accounts a on a.id = st.account_id
      left join public.afb_leaderboard_weekly w
        on w.account_id = st.account_id
       and w.week_start = v_week
    ),
    ranked as (
      select
        account_id,
        username,
        value,
        row_number() over(order by value desc, lower(username), account_id) as rank
      from valueset
      where value > 0
    )
    select
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'account_id', account_id,
            'username', username,
            'value', value,
            'rank', rank
          )
          order by rank
        ),
        '[]'::jsonb
      )
      into v_top
    from (select * from ranked order by rank limit v_limit) q;

    with valueset as (
      select
        st.account_id,
        a.username,
        case v_metric
          when 'revenue' then least(coalesce(w.revenue,0),st.lifetime_revenue)
          when 'sales' then least(coalesce(w.sales,0),st.sales)
          when 'dealer_sales' then least(coalesce(w.dealer_sales,0),st.dealer_sales)
          when 'harvests' then least(coalesce(w.harvests,0),st.harvests)
          when 'hybrids' then least(coalesce(w.hybrids_created,0),st.hybrids_created)
          when 'raids' then least(coalesce(w.raids_survived,0),st.raids_survived)
          when 'days' then least(coalesce(w.days_played,0),greatest(st.days_played-1,0))
          when 'career_score' then
            (least(coalesce(w.revenue,0),st.lifetime_revenue) / 10)
            + least(coalesce(w.sales,0),st.sales) * 20
            + least(coalesce(w.dealer_sales,0),st.dealer_sales) * 15
            + least(coalesce(w.harvests,0),st.harvests) * 50
            + least(coalesce(w.hybrids_created,0),st.hybrids_created) * 100
            + least(coalesce(w.raids_survived,0),st.raids_survived) * 250
            + least(coalesce(w.days_played,0),greatest(st.days_played-1,0)) * 25
        end::bigint as value
      from public.afb_leaderboard_state st
      join public.afb_player_accounts a on a.id = st.account_id
      left join public.afb_leaderboard_weekly w
        on w.account_id = st.account_id
       and w.week_start = v_week
    ),
    ranked as (
      select
        account_id,
        username,
        value,
        row_number() over(order by value desc, lower(username), account_id) as rank
      from valueset
      where value > 0
    )
    select jsonb_build_object(
      'account_id', account_id,
      'username', username,
      'value', value,
      'rank', rank
    )
      into v_me
    from ranked
    where account_id = v_account;

    select count(*)::integer into v_count
    from public.afb_leaderboard_state;
  else
    with valueset as (
      select
        st.account_id,
        a.username,
        case v_metric
          when 'revenue' then st.lifetime_revenue
          when 'sales' then st.sales
          when 'dealer_sales' then st.dealer_sales
          when 'harvests' then st.harvests
          when 'hybrids' then st.hybrids_created
          when 'raids' then st.raids_survived
          when 'days' then greatest(st.days_played - 1, 0)
          when 'career_score' then
            (st.lifetime_revenue / 10)
            + st.sales * 20
            + st.dealer_sales * 15
            + st.harvests * 50
            + st.hybrids_created * 100
            + st.raids_survived * 250
            + greatest(st.days_played - 1, 0) * 25
        end::bigint as value
      from public.afb_leaderboard_state st
      join public.afb_player_accounts a on a.id = st.account_id
    ),
    ranked as (
      select
        account_id,
        username,
        value,
        row_number() over(order by value desc, lower(username), account_id) as rank
      from valueset
    )
    select
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'account_id', account_id,
            'username', username,
            'value', value,
            'rank', rank
          )
          order by rank
        ),
        '[]'::jsonb
      )
      into v_top
    from (select * from ranked order by rank limit v_limit) q;

    with valueset as (
      select
        st.account_id,
        a.username,
        case v_metric
          when 'revenue' then st.lifetime_revenue
          when 'sales' then st.sales
          when 'dealer_sales' then st.dealer_sales
          when 'harvests' then st.harvests
          when 'hybrids' then st.hybrids_created
          when 'raids' then st.raids_survived
          when 'days' then greatest(st.days_played - 1, 0)
          when 'career_score' then
            (st.lifetime_revenue / 10)
            + st.sales * 20
            + st.dealer_sales * 15
            + st.harvests * 50
            + st.hybrids_created * 100
            + st.raids_survived * 250
            + greatest(st.days_played - 1, 0) * 25
        end::bigint as value
      from public.afb_leaderboard_state st
      join public.afb_player_accounts a on a.id = st.account_id
    ),
    ranked as (
      select
        account_id,
        username,
        value,
        row_number() over(order by value desc, lower(username), account_id) as rank
      from valueset
    )
    select jsonb_build_object(
      'account_id', account_id,
      'username', username,
      'value', value,
      'rank', rank
    )
      into v_me
    from ranked
    where account_id = v_account;

    select count(*)::integer into v_count
    from public.afb_leaderboard_state;
  end if;

  return jsonb_build_object(
    'metric', v_metric,
    'range', v_range,
    'limit', v_limit,
    'player_count', v_count,
    'week_start', v_week,
    'week_ends_at', ((v_week + 7)::timestamp at time zone 'America/New_York'),
    'top', v_top,
    'me', v_me
  );
end;
$function$

