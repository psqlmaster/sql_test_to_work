CREATE PROCEDURE sl_book_pay
-- @sqlmaster
(
    @comp1 INT,
    @mnt1 INT,
    @year1 INT
)
WITH RECOMPILE
AS
-- Счета списания
SELECT w.account_b,
       w.wo_type,
       w.wo_account
INTO #wo
FROM wo_accounts_map AS w
WHERE w.year_v = @year1
      AND id_example =
      (
          SELECT a.id_example
          FROM company_objects_links a
              INNER JOIN company_main AS b
                  ON a.id_company = b.id_company
          WHERE a.id_object = 13
                AND b.comp_scala = @comp1
      );

-- план счетов за год

SELECT b1.account_b AS acc,
       b1.account_name AS acc_name,
       b1.vat_code AS vat,
       v1.vat_prc AS vat_prc,
       b1.tax_rep AS tax_rep,
       b1.tax_rd AS tax_rd,
       b1.tax_acr AS tax_acr,
       b1.tax_pay AS tax_pay,
       b1.advance AS advance,
       b1.currency_id AS currency_id,
       b1.auto_system AS auto_system
INTO #plan1
FROM plan_schetov AS b1
    LEFT OUTER JOIN vat_codes AS v1
        ON b1.vat_code = v1.vat_code
WHERE year_v = @year1
      AND id_example =
      (
          SELECT a.id_example
          FROM company_objects_links a
              INNER JOIN company_main AS b
                  ON a.id_company = b.id_company
          WHERE a.id_object = 5
                AND b.comp_scala = @comp1
      );

-- клиенты

SELECT c.org_code,
       c.report_org_id,
       c.org_name,
       c.organization_id,
       --     (case when c.inn is NULL then '' else convert(varchar(20),c.inn) end) as inn  into #cust
       c.inn AS inn
INTO #cust
FROM organizations c
WHERE id_example =
(
    SELECT a.id_example
    FROM company_objects_links a
        INNER JOIN company_main AS b
            ON a.id_company = b.id_company
    WHERE a.id_object = 1
          AND b.comp_scala = @comp1
);


-- начисления 
SELECT i.factura_number AS factura,
       i.book_date AS f_date,
       c.org_name AS cust_name,
       c.inn AS inn,
       NULL AS paydate,
       ROUND((o.amount_org * o.pay_rate), 2) AS fact_amt,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base20,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat20,
       (CASE
            WHEN p.vat_prc = 10 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base10,
       (CASE
            WHEN p.vat_prc = 10 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat10,
       (CASE
            WHEN p.vat_prc = 0 THEN
                ROUND((o.amount_org * o.pay_rate), 2)
            ELSE
                0.00
        END
       ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       o.invoice AS inv,
       o.book_date AS inv_date,
       cur.currency_name_rus AS cur,
       ROUND(o.amount_org, 2) AS inv_amt,
       p.vat_prc AS vat,
       ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 1), 2) AS inv_base,
       ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 2), 2) AS inv_vat,
       i.percent_value AS prc,
       o.account AS acc,
       o.trans_number AS trans,
       o.customer_code AS cust_code,
       'Начисления' AS type
INTO #part1
FROM scala_sl_operations_all AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    LEFT OUTER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    LEFT OUTER JOIN #plan1 AS p
        ON o.account = p.acc
    LEFT OUTER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    LEFT OUTER JOIN #cust AS c
        ON o.customer_code = c.org_code
WHERE p.tax_acr != 0
      AND p.auto_system != 1
      AND o.pay_line IS NULL
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
      AND o.comp_scala = @comp1;

--- суммовые разницы

SELECT i.factura_number AS factura,
       i.book_date AS f_date,
       c.org_name AS cust_name,
       c.inn AS inn,
       o.book_date AS paydate,
       (-1.00) * (ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc) AS fact_amt,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc, p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc, p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc, p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc, p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 0 THEN
       (ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc)
                      ELSE
                          0.00
                  END
                 ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       o.invoice AS inv,
       o.book_date AS inv_date,
       'РУБ.' AS cur,
       (-1.00) * (ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc) AS inv_amt,
       p.vat_prc AS vat,
       (-1.00) * (ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc, p.vat_prc, 1), 2)) AS inv_base,
       (-1.00) * (ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2) - o.amount_loc, p.vat_prc, 2), 2)) AS inv_vat,
       i.percent_value AS prc,
       o.account AS acc,
       o.trans_number AS trans,
       o.customer_code AS cust_code,
       'Суммовые разницы' AS type
INTO #part2
FROM scala_sl_operations_all AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    LEFT OUTER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    LEFT OUTER JOIN #plan1 AS p
        ON o.account = p.acc
    LEFT OUTER JOIN #cust AS c
        ON o.customer_code = c.org_code
WHERE p.tax_rd != 0
      AND p.auto_system != 1
      AND o.pay_line IS NOT NULL
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
      AND o.comp_scala = @comp1
      AND (ROUND(o.amount_org * pay_rate, 2) - o.amount_org * o.pay_rate) != 0.00;

--- Платежи без РОЛ

SELECT i.factura_number AS factura,
       i.book_date AS f_date,

       --        i.factura_number  as factura,
       -- (case when i.factura_number is null then (ltrim(rtrim(invoice))+'_ADV') else i.factura_number end) as factura,
       --        i.book_date as f_date,
       c.org_name AS cust_name,
       c.inn AS inn,
       o.book_date AS paydate,
       (-1.00) * ROUND((o.amount_org * o.pay_rate), 2) AS fact_amt,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 0 THEN
                          ROUND((o.amount_org * o.pay_rate), 2)
                      ELSE
                          0.00
                  END
                 ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       o.invoice AS inv,
       o.book_date AS inv_date,
       cur.currency_name_rus AS cur,
       (-1.00) * ROUND(o.amount_org, 2) AS inv_amt,
       p.vat_prc AS vat,
       (-1.00) * ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 1), 2) AS inv_base,
       (-1.00) * ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 2), 2) AS inv_vat,
       0.00 AS prc,
       ---        i.percent_value as prc,
       o.account AS acc,
       o.trans_number AS trans,
       o.customer_code AS cust_code,
       (CASE
            WHEN dbo.spis_f(o.comp_scala, o.invoice, o.book_date, o.trans_number) = 0 THEN
                'Платежи без РОЛ'
            ELSE
                'Под списания'
        END
       ) AS type
INTO #part3
FROM scala_sl_operations_all AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    LEFT OUTER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    --       left  join invoices as i
    --         on (i.invoice_number=o.invoice and cmp.id_company=i.id_company)
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    LEFT OUTER JOIN #cust AS c
        ON o.customer_code = c.org_code
WHERE p.tax_pay != 0
      AND p.auto_system != 1
      AND o.pay_line IS NOT NULL
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
      AND o.comp_scala = @comp1;
--       and dbo.spis_f(o.comp_scala,o.invoice,o.book_date,o.trans_number)=0


--- Списания с обр. знаком без рол
SELECT i.factura_number AS factura,
       i.book_date AS f_date,
       --        i.factura_number as factura,
       --        i.book_date as f_date,
       c.org_name AS cust_name,
       c.inn AS inn,
       o.book_date AS paydate,
       ROUND((o.amount_org * o.pay_rate), 2) AS fact_amt,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base20,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat20,
       (CASE
            WHEN p.vat_prc = 10 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base10,
       (CASE
            WHEN p.vat_prc = 10 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat10,
       (CASE
            WHEN p.vat_prc = 0 THEN
                ROUND((o.amount_org * o.pay_rate), 2)
            ELSE
                0.00
        END
       ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       o.invoice AS inv,
       o.book_date AS inv_date,
       cur.currency_name_rus AS cur,
       ROUND(o.amount_org, 2) AS inv_amt,
       p.vat_prc AS vat,
       ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 1), 2) AS inv_base,
       ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 2), 2) AS inv_vat,
       0.00 AS prc,
       --        i.percent_value as prc,
       --        o.account as acc,
       wo.wo_account AS acc,
       o.trans_number AS trans,
       o.customer_code AS cust_code,
       'Списания с обр. знаком без рол' AS type
INTO #part4
FROM scala_sl_operations_all AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    LEFT OUTER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    --       inner join invoices as i
    --         on (i.invoice_number=o.invoice and cmp.id_company=i.id_company)
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN writeoff_list AS w
        ON (
               o.comp_scala = w.comp_scala
               AND o.invoice = w.invoice_number
               AND o.book_date = w.trans_date
               AND o.trans_number = w.trans_number
           )
    INNER JOIN #wo AS wo
        ON (
               wo.account_b = o.account
               AND wo.wo_type = w.wo_type
           )
    LEFT OUTER JOIN #cust AS c
        ON o.customer_code = c.org_code
WHERE p.tax_pay != 0
      AND p.auto_system != 1
      AND p.advance = 1
      AND o.pay_line IS NOT NULL
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
      AND o.comp_scala = @comp1;
--       and dbo.spis_f(o.comp_scala,o.invoice,o.book_date,o.trans_number)!=0


--------------
--select * into #part3 from #part30 as p1 where p1.trans not in (select p2.trans from #part4 as p2)
--------------

-- платежи рол

SELECT NULL AS factura,
       dbo.get_last_month_date(o.book_date) AS f_date,
       NULL AS cust_name,
       NULL AS inn,
       dbo.get_last_month_date(o.book_date) AS paydate,
       (-1.00) * ROUND((o.amount_org * o.pay_rate), 2) AS fact_amt,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 0 THEN
                          ROUND((o.amount_org * o.pay_rate), 2)
                      ELSE
                          0.00
                  END
                 ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       NULL AS inv,
       dbo.get_last_month_date(o.book_date) AS inv_date,
       cur.currency_name_rus AS cur,
       (-1.00) * ROUND(o.amount_org, 2) AS inv_amt,
       p.vat_prc AS vat,
       (-1.00) * ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 1), 2) AS inv_base,
       (-1.00) * ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 2), 2) AS inv_vat,
       NULL AS prc,
       o.account AS acc,
       NULL AS trans,
       o.customer_code AS cust_code,
       'Платежи рол' AS type,
       c.report_org_id AS rep_id
INTO #temp50
FROM scala_sl_operations_all AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    --       inner join invoices as i
    --        on (i.invoice_number=o.invoice and cmp.id_company=i.id_company)
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    LEFT OUTER JOIN #cust AS c
        ON o.customer_code = c.org_code
WHERE p.tax_pay != 0
      AND p.auto_system = 1
      AND
      (
          p.advance = 1
          OR
          (
              p.advance = 0
              AND o.pay_line IS NOT NULL
          )
      )
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
      AND o.comp_scala = @comp1;





SELECT ('RG_' + '_' + LTRIM(RTRIM(c.org_code)) + '_' + LTRIM(RTRIM(t.acc)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(t.paydate)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(t.paydate))))
       ) AS factura,
       t.f_date AS f_date,
       c.org_name AS cust_name,
       c.inn AS inn,
       t.paydate AS paydate,
       SUM(t.fact_amt) AS fact_amt,
       SUM(t.base20) AS base20,
       SUM(t.vat20) AS vat20,
       SUM(t.base10) AS base10,
       SUM(t.vat10) AS vat10,
       SUM(t.base0) AS base0,
       t.export AS export,
       t.pay_doc AS pay_doc,
       ('RG_' + '_' + LTRIM(RTRIM(c.org_code)) + '_' + LTRIM(RTRIM(t.acc)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(t.paydate)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(t.paydate))))
       ) AS inv,
       inv_date AS inv_date,
       t.cur AS cur,
       SUM(t.inv_amt) AS inv_amt,
       t.vat AS vat,
       SUM(t.inv_base) AS inv_base,
       SUM(t.inv_vat) AS inv_vat,
       t.prc AS prc,
       t.acc AS acc,
       t.trans AS trans,
       c.org_code AS cust_code,
       t.type AS type
INTO #part5
FROM #temp50 AS t
    LEFT OUTER JOIN #cust AS c
        ON t.rep_id = c.organization_id
GROUP BY factura,
         f_date,
         c.org_name,
         c.inn,
         paydate,
         export,
         pay_doc,
         inv,
         inv_date,
         cur,
         vat,
         prc,
         acc,
         trans,
         type,
         c.org_code
ORDER BY 1;



-- отгрузка карт


SELECT i.factura_number AS factura,
       i.book_date AS f_date,
       c.org_name AS cust_name,
       c.inn AS inn,
       i.book_date AS paydate,
       (-1.00) * ROUND((it.amount_b), 2) AS fact_amt,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 0 THEN
                          ROUND((it.amount_b), 2)
                      ELSE
                          0.00
                  END
                 ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       i.invoice_number AS inv,
       i.book_date AS inv_date,
       'Руб.' AS cur,
       (-1.00) * ROUND(it.amount_b, 2) AS inv_amt,
       p.vat_prc AS vat,
       (-1.00) * ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 1), 2) AS inv_base,
       (-1.00) * ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 2), 2) AS inv_vat,
       i.percent_value AS prc,
       it.account_b AS acc,
       i.trans_number AS trans,
       c.org_code AS cust_code,
       'Отгрузка карт' AS type
INTO #part6
FROM invoices AS i
    INNER JOIN company_main AS cmp
        ON cmp.id_company = i.id_company
    INNER JOIN invoices_transactions AS it
        ON (i.invoice_id = it.invoice_id)
    INNER JOIN #plan1 AS p
        ON it.account_b = p.acc
    INNER JOIN #cust AS c
        ON i.organization_id = c.organization_id
WHERE p.tax_rep != 0
      AND c.organization_id = c.report_org_id
      AND MONTH(i.book_date) = @mnt1
      AND YEAR(i.book_date) = @year1
      AND cmp.comp_scala = @comp1;




-- активация карт 


SELECT NULL AS factura,
       dbo.get_last_month_date(i.book_date) AS f_date,
       NULL AS cust_name,
       NULL AS inn,
       dbo.get_last_month_date(i.book_date) AS paydate,
       (-1.00) * ROUND((it.amount_b), 2) AS fact_amt,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 10 THEN
                          ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat10,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 0 THEN
                          ROUND((it.amount_b), 2)
                      ELSE
                          0.00
                  END
                 ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       NULL AS inv,
       dbo.get_last_month_date(i.book_date) AS inv_date,
       'Руб.' AS cur,
       (-1.00) * ROUND(it.amount_b, 2) AS inv_amt,
       p.vat_prc AS vat,
       (-1.00) * ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 1), 2) AS inv_base,
       (-1.00) * ROUND(dbo.vat_f(ROUND((it.amount_b), 2), p.vat_prc, 2), 2) AS inv_vat,
       i.percent_value AS prc,
       it.account_b AS acc,
       NULL AS trans,
       c.org_code AS cust_code,
       'Активация карт' AS type,
       c.report_org_id AS rep_id
INTO #temp70
FROM invoices AS i
    INNER JOIN company_main AS cmp
        ON cmp.id_company = i.id_company
    INNER JOIN invoices_transactions AS it
        ON (i.invoice_id = it.invoice_id)
    INNER JOIN #plan1 AS p
        ON it.account_b = p.acc
    INNER JOIN #cust AS c
        ON i.organization_id = c.organization_id
WHERE p.tax_rep != 0
      AND c.organization_id != c.report_org_id
      AND MONTH(i.book_date) = @mnt1
      AND YEAR(i.book_date) = @year1
      AND cmp.comp_scala = @comp1;



SELECT ('Act' + '_' + LTRIM(RTRIM(c.org_code)) + '_' + LTRIM(RTRIM(t.acc)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(t.paydate)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(t.paydate))))
       ) AS factura,
       t.f_date AS f_date,
       c.org_name AS cust_name,
       ' ' AS inn,
       t.paydate AS paydate,
       SUM(t.fact_amt) AS fact_amt,
       SUM(t.base20) AS base20,
       SUM(t.vat20) AS vat20,
       SUM(t.base10) AS base10,
       SUM(t.vat10) AS vat10,
       SUM(t.base0) AS base0,
       t.export AS export,
       t.pay_doc AS pay_doc,
       ('Act' + '_' + LTRIM(RTRIM(c.org_code)) + '_' + LTRIM(RTRIM(t.acc)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(t.paydate)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(t.paydate))))
       ) AS inv,
       inv_date AS inv_date,
       t.cur AS cur,
       SUM(t.inv_amt) AS inv_amt,
       t.vat AS vat,
       SUM(t.inv_base) AS inv_base,
       SUM(t.inv_vat) AS inv_vat,
       t.prc AS prc,
       t.acc AS acc,
       t.trans AS trans,
       c.org_code AS cust_code,
       t.type AS type
INTO #part7
FROM #temp70 AS t
    INNER JOIN #cust AS c
        ON t.rep_id = c.organization_id
GROUP BY factura,
         f_date,
         c.org_name,
         t.inn,
         paydate,
         export,
         pay_doc,
         inv,
         inv_date,
         cur,
         vat,
         prc,
         acc,
         trans,
         type,
         c.org_code
ORDER BY 1;




-- все вместе

SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base10 AS base10,
       vat10 AS vat10,
       base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       inv_amt AS inv_amt,
       vat AS vat,
       inv_base AS inv_base,
       inv_vat AS inv_vat,
       base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       type AS type /*into #total*/
FROM #part1
UNION ALL
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base10 AS base10,
       vat10 AS vat10,
       base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       inv_amt AS inv_amt,
       vat AS vat,
       inv_base AS inv_base,
       inv_vat AS inv_vat,
       base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       type AS type
FROM #part2
UNION ALL
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base10 AS base10,
       vat10 AS vat10,
       base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       inv_amt AS inv_amt,
       vat AS vat,
       inv_base AS inv_base,
       inv_vat AS inv_vat,
       base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       type AS type
FROM #part3
UNION ALL

--/*

SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base10 AS base10,
       vat10 AS vat10,
       base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       inv_amt AS inv_amt,
       vat AS vat,
       inv_base AS inv_base,
       inv_vat AS inv_vat,
       base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       type AS type
FROM #part4
UNION ALL

--*/

SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base10 AS base10,
       vat10 AS vat10,
       base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       inv_amt AS inv_amt,
       vat AS vat,
       inv_base AS inv_base,
       inv_vat AS inv_vat,
       base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       type AS type
FROM #part5
UNION ALL
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base10 AS base10,
       vat10 AS vat10,
       base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       inv_amt AS inv_amt,
       vat AS vat,
       inv_base AS inv_base,
       inv_vat AS inv_vat,
       base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       type AS type
FROM #part6
UNION ALL
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base10 AS base10,
       vat10 AS vat10,
       base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       inv_amt AS inv_amt,
       vat AS vat,
       inv_base AS inv_base,
       inv_vat AS inv_vat,
       base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       type AS type
FROM #part7;
