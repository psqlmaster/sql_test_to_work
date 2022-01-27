-- не оптимальный вариант для анализа
DECLARE @DateOfRequest DATETIME = '20150416 00:00:01';
IF OBJECT_ID('tempdb..#tmp') IS NOT NULL
    DROP TABLE #tmp;
WITH cte
AS (SELECT *,
           RN = ROW_NUMBER() OVER (PARTITION BY KODTOV,
                                                CONVERT(DATE, DATA)
                                   ORDER BY DATA DESC,
                                            ID DESC
                                  )
    FROM dbo.ch_price)
SELECT KODTOV,
       CENA,
       DATA,
       DateOfPrice = ISNULL(CONVERT(DATETIME, CONVERT(DATE, DATEADD(DD, 1, DATA))), '17530101')
INTO #tmp
FROM cte
WHERE RN = 1;
SELECT [Код товара] = k.kodtov,
       [Цена на 16.04.2015 00:00:01] = c.CENA,
       [Дата выставления цены] = CONVERT(VARCHAR(MAX), c.DATA, 104) + ' ' + CONVERT(VARCHAR(MAX), c.DATA, 108),
       [Предыдущая цена] = p.CENA,
       [Дата выставления пред.  цены] = CONVERT(VARCHAR(MAX), p.DATA, 104) + ' ' + CONVERT(VARCHAR(MAX), p.DATA, 108)
FROM dbo.k_kodtov_1 k
    OUTER APPLY
(
    SELECT TOP (1)
           *
    FROM #tmp t
    WHERE t.KODTOV = k.kodtov
          AND t.DateOfPrice <= @DateOfRequest
    ORDER BY KODTOV,
             DateOfPrice DESC
) c
    OUTER APPLY
(
    SELECT TOP (1)
           *
    FROM #tmp t
    WHERE t.KODTOV = k.kodtov
          AND t.DateOfPrice < c.DateOfPrice
    ORDER BY KODTOV,
             DateOfPrice DESC
) p
ORDER BY k.kodtov;
