begin;
-- Lock accounts in a stable order, matching leaderboard reports.
select id from public.afb_player_accounts order by id for update;
insert into public.afb_leaderboard_repair_archive(reason,original_row) select 'Global weekly restart: historical weekly accounting cannot be reconstructed',to_jsonb(w) from public.afb_leaderboard_weekly w where week_start=public.afb_leaderboard_week_start();
update public.afb_leaderboard_state st set high_water=jsonb_build_object('lifetime_revenue',greatest(st.lifetime_revenue,coalesce((st.high_water->>'lifetime_revenue')::bigint,0)),'sales',greatest(st.sales,coalesce((st.high_water->>'sales')::bigint,0)),'dealer_sales',greatest(st.dealer_sales,coalesce((st.high_water->>'dealer_sales')::bigint,0)),'harvests',greatest(st.harvests,coalesce((st.high_water->>'harvests')::bigint,0)),'hybrids_created',greatest(st.hybrids_created,coalesce((st.high_water->>'hybrids_created')::bigint,0)),'raids_survived',greatest(st.raids_survived,coalesce((st.high_water->>'raids_survived')::bigint,0)),'days_played',greatest(st.days_played,coalesce((st.high_water->>'days_played')::bigint,1)));
update public.afb_leaderboard_weekly set revenue=0,sales=0,dealer_sales=0,harvests=0,hybrids_created=0,raids_survived=0,days_played=0,updated_at=now() where week_start=public.afb_leaderboard_week_start();
commit;
