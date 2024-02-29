
--"inquiryTravelEfficiencyByEqType
          SELECT t.s_time, t.e_time, t.hour_step, SUM(eta_distance) eta_distance, SUM(ata_distance) ata_distance, SUM(eta_time_sec) eta_time_sec, SUM(ata_time_sec) ata_time_sec
            FROM (SELECT m.s_time,
                         CASE WHEN m.hour_step = 0 THEN m.d_now ELSE m.s_time + INTERVAL '1 hour' - INTERVAL '1 ms' END e_time,
                         TO_CHAR(m.s_time, 'yyyymmddhh24') hour_step
                    FROM (SELECT m.hour_step, DATE_TRUNC('hour', m.d_now) - (INTERVAL '1 hour' * m.hour_step) s_time, m.d_now
                            FROM (SELECT GENERATE_SERIES(5, 0, -1) hour_step, #{dNow}::TIMESTAMP d_now) m 
                         ) m
                 ) t
                 LEFT OUTER JOIN
                 (  SELECT eq_type, eq_no, job_id, job_cmpl_time,
                           SUM(eta_distance::INTEGER) eta_distance, SUM(ata_distance::INTEGER) ata_distance,
                           SUM(eta_time_sec::INTEGER) eta_time_sec, SUM(ata_time_sec::INTEGER) ata_time_sec
                      FROM (SELECT eq_type, eq_no, job_id, job_cmpl_time,
                                   trv_info -> 'etaDistance' eta_distance, trv_info -> 'ataDistance' ata_distance,
                                   trv_info -> 'etaTimeSec' eta_time_sec, trv_info -> 'ataTimeSec' ata_time_sec
                              FROM (SELECT bi_jh_eq_type eq_type, bi_jh_eq_no eq_no, bi_jh_job_id job_id, bi_jh_job_cmpl_time job_cmpl_time, jsonb_array_elements (bi_jh_trv_with_eta) trv_info 
                                      FROM public.bi_job_hist
                                     WHERE bi_jh_trv_with_eta IS NOT NULL
                                       AND bi_jh_tml_id = #{tmlId}
                                       AND bi_jh_eq_type = #{eqType}
                                       AND bi_jh_job_cmpl_time BETWEEN #{dNow}::TIMESTAMP - (INTERVAL '1 hour' * 6) AND #{dNow}::TIMESTAMP) m
                           ) m
                  GROUP BY eq_type, eq_no, job_id, job_cmpl_time) j
                 ON (t.s_time <![CDATA[<=]]> j.job_cmpl_time AND t.e_time >= j.job_cmpl_time)
        GROUP BY t.s_time, t.e_time, t.hour_step
        ORDER BY 1;

    
--- inquiryTravelEfficiencyGraphByEqType
		SELECT eq_type, eq_no, job_id, cntr_no, eta_distance, ata_distance, eta_time_sec, ata_time_sec
		  FROM (  SELECT eq_type, eq_no, job_id, cntr_no, 
		                   SUM(eta_distance::INTEGER) eta_distance, SUM(ata_distance::INTEGER) ata_distance,
		                   SUM(eta_time_sec::INTEGER) eta_time_sec, SUM(ata_time_sec::INTEGER) ata_time_sec
		              FROM (SELECT eq_type, eq_no, job_id, cntr_no,
		                           trv_info -> 'etaDistance' eta_distance, trv_info -> 'ataDistance' ata_distance,
		                           trv_info -> 'etaTimeSec' eta_time_sec, trv_info -> 'ataTimeSec' ata_time_sec
		                      FROM (SELECT bi_jh_eq_type eq_type, bi_jh_eq_no eq_no, bi_jh_job_id job_id, bi_jh_cntr_no cntr_no, 
		                                   jsonb_array_elements (bi_jh_trv_with_eta) trv_info 
		                              FROM public.bi_job_hist
		                             WHERE bi_jh_trv_with_eta IS NOT NULL
		                               AND bi_jh_tml_id = :tmlId
		                               AND bi_jh_eq_type = :eqType
		                               AND bi_jh_job_cmpl_time BETWEEN :fromDate::TIMESTAMP AND :toDate::TIMESTAMP) m
		                   ) m
		        GROUP BY eq_type, eq_no, job_id, cntr_no) j;


--- inquiryTravelEfficiencyJobDetail
		SELECT r_seq, cntr_no, eq_no, from_step, to_step, user_id, eta_distance, ata_distance, eta_time_sec, ata_time_sec, ata_time_sec - eta_time_sec trv_efc_time, ata_distance - eta_distance trv_efc_distance
		  FROM (SELECT row_number() over() r_seq, cntr_no, eq_no, trv_info ->> 'fromStep' from_step, trv_info ->> 'toStep' to_step, user_id,
		               (trv_info -> 'etaDistance')::INTEGER eta_distance, (trv_info -> 'ataDistance')::INTEGER ata_distance,
		               (trv_info -> 'etaTimeSec')::INTEGER eta_time_sec, (trv_info -> 'ataTimeSec')::INTEGER ata_time_sec
		          FROM (SELECT bi_jh_eq_type eq_type, bi_jh_eq_no eq_no, bi_jh_job_id job_id, bi_jh_cntr_no cntr_no, bi_jh_job_cmpl_time job_cmpl_time, bi_jh_user_id user_id,
		                       jsonb_array_elements (bi_jh_trv_with_eta) trv_info
		                  FROM public.bi_job_hist
		                 WHERE bi_jh_trv_with_eta IS NOT NULL
		                   AND bi_jh_tml_id = #{tmlId}
		                   AND bi_jh_eq_type = #{eqType}
		                   AND bi_jh_job_id = #{jobId}
						   AND bi_jh_cntr_no = #{cntrNo} ) m
		        ) m

--- inquiryTravelEfficiencyWithJob
		  SELECT t.s_time, t.e_time, t.hour_step, ROUND(SUM(et.dist)) trv_dist, ROUND(SUM(j.trv_distance)) trv_job_dist
		    FROM (SELECT m.s_time,
		                 CASE WHEN m.hour_step = 0 THEN m.d_now ELSE m.s_time + INTERVAL '1 hour' - INTERVAL '1 ms' END e_time,
		                 TO_CHAR(m.s_time, 'yyyymmddhh24') hour_step
		            FROM (SELECT m.hour_step, DATE_TRUNC('hour', m.d_now) - (INTERVAL '1 hour' * m.hour_step) s_time, m.d_now
		                    FROM (SELECT GENERATE_SERIES(5, 0, -1) hour_step, :dNow::TIMESTAMP d_now) m
		                 ) m
		         ) t
		         LEFT OUTER JOIN
		         (  SELECT TO_CHAR(et.bi_ev_trv_etime, 'yyyymmddhh24') hour_step, SUM(et.bi_ev_dist) dist
		              FROM public.bi_eq_travel et
		             WHERE et.bi_ev_tml_id = :tmlId
		               AND et.bi_ev_eq_type = :eqType
		               AND et.bi_ev_trv_stime >= :dNow::TIMESTAMP - (INTERVAL '1 hour' * 6)
		               AND et.bi_ev_trv_etime <= :dNow::TIMESTAMP
		          GROUP BY TO_CHAR(et.bi_ev_trv_etime, 'yyyymmddhh24')
		         ) et
		         ON (t.hour_step = et.hour_step)
		         LEFT OUTER JOIN
		         (  SELECT TO_CHAR(e.bi_et_last_job_cmpl_time , 'yyyymmddhh24') hour_step, SUM (e.bi_et_trv_dist) trv_distance
		              FROM public.bi_eq_tran e
		             WHERE e.bi_et_tml_id = :tmlId
		               AND e.bi_et_eq_type = :eqType
		               AND e.bi_et_last_job_cmpl_time BETWEEN :dNow::TIMESTAMP - (INTERVAL '1 hour' * 6) AND :dNow::TIMESTAMP
		          GROUP BY TO_CHAR(e.bi_et_last_job_cmpl_time , 'yyyymmddhh24')
		         ) j
		         ON (t.hour_step = j.hour_step)
		GROUP BY t.s_time, t.e_time, t.hour_step;

--- inquiryTravelEfficiencyWithJobGraph
				  SELECT et.eq_no, et.dist total_dist, j.trv_distance job_dist, et.dist - COALESCE (j.trv_distance, 0) no_job_dist
		    FROM (  SELECT et.bi_ev_eq_type eq_type, et.bi_ev_eq_no eq_no, ROUND(SUM(et.bi_ev_dist)) dist
		              FROM public.bi_eq_travel et 
		             WHERE et.bi_ev_tml_id = :tmlId
		               AND et.bi_ev_eq_type = :eqType
		               AND et.bi_ev_trv_stime >= :fromDate
		               AND et.bi_ev_trv_etime <= :toDate
		          GROUP BY et.bi_ev_eq_type, et.bi_ev_eq_no
		         ) et
		         LEFT OUTER JOIN
		         (  SELECT bi_et_eq_type eq_type, bi_et_eq_no eq_no, SUM (e.bi_et_trv_dist) trv_distance
		              FROM public.bi_eq_tran e
		             WHERE e.bi_et_tml_id = :tmlId
		               AND e.bi_et_eq_type = :eqType
		               AND e.bi_et_last_job_cmpl_time BETWEEN :fromDate AND :toDate
		          GROUP BY bi_et_eq_type, bi_et_eq_no
		         ) j
		         ON (et.eq_type = j.eq_type AND et.eq_no = j.eq_no)
		ORDER BY et.eq_no;      
		      

    
--- inquiryTravelEfficiencyWithJobDetail
		  SELECT ROW_NUMBER() OVER(ORDER BY job_cmpl_time) r_seq, job_cmpl_time, cntr_no, eq_no, job_type, from_loc, to_loc, ROUND(SUM(dist)) dist, user_id, eq_tran_id
		    FROM (SELECT bi_jh_job_cmpl_time job_cmpl_time, bi_jh_cntr_no cntr_no, bi_jh_eq_no eq_no, bi_jh_job_type job_type,
		                 bi_jh_from_loc from_loc, bi_jh_to_loc to_loc, (JSONB_ARRAY_ELEMENTS(bi_jh_job_cycle_step) -> 'trvDistance')::INTEGER dist, bi_jh_user_id user_id,
		                 bi_jh_eq_tran_id eq_tran_id
		            FROM public.bi_job_hist jh
		           WHERE bi_jh_tml_id = :tmlId
		             AND bi_jh_eq_type = :eqType
		             AND bi_jh_eq_no = :eqNo
		             AND bi_jh_job_cmpl_time BETWEEN :fromDate AND :toDate) m
		GROUP BY job_cmpl_time, cntr_no ,eq_no, job_type, from_loc, to_loc, user_id, eq_tran_id
		ORDER BY 1;   
    
    
--- inquiryJobCycleTime
		  SELECT t.s_time, t.e_time, t.hour_step,
		         SUM(CASE WHEN COALESCE(j.activity_type, 'Working') = 'Working' THEN interval_sec ELSE 0 END) working_time_sec,
                 SUM(CASE WHEN j.activity_type = 'Waiting' THEN interval_sec ELSE 0 END) waiting_time_sec
		    FROM (SELECT m.s_time,
		                     CASE WHEN m.hour_step = 0 THEN m.d_now ELSE m.s_time + INTERVAL '1 hour' - INTERVAL '1 ms' END e_time,
		                     TO_CHAR(m.s_time, 'yyyymmddhh24') hour_step
		                FROM (SELECT m.hour_step, DATE_TRUNC('hour', m.d_now) - (INTERVAL '1 hour' * m.hour_step) s_time, m.d_now
		                        FROM (SELECT GENERATE_SERIES(5, 0, -1) hour_step, #{dNow}::TIMESTAMP d_now) m 
		                     ) m
		           ) t
		         LEFT OUTER JOIN
		         (SELECT bi_jh_job_cmpl_time job_cmpl_time,
		                 jsonb_array_elements( bi_jh_job_cycle_step) ->> 'activityType' activity_type,
		                 (jsonb_array_elements( bi_jh_job_cycle_step) -> 'intervalSec')::INTEGER interval_sec
		            FROM public.bi_job_hist jh
		           WHERE jh.bi_jh_tml_id = #{tmlId}
		             AND jh.bi_jh_eq_type = #{eqType}
		             AND jh.bi_jh_job_cmpl_time BETWEEN #{dNow}::TIMESTAMP - (INTERVAL '1 hour' * 6) AND #{dNow}::TIMESTAMP
		             AND jh.bi_jh_job_id IS NOT NULL
		         ) j
		         ON (t.s_time <![CDATA[<=]]> j.job_cmpl_time AND t.e_time >= j.job_cmpl_time)
		GROUP BY t.s_time, t.e_time, t.hour_step
    

--- inquiryJobCycleTimeGraph
  SELECT job_id, cntr_no, job_cmpl_time,
         SUM(CASE WHEN COALESCE(activity_type, 'Working') = 'Working' THEN interval_sec ELSE 0 END) working_time,
 SUM(CASE WHEN activity_type = 'Waiting' THEN interval_sec ELSE 0 END) waiting_time,
     SUM(interval_sec)    
FROM (SELECT bi_jh_job_id job_id, bi_jh_cntr_no cntr_no, bi_jh_job_cmpl_time job_cmpl_time,
             jsonb_array_elements( bi_jh_job_cycle_step) ->> 'activityType' activity_type,
 (jsonb_array_elements( bi_jh_job_cycle_step) -> 'intervalSec')::integer interval_sec
            FROM public.bi_job_hist jh
           WHERE jh.bi_jh_tml_id = :tmlId
             AND jh.bi_jh_eq_type = :eqType
             AND jh.bi_jh_job_cmpl_time BETWEEN :fromDate AND :toDate
             AND jh.bi_jh_job_id IS NOT NULL
         ) m
GROUP BY job_id, cntr_no, job_cmpl_time;
    
--- inquiryJobCycleTimeDetail
		SELECT r_seq, cntr_no, eq_no, from_step, to_step, user_id, eta_distance, ata_distance, eta_time_sec, ata_time_sec, ata_time_sec - eta_time_sec trv_efc_time, ata_distance - eta_distance trv_efc_distance
		  FROM (SELECT row_number() over() r_seq, cntr_no, eq_no, trv_info ->> 'fromStep' from_step, trv_info ->> 'toStep' to_step, user_id,
		               (trv_info -> 'etaDistance')::INTEGER eta_distance, (trv_info -> 'ataDistance')::INTEGER ata_distance,
		               (trv_info -> 'etaTimeSec')::INTEGER eta_time_sec, (trv_info -> 'ataTimeSec')::INTEGER ata_time_sec
		          FROM (SELECT bi_jh_eq_type eq_type, bi_jh_eq_no eq_no, bi_jh_job_id job_id, bi_jh_cntr_no cntr_no, bi_jh_job_cmpl_time job_cmpl_time, bi_jh_user_id user_id,
		                       jsonb_array_elements (bi_jh_trv_with_eta) trv_info
		                  FROM public.bi_job_hist
		                 WHERE bi_jh_trv_with_eta IS NOT NULL
		                   AND bi_jh_tml_id = :tmlId
		                   AND bi_jh_eq_type = :eqType
		                   AND bi_jh_job_id = :jobId) m
		        ) m;
    
    
--- inquiryLadenDistance
          SELECT t.s_time, t.e_time, t.hour_step,
                 SUM(CASE WHEN j.laden_status = 'L' THEN j.trv_dist ELSE 0 END) laden_dist,
                 SUM(CASE WHEN j.laden_status = 'U' THEN j.trv_dist ELSE 0 END) unladen_dist
            FROM (SELECT m.s_time,
                             CASE WHEN m.hour_step = 0 THEN m.d_now ELSE m.s_time + INTERVAL '1 hour' - INTERVAL '1 ms' END e_time,
                             TO_CHAR(m.s_time, 'yyyymmddhh24') hour_step
                        FROM (SELECT m.hour_step, DATE_TRUNC('hour', m.d_now) - (INTERVAL '1 hour' * m.hour_step) s_time, m.d_now
                                FROM (SELECT GENERATE_SERIES(5, 0, -1) hour_step, #{dNow}::TIMESTAMP d_now) m
                             ) m
                   ) t
                   LEFT OUTER JOIN
                   (SELECT e.bi_et_last_job_cmpl_time job_cmpl_time,
                          (jsonb_array_elements(e.bi_et_event_step) -> 'trvDistance')::NUMERIC trv_dist,
                          jsonb_array_elements(e.bi_et_event_step) ->> 'ladenStatus' laden_status
                     FROM public.bi_eq_tran e
                    WHERE e.bi_et_tml_id = #{tmlId}
                      AND e.bi_et_eq_type = #{eqType}
                      AND e.bi_et_event_step IS NOT NULL
                      AND e.bi_et_last_job_cmpl_time BETWEEN #{dNow}::TIMESTAMP - INTERVAL '1 hour' * 6 AND  #{dNow}::TIMESTAMP) j
                   ON (j.job_cmpl_time BETWEEN t.s_time AND t.e_time)
        GROUP BY t.s_time, t.e_time, t.hour_step

    
--- inquiryLadenDistanceGraph
          SELECT eq_no,
                 SUM(CASE WHEN j.laden_status = 'L' THEN j.trv_dist ELSE 0 END) laden_dist,
                 SUM(CASE WHEN j.laden_status = 'U' THEN j.trv_dist ELSE 0 END) unladen_dist,
                 SUM(j.trv_dist) total_dist
            FROM (SELECT e.bi_et_eq_no eq_no,
                         e.bi_et_last_job_cmpl_time job_cmpl_time,
                         (jsonb_array_elements(e.bi_et_event_step) -> 'trvDistance')::INTEGER trv_dist,
                         jsonb_array_elements(e.bi_et_event_step) ->> 'ladenStatus' laden_status
                   FROM public.bi_eq_tran e
                  WHERE e.bi_et_tml_id = :tmlId
                    AND e.bi_et_eq_type = :eqType
                    AND e.bi_et_event_step IS NOT NULL
                    AND e.bi_et_last_job_cmpl_time BETWEEN :fromDate AND :toDate) j
        GROUP BY eq_no;
		      
    
-- inquiryLadenDistanceDetail
		  SELECT ROW_NUMBER () OVER() r_seq,
		         job_cmpl_time, cntr_no, eq_no, job_type, 
		         SUM(CASE WHEN j.laden_status = 'L' THEN j.trv_dist ELSE 0 END) laden_dist,
		         SUM(CASE WHEN j.laden_status = 'U' THEN j.trv_dist ELSE 0 END) unladen_dist,
		         SUM(j.trv_dist) total_dist,
		         user_id
		    FROM (SELECT jh.bi_jh_job_cmpl_time job_cmpl_time, jh.bi_jh_cntr_no cntr_no, jh.bi_jh_eq_no eq_no,
		                 jh.bi_jh_job_type job_type, jh.bi_jh_user_id user_id,
		                 (jsonb_array_elements(jh.bi_jh_job_cycle_step) -> 'trvDistance')::INTEGER trv_dist,
		                 jsonb_array_elements(jh.bi_jh_job_cycle_step) ->> 'ladenStatus' laden_status 
		            FROM public.bi_job_hist jh
		           WHERE jh.bi_jh_tml_id = #{tmlId}
		             AND jh.bi_jh_eq_type = #{eqType}
		             AND jh.bi_jh_eq_no = #{eqNo}
		             AND jh.bi_jh_job_cycle_step IS NOT NULL 
		             AND jh.bi_jh_job_cmpl_time BETWEEN #{fromDate} AND #{toDate}) j
		GROUP BY job_cmpl_time, cntr_no, eq_no, job_type, user_id;
    
    
--- inquiryFuelConsumption
		  SELECT s_time, e_time, hour_step, SUM(COALESCE(fuel, 0)) fuel
		    FROM (SELECT m.s_time,
		                 CASE WHEN m.hour_step = 0 THEN m.d_now ELSE m.s_time + INTERVAL '1 hour' - INTERVAL '1 ms' END e_time,
		                 TO_CHAR(m.s_time, 'yyyymmddhh24') hour_step
		            FROM (SELECT m.hour_step, DATE_TRUNC('hour', m.d_now) - (INTERVAL '1 hour' * m.hour_step) s_time, m.d_now
		                    FROM (SELECT GENERATE_SERIES(5, 0, -1) hour_step, #{dNow}::TIMESTAMP d_now) m 
		                 ) m
		         ) t
		         LEFT OUTER JOIN 
		         (SELECT bi_ev_trv_stime trv_stime, bi_ev_trv_etime trv_etime, bi_ev_fuel fuel
		            FROM public.bi_eq_travel v
		           WHERE v.bi_ev_tml_id = #{tmlId}
		             AND v.bi_ev_eq_type = #{eqType}
                     AND v.bi_ev_trv_stime >= #{dNow}::TIMESTAMP - (INTERVAL '1 hour' * 6)
                     AND v.bi_ev_trv_etime <![CDATA[<=]]> #{dNow}::TIMESTAMP
		         ) v
		         ON (t.s_time <![CDATA[<=]]> v.trv_stime AND t.e_time >= v.trv_etime)
		GROUP BY s_time, e_time, hour_step

    
--- inquiryFuelConsumptionGraph
		SELECT v.eq_no, v.fuel_cons, j.job_fuel
		  FROM (SELECT bi_ev_eq_no eq_no, SUM(COALESCE(bi_ev_fuel, 0)) fuel_cons
		          FROM public.bi_eq_travel
		         WHERE bi_ev_tml_id = #{tmlId}
		            AND bi_ev_eq_type = #{eqType}
		            AND bi_ev_trv_stime >= #{fromDate}
		            AND bi_ev_trv_etime <![CDATA[<=]]> #{toDate}
		            GROUP BY bi_ev_eq_no
		       ) v
		       LEFT OUTER JOIN
		       (  SELECT eq_no, SUM (job_fuel) job_fuel
                    FROM (  SELECT bi_et_eq_no eq_no, bi_et_fuel job_fuel
                              FROM public.bi_eq_tran
                             WHERE bi_et_tml_id = #{tmlId}
                               AND bi_et_eq_type = #{eqType}
                               AND bi_et_last_job_cmpl_time BETWEEN #{fromDate} AND #{toDate}
                         ) j
		        GROUP BY eq_no
		       ) j
		       ON (v.eq_no = j.eq_no)
    
--- inquiryFuelConsumptionDetail
		  SELECT ROW_NUMBER() OVER() r_seq, eq_no, cntr_no, job_type, SUM(trv_dist) trv_dist, fuel, user_id
		    FROM (SELECT bi_jh_eq_no eq_no, bi_jh_cntr_no cntr_no, bi_jh_job_type job_type, 
		                 (JSONB_ARRAY_ELEMENTS(bi_jh_job_cycle_step) -> 'trvDistance')::INTEGER trv_dist, bi_jh_fuel fuel, bi_jh_user_id user_id
		            FROM public.bi_job_hist jh
		           WHERE bi_jh_tml_id = #{tmlId}
		             AND bi_jh_eq_type = #{eqType}
		             AND bi_jh_job_cmpl_time BETWEEN #{fromDate} AND #{toDate}
		             AND bi_jh_eq_no = #{eqNo}) m
		GROUP BY eq_no, cntr_no, job_type, fuel, user_id
    
    
--- inquiryExecutionWithJob
		  SELECT s_time, e_time, hour_step,
		         SUM(COALESCE(job_count, 0)) with_job_count,
		         SUM(COALESCE(without_job_count, 0)) without_job_count,
		         SUM(COALESCE(job_count + without_job_count, 0)) total_count
		    FROM (SELECT m.s_time,
		                   CASE WHEN m.hour_step = 0 THEN m.d_now ELSE m.s_time + INTERVAL '1 hour' - INTERVAL '1 ms' END e_time,
		                   TO_CHAR(m.s_time, 'yyyymmddhh24') hour_step
		              FROM (SELECT m.hour_step, DATE_TRUNC('hour', m.d_now) - (INTERVAL '1 hour' * m.hour_step) s_time, m.d_now
		                      FROM (SELECT GENERATE_SERIES(5, 0, -1) hour_step, #{dNow}::TIMESTAMP d_now) m 
		                   ) m
		           ) t
		          LEFT OUTER JOIN 
		          (SELECT bi_jh_job_cmpl_time job_cmpl_time, 
		                  CASE WHEN bi_jh_job_id IS NOT NULL THEN 1 ELSE 0 END job_count,
		                  CASE WHEN bi_jh_job_id IS NULL THEN 1 ELSE 0 END without_job_count
		             FROM public.bi_job_hist jh
		            WHERE jh.bi_jh_tml_id = #{tmlId}
		              AND jh.bi_jh_eq_type = #{eqType}
		              AND jh.bi_jh_job_cmpl_time BETWEEN #{dNow}::TIMESTAMP - (INTERVAL '1 hour' * 6) AND #{dNow}::TIMESTAMP) jh
		     ON (jh.job_cmpl_time BETWEEN t.s_time AND t.e_time)
		GROUP BY s_time, e_time, hour_step

    
--- inquiryExecutionWithJobGraph
	  	SELECT bi_jh_eq_no eq_no,
	  	       SUM(CASE WHEN bi_jh_job_id IS NOT NULL THEN 1 ELSE 0 END) with_job_count,
	  	       SUM(CASE WHEN bi_jh_job_id IS NULL THEN 1 ELSE 0 END) without_job_count,
	  	       COUNT(*) total_count
	  	  FROM public.bi_job_hist jh
	     WHERE jh.bi_jh_tml_id = #{tmlId}
	  	   AND jh.bi_jh_eq_type = #{eqType}
	  	   AND jh.bi_jh_job_cmpl_time BETWEEN #{fromDate}::TIMESTAMP AND #{toDate}::TIMESTAMP
        GROUP BY bi_jh_eq_no

    
--- inquiryExecutionWithJobDetail
		  SELECT ROW_NUMBER() OVER() r_seq,
		         job_cmpl_time, cntr_no, eq_no, job_type, from_loc, to_loc, SUM(COALESCE(dist, 0)) dist, user_id 
		    FROM (SELECT bi_jh_job_cmpl_time job_cmpl_time, bi_jh_cntr_no cntr_no, bi_jh_eq_no eq_no, bi_jh_job_type job_type,
		                 bi_jh_from_loc from_loc, bi_jh_to_loc to_loc, (jsonb_array_elements(bi_jh_job_cycle_step) -> 'trvDistance')::INTEGER dist,
		                 bi_jh_user_id user_id 
		            FROM public.bi_job_hist jh
		           WHERE jh.bi_jh_tml_id = #{tmlId}
		             AND jh.bi_jh_eq_type = #{eqType}
		             AND jh.bi_jh_job_cmpl_time BETWEEN #{fromDate}::TIMESTAMP AND #{toDate}::TIMESTAMP
		             AND jh.bi_jh_eq_no = #{eqNo}) m
		GROUP BY job_cmpl_time, cntr_no, eq_no, job_type, from_loc, to_loc, user_id
    

