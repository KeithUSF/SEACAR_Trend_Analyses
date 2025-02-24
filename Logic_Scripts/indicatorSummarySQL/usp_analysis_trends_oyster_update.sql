USE [seacar_atlas]
GO
/****** Object:  StoredProcedure [dbo].[usp_analysis_trends_oyster_update]    Script Date: 9/8/2023 10:03:41 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[usp_analysis_trends_oyster_update]
AS
BEGIN
	SET NOCOUNT ON;

    -- EXECUTE usp_analysis_trends_oyster_update;

	DECLARE @htmlTimestamp varchar(300) = CONCAT('<small class="float-right mr-3" style="color:#ccd">', FORMAT(GETDATE(), 'M.d.yy'), '</small>');
	DECLARE @addTimestamp bit = 1;
	DECLARE @ts varchar(300) = CASE @addTimestamp WHEN 1 THEN @htmlTimestamp END

	-- GOT DATA? Nope, not enough
	--
	-- Update Trend and "State of the Indicator" text for managed areas with insufficient data
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: OY (4)
	-- Indicators: Density, PercentLive, SizeClass (13, 15, 16)
	
	UPDATE		mahi
	SET			Trend = NULL, 
				IndicatorState = CONCAT(@ts, '<p>', 'Insufficient data was available to assess long-term trends for ', 
					CASE mahi.IndicatorID 
						WHEN 13 THEN 'density' 
						WHEN 15 THEN 'percent live' 
						WHEN 16 THEN 'shell height' 
						ELSE '<<__>>' 
					END, 
					' in ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData,
	--			NEW_Trend = NULL,
	--			NEW_IndicatorState = 
	--				CONCAT('<p>', 'Insufficient data was available to assess long-term trends for ', 
	--					CASE mahi.IndicatorID 
	--						WHEN 13 THEN 'density' 
	--						WHEN 15 THEN 'percent live' 
	--						WHEN 16 THEN 'shell height' 
	--						ELSE '<<__>>' 
	--					END, 
	--					' in ', ma.ShortName, '.<p>')
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (13, 15, 16) 
				AND mahi.HasData = 1 
				AND mahip.SufficientData = 0;
	
	



	---- GOT DATA? Nope, zilch
	--
	---- Update Trend and "State of the Indicator" text for managed areas with no data
	----
	---- TABLE: ManagedArea_Habitat_Indicator
	---- FIELDS: Trend, IndicatorState
	-- Habitats: OY (4)
	-- Indicators: Density, PercentLive, SizeClass (13, 15, 16)
	
	UPDATE		mahi
	SET			Trend = NULL, 
				IndicatorState = CONCAT(@ts, 
					'<p>', 'Data for ', 
					CASE mahi.IndicatorID 
						WHEN 13 THEN 'density' 
						WHEN 15 THEN 'percent live' 
						WHEN 16 THEN 'shell height' 
						ELSE '<<__>>' 
					END, 
					' is needed for ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData,
	--			NEW_Trend = NULL,
	--			NEW_IndicatorState = CONCAT('<p>', 'Data for ', 
	--				CASE mahi.IndicatorID 
	--					WHEN 13 THEN 'density' 
	--					WHEN 15 THEN 'percent live' 
	--					WHEN 16 THEN 'shell height' 
	--					ELSE '<<__>>' 
	--				END, 
	--				' is needed for ', ma.ShortName, '.<p>')
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (13, 15, 16) 
				AND mahi.HasData = 0 
				AND mahip.SufficientData = 0;



	/*

	SELECT * FROM vw_Combined_Parameter_Indicator WHERE ParameterID IN (SELECT DISTINCT ParameterID FROM Combined_OYSTER_Analysis);
	SELECT * FROM Combined_OYSTER_Analysis;
	SELECT * FROM vw_ManagedArea_Habitat_Indicator WHERE IndicatorID IN (SELECT DISTINCT IndicatorID FROM Combined_OYSTER_Analysis a INNER JOIN vw_Combined_Parameter_Indicator b ON a.ParameterID = b.ParameterID);
	SELECT * FROM vw_ManagedArea_Habitat_Indicator_Parameter WHERE ParameterID IN (SELECT DISTINCT ParameterID FROM Combined_OYSTER_Analysis);

	*/


	---- TREND VALUE MEANINGS
	---- ManagedArea_Habitat_Indicator.Trend
	---- NULL	= Insufficient Data;
	----	-99 = Under Review
	----	-1	= Decreasing
	----	0	= No Trend
	----	1	= Increasing


	-- SELECT * FROM vw_Combined_Parameter_Indicator WHERE IndicatorID IN (13, 15, 16);

END
