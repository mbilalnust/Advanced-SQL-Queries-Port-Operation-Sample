-- Productivity only uses job_hist table
--inquiryProductivityByEqType
		SELECT m.s_date, m.e_date, m.hour_step, s.job_qty, j.job_type_qty job_type_qty_str, c.cntr_len_qty cntr_len_qty_str
		  FROM (SELECT m.s_date, -- just creating start and endtimes from the point when date is entered
		               CASE WHEN m.hour_step = 0 THEN m.d_now ELSE m.s_date + INTERVAL '1 hour' - INTERVAL '1 ms' END e_date,
		               TO_CHAR(m.s_date, 'yyyymmddhh24') hour_step
		          FROM (SELECT m.hour_step, DATE_TRUNC('hour', m.d_now) - (INTERVAL '1 hour' * m.hour_step) s_date, m.d_now
		                  FROM (SELECT GENERATE_SERIES(5, 0, -1) hour_step, :dNow::TIMESTAMP d_now) m
		               ) m 
		       ) m
		       LEFT OUTER join -- total job quantity per hour
		       (  SELECT TO_CHAR(h.bi_jh_job_cmpl_time, 'yyyymmddhh24') hour_step, COUNT(*) job_qty
		            FROM public.bi_job_hist h
		           WHERE h.bi_jh_tml_id = :tmlId
		             AND h.bi_jh_job_cmpl_time between :dNow::TIMESTAMP - INTERVAL '1 hour' * 6 and :dNow::TIMESTAMP
		             AND h.bi_jh_eq_type = :eqType
		        GROUP BY TO_CHAR(h.bi_jh_job_cmpl_time, 'yyyymmddhh24')) s
		       ON (m.hour_step = s.hour_step)
		       LEFT OUTER join -- job quantity by job type
		       (  SELECT m.hour_step, TO_JSON(ARRAY_AGG(m.job_type_qty)) job_type_qty -- per hour aggregate of jobs per job type
		            FROM (  SELECT TO_CHAR(h.bi_jh_job_cmpl_time, 'yyyymmddhh24') hour_step, -- summarize hour per job type quantity
		                           JSON_BUILD_OBJECT('jobType',  h.bi_jh_job_type, 'jobQty', COUNT(*)) job_type_qty
		                      FROM public.bi_job_hist h
		                     WHERE h.bi_jh_tml_id = :tmlId
		                       AND h.bi_jh_job_cmpl_time between :dNow::TIMESTAMP - INTERVAL '1 hour' * 6 and :dNow::TIMESTAMP
		                       AND h.bi_jh_eq_type = :eqType
		                  GROUP BY TO_CHAR(h.bi_jh_job_cmpl_time, 'yyyymmddhh24'), h.bi_jh_job_type) m
		        GROUP BY m.hour_step) j
		       ON (m.hour_step = j.hour_step)
               LEFT OUTER join -- job quantity by container size
               (  SELECT m.hour_step, TO_JSON(ARRAY_AGG(m.cntr_len_qty)) cntr_len_qty -- each hour container quantity with size
                   FROM (  SELECT h.hour_step, --- counting in each hour the quantity of 20 and 40'
                                  JSON_BUILD_OBJECT ('cntrLen', cntr_len, 'jobQty', COUNT(*)) cntr_len_qty
                             FROM (SELECT TO_CHAR(h.bi_jh_job_cmpl_time, 'yyyymmddhh24') hour_step, --- extracting timewise 20 and 40' containers
                                          CASE WHEN SUBSTRING(h.bi_jh_cntr_attr ->> 'cntrIso', 1, 1) IS NULL THEN NULL
                                               WHEN SUBSTRING(h.bi_jh_cntr_attr ->> 'cntrIso', 1, 1) = '2' THEN '20'
                                               ELSE '40'
                                          END cntr_len
                                     FROM public.bi_job_hist h
                                    WHERE h.bi_jh_tml_id = :tmlId
                                      AND h.bi_jh_job_cmpl_time between :dNow::TIMESTAMP - INTERVAL '1 hour' * 6 and :dNow::TIMESTAMP
                                      AND h.bi_jh_eq_type = :eqType) h
                         GROUP BY h.hour_step, h.cntr_len) m
                GROUP BY m.hour_step) c
		       ON (m.hour_step = c.hour_step);

			   
			   
-- inquiryProductivityGraphListByEqType
					SELECT m.eq_no, m.job_qty, jt.job_type_qty job_type_qty_str, jc.cntr_len_qty cntr_len_qty_str
		  FROM (  SELECT h.bi_jh_eq_no eq_no, COUNT(*) job_qty -- total jobs by eq no wise
		            FROM public.bi_job_hist h
		           WHERE h.bi_jh_tml_id = :tmlId
		             AND h.bi_jh_eq_type = :eqType
		             AND h.bi_jh_job_cmpl_time BETWEEN :fromDate AND :toDate
		        GROUP BY h.bi_jh_eq_no ) m
		       LEFT OUTER join -- eqno vs job type
		       (  SELECT eq_no, TO_JSON(ARRAY_AGG(m.job_type_qty)) job_type_qty
		            FROM (  SELECT h.bi_jh_eq_no eq_no, JSON_BUILD_OBJECT('jobType',  h.bi_jh_job_type, 'jobQty', COUNT(*)) job_type_qty
		                        FROM public.bi_job_hist h
		                       WHERE h.bi_jh_tml_id = :tmlId
			                     AND h.bi_jh_eq_type = :eqType
			                     AND h.bi_jh_job_cmpl_time BETWEEN :fromDate AND :toDate
		                    GROUP BY h.bi_jh_eq_no, h.bi_jh_job_type) m
		        GROUP BY eq_no) jt
		       ON (m.eq_no = jt.eq_no)
		       LEFT OUTER join --eqno vs container size quantity
		       (  SELECT eq_no, TO_JSON(ARRAY_AGG(m.cntr_len_qty)) cntr_len_qty
                    FROM (  SELECT eq_no, JSON_BUILD_OBJECT('cntrLen', cntr_len, 'jobQty', COUNT(*)) cntr_len_qty
                              FROM (SELECT h.bi_jh_eq_no eq_no, 
                                           CASE WHEN SUBSTRING(h.bi_jh_cntr_attr ->> 'cntrIso', 1, 1) IS NULL THEN NULL
                                                WHEN SUBSTRING(h.bi_jh_cntr_attr ->> 'cntrIso', 1, 1) = '2' THEN '20'
                                                ELSE '40'
                                           END cntr_len
                                      FROM public.bi_job_hist h
                                     WHERE h.bi_jh_tml_id = :tmlId
		                               AND h.bi_jh_eq_type = :eqType
		                               AND h.bi_jh_job_cmpl_time BETWEEN :fromDate AND :toDate
                                   ) h
                          GROUP BY h.eq_no, cntr_len) m
		        GROUP BY eq_no) jc
		       ON (m.eq_no = jc.eq_no);		      

			   
--inquiryProductivityJobList -- only selecting the relevant columns from job hist
  SELECT ROW_NUMBER() OVER() seq,
		         h.bi_jh_job_cmpl_time job_cmpl_time, 
		         CASE WHEN SUBSTRING(h.bi_jh_cntr_attr ->> 'cntrIso', 1, 1) IS NULL THEN NULL
                    WHEN SUBSTRING(h.bi_jh_cntr_attr ->> 'cntrIso', 1, 1) = '2' THEN '20'
                    ELSE '40'
                 END cntr_len,
                 h.bi_jh_eq_no eq_no, h.bi_jh_cntr_no cntr_no,
		         h.bi_jh_job_type job_type, h.bi_jh_from_eq_no from_eq_no, h.bi_jh_to_eq_no to_eq_no, h.bi_jh_user_id user_id
		    FROM public.bi_job_hist h
		   WHERE h.bi_jh_tml_id = :tmlId
		     AND h.bi_jh_eq_type = :eqType
		     AND h.bi_jh_eq_no = :eqNo 
		     AND h.bi_jh_job_cmpl_time BETWEEN :fromDate and :toDate
		ORDER BY h.bi_jh_job_cmpl_time;				      
		      		
		
			   
			