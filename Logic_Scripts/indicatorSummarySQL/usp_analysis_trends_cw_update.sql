USE [seacar_atlas]
GO
/****** Object:  StoredProcedure [dbo].[usp_analysis_trends_cw_update]    Script Date: 9/8/2023 10:03:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[usp_analysis_trends_cw_update]
AS
BEGIN
	SET NOCOUNT ON;

    -- EXECUTE usp_analysis_trends_cw_update;

	DECLARE @htmlTimestamp varchar(300) = CONCAT('<small class="float-right mr-3" style="color:#ccd">', FORMAT(GETDATE(), 'M.d.yy'), '</small>');
	DECLARE @addTimestamp bit = 1;
	DECLARE @ts varchar(300) = CASE @addTimestamp WHEN 1 THEN @htmlTimestamp END

	-- CW Species Richness
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: CW (1)
	-- Indicators: Species Richness (18)

	;WITH cteAnalysis AS (

		SELECT		a.*,
					ma.LongName,
					ma.ShortName, 
					lu.HabitatID, lu.IndicatorID
		FROM		Combined_CW_Analysis a
		INNER JOIN	ManagedArea ma ON a.AreaID = ma.ManagedAreaID
		INNER JOIN	vw_Combined_Parameter_Indicator lu ON lu.ParameterID = a.ParameterID
	)
	--SELECT * FROM cteAnalysis WHERE N_Years > 0;
	--,cteCombined AS (SELECT	*, ROW_NUMBER() OVER (PARTITION BY AreaID ORDER BY SpeciesGroup DESC) AS ROWNUM FROM	cteAnalysis)
	, 
	ctePivoted AS (

		SELECT		AreaID, 
					ShortName,
					HabitatID,
					IndicatorID,

					PorMin = MIN(EarliestYear),
					PorMax = MAX(LatestYear),
					MaxNumYears = MAX(N_Years),

					sg1			= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN SpeciesGroup END), 
					sg1_years	= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN N_Years END), 
					sg1_begY	= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN EarliestYear END), 
					sg1_endY	= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN LatestYear END), 
					sg1_min		= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN [Min] END), 
					sg1_max		= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN [Max] END), 
					sg1_minY	= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN Year_MinRichness END), 
					sg1_maxY	= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN Year_MaxRichness END), 
					sg1_mean	= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN Mean END), 
					sg1_suff	= MIN(CASE SpeciesGroup WHEN 'Mangroves and associate' THEN SufficientData END + 0), 

					sg2			= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN SpeciesGroup END), 
					sg2_years	= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN N_Years END), 
					sg2_begY	= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN EarliestYear END), 
					sg2_endY	= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN LatestYear END), 
					sg2_min		= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN [Min] END), 
					sg2_max		= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN [Max] END), 
					sg2_minY	= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN Year_MinRichness END), 
					sg2_maxY	= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN Year_MaxRichness END), 
					sg2_mean	= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN Mean END), 
					sg2_suff	= MIN(CASE SpeciesGroup WHEN 'Marsh' THEN SufficientData END + 0), 

					sg3			= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN SpeciesGroup END), 
					sg3_years	= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN N_Years END), 
					sg3_begY	= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN EarliestYear END), 
					sg3_endY	= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN LatestYear END), 
					sg3_min		= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN [Min] END), 
					sg3_max		= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN [Max] END), 
					sg3_minY	= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN Year_MinRichness END), 
					sg3_maxY	= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN Year_MaxRichness END), 
					sg3_mean	= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN Mean END), 
					sg3_suff	= MIN(CASE SpeciesGroup WHEN 'Marsh succulents' THEN SufficientData END + 0)
				
		FROM		cteAnalysis 
		--WHERE		ROWNUM = 1
		GROUP BY	AreaID, ShortName, HabitatID, IndicatorID

	)
	,
	cteResults AS (

		SELECT	AreaID, 
				ShortName, 
				HabitatID, 
				IndicatorID, 
				sg1, sg1_suff,
				sg2, sg2_suff,
				sg3, sg3_suff,
				IndicatorState = 
					CASE 
						WHEN sg1 IS NULL AND sg2 IS NULL AND sg3 IS NULL THEN CONCAT('Understanding the species diversity and composition of Florida''s wetlands is important to managing these coastal habitats; however, long-term data for ', ShortName, ' is not available, and more monitoring using comparable methods is needed across the state.')
						ELSE
							CONCAT(
								'',
								CASE 
									WHEN sg1 IS NOT NULL AND sg1_suff = 1 THEN
										CONCAT(
											CONCAT('Between ', sg1_begY, ' and ', sg1_endY, ', species composition surveys showed an average of ', FORMAT(sg1_mean, 'N2'), ' mangroves and associate species, with a maximum of ', FORMAT(sg1_max, 'N2'), ' in ', sg1_maxY, ' and a minimum of ', FORMAT(sg1_min, 'N2'), ' in ', sg1_minY, '.'),
											CASE WHEN (sg2 IS NOT NULL AND sg2_suff = 1) THEN
												CONCAT(' Between ', sg2_begY, ' and ', sg2_endY, ', species composition surveys showed an average of ', FORMAT(sg2_mean, 'N2'), ' marsh species, with a maximum of ', FORMAT(sg2_max, 'N2'), ' in ', sg2_maxY, ' and a minimum of ', FORMAT(sg2_min, 'N2'), ' in ', sg2_minY, '.')
												ELSE ''
											END,
											CASE WHEN (sg3 IS NOT NULL AND sg3_suff = 1) THEN
												CONCAT(' Between ', sg3_begY, ' and ', sg3_endY, ', species composition surveys showed an average of ', FORMAT(sg3_mean, 'N2'), ' marsh succulent species, with a maximum of ', FORMAT(sg3_max, 'N2'), ' in ', sg3_maxY, ' and a minimum of ', FORMAT(sg3_min, 'N2'), ' in ', sg3_minY, '.')
												ELSE ''
											END
										)

									WHEN sg1 IS NULL AND (sg2 IS NOT NULL AND sg2_suff = 1) THEN 
										CONCAT('Between ', sg2_begY, ' and ', sg2_endY, ', species composition surveys showed an average of ', FORMAT(sg2_mean, 'N1'), ' marsh species, with a maximum of ', FORMAT(sg2_max, 'N2'), ' in ', sg2_maxY, ' and a minimum of ', FORMAT(sg2_min, 'N2'), ' in ', sg2_minY, '.',
											CASE 
												WHEN (sg3 IS NOT NULL AND sg3_suff = 1) THEN CONCAT(' Between ', sg3_begY, ' and ', sg3_endY, ', species composition surveys showed an average of ', FORMAT(sg3_mean, 'N2'), ' marsh succulent species, with a maximum of ', FORMAT(sg3_max, 'N2'), ' in ', sg3_maxY, ' and a minimum of ', FORMAT(sg3_min, 'N2'), ' in ', sg3_minY, '.')
												ELSE ''
											END
										)

									WHEN sg1 IS NULL AND sg2 IS NULL AND (sg3 IS NOT NULL AND sg3_suff = 1) THEN 
										CONCAT('Between ', sg3_begY, ' and ', sg3_endY, ', species composition surveys showed an average of ', FORMAT(sg3_mean, 'N1'), ' marsh succulent species, with a maximum of ', FORMAT(sg3_max, 'N2'), ' in ', sg3_maxY, ' and a minimum of ', FORMAT(sg3_min, 'N2'), ' in ', sg3_minY, '.')

									--ELSE CONCAT('Insufficient data was available to assess long-term trends for species composition in ', ShortName, '.')
									ELSE CONCAT('With only ', MaxNumYears, ' year', CASE MaxNumYears WHEN 1 THEN '' ELSE 's' END, ' of survey data available',
											CASE MaxNumYears WHEN 1 THEN '' ELSE CONCAT(' from ', PorMin, ' to ', PorMax) END, ', there was insufficient data to assess long-term species composition trends in ', ShortName, '.')
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
	INNER JOIN	cteResults							r ON r.AreaID = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID
	

	-- SELECT * FROM vw_Combined_Parameter_Indicator WHERE ParameterID IN (49);
END
