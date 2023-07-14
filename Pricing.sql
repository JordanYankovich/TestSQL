USE Import
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.New_OwnPrice') IS NOT NULL
	DROP PROCEDURE dbo.New_OwnPrice
GO

CREATE PROCEDURE dbo.New_OwnPrice
	@Shop INT
AS 

BEGIN

DECLARE @PresentTime AS SMALLDATETIME
DECLARE @OurPrices TABLE (
	LocationId VARCHAR(20) NOT NULL,
	ProductID VARCHAR(20) NOT NULL,
	ValidityDate DATETIME NOT NULL,
	PriceAmount SMALLMONEY NOT NULL
)

SET @PresentTime = CAST(GETDATE() AS SMALLDATETIME)

INSERT INTO @OurPrices
SELECT DISTINCT
	CAST(FileData.ShopNumber AS VARCHAR(20)) AS LocationID,
	CAST(FileData.Product AS VARCHAR(20)) AS ProductID,
	RowDate AS ValidityDate,
	CAST(CASE WHEN Price > PriceGC THEN Price ELSE PriceGC END AS SMALLMONEY) AS PriceAmount
FROM 
		dbo.FileData 
	INNER JOIN (
		SELECT 
			FileData.ShopNumber,
			FileData.Product,
			MAX(FileData.RowDate) AS MaxDate,
			FileData.CodeId
		FROM 
				dbo.FileData
			INNER JOIN (
				SELECT DISTINCT
					FileData.ShopNumber,
					FileData.BatchNo
				FROM
						dbo.FileData
					INNER JOIN (
						SELECT
							ShopNumber,
							MAX(RowDate) AS MaxDate
						FROM
							dbo.FileData
						WHERE 
							BatchNo <> 0
							AND ShopNumber = @Shop
						GROUP BY
							ShopNumber
					) RowDates
							ON RowDates.ShopNumber = FileData.ShopNumber
								AND RowDates.MaxDate = dbo.FileData.RowDate
				WHERE
					BatchNo <> 0
				) Batch
					ON Batch.BatchNo = FileData.BatchNo
						AND Batch.ShopNumber = FileData.ShopNumber
		WHERE
			CodeId = 6
		GROUP BY
			FileData.ShopNumber,
			FileData.Product,
			FileData.CodeId
		) LastBatch
			ON LastBatch.ShopNumber = FileData.ShopNumber
				AND LastBatch.Product = FileData.Product
				AND LastBatch.MaxDate = dbo.FileData.RowDate
				AND LastBatch.CodeId = dbo.FileData.CodeId

UPDATE MUSADTSQL1.DTMUSAKalibrate.dbo.NewPrices
SET
	ValidityDate = SourceTable.ValidityDate,
	PriceAmount = SourceTable.PriceAmount,
	UpdateTime = @PresentTime,
	HasBeenProcessed = CAST(0 AS BIT)
FROM
		MUSADTSQL1.DTMUSAKalibrate.dbo.NewPrices TargetTable
	INNER JOIN
		@OurPrices SourceTable
			ON TargetTable.LocationId = SourceTable.LocationId 
				AND TargetTable.ProductID = SourceTable.ProductID
WHERE
	TargetTable.PriceAmount <> SourceTable.PriceAmount 

END
GO

GRANT EXECUTE ON dbo.New_OwnPrice TO SP_Execute AS dbo
GO
