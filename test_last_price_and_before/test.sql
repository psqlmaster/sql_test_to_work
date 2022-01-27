-- @sqlmaster
/**
CREATE TABLE [dbo].[k_kodtov]
(
    [kodtov] [VARCHAR](6) NOT NULL,
    CONSTRAINT [PK_k_kodtov]
        PRIMARY KEY CLUSTERED ([kodtov] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
              ALLOW_PAGE_LOCKS = ON
             ) ON [PRIMARY]
) ON [PRIMARY];

CREATE TABLE [dbo].[ch_price]
(
    [ID] [INT] NOT NULL,
    [KODTOV] [VARCHAR](6) NOT NULL,
    [CENA] [NUMERIC](10, 2) NOT NULL,
    [DATA] [DATETIME] NOT NULL,
    CONSTRAINT [PK_ch_price]
        PRIMARY KEY CLUSTERED ([ID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON,
              ALLOW_PAGE_LOCKS = ON
             ) ON [PRIMARY]
) ON [PRIMARY];



EXEC sp_configure 'show advanced option', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO
EXEC sp_configure 'show advanced option', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO


INSERT INTO ch_price
SELECT *
FROM
    OPENROWSET('Microsoft.ACE.OLEDB.12.0',
               'Excel 12.0;HDR=YES;Database=C:\Users\alek\Downloads\test_data.xlsx',
               'SELECT * FROM [ch_price$]'
              );
INSERT INTO k_kodtov
SELECT *
FROM
    OPENROWSET('Microsoft.ACE.OLEDB.12.0',
               'Excel 12.0;HDR=YES;Database=C:\Users\alek\Downloads\test_data.xlsx',
               'SELECT * FROM [k_kodtov$]'
              );
*/
--Получить цену на начало 16.04.2015 и цену, которая действовала до выставления этой цены.
DECLARE @d DATETIME;
SET @d = '16.04.2015';
WITH cte (kodtov, CENA, data)
AS (SELECT A.kodtov,
           CENA,
           DATA
    FROM dbo.k_kodtov A
        LEFT JOIN
        (
            SELECT a.kodtov,
                   CENA,
                   b.DATA
            FROM dbo.k_kodtov a
                JOIN dbo.ch_price b
                    ON a.kodtov = b.KODTOV
            WHERE DATA < @d
        ) B
            ON B.kodtov = A.kodtov)
SELECT k [Код товара],
       c1 [Цена на 16.04.2015 00:00:00],
       d1 [Дата выставления цены],
       c2 [Предыдущая цена],
       d2 [Дата выставления пред.  цены]
FROM
(
    SELECT A.kodtov k,
           A.CENA c1,
           A.data d1,
           B.CENA c2,
           B.data d2,
           ROW_NUMBER() OVER (PARTITION BY A.kodtov ORDER BY A.data DESC) number
    FROM
    (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY kodtov ORDER BY data DESC) number
        FROM cte
    ) A
        LEFT JOIN
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY kodtov ORDER BY data DESC) number
            FROM cte
        ) B
            ON A.kodtov = B.kodtov
               AND A.number = 1
               AND B.number >= 2
               AND CAST(B.data AS DATE) <= CAST(A.data - 1 AS DATE)
) A
WHERE A.number = 1
ORDER BY A.k;
