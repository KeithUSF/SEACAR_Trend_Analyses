USE [seacar_atlas]
GO
/****** Object:  StoredProcedure [dbo].[usp_analysis_trends_nekton_update]    Script Date: 9/8/2023 10:03:29 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[usp_analysis_trends_nekton_update]
AS
BEGIN
	SET NOCOUNT ON;

    -- EXECUTE usp_analysis_trends_nekton_update;

	DECLARE @htmlTimestamp varchar(300) = CONCAT('<small class="float-right mr-3" style="color:#ccd">', FORMAT(GETDATE(), 'M.d.yy'), '</small>');
	DECLARE @addTimestamp bit = 1;
	DECLARE @ts varchar(300) = CASE @addTimestamp WHEN 1 THEN @htmlTimestamp END


	;WITH cteAnalysis AS (

		SELECT		a.*,
					ma.LongName,
					ma.ShortName, 
					lu.HabitatID, lu.IndicatorID
		FROM		Combined_NEKTON_Analysis a
		INNER JOIN	ManagedArea ma ON a.AreaID = ma.ManagedAreaID
		INNER JOIN	vw_Combined_Parameter_Indicator lu ON lu.ParameterID = a.ParameterID
	)
	--SELECT * FROM cteAnalysis
	, 
	ctePivoted AS (

		SELECT		AreaID, 
					ShortName,
					HabitatID,
					IndicatorID,

					PorMin = MIN(EarliestYear),
					PorMax = MAX(LatestYear),
					MaxNumYears = MAX(N_Years),

					opt1		= MIN(CASE GearType WHEN 'Trawl' THEN GearType END), 
					opt1_years	= MIN(CASE GearType WHEN 'Trawl' THEN N_Years END), 
					opt1_begY	= MIN(CASE GearType WHEN 'Trawl' THEN EarliestYear END), 
					opt1_endY	= MIN(CASE GearType WHEN 'Trawl' THEN LatestYear END), 
					opt1_min	= MIN(CASE GearType WHEN 'Trawl' THEN [Min] END), 
					opt1_max	= MIN(CASE GearType WHEN 'Trawl' THEN [Max] END), 
					opt1_minY	= MIN(CASE GearType WHEN 'Trawl' THEN Year_MinRichness END), 
					opt1_maxY	= MIN(CASE GearType WHEN 'Trawl' THEN Year_MaxRichness END), 
					opt1_mean	= MIN(CASE GearType WHEN 'Trawl' THEN Mean END), 
					opt1_suff	= MIN(CASE GearType WHEN 'Trawl' THEN SufficientData END + 0), 

					opt2		= MIN(CASE GearType WHEN 'Seine' THEN GearType END), 
					opt2_years	= MIN(CASE GearType WHEN 'Seine' THEN N_Years END), 
					opt2_begY	= MIN(CASE GearType WHEN 'Seine' THEN EarliestYear END), 
					opt2_endY	= MIN(CASE GearType WHEN 'Seine' THEN LatestYear END), 
					opt2_min	= MIN(CASE GearType WHEN 'Seine' THEN [Min] END), 
					opt2_max	= MIN(CASE GearType WHEN 'Seine' THEN [Max] END), 
					opt2_minY	= MIN(CASE GearType WHEN 'Seine' THEN Year_MinRichness END), 
					opt2_maxY	= MIN(CASE GearType WHEN 'Seine' THEN Year_MaxRichness END), 
					opt2_mean	= MIN(CASE GearType WHEN 'Seine' THEN Mean END), 
					opt2_suff	= MIN(CASE GearType WHEN 'Seine' THEN SufficientData END + 0)
				
		FROM		cteAnalysis 
		--WHERE		ROWNUM = 1
		GROUP BY	AreaID, ShortName, HabitatID, IndicatorID

	)
	--SELECT * FROM ctePivoted
	,
	cteResults AS (

		-- per 2023_07_Logic_ManagedAreaHabitatIndicator_V2.xlsx they apparently want to ignore all SEINE
		SELECT	AreaID, 
				ShortName, 
				HabitatID, 
				IndicatorID, 
				opt1, opt1_suff,
				opt2, opt2_suff,
				IndicatorState = 
					CASE 
						WHEN opt1 IS NULL AND opt2 IS NULL THEN 
							CONCAT('Data for Nekton richness is needed for ', ShortName, '.')
						ELSE
							CONCAT(
								'',
								CASE 
									WHEN opt1 IS NOT NULL AND opt1_suff = 1 THEN
										CONCAT(
											CONCAT('Between ', opt1_begY, ' and ', opt1_endY, ' annual ', LOWER(opt1), ' surveys showed average Nekton richness per 100 square meters was ', FORMAT(opt1_mean, 'N2'), ' species, with a maximum of ', FORMAT(opt1_max, 'N2'), ' species per 100 square meters in ', opt1_maxY, ' and a minimum of ', FORMAT(opt1_min, 'N2'), ' species per 100 square meters in ', opt1_minY, '.'),
											--CASE WHEN (opt2 IS NOT NULL AND opt2_suff = 1) THEN
											--	CONCAT(' Annual ', LOWER(opt2), ' surveys showed average Nekton richness per 100 square meters was ', FORMAT(opt2_mean, 'N2'), ' species between ', opt1_begY, ' and ', opt1_endY, ', with a maximum of ', FORMAT(opt2_max, 'N2'), ' species per 100 square meters in ', opt2_maxY, ' and a minimum of ', FORMAT(opt2_min, 'N2'), ' species per 100 square meters in ', opt2_minY, '.')
											--	ELSE ''
											--END
											''
										)

									WHEN opt1 IS NULL AND (opt2 IS NOT NULL AND opt2_suff = 1) THEN 
										CONCAT('Between ', opt2_begY, ' and ', opt2_endY, ' annual ', LOWER(opt2), ' surveys showed average Nekton richness per 100 square meters was ', FORMAT(opt2_mean, 'N2'), ' species, with a maximum of ', FORMAT(opt2_max, 'N2'), ' species per 100 square meters in ', opt2_maxY, ' and a minimum of ', FORMAT(opt2_min, 'N2'), ' species per 100 square meters in ', opt2_minY, '.')

									ELSE CONCAT(
										'Insufficient data was available to assess long-term trends for Nekton richness in ', ShortName, '.',
										' Five years of data are required to assess long-term trends for Nekton richness. ', ShortName, ' only has ', MaxNumYears, ' year', CASE MaxNumYears WHEN 1 THEN '' ELSE 's' END, ' of data as of ', PorMax, '.')
								END,
								''
							)
					END

		FROM	ctePivoted a
	)

	--SELECT AreaID, ShortName, r.HabitatID, r.IndicatorID, mahi.HasData,
	--	Trend = CASE 
	--				WHEN UPPER(r.IndicatorState) LIKE '%DATA%NEEDED%' THEN NULL
	--				WHEN UPPER(r.IndicatorState) LIKE '%INSUFFICIENT%' THEN NULL
	--				ELSE -99
	--			END
	--	,
	--	IndicatorState = CONCAT('<p>', r.IndicatorState, '</p>')
	--FROM ManagedArea_Habitat_Indicator		mahi
	--INNER JOIN cteResults r ON r.AreaID = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID

	UPDATE		mahi
	SET			Trend = CASE 
					WHEN UPPER(r.IndicatorState) LIKE '%DATA%NEEDED%' OR UPPER(r.IndicatorState) LIKE '%NO DATA%' THEN NULL
					WHEN UPPER(r.IndicatorState) LIKE '%INSUFFICIENT%' THEN NULL
					ELSE -99
				END,
				IndicatorState = CONCAT(@ts, '<p>', r.IndicatorState, '</p>')
	FROM		ManagedArea_Habitat_Indicator		mahi
	INNER JOIN	cteResults							r ON r.AreaID = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID;

	/*
	-- GOT DATA? Nope, not enough
	--
	-- Update Trend and "State of the Indicator" text for managed areas with insufficient data
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: WC (7)
	-- Indicators: Nekton richness (9)
	
	UPDATE		mahi
	SET			Trend = NULL, 
				IndicatorState = CONCAT('<p>', 'Insufficient data was available to assess long-term trends for nekton richness in ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData,
	--			NEW_Trend = NULL,
	--			NEW_IndicatorState = CONCAT('<p>', 'Insufficient data was available to assess long-term trends for nekton richness in ', ma.ShortName, '.<p>')
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (9) 
				AND mahi.HasData = 1 
				AND mahip.SufficientData = 0;
	
	



	---- GOT DATA? Nope, zilch
	--
	---- Update Trend and "State of the Indicator" text for managed areas with no data
	----
	---- TABLE: ManagedArea_Habitat_Indicator
	---- FIELDS: Trend, IndicatorState
	-- Habitats: WC (7)
	-- Indicators: Nekton richness (9)
	
	UPDATE		mahi
	SET			Trend = NULL, 
				IndicatorState = CONCAT('<p>', 'Data for nekton richness is needed for ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData,
	--			NEW_Trend = NULL,
	--			NEW_IndicatorState = CONCAT('<p>', 'Data for nekton richness is needed for ', ma.ShortName, '.<p>')
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (9) 
				AND mahi.HasData = 0 
				AND mahip.SufficientData = 0;
	*/


	/*

	SELECT * FROM vw_Combined_Parameter_Indicator WHERE ParameterID IN (SELECT DISTINCT ParameterID FROM Combined_NEKTON_Analysis);
	SELECT * FROM Combined_NEKTON_Analysis WHERE N_Data > 0;
	SELECT * FROM vw_ManagedArea_Habitat_Indicator WHERE IndicatorID IN (SELECT DISTINCT IndicatorID FROM Combined_NEKTON_Analysis a INNER JOIN vw_Combined_Parameter_Indicator b ON a.ParameterID = b.ParameterID);
	SELECT * FROM vw_ManagedArea_Habitat_Indicator_Parameter WHERE ParameterID IN (SELECT DISTINCT ParameterID FROM Combined_NEKTON_Analysis);

	*/


	---- TREND VALUE MEANINGS
	---- ManagedArea_Habitat_Indicator.Trend
	---- NULL	= Insufficient Data;
	----	-99 = Under Review
	----	-1	= Decreasing
	----	0	= No Trend
	----	1	= Increasing

	-- SELECT * FROM vw_Combined_Parameter_Indicator WHERE IndicatorID IN (9) AND Active = 1;

END
