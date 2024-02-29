        WITH day_cond AS
            (SELECT :dDay::TIMESTAMP start_time,
                    :dDay::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms' end_time)
        SELECT -- 1 level
               calendar_time_min,
               -- 2 level
               calendar_time_min - tml_close_min AS top_min,
               tml_close_min,
               -- 3 level
               ign_time_min + unsch_down_time_min + offline_opr_delay_min AS at_min,
               sch_down_time_min,
               calendar_time_min - tml_close_min - ign_time_min - unsch_down_time_min - offline_opr_delay_min - sch_down_time_min AS no_demand_min,
               -- 4 level
               ign_time_min AS util_time_min,
               offline_opr_delay_min,
               unsch_down_time_min,
               -- 5 level
               job_cycle_time_min + without_job_cycle_time_min AS toc_min,
               ign_time_min - job_cycle_time_min - without_job_cycle_time_min AS online_opr_delay_min,
               -- 6 level
               job_cycle_time_min - job_cycle_waiting_time_min AS vot_min,
               job_cycle_waiting_time_min AS non_value_opr_time_min,
               ign_time_min - job_cycle_time_min - without_job_cycle_time_min - tos_failure_online_min idle_time_min,
               tos_failure_online_min
          FROM (SELECT m.calendar_time_min, g.ign_time_min, j.job_cycle_time_min, j.job_cycle_waiting_time_min, j.without_job_cycle_time_min,
                       c.tml_close_min, c.sch_down_time_min, c.unsch_down_time_min, c.offline_opr_delay_min, c.tos_failure_online_min, c.online_down_time_min, c.other_idle_time_min
                  FROM (SELECT count(*) * 24 * 60 calendar_time_min 
                          FROM bi_eq be
                         WHERE bi_eq_tml_id = :tmlId AND bi_eq_eq_type = :eqType
                       ) m
                       CROSS JOIN
                       (SELECT ROUND(SUM(EXTRACT (epoch FROM ign_off_time - ign_on_time)) / 60 ) ign_time_min
                          FROM (SELECT bi_eg_eq_type EQ_TYPE, bi_eg_eq_no EQ_NO,
                                       GREATEST (bi_eg_ign_on_time, c.start_time) IGN_ON_TIME,
                                       LEAST (COALESCE(bi_eg_ign_off_time, NOW()), c.end_time) IGN_OFF_TIME
                                  FROM bi_eq_ignition g
                                       INNER JOIN
                                       bi_eq e
                                       ON (    g.bi_eg_tml_id = e.bi_eq_tml_id
                                           AND g.bi_eg_eq_type = e.bi_eq_eq_type
                                           AND g.bi_eg_eq_no = e.bi_eq_eq_no)
                                       CROSS JOIN
                                       day_cond c
                                 WHERE bi_eg_tml_id = :tmlId
                                   AND bi_eg_eq_type = :eqType
                                   AND (    (bi_eg_ign_off_time IS NULL AND bi_eg_ign_on_time < c.end_time)
                                         OR (bi_eg_ign_on_time >= c.start_time AND bi_eg_ign_off_time <= c.end_time)
                                         OR (bi_eg_ign_off_time > c.start_time AND bi_eg_ign_on_time < c.start_time)
                                         OR (bi_eg_ign_on_time < c.end_time AND bi_eg_ign_off_time > c.end_time)
                                         OR (bi_eg_ign_on_time < c.start_time AND bi_eg_ign_off_time > c.end_time)
                                       )
                                ) g
                       ) g
                       CROSS JOIN
                       (SELECT ROUND(SUM(job_cycle_time_sec) / 60) job_cycle_time_min,
                               ROUND(SUM(job_cycle_waiting_time_sec) / 60) job_cycle_waiting_time_min,
                               ROUND(SUM(without_job_cycle_time_sec) / 60) without_job_cycle_time_min
                          FROM (SELECT eq_no, job_id, job_fetching_time, job_cmpl_time,
                                       sum (CASE WHEN job_id IS NOT NULL THEN job_cycle_time_sec ELSE 0 END) job_cycle_time_sec,
                                       SUM (CASE WHEN job_id IS NOT NULL AND activity_type = 'Waiting' THEN job_cycle_time_sec ELSE 0 END) job_cycle_waiting_time_sec,
                                       SUM (CASE WHEN job_id IS NULL THEN job_cycle_time_sec ELSE 0 END) without_job_cycle_time_sec
                                  FROM (SELECT bi_jh_eq_no eq_no, bi_jh_job_id job_id, bi_jh_job_fetching_time job_fetching_time,
                                               bi_jh_job_cmpl_time job_cmpl_time,
                                               (jsonb_array_elements(bi_jh_job_cycle_step) -> 'intervalSec')::NUMERIC job_cycle_time_sec,
                                               jsonb_array_elements(bi_jh_job_cycle_step) ->> 'activityType' activity_type
                                          FROM bi_job_hist j
                                               CROSS JOIN
                                               day_cond c
                                         WHERE j.bi_jh_tml_id = :tmlId
                                           AND j.bi_jh_eq_type = :eqType
                                           AND j.bi_jh_job_cmpl_time BETWEEN c.start_time AND c.end_time) m
                                GROUP BY eq_no, job_id, job_fetching_time, job_cmpl_time
                               ) j
                       ) j
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
                           AND bi_ov_eq_type = :eqType) c
               ) m;
