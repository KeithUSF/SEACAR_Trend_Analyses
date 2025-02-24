USE [seacar_atlas]
GO
/****** Object:  StoredProcedure [dbo].[usp_analysis_trends_acreage_update]    Script Date: 9/8/2023 10:02:49 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[usp_analysis_trends_acreage_update]
AS
BEGIN
	SET NOCOUNT ON;

    -- EXECUTE usp_analysis_trends_acreage_update;

	DECLARE @htmlTimestamp varchar(300) = CONCAT('<small class="float-right mr-3" style="color:#ccd">', FORMAT(GETDATE(), 'M.d.yy'), '</small>');
	DECLARE @addTimestamp bit = 1;
	DECLARE @ts varchar(300) = CASE @addTimestamp WHEN 1 THEN @htmlTimestamp END

	DECLARE		@RowCount__Acreage_Insufficient_Data INT;
	DECLARE		@RowCount__Acreage_No_Data INT;
	DECLARE		@RowCount__Acreage_With_Data INT;

	-- SELECT * FROM vw_Combined_Parameter_Indicator WHERE IndicatorID IN (2, 33, 17, 14);

	-- ACREAGE DATA? INSUFFICIENT
	-- Update Trend and "State of the Indicator" text for managed areas with insufficient acreage data
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: SAV, CR, CW, OY (6, 2, 1, 4)
	-- Indicators: Acreage (2, 33, 17, 14)

	
	UPDATE		mahi
	--SET			Trend = NULL, IndicatorState = CONCAT(@ts, '<p>', 'Insufficient data was available to assess long-term trends for acreage in ', ma.ShortName, '.<p>')	-- DEP now says treat Insufficient as Needed Data
	SET			Trend = NULL, 
				IndicatorState = CONCAT(@ts, '<p>', 
					CASE mahi.IndicatorID 
						WHEN 2 THEN 'SAV'
						WHEN 14 THEN 'Oyster'
						WHEN 17 THEN 'Coastal wetland'
						WHEN 33 THEN 'Coral'
						ELSE '<ERROR'
					END,
					' mapping data is needed for ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (2, 14, 17, 33) 
				AND mahi.HasData = 1 
				AND mahip.SufficientData = 0;
	
	SELECT @RowCount__Acreage_Insufficient_Data = @@ROWCOUNT;
	PRINT(CONCAT('Acreage (Insufficient Data) Status Updates: ', @RowCount__Acreage_Insufficient_Data));




	-- ACREAGE DATA? NO
	-- Update Trend and "State of the Indicator" text for managed areas with no acreage data
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: SAV, CR, CW, OY (6, 2, 1, 4)
	-- Indicators: Acreage (2, 33, 17, 14)
	
	UPDATE		mahi
	SET			Trend = NULL, 
				IndicatorState = CONCAT(@ts, '<p>', 
					CASE mahi.IndicatorID 
						WHEN 2 THEN 'SAV'
						WHEN 14 THEN 'Oyster'
						WHEN 17 THEN 'Coastal wetland'
						WHEN 33 THEN 'Coral'
						ELSE '<ERROR'
					END,
					' mapping data is needed for ', ma.ShortName, '.<p>')
	--SET			Trend = NULL, IndicatorState = CONCAT(@ts, '<p>', 'No data is available for acreage in ', ma.ShortName, '.<p>')
	--SELECT		mahi.ManagedAreaID, ma.ShortName, mahi.HabitatID, mahi.IndicatorID, mahi.Trend, mahi.IndicatorState, mahi.HasData, mahip.SufficientData
	FROM		ManagedArea_Habitat_Indicator				mahi
	INNER JOIN	ManagedArea_Habitat_Indicator_Parameter		mahip	ON mahip.ManagedAreaHabitatIndicatorID = mahi.ManagedAreaHabitatIndicatorID
	INNER JOIN	ManagedArea									ma		ON mahip.ManagedAreaID = ma.ManagedAreaID AND ma.ManagedAreaID = mahip.ManagedAreaID
	WHERE		mahi.IndicatorID IN (2, 14, 17, 33) 
				AND mahi.HasData = 0 
				AND mahip.SufficientData = 0;

	SELECT @RowCount__Acreage_No_Data = @@ROWCOUNT;
	PRINT(CONCAT('Acreage (No Data) Status Updates: ', @RowCount__Acreage_No_Data));


	-- ACREAGE DATA? YES
	-- Update Trend and "State of the Indicator" text for managed areas with acreage data
	--
	-- TABLE: ManagedArea_Habitat_Indicator
	-- FIELDS: Trend, IndicatorState
	-- Habitats: SAV, CR, CW, OY (6, 2, 1, 4)
	-- Indicators: Acreage (2, 33, 17, 14)

	;WITH cteLandCoverHabitatLU AS (

		SELECT DISTINCT	HabitatId, 
						IndicatorID =	CASE HabitatID 
											WHEN 1 THEN 17	-- CW | Acreage
											WHEN 2 THEN 33  -- CR | Acreage
											WHEN 4 THEN 14  -- OY | Acreage
											WHEN 6 THEN 2	-- SAV | Acreage
										END,
						LandCoverHabitat 
		FROM			Combined_Acreage_Analysis_Detail

	),
	cteAcreageAnalysis AS (

		SELECT		AreaID, 
					ManagedAreaName,
					ManagedAreaShortName = ma.ShortName, 
					lu.HabitatID, lu.IndicatorID, a.LandCoverHabitat, Analysis_Include_YN, LandCoverGroup, 
					LandCoverGroupName = CASE LandCoverGroup
											WHEN 'Invasives' THEN 'Invasives' 
											WHEN 'Mangroves' THEN 'Mangroves' 
											WHEN 'Marsh' THEN 'Marsh' 
											WHEN 'OY' THEN 'Intertidal Oyster Reefs' 
											WHEN 'SAV' THEN 'Submerged Aquatic Vegetation' 
											ELSE LandCoverGroup 
										END, 
					NumberOfYears, 
					MinYear, 
					MinYearHectares =	CASE (CONVERT(decimal(28,3), MinYearHectares) % 1) 
											WHEN 0 THEN FORMAT(MinYearHectares, 'N0') 
											ELSE FORMAT(MinYearHectares, 'N1') 
										END, 
					MaxYear, 
					MaxYearHectares =	CASE (CONVERT(decimal(28,3), MaxYearHectares) % 1) 
											WHEN 0 THEN FORMAT(MaxYearHectares, 'N0') 
											ELSE FORMAT(MaxYearHectares, 'N1') 
										END, 
					HectaresChange, PercentChange, 
					PercentChange100 = 100. * PercentChange, 
					ChangeResult = CASE WHEN PercentChange > 0 THEN 'Increase' WHEN PercentChange < 0 THEN 'Decrease' ELSE 'No Change' END
		FROM		[TUP-WI-SQLDB].seacar.dbo.Combined_Acreage_Analysis a
		INNER JOIN	ManagedArea ma ON a.AreaID = ma.ManagedAreaID
		INNER JOIN	cteLandCoverHabitatLU lu ON lu.LandCoverHabitat = a.LandCoverHabitat

	)
	--SELECT * FROM cteAcreageAnalysis
	,
	cteCombined AS (

		SELECT	*, 
				ROW_NUMBER() OVER (PARTITION BY AreaID, LandCoverHabitat, LandCoverGroup ORDER BY Analysis_Include_YN DESC) AS ROWNUM
		FROM	cteAcreageAnalysis
		WHERE	MinYear != MaxYear -- if minyear==maxyear then there's insufficient data to report a trend/change

	)
	--SELECT * FROM cteCombined
	, 
	ctePivoted AS (

		SELECT		AreaID, 
					ManagedAreaName,
					ManagedAreaShortName,
					HabitatID, 
					IndicatorID, 

					oy1			= MIN(CASE LandCoverGroup WHEN 'OY' THEN LandCoverGroup END), 
					oy1_min		= MIN(CASE LandCoverGroup WHEN 'OY' THEN MinYear END), 
					oy1_minVal	= MIN(CASE LandCoverGroup WHEN 'OY' THEN MinYearHectares END), 
					oy1_max		= MIN(CASE LandCoverGroup WHEN 'OY' THEN MaxYear END), 
					oy1_maxVal	= MIN(CASE LandCoverGroup WHEN 'OY' THEN MaxYearHectares END), 
					oy1_pc		= MIN(CASE LandCoverGroup WHEN 'OY' THEN PercentChange100 END), 
					oy1_pcr		= MIN(CASE LandCoverGroup WHEN 'OY' THEN ChangeResult END), 

					sav1		= MIN(CASE LandCoverGroup WHEN 'SAV' THEN LandCoverGroup END), 
					sav1_min	= MIN(CASE LandCoverGroup WHEN 'SAV' THEN MinYear END), 
					sav1_minVal	= MIN(CASE LandCoverGroup WHEN 'SAV' THEN MinYearHectares END), 
					sav1_max	= MIN(CASE LandCoverGroup WHEN 'SAV' THEN MaxYear END), 
					sav1_maxVal	= MIN(CASE LandCoverGroup WHEN 'SAV' THEN MaxYearHectares END), 
					sav1_pc		= MIN(CASE LandCoverGroup WHEN 'SAV' THEN PercentChange100 END), 
					sav1_pcr	= MIN(CASE LandCoverGroup WHEN 'SAV' THEN ChangeResult END), 
				
					cw1			= MIN(CASE LandCoverGroup WHEN 'Mangroves' THEN LandCoverGroup END), 
					cw1_min		= MIN(CASE LandCoverGroup WHEN 'Mangroves' THEN MinYear END), 
					cw1_minVal	= MIN(CASE LandCoverGroup WHEN 'Mangroves' THEN MinYearHectares END), 
					cw1_max		= MIN(CASE LandCoverGroup WHEN 'Mangroves' THEN MaxYear END), 
					cw1_maxVal	= MIN(CASE LandCoverGroup WHEN 'Mangroves' THEN MaxYearHectares END), 
					cw1_pc		= MIN(CASE LandCoverGroup WHEN 'Mangroves' THEN PercentChange100 END), 
					cw1_pcr		= MIN(CASE LandCoverGroup WHEN 'Mangroves' THEN ChangeResult END), 
				
					cw2			= MIN(CASE LandCoverGroup WHEN 'Marsh' THEN LandCoverGroup END), 
					cw2_min		= MIN(CASE LandCoverGroup WHEN 'Marsh' THEN MinYear END), 
					cw2_minVal	= MIN(CASE LandCoverGroup WHEN 'Marsh' THEN MinYearHectares END), 
					cw2_max		= MIN(CASE LandCoverGroup WHEN 'Marsh' THEN MaxYear END), 
					cw2_maxVal	= MIN(CASE LandCoverGroup WHEN 'Marsh' THEN MaxYearHectares END), 
					cw2_pc		= MIN(CASE LandCoverGroup WHEN 'Marsh' THEN PercentChange100 END), 
					cw2_pcr		= MIN(CASE LandCoverGroup WHEN 'Marsh' THEN ChangeResult END), 
				
					cw3			= MIN(CASE LandCoverGroup WHEN 'Invasives' THEN LandCoverGroup END), 
					cw3_min		= MIN(CASE LandCoverGroup WHEN 'Invasives' THEN MinYear END), 
					cw3_minVal	= MIN(CASE LandCoverGroup WHEN 'Invasives' THEN MinYearHectares END), 
					cw3_max		= MIN(CASE LandCoverGroup WHEN 'Invasives' THEN MaxYear END), 
					cw3_maxVal	= MIN(CASE LandCoverGroup WHEN 'Invasives' THEN MaxYearHectares END), 
					cw3_pc		= MIN(CASE LandCoverGroup WHEN 'Invasives' THEN PercentChange100 END), 
					cw3_pcr		= MIN(CASE LandCoverGroup WHEN 'Invasives' THEN ChangeResult END)

		FROM		cteCombined 
		WHERE		ROWNUM = 1
		GROUP BY	AreaID, ManagedAreaName, ManagedAreaShortName, HabitatID, IndicatorID

	)
	--SELECT * FROM ctePivoted
	,
	cteResults AS (

		SELECT	AreaID, 
				ManagedAreaShortName, 
				HabitatID, 
				IndicatorID, 
				sav1,
				oy1,
				cw1, 
				cw2, 
				cw3,
				IndicatorState = 
					CASE HabitatID 
						-- SAV
						WHEN 6 THEN	
							CONCAT(
								'There has been ',
								CASE 
									WHEN [sav1_pc] = 0 THEN 'no change ' 
									ELSE CONCAT('a ', ABS(sav1_pc), '% ', CASE WHEN [sav1_pc] > 0 THEN 'increase' ELSE 'decrease' END, ' ')
								END, 
								'in hectares of mapped submerged aquatic vegetation between ', 
								[sav1_min], ' (', [sav1_minVal], ' hectares) and ',  CAST([sav1_max] as nvarchar), ' (', [sav1_maxVal], ' hectares).')

						-- OY
						WHEN 4 THEN
							CONCAT(
								'There has been ',
								CASE 
									WHEN [oy1_pc] = 0 THEN 'no change ' 
									ELSE CONCAT('a ', ABS(oy1_pc), '% ', CASE WHEN [oy1_pc] > 0 THEN 'increase' ELSE 'decrease' END, ' ')
								END, 
								'in hectares of mapped intertidal oyster reefs between ', 
								[oy1_min], ' (', [oy1_minVal], ' hectares) and ',  CAST([oy1_max] as nvarchar), ' (', [oy1_maxVal], ' hectares).')

						-- CW
						WHEN 1 THEN 
							CONCAT(
								'Mapping efforts in ', [ManagedAreaShortName], ' show a ', 
								CASE 
									WHEN cw1 IS NOT NULL THEN
												
										CONCAT([cw1_pc], '% change in mangrove coverage ', 
											CASE 
												WHEN [cw1_min] = [cw1_max] THEN CONCAT('in ', [cw1_min]) 
												ELSE CONCAT('between ', [cw1_min], ' and ', [cw1_max]) 
											END, 
										CASE 
											WHEN [cw2] IS NOT NULL AND [cw3] IS NULL THEN ', and a '
											WHEN [cw2] IS NULL AND [cw3] IS NULL THEN ''
											ELSE ', a '
										END,
										CASE WHEN [cw2] IS NOT NULL
											THEN
												CONCAT([cw2_pc], '% change in marsh coverage ', 
													CASE 
														WHEN [cw2_min] = [cw2_max] THEN CONCAT('in ', [cw2_min]) 
														ELSE CONCAT('between ', [cw2_min], ' and ', [cw2_max]) 
													END)
											ELSE ''
										END,
										'', 
										CASE WHEN [cw3] IS NOT NULL THEN 
												CONCAT(', and a ', [cw3_pc], '% change in invasive coverage ', 
													CASE 
														WHEN [cw3_min] = [cw3_max] THEN CONCAT('in ', [cw3_min]) 
														ELSE CONCAT('between ', [cw3_min], ' and ', [cw3_max]) 
													END, 
												'.')
											ELSE '.'
										END)

									WHEN cw1 IS NULL AND cw2 IS NOT NULL AND cw3 IS NULL THEN
										CONCAT([cw2_pc], '% change in marsh coverage ', 
											CASE 
												WHEN [cw2_min] = [cw2_max] THEN CONCAT('in ', [cw2_min]) 
												ELSE CONCAT('between ', [cw2_min], ' and ', [cw2_max]) 
											END,
											'.')
							
									WHEN cw1 IS NULL AND cw2 IS NULL AND cw3 IS NOT NULL THEN
										CONCAT([cw3_pc], '% change in invasive coverage ', 
											CASE 
												WHEN [cw3_min] = [cw3_max] THEN CONCAT('in ', [cw3_min]) 
												ELSE CONCAT('between ', [cw3_min], ' and ', [cw3_max]) 
											END, 
											'.')
							
									ELSE ''

								END)

						ELSE 'ERROR'
					END

		FROM	ctePivoted a
	)
	--SELECT		r.AreaID, r.ManagedAreaShortName, lu.LandCoverHabitat, r.HabitatID, r.IndicatorID,
	--			--mahi.ManagedAreaHabitatIndicatorID, Trend, mahi.HasData, 
	--			mahi.IndicatorState AS [Current_IndiatorState], 
	--			CONCAT('<p>', r.IndicatorState, '</p>') AS [NEW_IndiatorState]
	--FROM		cteResults r
	--LEFT JOIN	ManagedArea_Habitat_Indicator mahi ON r.AreaID = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID
	--INNER JOIN cteLandCoverHabitatLU lu ON r.HabitatID = lu.HabitatID
	--WHERE		mahi.HabitatID IN (1, 2, 4, 6) AND mahi.IndicatorID IN (2, 14, 17, 33)
	--ORDER BY	r.HabitatID ASC, r.AreaID;

	UPDATE		mahi
	SET			Trend = -99,
				IndicatorState = CONCAT(@ts, '<p>', r.IndicatorState, '</p>')
	FROM		ManagedArea_Habitat_Indicator		mahi
	INNER JOIN	cteResults							r ON r.AreaID = mahi.ManagedAreaID AND r.HabitatID = mahi.HabitatID AND r.IndicatorID = mahi.IndicatorID


	SELECT @RowCount__Acreage_With_Data = @@ROWCOUNT;
	PRINT(CONCAT('Acreage (With Data) Status Updates: ', @RowCount__Acreage_With_Data));



	-- TREND VALUE MEANINGS
	-- ManagedArea_Habitat_Indicator.Trend
	-- NULL	= Insufficient Data;
	--	-99 = Under Review
	--	-1	= Decreasing
	--	0	= No Trend
	--	1	= Increasing

	-- SELECT * FROM vw_Combined_Parameter_Indicator WHERE IndicatorID IN (2, 14, 17, 33);

END
