---- inquiryOEEDefaultValueList
		select * from public.bi_oee_tml_value
		where bi_ov_tml_id = #{biOvTmlId}
		and   bi_ov_tml_gp = #{biOvTmlGp}
		and   bi_ov_eq_type= #{biOvEqType}
		order by bi_ov_value_seq;

---- updateOEEDefaultValue
		UPDATE public.bi_oee_tml_value
		SET bi_ov_value        = #{biOvValue}
		where bi_ov_tml_id     = #{biOvTmlId}
		and   bi_ov_tml_gp     = #{biOvTmlGp}
		and   bi_ov_eq_type    = #{biOvEqType}
		and   bi_ov_value_type = #{biOvValueType};