			--- inquiryAvaiableJobPerformed        
        SELECT COUNT(e.eq_no) * 24 available_hour /*eq_nos needs checking*/, CEIL(SUM(EXTRACT(EPOCH FROM (m.job_end_time - m.job_start_time)) / 60 / 60)) job_performed_hour
          FROM (SELECT bi_eq_eq_type eq_type, bi_eq_eq_no eq_no -- select all eqs and nos from eq table
                  FROM public.bi_eq e
                 WHERE bi_eq_tml_id = :tmlId
                   AND bi_eq_eq_type = :eqType
                   AND COALESCE (bi_eq_remove_flag, 'N') != 'Y'
               ) e
               LEFT OUTER join  --- one end value for equipment during whole day (To cater this problem, we can find the job performed using calculation obtined from ignition time, where we have job on and off grouped by eqno, ignOn and ignOff), Use my simple direct CTE method.
               (  SELECT bi_jh_eq_type eq_type, bi_jh_eq_no eq_no, GREATEST(MIN(bi_jh_job_fetching_time), :day::TIMESTAMP) job_start_time, MAX(bi_jh_job_cmpl_time) job_end_time 
                   WHERE bi_jh_tml_id = :tmlId
                     AND bi_jh_eq_type = :eqType
                     AND bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL  '1 ms'
                GROUP BY eq_type, eq_no
               )  m
               ON (e.eq_type = m.eq_type AND e.eq_no = m.eq_no);      
		      

    ----inquiryAvaiableJobPerformedGraphList -- this graph will not show the breaking of vertical bars (point of eq job on and off)
          SELECT e.eq_no, -- showing all the equipments on the terminal
                 :day::TIMESTAMP avail_start_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms' avail_end_time,
                 1440 avail_min, --fixed available time for equipment, hard coded (thus not considering the downtime or other delayed times)
                 m.job_start_time, m.job_end_time,
                 CEIL(EXTRACT(EPOCH FROM (m.job_end_time - m.job_start_time)) / 60) job_performed_min 
            FROM (SELECT bi_eq_eq_type eq_type, bi_eq_eq_no eq_no
                    FROM public.bi_eq e
                   WHERE bi_eq_tml_id = :tmlId
                     AND bi_eq_eq_type = :eqType
                     AND COALESCE (bi_eq_remove_flag, 'N') != 'Y'
                 ) e
                 LEFT OUTER JOIN 
                 (  SELECT h.bi_jh_eq_type eq_type, h.bi_jh_eq_no eq_no, GREATEST(MIN(h.bi_jh_job_fetching_time), :day::TIMESTAMP) job_start_time, MAX(h.bi_jh_job_cmpl_time) job_end_time
                      FROM public.bi_job_hist h
                     WHERE h.bi_jh_tml_id = :tmlId
                       AND h.bi_jh_eq_type = :eqType
                       AND h.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                  GROUP BY h.bi_jh_eq_type, h.bi_jh_eq_no) m
                 ON (e.eq_type = m.eq_type AND e.eq_no = m.eq_no)
        ORDER BY e.eq_no;	
		      
		     ----inquiryAvaiableJobPerformedEqHourList
         SELECT e.hour_step, e.eq_no, e.start_time, e.end_time, 
               CASE WHEN m.job_start_time BETWEEN e.start_time AND e.end_time THEN m.job_start_time ELSE NULL END job_start_time, 
               CASE WHEN m.job_end_time BETWEEN e.start_time AND e.end_time THEN m.job_end_time ELSE NULL END job_end_time,
               CASE WHEN e.start_time >= DATE_TRUNC('hour', m.job_start_time) AND e.end_time < m.job_end_time
                        THEN CEIL(ABS(EXTRACT(EPOCH FROM (m.job_start_time - e.end_time)) / 60)) 
                    WHEN e.start_time >= DATE_TRUNC('hour', m.job_start_time) AND m.job_end_time BETWEEN e.start_time AND e.end_time
                        THEN CEIL(ABS(EXTRACT(EPOCH FROM (m.job_start_time - m.job_end_time)) / 60))
                    ELSE NULL
               END job_performed_time_min
          FROM (SELECT hour_step, eq_type, eq_no, -- eqno, 24hrs and mentioning the start and end of 24 hr here
                       :day::TIMESTAMP + INTERVAL '1 hour' * (hour_step - 1) start_time,
                       :day::TIMESTAMP + INTERVAL '1 hour' * (hour_step) - INTERVAL '1 ms' end_time
                  FROM (SELECT bi_eq_eq_type eq_type, bi_eq_eq_no eq_no, GENERATE_SERIES(1, 24) hour_step
                          FROM public.bi_eq e
                         WHERE bi_eq_tml_id = :tmlId
                           AND bi_eq_eq_type = :eqType
                           AND bi_eq_eq_no = :eqNo
                           AND COALESCE (bi_eq_remove_flag, 'N') != 'Y'
                       ) e
               ) e
               LEFT OUTER join -- start and end of job performed for each equipment no.
               (  SELECT h.bi_jh_eq_type eq_type, h.bi_jh_eq_no eq_no, GREATEST(MIN(h.bi_jh_job_fetching_time), :day::TIMESTAMP) job_start_time, MAX(h.bi_jh_job_cmpl_time) job_end_time
                    FROM public.bi_job_hist h
                   WHERE h.bi_jh_tml_id = :tmlId
                     AND h.bi_jh_eq_type = :eqType
                     AND h.bi_jh_eq_no = :eqNo
                     AND h.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                GROUP BY h.bi_jh_eq_type, h.bi_jh_eq_no
               ) m
               ON (e.eq_no = m.eq_no)
         order by e.hour_step;  
		 
		 

                   --- inquiryIgnitionJobPerformed 
        SELECT SUM(CEIL(ABS(EXTRACT(EPOCH FROM m.ign_on_time - m.ign_off_time) / 60))) ign_time_min,
               SUM(m.job_performed_time_min) job_performed_time_min
          FROM (  SELECT m.eq_no, m.ign_on_time, m.ign_off_time, -- grouping the time difference of job performed by ignition on and off time
                         CEIL(ABS(EXTRACT(EPOCH FROM (MIN(m.job_start_time) - MAX(m.job_end_time))) / 60)) job_performed_time_min --min,max grouping based on eqno,ignOn and ignOff
                    FROM (SELECT g.eq_no, g.ign_on_time, g.ign_off_time, jh.job_start_time, jh.job_end_time
                            FROM (SELECT g.bi_eg_eq_no eq_no, GREATEST(g.bi_eg_ign_on_time, :day::TIMESTAMP) ign_on_time,
                                         LEAST(g.bi_eg_ign_off_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') ign_off_time
                                    FROM public.bi_eq_ignition g
                                   WHERE g.bi_eg_tml_id = :tmlId
                                     AND g.bi_eg_eq_type = :eqType
                                     AND g.bi_eg_ign_on_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                     AND COALESCE (g.bi_eg_ign_off_time, now()) >= :day::TIMESTAMP) g 
                                 LEFT OUTER JOIN
                                 (SELECT jh.bi_jh_eq_type eq_type, jh.bi_jh_eq_no eq_no, jh.bi_jh_job_fetching_time job_start_time, jh.bi_jh_job_cmpl_time job_end_time
                                    FROM public.bi_job_hist jh
                                   WHERE jh.bi_jh_tml_id = :tmlId
                                     AND jh.bi_jh_eq_type = :eqType
                                     AND jh.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') jh
                                 ON (jh.job_end_time BETWEEN g.ign_on_time AND g.ign_off_time AND g.eq_no = jh.eq_no)) m
                GROUP BY m.eq_no, m.ign_on_time, m.ign_off_time) m; -- for dual job, this groupby is imp
       

    --- inquiryIgnitionJobPerformedGraphList
                  --- inquiryIgnitionJobPerformedGraphList -- this graph can show breaking of vertical bars unlike first Available/Performed Job graph
          SELECT m.eq_no, m.ign_on_time ign_start_time, m.ign_off_time ign_end_time, CEIL(ABS(EXTRACT(EPOCH FROM m.ign_on_time - m.ign_off_time) / 60)) ign_time_min,
                 MIN(m.job_start_time) job_start_time, MAX(m.job_end_time) job_end_time,
                 CEIL(ABS(EXTRACT(EPOCH FROM (MIN(m.job_start_time) - MAX(m.job_end_time))) / 60)) job_performed_time_min
                    FROM (SELECT g.eq_no, g.ign_on_time, g.ign_off_time, jh.job_start_time, jh.job_end_time
                            FROM (SELECT g.bi_eg_eq_no eq_no, GREATEST(g.bi_eg_ign_on_time, :day::TIMESTAMP) ign_on_time,
                                         LEAST(g.bi_eg_ign_off_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') ign_off_time
                                    FROM public.bi_eq_ignition g
                                   WHERE g.bi_eg_tml_id = :tmlId
                                     AND g.bi_eg_eq_type = :eqType
                                     AND g.bi_eg_ign_on_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                     AND COALESCE (g.bi_eg_ign_off_time, now()) >= :day::TIMESTAMP) g
                                 LEFT OUTER JOIN
                                 (SELECT jh.bi_jh_eq_type eq_type, jh.bi_jh_eq_no eq_no, GREATEST(jh.bi_jh_job_fetching_time, :day::TIMESTAMP) job_start_time, jh.bi_jh_job_cmpl_time job_end_time
                                    FROM public.bi_job_hist jh
                                   WHERE jh.bi_jh_tml_id = :tmlId
                                     AND jh.bi_jh_eq_type = :eqType
                                     AND jh.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') jh
                                 ON (jh.job_end_time BETWEEN g.ign_on_time AND g.ign_off_time AND g.eq_no = jh.eq_no)) m
        GROUP BY m.eq_no, m.ign_on_time, m.ign_off_time; 
		
    
                 --- inquiryIgnitionJobPerformedEqHourList -- ignOn and Off based on hour list shows that an equipment is turned on and off each hour (which is not true, thus, this list does not indicate the exact on and off timings). 2nd Page code with option of filtering based on eqNo would suffice
         SELECT t.hour_seq, t.eq_no, t.start_time ign_start_time, t.end_time ign_end_time,
                 CASE WHEN g.job_start_time BETWEEN t.start_time AND t.end_time THEN g.job_start_time ELSE NULL END job_start_time,
                 CASE WHEN g.job_end_time BETWEEN t.start_time AND t.end_time THEN g.job_end_time ELSE NULL END job_end_time,
                 CASE WHEN t.start_time >= DATE_TRUNC('hour', g.job_start_time) AND t.end_time < g.job_end_time
                          THEN CEIL(ABS(EXTRACT(EPOCH FROM (g.job_start_time - t.end_time)) / 60))
                      WHEN t.start_time >= DATE_TRUNC('hour', g.job_start_time) AND g.job_end_time BETWEEN t.start_time AND t.end_time
                          THEN CEIL(ABS(EXTRACT(EPOCH FROM (g.job_start_time - g.job_end_time)) / 60)) -- should be t.start_time - g.job_end_time
                      ELSE NULL
                 END job_performed_time_min
                 -- this is related to creating --
            FROM (SELECT CASE WHEN m.hour_seq = 1 THEN m.ign_on_time_on_day ELSE DATE_TRUNC('hour', m.ign_on_time_on_day + (INTERVAL '1 hour' * (m.hour_seq - 1))) END start_time,
                         CASE WHEN m.hour_seq = ign_gap_hour THEN m.ign_off_time_on_day ELSE DATE_TRUNC('hour', m.ign_on_time_on_day + (INTERVAL '1 hour' * (m.hour_seq))) - INTERVAL '1 ms' END end_time,
                         m.eq_no, m.hour_seq -- below table is created based on the total hour span of ignition time 
                    FROM (SELECT m.eq_no, GENERATE_SERIES(1, (m.ign_gap_hour)::integer) hour_seq, m.ign_on_time_on_day, m.ign_off_time_on_day, ign_gap_hour
                            FROM ( SELECT m.eq_no, MIN(m.ign_on_time) ign_on_time_on_day, MAX(m.ign_off_time) ign_off_time_on_day, --****min and max of eq would give one ignOn and ignOff time for whole day instead of breaks obtained in the second page
                                         CEIL(ABS(EXTRACT(EPOCH FROM (MIN(m.ign_on_time) - MAX(m.ign_off_time))) / 60 / 60)) ign_gap_hour
                                    FROM (SELECT g.bi_eg_eq_no eq_no, GREATEST(g.bi_eg_ign_on_time, :day::TIMESTAMP) ign_on_time,
                                                 LEAST(g.bi_eg_ign_off_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') ign_off_time
                                            FROM public.bi_eq_ignition g
                                           WHERE g.bi_eg_tml_id = :tmlId
                                             AND g.bi_eg_eq_type = :eqType
                                             AND g.bi_eg_eq_no = :eqNo
                                             AND g.bi_eg_ign_on_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                             AND COALESCE (g.bi_eg_ign_off_time, now()) >= :day::TIMESTAMP) m
                                  GROUP BY m.eq_no) m
                         ) m
                 ) t
                 LEFT OUTER join -- calculation related to total job performed and ignition time is here
                 (  SELECT m.eq_no, m.ign_on_time, m.ign_off_time, CEIL(ABS(EXTRACT(EPOCH FROM m.ign_on_time - m.ign_off_time) / 60)) ign_time_min,
                           MIN(m.job_start_time) job_start_time, MAX(m.job_end_time) job_end_time,
                           CEIL(ABS(EXTRACT(EPOCH FROM (MIN(m.job_start_time) - MAX(m.job_end_time))) / 60)) job_performed_time_min
                      FROM (SELECT g.eq_no, g.ign_on_time, g.ign_off_time, jh.job_start_time, jh.job_end_time
                              FROM (SELECT g.bi_eg_eq_no eq_no, GREATEST(g.bi_eg_ign_on_time, :day::TIMESTAMP) ign_on_time,
                                           LEAST(g.bi_eg_ign_off_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') ign_off_time
                                      FROM public.bi_eq_ignition g
                                     WHERE g.bi_eg_tml_id = :tmlId
                                       AND g.bi_eg_eq_type = :eqType
                                       AND g.bi_eg_eq_no = :eqNo
                                       AND g.bi_eg_ign_on_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                       AND COALESCE (g.bi_eg_ign_off_time, now()) >= :day::TIMESTAMP) g
                                   LEFT OUTER JOIN
                                   (SELECT jh.bi_jh_eq_type eq_type, jh.bi_jh_eq_no eq_no, GREATEST(jh.bi_jh_job_fetching_time, :day::TIMESTAMP) job_start_time, jh.bi_jh_job_cmpl_time job_end_time
                                      FROM public.bi_job_hist jh
                                     WHERE jh.bi_jh_tml_id = :tmlId
                                       AND jh.bi_jh_eq_type = :eqType
                                       AND jh.bi_jh_eq_no = :eqNo
                                       AND jh.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') jh
                                   ON (jh.job_end_time BETWEEN g.ign_on_time AND g.ign_off_time AND g.eq_no = jh.eq_no)
                           ) m
                  GROUP BY m.eq_no, m.ign_on_time, m.ign_off_time) g
                 ON (g.eq_no = t.eq_no AND DATE_TRUNC('hour', g.ign_on_time) <= t.start_time AND DATE_TRUNC('hour', g.ign_off_time) >= t.start_time)
        ORDER BY t.hour_seq;


      	---- inquiryLoginJobPerformed -- code is similar to previous graph code
        SELECT SUM(CEIL(ABS(EXTRACT(EPOCH FROM m.log_in_time - m.log_out_time) / 60))) log_time_min,
               SUM(m.job_performed_time_min) job_performed_time_min
          FROM (  SELECT m.eq_no, m.log_in_time, m.log_out_time,
                         CEIL(ABS(EXTRACT(EPOCH FROM (MIN(m.job_start_time) - MAX(m.job_end_time))) / 60)) job_performed_time_min
                    FROM (SELECT l.eq_no, l.log_in_time, l.log_out_time, jh.job_start_time, jh.job_end_time
                            FROM (SELECT l.bi_el_eq_no eq_no, GREATEST(l.bi_el_log_in_time, :day::TIMESTAMP) log_in_time,
                                         LEAST(l.bi_el_log_out_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') log_out_time
                                    FROM public.bi_eq_login l
                                   WHERE l.bi_el_tml_id = :tmlId
                                     AND l.bi_el_eq_type = :eqType
                                     AND l.bi_el_log_in_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                     AND COALESCE (l.bi_el_log_out_time, now()) >= :day::TIMESTAMP) l
                                 LEFT OUTER JOIN
                                 (SELECT jh.bi_jh_eq_type eq_type, jh.bi_jh_eq_no eq_no, GREATEST(jh.bi_jh_job_fetching_time, :day::TIMESTAMP) job_start_time, jh.bi_jh_job_cmpl_time job_end_time
                                    FROM public.bi_job_hist jh
                                   WHERE jh.bi_jh_tml_id = :tmlId
                                     AND jh.bi_jh_eq_type = :eqType
                                     AND jh.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') jh
                                 ON (jh.job_end_time BETWEEN l.log_in_time AND l.log_out_time AND l.eq_no = jh.eq_no)) m
                GROUP BY m.eq_no, m.log_in_time, m.log_out_time) m; 



    
         --- inquiryLoginJobPerformedGraphList
          SELECT m.eq_no, m.log_in_time, m.log_out_time, ROUND(ABS(EXTRACT(EPOCH FROM m.log_in_time - m.log_out_time) / 60)) log_time_min,
                 MIN(m.job_start_time) job_star_time, MAX(m.job_end_time) job_end_time,
                 ROUND(ABS(EXTRACT(EPOCH FROM (MIN(m.job_start_time) - MAX(m.job_end_time))) / 60)) job_performed_time_min
            FROM (SELECT l.eq_no, l.log_in_time, l.log_out_time, jh.job_start_time, jh.job_end_time
                    FROM (SELECT l.bi_el_eq_no eq_no, GREATEST(l.bi_el_log_in_time, :day::TIMESTAMP) log_in_time,
                                 LEAST(l.bi_el_log_out_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') log_out_time
                            FROM public.bi_eq_login l
                           WHERE l.bi_el_tml_id = :tmlId
                             AND l.bi_el_eq_type = :eqType
                             AND l.bi_el_log_in_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                             AND COALESCE (l.bi_el_log_out_time, now()) >= :day::TIMESTAMP) l
                         LEFT OUTER JOIN
                         (SELECT jh.bi_jh_eq_type eq_type, jh.bi_jh_eq_no eq_no, GREATEST(jh.bi_jh_job_fetching_time, :day::TIMESTAMP) job_start_time, jh.bi_jh_job_cmpl_time job_end_time
                            FROM public.bi_job_hist jh
                           WHERE jh.bi_jh_tml_id = :tmlId
                             AND jh.bi_jh_eq_type = :eqType
                             AND jh.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') jh
                         ON (jh.job_end_time BETWEEN l.log_in_time AND l.log_out_time AND l.eq_no = jh.eq_no)
                 ) m
        GROUP BY m.eq_no, m.log_in_time, m.log_out_time;   
		
		
				  
           ---- inquiryLoginJobPerformedEqHourList -- it ll face similar issue as ignition graph
        SELECT t.hour_seq, t.eq_no, t.start_time log_start_time, t.end_time log_end_time,
                 CASE WHEN l.job_start_time BETWEEN t.start_time AND t.end_time THEN l.job_start_time ELSE NULL END job_start_time,
                 CASE WHEN l.job_end_time BETWEEN t.start_time AND t.end_time THEN l.job_end_time ELSE NULL END job_end_time,
                 CASE WHEN t.start_time >= DATE_TRUNC('hour', l.job_start_time) AND t.end_time < l.job_end_time
                          THEN CEIL(ABS(EXTRACT(EPOCH FROM (l.job_start_time - t.end_time)) / 60))
                      WHEN t.start_time >= DATE_TRUNC('hour', l.job_start_time) AND l.job_end_time BETWEEN t.start_time AND t.end_time
                          THEN CEIL(ABS(EXTRACT(EPOCH FROM (l.job_start_time - l.job_end_time)) / 60)) -- should be t.start_time - g.job_end_time
                      ELSE NULL
                 END job_performed_time_min
            FROM (SELECT CASE WHEN m.hour_seq = 1 THEN m.log_in_time_on_day ELSE DATE_TRUNC('hour', m.log_in_time_on_day + (INTERVAL '1 hour' * (m.hour_seq - 1))) END start_time,
                         CASE WHEN m.hour_seq = login_gap_hour THEN m.log_out_time_on_day ELSE DATE_TRUNC('hour', m.log_in_time_on_day + (INTERVAL '1 hour' * (m.hour_seq))) - INTERVAL '1 ms' END end_time,
                         m.eq_no, m.hour_seq ---below table is created based on the total hour span of ignition time 
                    FROM (SELECT m.eq_no, GENERATE_SERIES(1, (m.login_gap_hour)::integer) hour_seq, m.log_in_time_on_day, m.log_out_time_on_day, login_gap_hour
                            FROM ( SELECT m.eq_no, MIN(m.log_in_time) log_in_time_on_day, MAX(m.log_out_time) log_out_time_on_day,
                                         CEIL(ABS(EXTRACT(EPOCH FROM (MIN(m.log_in_time) - MAX(m.log_out_time))) / 60 / 60)) login_gap_hour
                                    FROM (SELECT l.bi_el_eq_no eq_no, GREATEST(l.bi_el_log_in_time, :day::TIMESTAMP) log_in_time,
                                                 LEAST(l.bi_el_log_out_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') log_out_time
                                            FROM public.bi_eq_login l
                                           WHERE l.bi_el_tml_id = :tmlId
                                             AND l.bi_el_eq_type = :eqType
                                             AND l.bi_el_eq_no = :eqNo
                                             AND l.bi_el_log_in_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                             AND COALESCE (l.bi_el_log_out_time, now()) >= :day::TIMESTAMP) m
                                  GROUP BY m.eq_no) m
                         ) m
                 ) t
                 LEFT OUTER JOIN  -- calculation related to total job performed and logOn time is here
                 (  SELECT m.eq_no, m.log_in_time, m.log_out_time, ROUND(ABS(EXTRACT(EPOCH FROM m.log_in_time - m.log_out_time) / 60)) login_time_min,
                           MIN(m.job_start_time) job_start_time, MAX(m.job_end_time) job_end_time,
                           ROUND(ABS(EXTRACT(EPOCH FROM (MIN(m.job_start_time) - MAX(m.job_end_time))) / 60)) job_performed_time_min
                      FROM (SELECT l.eq_no, l.log_in_time, l.log_out_time, jh.job_start_time, jh.job_end_time
                              FROM (SELECT l.bi_el_eq_no eq_no, GREATEST(l.bi_el_log_in_time, :day::TIMESTAMP) log_in_time,
                                           LEAST(l.bi_el_log_out_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') log_out_time
                                      FROM public.bi_eq_login l
                                     WHERE l.bi_el_tml_id = :tmlId
                                       AND l.bi_el_eq_type = :eqType
                                       AND l.bi_el_eq_no = :eqNo
                                       AND l.bi_el_log_in_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                       AND COALESCE (l.bi_el_log_out_time, now()) >= :day::TIMESTAMP) l
                                   LEFT OUTER JOIN
                                   (SELECT jh.bi_jh_eq_type eq_type, jh.bi_jh_eq_no eq_no, GREATEST(jh.bi_jh_job_fetching_time, :day::TIMESTAMP) job_start_time, jh.bi_jh_job_cmpl_time job_end_time
                                      FROM public.bi_job_hist jh
                                     WHERE jh.bi_jh_tml_id = :tmlId
                                       AND jh.bi_jh_eq_type = :eqType
                                       AND jh.bi_jh_eq_no = :eqNo
                                       AND jh.bi_jh_job_cmpl_time BETWEEN :day::TIMESTAMP AND :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') jh
                                   ON (jh.job_end_time BETWEEN l.log_in_time AND l.log_out_time)
                           ) m
                  GROUP BY m.eq_no, m.log_in_time, m.log_out_time) l
                 ON (l.eq_no = t.eq_no AND DATE_TRUNC('hour', l.log_in_time) <= t.start_time AND DATE_TRUNC('hour', l.log_out_time) >= t.start_time)
        ORDER BY t.hour_seq;
       
              	---- inquiryIgnitionBreakTime
       SELECT SUM(ROUND(ABS(EXTRACT(EPOCH FROM m.ign_on_time - m.ign_off_time) / 60))) ign_time_min, -- here we do the total sum
               SUM(m.brk_end_time_time_min) brk_end_time_min
          FROM (  SELECT m.eq_no, m.ign_on_time, m.ign_off_time,
                         ROUND(ABS(EXTRACT(EPOCH FROM (MIN(m.brk_start_time) - MAX(m.brk_end_time))) / 60)) brk_end_time_time_min -- here we do the grouping
                    FROM (SELECT g.eq_no, g.ign_on_time, g.ign_off_time, b.brk_start_time, b.brk_end_time -- here we get both
                            FROM (SELECT g.bi_eg_eq_no eq_no, GREATEST(g.bi_eg_ign_on_time, :day::TIMESTAMP) ign_on_time, -- we are getting ignition times here
                                         LEAST(g.bi_eg_ign_off_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') ign_off_time
                                    FROM public.bi_eq_ignition g
                                   WHERE g.bi_eg_tml_id = :tmlId
                                     AND g.bi_eg_eq_type = :eqType
                                     AND g.bi_eg_ign_on_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                     AND COALESCE (g.bi_eg_ign_off_time, now()) >= :day::TIMESTAMP) g
                                 LEFT OUTER join -- we are getting break times here 
                                 (SELECT b.bi_eb_tml_id tml_id, b.bi_eb_eq_type eq_type, b.bi_eb_eq_no eq_no,
                                         GREATEST(b.bi_eb_brk_start_time, :day::TIMESTAMP) brk_start_time,
                                         LEAST(COALESCE(b.bi_eb_brk_end_time, now()), :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') brk_end_time
                                    FROM public.bi_eq_breaktime b
                                   WHERE b.bi_eb_tml_id = :tmlId
                                     AND b.bi_eb_eq_type = :eqType
                                     AND b.bi_eb_brk_start_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                     AND COALESCE(b.bi_eb_brk_end_time, now()) >= :day::TIMESTAMP) b
                                 ON (g.ign_on_time <= b.brk_start_time AND g.ign_off_time >= b.brk_end_time AND g.eq_no = b.eq_no)
                         ) m
                GROUP BY m.eq_no, m.ign_on_time, m.ign_off_time) m;
       
         ---- inquiryIgnitionBreakTimeGraphList
        SELECT g.eq_no, g.ign_on_time, g.ign_off_time,
               b.brk_start_time, b.brk_end_time, CEIL(ABS(EXTRACT(EPOCH FROM (b.brk_start_time - b.brk_end_time)) / 60)) brk_time_min
          FROM (SELECT g.bi_eg_eq_no eq_no, GREATEST(g.bi_eg_ign_on_time, :day::TIMESTAMP) ign_on_time,
                       LEAST(g.bi_eg_ign_off_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') ign_off_time
                  FROM public.bi_eq_ignition g
                 WHERE g.bi_eg_tml_id = :tmlId
                   AND g.bi_eg_eq_type = :eqType
                   AND g.bi_eg_ign_on_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                   AND COALESCE (g.bi_eg_ign_off_time, now()) >= :day::TIMESTAMP) g
               LEFT OUTER JOIN
               (SELECT b.bi_eb_tml_id tml_id, b.bi_eb_eq_type eq_type, b.bi_eb_eq_no eq_no,
                       GREATEST(b.bi_eb_brk_start_time, :day::TIMESTAMP) brk_start_time,
                       LEAST(COALESCE(b.bi_eb_brk_end_time, now()), :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') brk_end_time
                  FROM public.bi_eq_breaktime b
                 WHERE b.bi_eb_tml_id = :tmlId
                   AND b.bi_eb_eq_type = :eqType
                   AND b.bi_eb_brk_start_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                   AND COALESCE(b.bi_eb_brk_end_time, now()) >= :day::TIMESTAMP) b
               ON (g.ign_on_time <= b.brk_start_time AND g.ign_off_time >= b.brk_end_time AND g.eq_no = b.eq_no);  
    
              ---- inquiryIgnitionBreakTimeEqHourList
        SELECT m.hour_seq, m.eq_no, m.ign_start_time, m.ign_end_time, m.brk_start_time, m.brk_end_time,
               CASE WHEN m.ign_start_time >= DATE_TRUNC('hour', m.org_brk_start_time) AND m.ign_end_time < m.org_brk_end_time
                        THEN CEIL(ABS(EXTRACT(EPOCH FROM (m.org_brk_start_time - m.ign_end_time)) / 60))
                    WHEN m.ign_start_time >= DATE_TRUNC('hour', m.org_brk_start_time) AND m.org_brk_end_time BETWEEN m.ign_start_time AND m.ign_end_time
                        THEN CEIL(ABS(EXTRACT(EPOCH FROM (m.org_brk_start_time - m.org_brk_end_time)) / 60))
                    ELSE NULL
               END brk_time_min
          FROM (SELECT t.hour_seq, t.eq_no, t.start_time ign_start_time, t.end_time ign_end_time,
                       CASE WHEN b.brk_start_time BETWEEN t.start_time AND t.end_time THEN b.brk_start_time ELSE NULL END brk_start_time,
                       CASE WHEN b.brk_end_time BETWEEN t.start_time AND t.end_time THEN b.brk_end_time ELSE NULL END brk_end_time,
                       b.brk_start_time org_brk_start_time, b.brk_end_time org_brk_end_time
                  FROM (SELECT CASE WHEN m.hour_seq = 1 THEN m.ign_on_time_on_day ELSE DATE_TRUNC('hour', m.ign_on_time_on_day + (INTERVAL '1 hour' * (m.hour_seq - 1))) END start_time,
                               CASE WHEN m.hour_seq = ign_gap_hour THEN m.ign_off_time_on_day ELSE DATE_TRUNC('hour', m.ign_on_time_on_day + (INTERVAL '1 hour' * (m.hour_seq))) - INTERVAL '1 ms' END end_time,
                               m.eq_no, m.hour_seq
                          FROM (SELECT m.eq_no, GENERATE_SERIES(1, (m.ign_gap_hour)::integer) hour_seq, m.ign_on_time_on_day, m.ign_off_time_on_day, ign_gap_hour
                                  FROM ( SELECT m.eq_no, MIN(m.ign_on_time) ign_on_time_on_day, MAX(m.ign_off_time) ign_off_time_on_day,
                                               CEIL(ABS(EXTRACT(EPOCH FROM (MIN(m.ign_on_time) - MAX(m.ign_off_time))) / 60 / 60)) ign_gap_hour
                                          FROM (SELECT g.bi_eg_eq_no eq_no, GREATEST(g.bi_eg_ign_on_time, :day::TIMESTAMP) ign_on_time,
                                                       LEAST(g.bi_eg_ign_off_time, :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') ign_off_time
                                                  FROM public.bi_eq_ignition g
                                                 WHERE g.bi_eg_tml_id = :tmlId
                                                   AND g.bi_eg_eq_type = :eqType
                                                   AND g.bi_eg_eq_no = :eqNo
                                                   AND g.bi_eg_ign_on_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                                                   AND COALESCE (g.bi_eg_ign_off_time, now()) >= :day::TIMESTAMP) m
                                        GROUP BY m.eq_no) m
                               ) m
                       ) t
                       LEFT OUTER JOIN
                       (SELECT b.bi_eb_tml_id tml_id, b.bi_eb_eq_type eq_type, b.bi_eb_eq_no eq_no,
                               GREATEST(b.bi_eb_brk_start_time, :day::TIMESTAMP) brk_start_time,
                               LEAST(COALESCE(b.bi_eb_brk_end_time, now()), :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms') brk_end_time
                          FROM public.bi_eq_breaktime b
                         WHERE b.bi_eb_tml_id = :tmlId
                           AND b.bi_eb_eq_type = :eqType
                           AND b.bi_eb_eq_no = :eqNo
                           AND b.bi_eb_brk_start_time <= :day::TIMESTAMP + INTERVAL '1 day' - INTERVAL '1 ms'
                           AND COALESCE(b.bi_eb_brk_end_time, now()) >= :day::TIMESTAMP) b
                       ON (b.eq_no = t.eq_no AND DATE_TRUNC('hour', b.brk_start_time) <= DATE_TRUNC('hour', t.start_time) AND DATE_TRUNC('hour', b.brk_end_time) >= DATE_TRUNC('hour', t.start_time))
               ) m;    
              