USE [seacar_atlas]
GO
/****** Object:  StoredProcedure [dbo].[usp_analysis_trends_coral_update]    Script Date: 9/8/2023 10:03:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




ALTER PROCEDURE [dbo].[usp_analysis_trends_coral_update]
AS
BEGIN
	SET NOCOUNT ON;

    -- EXECUTE usp_analysis_trends_coral_update;

	DECLARE @htmlTimestamp varchar(300) = CONCAT('<small class="float-right mr-3" style="color:#ccd">', FORMAT(GETDATE(), 'M.d.yy'), '</small>');
	DECLARE @addTimestamp bit = 1;
	DECLARE @ts varchar(300) = CASE @addTimestamp WHEN 1 THEN @htmlTimestamp END


	-- GOT DATA? Nope, not enough
	--
	-- Update Trend and "State of the Indicator" text for managed areas with insufficient data
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: CR (2)
	-- Indicators: Grazers and Reef Dependent Species, Percent Cover (11, 12)
	
	UPDATE		mahi
	SET			Trend = NULL, 
				IndicatorState = CONCAT(@ts, '<p>', 'Insufficient data was available to assess long-term trends for ', 
					CASE mahi.IndicatorID 
						WHEN 11 THEN 'species richness' 
						WHEN 12 THEN 'percent cover' 
						ELSE '<<__>>' 
					END, 
					' in ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData,
	--			NEW_Trend = NULL,
	--			NEW_IndicatorState = 
	--				CONCAT('<p>', 'Insufficient data was available to assess long-term trends for ', 
	--					CASE mahi.IndicatorID 
	--						WHEN 11 THEN 'species richness' 
	--						WHEN 12 THEN 'percent cover' 
	--						ELSE '<<__>>' 
	--					END, 
	--					' in ', ma.ShortName, '.<p>')
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (11, 12) 
				AND mahi.HasData = 1 
				AND mahip.SufficientData = 0;
	
	



	---- GOT DATA? Nope, zilch
	--
	---- Update Trend and "State of the Indicator" text for managed areas with no data
	----
	---- TABLE: ManagedArea_Habitat_Indicator
	---- FIELDS: Trend, IndicatorState
	-- Habitats: CR (2)
	-- Indicators: Grazers and Reef Dependent Species, Percent Cover (11, 12)
	
	UPDATE		mahi
	SET			Trend = NULL, 
				IndicatorState = CONCAT(@ts, 
					'<p>', 'Data for ', 
					CASE mahi.IndicatorID 
						WHEN 11 THEN 'species richness' 
						WHEN 12 THEN 'percent cover' 
						ELSE '<<__>>' 
					END, 
					' is needed for ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData,
	--			NEW_Trend = NULL,
	--			NEW_IndicatorState = CONCAT('<p>', 'Data for ', 
	--				CASE mahi.IndicatorID 
	--					WHEN 11 THEN 'species richness' 
	--					WHEN 12 THEN 'percent cover' 
	--					ELSE '<<__>>' 
	--				END, 
	--				' is needed for ', ma.ShortName, '.<p>')
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (11, 12) 
				AND mahi.HasData = 0 
				AND mahip.SufficientData = 0;



	-- I think the below is overwriting any of the above...
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: CR (2)
	-- Indicators: Grazers and Reef Dependent Species, Percent Cover (11, 12)

	;WITH cteAnalysis AS (

		SELECT		a.*,
					ma.LongName,
					ma.ShortName, 
					lu.HabitatID, lu.IndicatorID, lu.IndicatorName, lu.ParameterName
		FROM		Combined_Coral_Analysis a
		INNER JOIN	ManagedArea ma ON a.AreaID = ma.ManagedAreaID
		INNER JOIN	vw_Combined_Parameter_Indicator lu ON lu.ParameterID = a.ParameterID
	)
	--SELECT * FROM cteAnalysis WHERE N_Years > 0;
	,
	cteResults AS (

		SELECT	--AreaID, ShortName, HabitatID, IndicatorID, IndicatorName, 
				a.*, 
				IndicatorState = CASE 
					WHEN (SufficientData = 0 AND N_Years = 0) THEN 
						CONCAT('Long-term ',
							CASE IndicatorID WHEN 11 THEN 'species richness' WHEN 12 THEN 'coral species cover' ELSE '<<ERROR>>' END,
							' survey data is not available in ', ShortName, ', and more monitoring is needed across the state.')

					WHEN (SufficientData = 0 AND N_Years > 0) THEN 
						CONCAT('With only ', N_Years, ' year', CASE N_Years WHEN 1 THEN '' ELSE 's' END, ' of survey data available',
							CASE N_Years WHEN 1 THEN '' ELSE CONCAT(' from ', EarliestYear, ' to ', LatestYear) END, ', there was insufficient data to assess long-term ',
							CASE IndicatorID WHEN 11 THEN 'species richness' WHEN 12 THEN 'coral species cover' ELSE '<<ERROR>>' END, ' in ', ShortName, '.')

					ELSE CASE IndicatorID
						WHEN 11 THEN
							CONCAT('Between ', EarliestYear, ' and ', LatestYear, ', species richness surveys in ', ShortName, ' showed an average of ', FORMAT(Mean, 'N2'), ' grazers and reef dependent species, with a maximum of ', FORMAT([Max], 'N0'), ' in ', Year_MaxRichness, ' and a minimum of ', FORMAT([Min], 'N0'), ' in ', Year_MinRichness, '.')
						WHEN 12 THEN
							CONCAT('Between ', EarliestYear, ' and ', LatestYear, ', data monitoring efforts in ', ShortName, ' showed ', 
							CASE 
								WHEN p > 0.05 THEN 'no significant change'
								WHEN (p <= 0.05 AND LME_Slope < 0.0) THEN 'a decrease' 
								WHEN (p <= 0.05 AND LME_Slope > 0.0) THEN 'an increase' 
								ELSE '<< ERROR >>'
							END, 
							' in the percent cover of coral species.')
						ELSE
							'<< ERROR >>'
					END
				END

		FROM	cteAnalysis a
	)
	--select * from cteResults

	--SELECT AreaID, ShortName, r.HabitatID, r.IndicatorID, mahi.HasData,
		--Trend = CASE 
		--	WHEN (r.SufficientData = 0 AND r.N_Data = 0) THEN NULL
		--	WHEN (r.SufficientData = 0 AND r.N_Data > 0) THEN NULL
		--	WHEN (r.SufficientData = 1 AND LOWER(r.IndicatorState) LIKE '%a decrease%') THEN -1
		--	WHEN (r.SufficientData = 1 AND LOWER(r.IndicatorState) LIKE '%no significant%') THEN 0
		--	WHEN (r.SufficientData = 1 AND LOWER(r.IndicatorState) LIKE '%an increase%') THEN 1
		--	ELSE -99
		--END
	--	,
	--	IndicatorState = CONCAT('<p>', r.IndicatorState, '</p>')
	--FROM ManagedArea_Habitat_Indicator		mahi
	--INNER JOIN cteResults r ON r.AreaID = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID

	UPDATE		mahi
	SET			Trend = CASE 
					WHEN (r.SufficientData = 0 AND r.N_Data = 0) THEN NULL
					WHEN (r.SufficientData = 0 AND r.N_Data > 0) THEN NULL
					WHEN (r.SufficientData = 1 AND LOWER(r.IndicatorState) LIKE '%a decrease%') THEN -99	-- -1
					WHEN (r.SufficientData = 1 AND LOWER(r.IndicatorState) LIKE '%no significant%') THEN -99	-- 0
					WHEN (r.SufficientData = 1 AND LOWER(r.IndicatorState) LIKE '%an increase%') THEN -99	-- 1
					ELSE -99
				END,
				IndicatorState = CONCAT(@ts, '<p>', r.IndicatorState, '</p>')
	FROM		ManagedArea_Habitat_Indicator		mahi
	INNER JOIN	cteResults							r ON r.AreaID = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID;

	/*

	SELECT * FROM vw_Combined_Parameter_Indicator WHERE ParameterID IN (SELECT DISTINCT ParameterID FROM Combined_Coral_Analysis);	P(43, 47) I(12, 11)
	SELECT * FROM Combined_Coral_Analysis WHERE ParameterID = 43 AND N_Data > 0;
	SELECT * FROM Combined_Coral_Analysis WHERE ParameterID = 47 AND N_Data > 0;
	SELECT * FROM vw_ManagedArea_Habitat_Indicator WHERE IndicatorID IN (SELECT DISTINCT IndicatorID FROM Combined_Coral_Analysis a INNER JOIN vw_Combined_Parameter_Indicator b ON a.ParameterID = b.ParameterID); -- 11, 12
	SELECT * FROM vw_ManagedArea_Habitat_Indicator_Parameter WHERE ParameterID IN (SELECT DISTINCT ParameterID FROM Combined_Coral_Analysis);

	*/


	---- TREND VALUE MEANINGS
	---- ManagedArea_Habitat_Indicator.Trend
	---- NULL	= Insufficient Data;
	----	-99 = Under Review
	----	-1	= Decreasing
	----	0	= No Trend
	----	1	= Increasing


	-- SELECT * FROM vw_Combined_Parameter_Indicator WHERE IndicatorID IN (11, 12) AND Active = 1;

END
