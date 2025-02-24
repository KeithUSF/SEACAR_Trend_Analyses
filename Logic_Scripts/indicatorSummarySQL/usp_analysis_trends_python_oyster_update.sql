USE [seacar_atlas]
GO
/****** Object:  StoredProcedure [dbo].[usp_analysis_trends_python_oyster_update]    Script Date: 9/8/2023 10:04:09 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[usp_analysis_trends_python_oyster_update]
AS
BEGIN
	SET NOCOUNT ON;

	-- EXEC usp_analysis_trends_python_oyster_update


	

	DECLARE @htmlTimestamp varchar(300) = CONCAT('<small class="float-right mr-3" style="color:#ccd">', FORMAT(GETDATE(), 'M.d.yy'), '</small>');
	DECLARE @addTimestamp bit = 1;
	DECLARE @ts varchar(300) = CASE @addTimestamp WHEN 1 THEN @htmlTimestamp END;


	;WITH cteResults AS (
		SELECT		a.*, 
					b.ShortName, b.LongName, 
					c.HabitatID, c.HabitatName, c.IndicatorID, c.IndicatorName,
					AnalysisText = CASE a.ParameterID
						WHEN 26 THEN 
							CONCAT(
								'Live oyster density within ', b.ShortName, ' has shown ',
								CASE Significant 
									WHEN 1 THEN CONCAT('', CASE WHEN ModelEstimate > 0 THEN 'an increase' ELSE 'a decrease' END)
									ELSE 'no significant change' 
								END,
								' between ', EarliestLiveDate, ' and ', LatestLiveDate, '.'
							)  
						WHEN 27 THEN 
							CONCAT(
								'Between ', EarliestLiveDate, ' and ', LatestLiveDate, ' data shows ',
								CASE Significant 
									WHEN 1 THEN CONCAT('', CASE WHEN ModelEstimate > 0 THEN 'an increase' ELSE 'a decrease' END)
									ELSE 'no significant change' 
								END,
								' in the proportion of live oysters within ', b.ShortName, '.'
							)
						ELSE '<<ERROR>>'
					END
		FROM		Combined_OYSTER_Analysis a
		INNER JOIN	ManagedArea b on a.AreaID = b.ManagedAreaID
		INNER JOIN	vw_Combined_Parameter_Indicator c ON a.ParameterID = c.ParameterID
		WHERE		HabitatType IN ('Natural') 
					AND a.ParameterID IN (26, 27)
					AND SufficientData = 1
	)

	UPDATE		mahi
	SET			Trend = CASE 
					WHEN UPPER(r.AnalysisText) LIKE '%DATA%NEEDED%' THEN NULL
					WHEN UPPER(r.AnalysisText) LIKE '%INSUFFICIENT%' THEN NULL
					ELSE -99
				END,
				IndicatorState = CONCAT(@ts, '<p>', r.AnalysisText, '</p>')
	FROM		ManagedArea_Habitat_Indicator		mahi
	INNER JOIN	cteResults							r ON r.[AreaID] = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID
	;



END
