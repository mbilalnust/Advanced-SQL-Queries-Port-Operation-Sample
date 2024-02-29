---- inquiryItvOee
        WITH day_cond AS
            (SELECT #{dDay}::TIMESTAMP start_time,
                    #{dDay}::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms' end_time)
        SELECT m.calendar_time_min,
               c.tml_close_min,
               m.calendar_time_min - c.tml_close_min top_min,
               m.calendar_time_min - c.tml_close_min - (m.util_time_min + c.unsch_down_time_min) - c.sch_down_time_min no_demand_min,
               c.sch_down_time_min,
               m.util_time_min + c.unsch_down_time_min at_min,
               c.unsch_down_time_min,
               c.offline_opr_delay_min,
               m.util_time_min,
               m.util_time_min - m.job_cycle_time_min online_opr_delay_min,
               c.tos_failure_online_min,
               c.online_down_time_min,
               m.util_time_min - m.job_cycle_time_min - c.tos_failure_online_min idle_time_min,
               m.log_in_idle_time_min,
               m.job_fetching_idle_time_min,
               m.drv_shift_idle_time_min,
               c.other_idle_time_min,
               m.job_cycle_time_min toc_min,
               job_cycle_waiting_time_min non_value_opr_time_min,
               m.job_cycle_time_min - m.job_cycle_waiting_time_min vot_min
          FROM (
                SELECT eq_type, COUNT(DISTINCT eq_no) * 24 * 60 calendar_time_min,
                       SUM(job_cycle_time_min) job_cycle_time_min, SUM(job_cycle_waiting_time_min) job_cycle_waiting_time_min, SUM(util_time_min) util_time_min, SUM(log_in_idle_time_min) log_in_idle_time_min,
                       COUNT(DISTINCT eq_no) * 24 * 60 - SUM(log_time_min) drv_shift_idle_time_min, SUM(job_fetching_idle_time_min) job_fetching_idle_time_min
                  FROM (
                        SELECT eq_type, eq_no, ign_on_time, ign_off_time, log_in_time, log_out_time, first_job_fetching_time, job_cycle_time_min, job_cycle_waiting_time_min,
                               CEIL(EXTRACT (EPOCH FROM ign_off_time - ign_on_time) / 60) util_time_min, GREATEST(CEIL(EXTRACT(EPOCH FROM log_in_time - ign_on_time) / 60), 0) log_in_idle_time_min,
                               CEIL(EXTRACT (EPOCH FROM log_out_time - log_in_time) / 60) log_time_min, GREATEST(CEIL(EXTRACT(EPOCH FROM first_job_fetching_time - log_in_time) / 60), 0) job_fetching_idle_time_min
                          FROM (
                                SELECT g.eq_type, g.eq_no, g.ign_on_time, g.ign_off_time, l.log_in_time, l.log_out_time, MIN(j.job_fetching_time) first_job_fetching_time,
                                       CEIL(SUM(j.job_cycle_time_sec) / 60) job_cycle_time_min, CEIL(SUM(j.job_cycle_waiting_time_sec) / 60) job_cycle_waiting_time_min
                                  FROM (
                                        SELECT bi_eg_eq_type EQ_TYPE, bi_eg_eq_no EQ_NO,
                                               GREATEST (bi_eg_ign_on_time, c.start_time) IGN_ON_TIME,
                                               LEAST (COALESCE(bi_eg_ign_off_time, NOW()), c.end_time) IGN_OFF_TIME
                                          FROM bi_eq_ignition g
                                               CROSS JOIN
                                               day_cond c
                                         WHERE bi_eg_tml_id = :tmlId
                                           AND bi_eg_eq_type = 'YT'
                                           AND (    (bi_eg_ign_off_time IS NULL AND bi_eg_ign_on_time <![CDATA[<]]> c.end_time)
                                                 OR (bi_eg_ign_on_time >= c.start_time AND bi_eg_ign_off_time <![CDATA[<=]]> c.end_time)
                                                 OR (bi_eg_ign_off_time > c.start_time AND bi_eg_ign_on_time <![CDATA[<]]> c.start_time)
                                                 OR (bi_eg_ign_on_time <![CDATA[<]]> c.end_time AND bi_eg_ign_off_time > c.end_time)
                                                 OR (bi_eg_ign_on_time <![CDATA[<]]> c.start_time AND bi_eg_ign_off_time > c.end_time)
                                               )
                                       ) g
                                       LEFT OUTER JOIN
                                       (
                                        SELECT bi_el_eq_type EQ_TYPE, bi_el_eq_no EQ_NO,
                                               GREATEST (bi_el_log_in_time, c.start_time) log_in_time,
                                               LEAST (COALESCE(bi_el_log_out_time, NOW()), c.end_time) log_out_time
                                          FROM bi_eq_login l
                                               CROSS JOIN
                                               day_cond c
                                         WHERE bi_el_tml_id = :tmlId
                                           AND bi_el_eq_type = 'YT'
                                           AND (    (bi_el_log_out_time IS NULL AND bi_el_log_in_time <![CDATA[<]]> c.end_time)
                                                 OR (bi_el_log_in_time >= c.start_time AND bi_el_log_out_time <![CDATA[<=]]> c.end_time)
                                                 OR (bi_el_log_out_time > c.start_time AND bi_el_log_in_time <![CDATA[<]]> c.start_time)
                                                 OR (bi_el_log_in_time <![CDATA[<]]> c.end_time AND bi_el_log_out_time > c.end_time)
                                                 OR (bi_el_log_in_time <![CDATA[<]]> c.start_time AND bi_el_log_out_time > c.end_time)
                                               )
                                       ) l
                                       ON (g.eq_no = l.eq_no AND g.ign_on_time <![CDATA[<=]]> l.log_in_time AND g.ign_off_time >= l.log_out_time)
                                       LEFT OUTER JOIN
                                       (
                                        SELECT eq_no, job_id, job_fetching_time, job_cmpl_time, sum(job_cycle_time_sec) job_cycle_time_sec, SUM (CASE WHEN activity_type = 'Waiting' THEN job_cycle_time_sec ELSE 0 END) job_cycle_waiting_time_sec
                                          FROM (SELECT bi_jh_eq_no eq_no, bi_jh_job_id job_id, bi_jh_job_fetching_time job_fetching_time, bi_jh_job_cmpl_time job_cmpl_time, (jsonb_array_elements(bi_jh_job_cycle_step) -> 'intervalSec')::NUMERIC job_cycle_time_sec,
                                                       jsonb_array_elements(bi_jh_job_cycle_step) ->> 'activityType' activity_type
                                                  FROM bi_job_hist j
                                                       CROSS JOIN
                                                       day_cond c
                                                 WHERE j.bi_jh_tml_id = :tmlId
                                                   AND j.bi_jh_eq_type = 'YT'
                                                   AND j.bi_jh_job_cmpl_time BETWEEN c.start_time AND c.end_time) m
                                        GROUP BY eq_no, job_id, job_fetching_time, job_cmpl_time
                                       ) j
                                       ON (l.eq_no = j.eq_no AND j.job_cmpl_time BETWEEN l.log_in_time AND l.log_out_time)
                                GROUP BY g.eq_type, g.eq_no, g.ign_on_time, g.ign_off_time, l.log_in_time, l.log_out_time) m
                        ) m
                GROUP BY eq_type
               ) m
               CROSS JOIN
               (SELECT COALESCE(MAX(CASE WHEN bi_ov_value_type = 'SCH_DOWN' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) sch_down_time_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'USCH_DOWN' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) unsch_down_time_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'TML_CLOSE' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) tml_close_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'OFFLINE_OPR_DELAY' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) offline_opr_delay_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'TOS_FAILURE_ONLINE' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) tos_failure_online_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'ONLINE_DOWN' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) online_down_time_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'OTHER_IDLE' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) other_idle_time_min
                  FROM public.bi_oee_tml_value
                 WHERE bi_ov_tml_id = :tmlId
                   AND bi_ov_eq_type = 'YT') c;
    
--- inquiryCraneOee
        WITH day_cond AS
            (SELECT #{dDay}::TIMESTAMP start_time,
                    #{dDay}::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms' end_time)
        SELECT m.calendar_time_min,
               c.tml_close_min,
               m.calendar_time_min - c.tml_close_min top_min,
               m.calendar_time_min - c.tml_close_min - (m.util_time_min + c.unsch_down_time_min) - c.sch_down_time_min no_demand_min,
               c.sch_down_time_min,
               m.util_time_min + c.unsch_down_time_min at_min,
               c.unsch_down_time_min,
               c.offline_opr_delay_min,
               m.util_time_min,
               m.util_time_min - m.job_cycle_time_min online_opr_delay_min,
               c.tos_failure_online_min,
               c.online_down_time_min,
               m.util_time_min - m.job_cycle_time_min - c.tos_failure_online_min idle_time_min,
               m.log_in_idle_time_min,
               m.job_fetching_idle_time_min,
               m.drv_shift_idle_time_min,
               c.other_idle_time_min,
               m.job_cycle_time_min toc_min,
               job_cycle_waiting_time_min non_value_opr_time_min,
               m.job_cycle_time_min - m.job_cycle_waiting_time_min + m.without_job_cycle_time_min vot_min,
               m.job_cycle_time_min - m.job_cycle_waiting_time_min execution_with_job_min,
               m.without_job_cycle_time_min rehandle_without_job_min
          FROM (
                SELECT eq_type, count(DISTINCT eq_no) * 24 * 60 calendar_time_min,
                       sum(job_cycle_time_min) job_cycle_time_min, sum(job_cycle_waiting_time_min) job_cycle_waiting_time_min, sum(util_time_min) util_time_min, sum(log_in_idle_time_min) log_in_idle_time_min,
                       count(DISTINCT eq_no) * 24 * 60 - sum(log_time_min) drv_shift_idle_time_min, sum(job_fetching_idle_time_min) job_fetching_idle_time_min, sum(without_job_cycle_time_min) without_job_cycle_time_min
                  FROM (
                        SELECT eq_type, eq_no, ign_on_time, ign_off_time, log_in_time, log_out_time, first_job_fetching_time, job_cycle_time_min, job_cycle_waiting_time_min,
                               CEIL(EXTRACT (EPOCH FROM ign_off_time - ign_on_time) / 60) util_time_min, GREATEST(CEIL(EXTRACT(EPOCH FROM log_in_time - ign_on_time) / 60), 0) log_in_idle_time_min,
                               CEIL(EXTRACT (EPOCH FROM log_out_time - log_in_time) / 60) log_time_min, GREATEST(CEIL(EXTRACT(EPOCH FROM first_job_fetching_time - log_in_time) / 60), 0) job_fetching_idle_time_min,
                               without_job_cycle_time_min
                          FROM (
                                SELECT g.eq_type, g.eq_no, g.ign_on_time, g.ign_off_time, l.log_in_time, l.log_out_time, MIN(j.job_fetching_time) first_job_fetching_time,
                                       CEIL(sum(j.job_cycle_time_sec) / 60) job_cycle_time_min, ceil(sum(j.job_cycle_waiting_time_sec) / 60) job_cycle_waiting_time_min,
                                       ceil(sum(j.without_job_cycle_time_sec) / 60) without_job_cycle_time_min
                                  FROM (
                                        SELECT bi_eg_eq_type EQ_TYPE, bi_eg_eq_no EQ_NO,
                                               GREATEST (bi_eg_ign_on_time, c.start_time) IGN_ON_TIME,
                                               LEAST (COALESCE(bi_eg_ign_off_time, NOW()), c.end_time) IGN_OFF_TIME
                                          FROM bi_eq_ignition g
                                               CROSS JOIN
                                               day_cond c
                                         WHERE bi_eg_tml_id = :tmlId
                                           AND bi_eg_eq_type = :eqType
                                           AND (    (bi_eg_ign_off_time IS NULL AND bi_eg_ign_on_time <![CDATA[<]]> c.end_time)
                                                 OR (bi_eg_ign_on_time >= c.start_time AND bi_eg_ign_off_time <![CDATA[<=]]> c.end_time)
                                                 OR (bi_eg_ign_off_time > c.start_time AND bi_eg_ign_on_time <![CDATA[<]]> c.start_time)
                                                 OR (bi_eg_ign_on_time <![CDATA[<]]> c.end_time AND bi_eg_ign_off_time > c.end_time)
                                                 OR (bi_eg_ign_on_time <![CDATA[<]]> c.start_time AND bi_eg_ign_off_time > c.end_time)
                                               )
                                       ) g
                                       LEFT OUTER JOIN
                                       (
                                        SELECT bi_el_eq_type EQ_TYPE, bi_el_eq_no EQ_NO,
                                               GREATEST (bi_el_log_in_time, c.start_time) log_in_time,
                                               LEAST (COALESCE(bi_el_log_out_time, NOW()), c.end_time) log_out_time
                                          FROM bi_eq_login l
                                               CROSS JOIN
                                               day_cond c
                                         WHERE bi_el_tml_id = :tmlId
                                           AND bi_el_eq_type = :eqType
                                           AND (    (bi_el_log_out_time IS NULL AND bi_el_log_in_time <![CDATA[<]]> c.end_time)
                                                 OR (bi_el_log_in_time >= c.start_time AND bi_el_log_out_time <![CDATA[<=]]> c.end_time)
                                                 OR (bi_el_log_out_time > c.start_time AND bi_el_log_in_time <![CDATA[<]]> c.start_time)
                                                 OR (bi_el_log_in_time <![CDATA[<]]> c.end_time AND bi_el_log_out_time > c.end_time)
                                                 OR (bi_el_log_in_time <![CDATA[<]]> c.start_time AND bi_el_log_out_time > c.end_time)
                                               )
                                       ) l
                                       ON (g.eq_no = l.eq_no AND g.ign_on_time <![CDATA[<=]]> l.log_in_time AND g.ign_off_time >= l.log_out_time)
                                       LEFT OUTER JOIN
                                       (
                                        SELECT eq_no, job_id, job_fetching_time, job_cmpl_time, sum(CASE WHEN job_id IS NOT NULL THEN job_cycle_time_sec ELSE 0 END) job_cycle_time_sec,
                                               SUM (CASE WHEN job_id IS NOT NULL AND activity_type = 'Waiting' THEN job_cycle_time_sec ELSE 0 END) job_cycle_waiting_time_sec,
                                               SUM (CASE WHEN job_id IS NULL THEN job_cycle_time_sec ELSE 0 END) without_job_cycle_time_sec
                                          FROM (SELECT bi_jh_eq_no eq_no, bi_jh_job_id job_id, bi_jh_job_fetching_time job_fetching_time, bi_jh_job_cmpl_time job_cmpl_time, (jsonb_array_elements(bi_jh_job_cycle_step) -> 'intervalSec')::NUMERIC job_cycle_time_sec,
                                                       jsonb_array_elements(bi_jh_job_cycle_step) ->> 'activityType' activity_type
                                                  FROM bi_job_hist j
                                                       CROSS JOIN
                                                       day_cond c
                                                 WHERE j.bi_jh_tml_id = :tmlId
                                                   AND j.bi_jh_eq_type = :eqType
                                                   AND j.bi_jh_job_cmpl_time BETWEEN c.start_time AND c.end_time) m
                                        GROUP BY eq_no, job_id, job_fetching_time, job_cmpl_time
                                       ) j
                                       ON (l.eq_no = j.eq_no AND j.job_cmpl_time BETWEEN l.log_in_time AND l.log_out_time)
                                GROUP BY g.eq_type, g.eq_no, g.ign_on_time, g.ign_off_time, l.log_in_time, l.log_out_time) m
                        ) m
                GROUP BY eq_type
               ) m
               CROSS JOIN 
               (SELECT COALESCE(MAX(CASE WHEN bi_ov_value_type = 'SCH_DOWN' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) sch_down_time_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'USCH_DOWN' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) unsch_down_time_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'TML_CLOSE' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) tml_close_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'OFFLINE_OPR_DELAY' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) offline_opr_delay_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'TOS_FAILURE_ONLINE' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) tos_failure_online_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'ONLINE_DOWN' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) online_down_time_min,
                       COALESCE(MAX(CASE WHEN bi_ov_value_type = 'OTHER_IDLE' THEN bi_ov_value::NUMERIC ELSE NULL END), 0) other_idle_time_min
                  FROM public.bi_oee_tml_value
                 WHERE bi_ov_tml_id = :tmlId
                   AND bi_ov_eq_type = #{eqType}) c;