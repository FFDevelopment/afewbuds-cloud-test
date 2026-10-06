begin;
do $$
declare a uuid; t text; n bigint; got bigint; report jsonb;
begin
 select id into a from public.afb_player_accounts where lower(username)='jkaay';
 if a is null then raise exception 'Test account missing'; end if;
 t:=public.afb_make_session(a,false)->>'session_token';
 update public.afb_leaderboard_state set lifetime_revenue=27000,high_water=jsonb_set(high_water,'{lifetime_revenue}','27000') where account_id=a;
 insert into public.afb_leaderboard_weekly(account_id,week_start,revenue) values(a,public.afb_leaderboard_week_start(),5000) on conflict(account_id,week_start) do update set revenue=5000;
 foreach n in array array[27000::bigint,0::bigint,27000::bigint,28000::bigint,28000::bigint] loop
  update public.afb_player_saves set save_json=jsonb_set(save_json,'{lifetime_revenue}',to_jsonb(n)) where account_id=a;
  report:=public.afb_leaderboard_report(t);
  select revenue into got from public.afb_leaderboard_weekly where account_id=a and week_start=public.afb_leaderboard_week_start();
  if got != (case when n=28000 then 6000 else 5000 end) then raise exception 'Repeated earning detected: %, %',n,got; end if;
  if n=0 and exists(select 1 from jsonb_array_elements(public.afb_leaderboard_get('revenue','weekly',50,t)->'top') e where e->>'username'='Jkaay' and (e->>'value')::bigint>0) then raise exception 'Weekly display exceeded current lifetime'; end if;
 end loop;
end $$;
select 'PASS regression, restored save, new earnings, repeated report and weekly display bounds' as verification;
rollback;
