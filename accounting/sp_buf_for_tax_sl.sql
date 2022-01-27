CREATE PROCEDURE [dbo].[sp_buf_for_tax_sl]
-- @sqlmaster
(
    @year1 INT,
    @mnt1 INT,
    @comp1 VARCHAR(2),
    @master VARCHAR(2),
    @clear INT = 1
)
-- функция для формирования КП-КП по оплате с августа  
-- exec sp_buf_for_tax_sl 2008,11,'0','31',1  

AS
DECLARE @id_company INT;
SELECT @id_company = id_company
FROM accounting..company_main
WHERE comp_scala = @master;

IF @clear = 0
    GOTO process;

-------------------выкачка данных для всех компаний в буфер--------------  

SELECT GETDATE(),
       'delete begin';

DELETE FROM sl_book_sov_sl_buf
WHERE (
          (
              MONTH(paydate) = @mnt1
              AND YEAR(paydate) = @year1
          )
          OR
          (
              MONTH(inv_date) = @mnt1
              AND YEAR(inv_date) = @year1
          )
      );

DELETE FROM fn_pl_wo_rol
WHERE MONTH(paydate) = @mnt1
      AND YEAR(paydate) = @year1;

DELETE FROM fn_pl_rol
WHERE MONTH(paydate) = @mnt1
      AND YEAR(paydate) = @year1;

DELETE FROM scala_sl_operations_all_lib_buf
WHERE MONTH(book_date) = @mnt1
      AND YEAR(book_date) = @year1;


SELECT GETDATE(),
       'delete end';

EXEC sp_advance_wrap @mnt1, @year1; ----------формирование буфера с авансами схлопывающимися + на - таблица advance_wrap_buf

INSERT INTO scala_sl_operations_all_lib_buf
(
    comp_scala,
    customer_code,
    invoice,
    book_date,
    trans_number,
    account,
    curr,
    amount_loc,
    amount_org,
    pay_line,
    pay_rate,
    mnth,
    year_v,
    s,
    hist_rate,
    calc_rd,
    trans_rd,
    factura_number,
    invoice_date,
    invoice_no_cred,
    comp_scala_cred
)
SELECT o.comp_scala,
       o.customer_code,
       o.invoice,
       o.book_date,
       o.trans_number,
       o.account,
       o.curr,
       o.amount_loc,
       o.amount_org,
       o.pay_line,
       o.pay_rate,
       o.mnth,
       o.year_v,
       o.s,
       o.hist_rate,
       o.calc_rd,
       o.trans_rd,
       i.factura_number,
       --case when  i.invoice_date is null then o.book_date else i.invoice_date end as invoice_date  
       o.inv_book_date AS invoice_date,
       i.invoice_no_cred,
       cmp2.comp_scala AS comp_scala_cred
FROM scala_sl_operations_all_lib AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    LEFT OUTER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    LEFT JOIN company_main AS cmp2
        ON cmp2.id_company = i.filial_no_cred
WHERE MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1;

SELECT GETDATE(),
       21;

INSERT INTO fn_pl_wo_rol
(
    comp_scala,
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    inv_amt,
    amount_loc,
    base20,
    vat20,
    base18,
    vat18,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    vat,
    vat_code,
    cur_code,
    inv_base,
    inv_vat,
    prc,
    acc,
    trans,
    cust_code,
    type,
    pay_line,
    trans_rd,
    calc_rd,
    invoice_no_cred,
    comp_scala_cred,
    invoice_billing_moving,
    advance_wrap
)
SELECT comp_scala,
       factura,
       f_date,
       cust_name,
       inn,
       kpp,
       paydate,
       fact_amt,
       inv_amt,
       amount_loc,
       base20,
       vat20,
       base18,
       vat18,
       base0,
       export,
       pay_doc,
       inv,
       inv_date,
       cur,
       vat,
       vat_code,
       cur_code,
       inv_base,
       inv_vat,
       prc,
       acc,
       trans,
       cust_code,
       type,
       pay_line,
       trans_rd,
       calc_rd,
       invoice_no_cred,
       comp_scala_cred,
       invoice_billing_moving,
       advance_wrap
FROM dbo.fn_pl_tlr_wo_ROL(@mnt1, @year1, @master)
OPTION (FORCE ORDER);
SELECT GETDATE(),
       22;

---------------------
SELECT o.invoice AS g_factura,
       dbo.get_last_month_date(o.book_date) AS f_date,
       MAX(c.org_code) AS g_org_code,
       c.org_name AS g_cust_name,
       ISNULL(c.inn, '') + ISNULL('/' + c.kpp, '') AS g_inn,
       c.org_name AS cust_name,
       ISNULL(c.inn, ' ') AS inn,
       ISNULL(c.kpp, ' ') AS kpp,
       dbo.get_last_month_date(o.book_date) AS paydate,
       SUM(ROUND((CAST(o.amount_org * o.pay_rate AS MONEY)), 2)) AS fact_amt,
       SUM(ROUND(o.amount_org, 2)) AS inv_amt,
       SUM(ROUND(o.amount_loc, 2)) AS amount_loc,
       SUM(   (CASE
                   WHEN p.vat_prc = 20 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                   ELSE
                       0.00
               END
              )
          ) AS base20,
       SUM(   (CASE
                   WHEN p.vat_prc = 20 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                   ELSE
                       0.00
               END
              )
          ) AS vat20,
       SUM(   (CASE
                   WHEN p.vat_prc = 18 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                   ELSE
                       0.00
               END
              )
          ) AS base18,
       SUM(   (CASE
                   WHEN p.vat_prc = 18 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                   ELSE
                       0.00
               END
              )
          ) AS vat18,
       SUM(   (CASE
                   WHEN p.vat_prc = 0 THEN
                       ROUND((o.amount_org * o.pay_rate), 2)
                   ELSE
                       0.00
               END
              )
          ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       o.invoice AS inv,
       dbo.get_last_month_date(o.book_date) AS inv_date,
       cur.currency_name_rus AS cur,
       p.vat_prc AS vat,
       p.vat AS vat_code,
       cur.currency_id AS cur_code,
       SUM(ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 1), 2)) AS inv_base,
       SUM(ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 2), 2)) AS inv_vat,
       NULL AS prc,
       o.account AS acc,
       MAX(o.trans_number) AS trans,
       MAX(c.org_code) AS cust_code,
       o.comp_scala AS comp_scala,
       'Сгруппированные платежи' AS type,
       c.report_org_id AS rep_id,
       SUM(o.trans_rd) AS trans_rd,
       SUM(o.calc_rd) AS calc_rd,
       (bm.invoice) AS invoice_billing_moving,
       (awb.invoice) AS advance_wrap
INTO #fn_pl_tlr_ROL
FROM scala_sl_operations_all_lib AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    INNER JOIN
    (
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
               b1.purch_book AS pl,
               b1.auto_system AS auto_system,
               b1.tax_book_r AS rev
        FROM plan_schetov AS b1
            INNER JOIN vat_codes AS v1
                ON b1.vat_code = v1.vat_code
        WHERE year_v = @year1
              AND id_example = 1
    ) AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations AS c
        ON (o.customer_code = c.org_code)
           AND (c.id_example = 31)
           AND c.report_org_id = c.organization_id
    LEFT JOIN scala_inv_lib_bill_moving AS bm
        ON bm.comp_scala = o.comp_scala
           AND bm.invoice = o.invoice
           AND o.pay_line IS NULL
    LEFT JOIN advance_wrap_buf AS awb
        ON awb.comp_scala = o.comp_scala
           AND awb.invoice = o.invoice
           AND o.pay_line = awb.pay_line
           AND o.book_date = awb.pay_date
WHERE p.tax_pay = 1
      AND
      (
          p.auto_system = 1
          AND p.vat <> 0
      )
      AND p.advance = 1
      AND p.pl = 1
      AND o.amount_org > 0
      AND o.mnth = @mnt1
      AND o.year_v = @year1
GROUP BY c.org_code,
         o.account,
         o.book_date,
         c.org_name,
         c.inn,
         c.kpp,
         cur.currency_name_rus,
         p.vat_prc,
         p.vat,
         cur.currency_id,
         o.comp_scala,
         bm.invoice,
         o.invoice,
         awb.invoice,
         c.report_org_id
UNION ALL
SELECT g_factura = ('RG_' + '_' + LTRIM(RTRIM(c2.org_code)) + '_' + LTRIM(RTRIM(o.account)) + '_'
                    + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(o.book_date)))) + '_'
                    + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(o.book_date))))
                   ),
       dbo.get_last_month_date(o.book_date) AS f_date,
       c2.org_code AS g_org_code,
       c2.org_name AS g_cust_name,
       ISNULL(c2.inn, '') + ISNULL('/' + c2.kpp, '') AS g_inn,
       'RG group users' AS cust_name,
       ' ' AS inn,
       ' ' AS kpp,
       dbo.get_last_month_date(o.book_date) AS paydate,
       SUM(ROUND((CAST(o.amount_org * o.pay_rate AS MONEY)), 2)) AS fact_amt,
       SUM(ROUND(o.amount_org, 2)) AS inv_amt,
       SUM(ROUND(o.amount_loc, 2)) AS amount_loc,
       SUM(   (CASE
                   WHEN p.vat_prc = 20 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                   ELSE
                       0.00
               END
              )
          ) AS base20,
       SUM(   (CASE
                   WHEN p.vat_prc = 20 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                   ELSE
                       0.00
               END
              )
          ) AS vat20,
       SUM(   (CASE
                   WHEN p.vat_prc = 18 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                   ELSE
                       0.00
               END
              )
          ) AS base18,
       SUM(   (CASE
                   WHEN p.vat_prc = 18 THEN
                       ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                   ELSE
                       0.00
               END
              )
          ) AS vat18,
       SUM(   (CASE
                   WHEN p.vat_prc = 0 THEN
                       ROUND((o.amount_org * o.pay_rate), 2)
                   ELSE
                       0.00
               END
              )
          ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       ('RG_' + '_' + LTRIM(RTRIM(c2.org_code)) + '_' + LTRIM(RTRIM(o.account)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(o.book_date)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(o.book_date))))
       ) AS inv,
       dbo.get_last_month_date(o.book_date) AS inv_date,
       cur.currency_name_rus AS cur,
       p.vat_prc AS vat,
       p.vat AS vat_code,
       cur.currency_id AS cur_code,
       SUM(ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 1), 2)) AS inv_base,
       SUM(ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 2), 2)) AS inv_vat,
       NULL AS prc,
       o.account AS acc,
       MAX(o.trans_number) AS trans,
       c2.org_code AS cust_code,
       o.comp_scala AS comp_scala,
       'Сгруппированные платежи' AS type,
       c2.report_org_id AS rep_id,
       SUM(o.trans_rd) AS trans_rd,
       SUM(o.calc_rd) AS calc_rd,
       (bm.invoice) AS invoice_billing_moving,
       (awb.invoice) AS advance_wrap
FROM scala_sl_operations_all_lib AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    INNER JOIN
    (
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
               b1.purch_book AS pl,
               b1.auto_system AS auto_system,
               b1.tax_book_r AS rev
        FROM plan_schetov AS b1
            INNER JOIN vat_codes AS v1
                ON b1.vat_code = v1.vat_code
        WHERE year_v = @year1
              AND id_example = 1
    ) AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations AS c
        ON (o.customer_code = c.org_code)
           AND (c.id_example = 31)
           AND c.report_org_id <> c.organization_id
    LEFT JOIN organizations AS c2
        ON (c.report_org_id = c2.organization_id)
           AND c2.id_example = 31
    LEFT JOIN scala_inv_lib_bill_moving AS bm
        ON bm.comp_scala = o.comp_scala
           AND bm.invoice = o.invoice
           AND o.pay_line IS NULL
    LEFT JOIN advance_wrap_buf AS awb
        ON awb.comp_scala = o.comp_scala
           AND awb.invoice = o.invoice
           AND o.pay_line = awb.pay_line
           AND o.book_date = awb.pay_date
WHERE p.tax_pay = 1
      AND
      (
          p.auto_system = 1
          AND p.vat <> 0
      )
      AND p.advance = 1
      AND p.pl = 1
      AND o.amount_org > 0
      AND o.mnth = @mnt1
      AND o.year_v = @year1
GROUP BY c2.org_code,
         o.account,
         o.book_date,
         c2.org_name,
         c2.inn,
         c2.kpp,
         cur.currency_name_rus,
         p.vat_prc,
         p.vat,
         cur.currency_id,
         o.comp_scala,
         c2.report_org_id,
         bm.invoice,
         awb.invoice;


INSERT INTO fn_pl_rol
(
    g_factura,
    f_date,
    g_org_code,
    g_cust_name,
    g_inn,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    inv_amt,
    amount_loc,
    base20,
    vat20,
    base18,
    vat18,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    vat,
    vat_code,
    cur_code,
    inv_base,
    inv_vat,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    rep_id,
    trans_rd,
    calc_rd,
    invoice_no_cred,
    comp_scala_cred,
    invoice_billing_moving,
    advance_wrap
)
SELECT g_factura,
       f_date,
       g_org_code,
       g_cust_name,
       g_inn,
       cust_name,
       inn,
       kpp,
       paydate,
       fact_amt,
       inv_amt,
       amount_loc,
       base20,
       vat20,
       base18,
       vat18,
       base0,
       export,
       pay_doc,
       inv,
       inv_date,
       cur,
       vat,
       vat_code,
       cur_code,
       inv_base,
       inv_vat,
       prc,
       acc,
       trans,
       cust_code,
       comp_scala,
       type,
       rep_id,
       trans_rd,
       calc_rd,
       '',
       '',
       invoice_billing_moving,
       advance_wrap
FROM #fn_pl_tlr_ROL;
--from dbo.fn_pl_tlr_ROL(@mnt1,@year1,@master) 
--option (force order)  
SELECT GETDATE(),
       23;



--------------------------------------------------------------------------------------------------------------------  
process:

SELECT *
INTO #SL21REV
FROM OPENQUERY
     (APP_SCALA, 'selecT * from scalaDB.dbo.SL21REV');
SELECT *
INTO #SPECIAL_GL_TRANS_V
FROM OPENQUERY
     (APP_SCALA, 'selecT * from scalaDB.dbo.SPECIAL_GL_TRANS_V');

UPDATE STATISTICS writeoff_list
WITH FULLSCAN;

-- Список компаний для выборки   

CREATE TABLE #master_t
(
    comp_scala VARCHAR(2)
);

IF (@comp1 = '00')
   OR (@comp1 = 0)
    INSERT INTO #master_t
    SELECT comp_scala
    FROM accounting..master_comp_scala
    WHERE comp_master = @master;
ELSE
    INSERT INTO #master_t
    VALUES
    (@comp1);


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
       b1.purch_book AS pl,
       b1.tax_book_r AS rev,
       b1.auto_system AS auto_system
INTO #plan1
FROM plan_schetov AS b1
    LEFT OUTER JOIN vat_codes AS v1
        ON b1.vat_code = v1.vat_code
WHERE year_v = @year1
      AND id_example IN
          (
              SELECT a.id_example
              FROM company_objects_links a
                  INNER JOIN company_main AS b
                      ON a.id_company = b.id_company
              WHERE a.id_object = 5
                    AND b.comp_scala IN
                        (
                            SELECT m3.comp_scala FROM #master_t AS m3
                        )
          );

--ALTER TABLE #plan1 ADD CONSTRAINT PK2 PRIMARY KEY CLUSTERED (acc)   
CREATE UNIQUE CLUSTERED INDEX #plan1_PK2 ON #plan1 (acc);

SELECT GETDATE(),
       3;
-- начисления   
SELECT i.factura_number AS factura,
       i.book_date AS f_date,
       c.org_name AS cust_name,
       (CASE
            WHEN MAIN.dbo.fn_is_inn(c.inn) = 1 THEN
                c.inn
            ELSE
                ''
        END
       ) AS inn,
       ISNULL(c.kpp, '') AS kpp,
       NULL AS paydate,
       --round((o.amount_org*o.pay_rate),2) as fact_amt,  
       o.amount_loc AS fact_amt,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base20,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat20,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base18,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat18,
       (CASE
            WHEN p.vat_prc = 0 THEN
                ROUND((o.amount_loc), 2)
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
       CAST(o.trans_number AS VARCHAR(100)) AS trans,
       o.customer_code AS cust_code,
       o.comp_scala AS comp_scala,
       'Начисления' AS type,
       o.amount_loc AS amount_loc,
       o.calc_rd,
       o.trans_rd,
       o.invoice_no_cred,
       o.comp_scala_cred
INTO #part1
FROM scala_sl_operations_all_lib_buf AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    INNER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations AS c
        ON o.customer_code = c.org_code
           AND c.id_example = @master
WHERE p.tax_acr = 1
      AND
      (
          p.auto_system = 0
          OR
          (
              p.auto_system = 1
              AND p.vat = 0
          )
          OR
          (
              p.auto_system = 1
              AND c.organization_id = c.report_org_id
          )
      )
      AND o.pay_line IS NULL
      AND o.comp_scala IN
          (
              SELECT m3.comp_scala FROM #master_t AS m3
          )
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1;

SELECT GETDATE(),
       '3R';
-- начисления РОЛ  
SELECT ('RG_' + '_' + LTRIM(RTRIM(c2.org_code)) + '_' + LTRIM(RTRIM(o.account)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(i.book_date)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(i.book_date))))
       ) AS factura,
       o.book_date AS f_date,
       c2.org_name AS cust_name,
       ' ' AS inn,
       ' ' AS kpp,
       NULL AS paydate,
       SUM(ROUND((o.amount_loc), 2)) AS fact_amt,
       SUM(   CASE
                  WHEN p.vat_prc = 20 THEN
                      ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 1), 2)
                  ELSE
                      0.00
              END
          ) AS base20,
       SUM(   CASE
                  WHEN p.vat_prc = 20 THEN
                      ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 2), 2)
                  ELSE
                      0.00
              END
          ) AS vat20,
       SUM(   CASE
                  WHEN p.vat_prc = 18 THEN
                      ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 1), 2)
                  ELSE
                      0.00
              END
          ) AS base18,
       SUM(   CASE
                  WHEN p.vat_prc = 18 THEN
                      ROUND(dbo.vat_f(ROUND((o.amount_loc), 2), p.vat_prc, 2), 2)
                  ELSE
                      0.00
              END
          ) AS vat18,
       SUM(   CASE
                  WHEN p.vat_prc = 0 THEN
                      ROUND((o.amount_loc), 2)
                  ELSE
                      0.00
              END
          ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       ('RG_' + '_' + LTRIM(RTRIM(c2.org_code)) + '_' + LTRIM(RTRIM(o.account)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(i.book_date)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(i.book_date))))
       ) AS inv,
       o.book_date AS inv_date,
       cur.currency_name_rus AS cur,
       SUM(ROUND(o.amount_org, 2)) AS inv_amt,
       p.vat_prc AS vat,
       SUM(ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 1), 2)) AS inv_base,
       SUM(ROUND(dbo.vat_f(ROUND((o.amount_org), 2), p.vat_prc, 2), 2)) AS inv_vat,
       i.percent_value AS prc,
       o.account AS acc,
       (CAST(o.trans_number AS VARCHAR(100))) AS trans,
       c2.org_code AS cust_code,
       o.comp_scala AS comp_scala,
       'Сгруппированные начисления' AS type,
       SUM(o.amount_loc) AS amount_loc,
       SUM(o.calc_rd) AS calc_rd,
       SUM(o.trans_rd) AS trans_rd,
       MIN(o.invoice_no_cred) AS invoice_no_cred,
       MIN(o.comp_scala_cred) AS comp_scala_cred
INTO #part1R
FROM scala_sl_operations_all_lib_buf AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    INNER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations AS c
        ON o.customer_code = c.org_code
           AND id_example = @master
    INNER JOIN organizations AS c2
        ON c.report_org_id = c2.organization_id
WHERE p.tax_acr = 1
      AND
      (
          p.auto_system = 1
          AND p.vat <> 0
          AND c.organization_id <> c.report_org_id
      )
      AND o.pay_line IS NULL
      AND o.comp_scala IN
          (
              SELECT m3.comp_scala FROM #master_t AS m3
          )
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
GROUP BY o.book_date,
         c2.org_code,
         c2.org_name,
         i.book_date,
         cur.currency_name_rus,
         p.vat_prc,
         i.percent_value,
         o.account,
         o.comp_scala,
         o.trans_number;

SELECT GETDATE(),
       4;
--- суммовые разницы  

SELECT i.factura_number AS factura,
       i.book_date AS f_date,
       c.org_name AS cust_name,
       (CASE
            WHEN MAIN.dbo.fn_is_inn(c.inn) = 1 THEN
                c.inn
            ELSE
                ''
        END
       ) AS inn,
       ISNULL(c.kpp, '') AS kpp,
       o.book_date AS paydate,
       (CASE
            WHEN SIGN(o.calc_rd) = SIGN(-o.amount_org) THEN
                ROUND(o.calc_rd, 2)
            ELSE
                0.00
        END
       ) AS fact_amt,
       (CASE
            WHEN SIGN(o.calc_rd) = SIGN(-o.amount_org) THEN
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND(o.calc_rd, 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       )
            ELSE
                0.00
        END
       ) AS base20,
       (CASE
            WHEN SIGN(o.calc_rd) = SIGN(-o.amount_org) THEN
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND(o.calc_rd, 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       )
            ELSE
                0.00
        END
       ) AS vat20,
       (CASE
            WHEN SIGN(o.calc_rd) = SIGN(-o.amount_org) THEN
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND(o.calc_rd, 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       )
            ELSE
                0.00
        END
       ) AS base18,
       (CASE
            WHEN SIGN(o.calc_rd) = SIGN(-o.amount_org) THEN
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND(o.calc_rd, 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       )
            ELSE
                0.00
        END
       ) AS vat18,
       (CASE
            WHEN SIGN(o.calc_rd) = SIGN(-o.amount_org) THEN
       (CASE
            WHEN p.vat_prc = 0 THEN
                ROUND(o.calc_rd, 2)
            ELSE
                0.00
        END
       )
            ELSE
                0.00
        END
       ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       o.invoice AS inv,
       o.book_date AS inv_date,
       'РУБ.' AS cur,
       ROUND((o.amount_org * o.pay_rate), 2) AS inv_amt,
       p.vat_prc AS vat,
       (ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)) AS inv_base,
       (ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)) AS inv_vat,
       i.percent_value AS prc,
       o.account AS acc,
       CAST(o.trans_number AS VARCHAR(100)) AS trans,
       o.customer_code AS cust_code,
       o.comp_scala AS comp_scala,
       'Суммовые разницы' AS type,
       -o.amount_loc AS amount_loc,
       o.calc_rd,
       o.trans_rd,
       o.invoice_no_cred,
       o.comp_scala_cred
INTO #part2
FROM scala_sl_operations_all_lib_buf AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    LEFT OUTER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    INNER JOIN organizations AS c
        ON o.customer_code = c.org_code
           AND id_example = @master
WHERE p.tax_rd = 1
      AND o.pay_line IS NOT NULL
      AND o.comp_scala IN
          (
              SELECT m3.comp_scala FROM #master_t AS m3
          )
      AND (CASE
               WHEN SIGN(o.calc_rd) = SIGN(-o.amount_org) THEN
                   ROUND(o.calc_rd, 2)
               ELSE
                   0.00
           END
          ) <> 0 ---fact_amt<>0  
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1;


SELECT GETDATE(),
       5;
--- Платежи без РОЛ  

SELECT CASE
           WHEN (p.advance = 1)
                OR (o.factura_number IS NULL) THEN
               o.invoice
           ELSE
               o.factura_number
       END AS factura,
       CASE
           WHEN (p.advance = 1) THEN
               o.book_date
           ELSE
               o.invoice_date
       END AS f_date,
       c.org_name AS cust_name,
       (CASE
            WHEN MAIN.dbo.fn_is_inn(c.inn) = 1 THEN
                c.inn
            ELSE
                ''
        END
       ) AS inn,
       ISNULL(c.kpp, '') AS kpp,
       o.book_date AS paydate,
       (-1.00) * ROUND((o.amount_org * o.pay_rate), 2) AS fact_amt,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0
                  END
                 ) AS base20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0
                  END
                 ) AS vat20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 18 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0
                  END
                 ) AS base18,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 18 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0
                  END
                 ) AS vat18,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 0 THEN
                          ROUND((o.amount_org * o.pay_rate), 2)
                      ELSE
                          0
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
       o.account AS acc,
       CAST(o.trans_number AS VARCHAR(100)) AS trans,
       o.customer_code AS cust_code,
       o.comp_scala AS comp_scala, --(case when (r.invoice is null) then 'Платежи' else 'сторно' end) as type,  
       'Платежи' AS type,
       -o.amount_loc AS amount_loc,
       o.calc_rd,
       o.trans_rd,
       o.invoice_no_cred,
       o.comp_scala_cred
INTO #part3
FROM scala_sl_operations_all_lib_buf AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations c
        ON o.customer_code = c.org_code
           AND id_example = @master
    LEFT JOIN #SL21REV AS r
        ON (o.invoice = r.invoice COLLATE DATABASE_DEFAULT)
           AND (r.SL21004 = o.trans_number COLLATE DATABASE_DEFAULT)
           AND (o.comp_scala = r.comp_scala COLLATE DATABASE_DEFAULT)
--(o.pay_line=r.SL21003 COLLATE database_default)  
WHERE p.tax_pay = 1
      AND
      (
          p.auto_system = 0
          OR
          (
              p.auto_system = 1
              AND p.vat = 0
          )
          OR
          (
              p.auto_system = 1
              AND c.organization_id = c.report_org_id
          )
      )
      AND
      (
          (
              p.advance = 1
              AND
              (
                  o.amount_org < 0
                  OR p.pl = 0
              )
          )
          OR
          (
              p.advance = 0
              AND o.pay_line IS NOT NULL
          )
      )
      AND o.comp_scala IN
          (
              SELECT m3.comp_scala FROM #master_t AS m3
          )
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
      AND r.invoice IS NULL;



SELECT GETDATE(),
       'Begin storno';
--- Сторно платежей  

SELECT o.invoice AS factura,
       o.SL21006 AS f_date,
       c.org_name AS cust_name,
       (CASE
            WHEN MAIN.dbo.fn_is_inn(c.inn) = 1 THEN
                c.inn
            ELSE
                ''
        END
       ) AS inn,
       ISNULL(c.kpp, '') AS kpp,
       o.SL21006 AS paydate,
       (-1.00) * ROUND((o.SL21008 * er.rate), 2) AS fact_amt,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.SL21008 * er.rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0
                  END
                 ) AS base20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 20 THEN
                          ROUND(dbo.vat_f(ROUND((o.SL21008 * er.rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0
                  END
                 ) AS vat20,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 18 THEN
                          ROUND(dbo.vat_f(ROUND((o.SL21008 * er.rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0
                  END
                 ) AS base18,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 18 THEN
                          ROUND(dbo.vat_f(ROUND((o.SL21008 * er.rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0
                  END
                 ) AS vat18,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 0 THEN
                          ROUND((o.SL21008 * er.rate), 2)
                      ELSE
                          0
                  END
                 ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       o.invoice AS inv,
       i.inv_book_date AS inv_date,
       cur.currency_name_rus AS cur,
       (-1.00) * ROUND(o.SL21008, 2) AS inv_amt,
       p.vat_prc AS vat,
       (-1.00) * ROUND(dbo.vat_f(ROUND((o.SL21008), 2), p.vat_prc, 1), 2) AS inv_base,
       (-1.00) * ROUND(dbo.vat_f(ROUND((o.SL21008), 2), p.vat_prc, 2), 2) AS inv_vat,
       0.00 AS prc,
       i.account AS acc,
       CAST(o.SL21004 AS VARCHAR(100)) AS trans,
       o.org_code AS cust_code,
       o.comp_scala AS comp_scala,
       'сторно' AS type,
       -o.SL21007 AS amount_loc,
       NULL AS calc_rd,
       NULL AS trans_rd,
       NULL AS invoice_no_cred,
       NULL AS comp_scala_cred
INTO #part_storno
FROM #SL21REV AS o
    INNER JOIN scala_inv_lib AS i
        ON (i.comp_scala = o.comp_scala COLLATE DATABASE_DEFAULT)
           AND (i.invoice = o.invoice COLLATE DATABASE_DEFAULT)
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = i.comp_scala
    INNER JOIN #plan1 AS p
        ON i.account = p.acc
    INNER JOIN currency_list AS cur
        ON i.curr = cur.currency_code
    INNER JOIN organizations c
        ON i.customer_code = c.org_code
           AND c.id_example = @master
    INNER JOIN exch_rates AS er
        ON er.rate_date = o.SL21006
           AND er.trg_curr = cmp.base_curr
           AND er.src_curr = i.curr
WHERE p.tax_pay = 1
      AND
      (
          p.auto_system = 0
          OR
          (
              p.auto_system = 1
              AND p.vat = 0
          )
          OR
          (
              p.auto_system = 1
              AND c.organization_id = c.report_org_id
          )
      )
      AND i.comp_scala IN
          (
              SELECT m3.comp_scala FROM #master_t AS m3
          )
      AND MONTH(o.SL21006) = @mnt1
      AND YEAR(o.SL21006) = @year1;

SELECT GETDATE(),
       'Begin Списания с обр. знаком';
--- Списания с обр. знаком  

SELECT CASE
           WHEN (p.advance = 1)
                OR (i.factura_number IS NULL) THEN
               o.invoice
           ELSE
               i.factura_number
       END AS factura,
       CASE
           WHEN (p.advance = 1)
                OR (i.invoice_date IS NULL) THEN
               o.book_date
           ELSE
               i.invoice_date
       END AS f_date,
       c.org_name AS cust_name,
       (CASE
            WHEN MAIN.dbo.fn_is_inn(c.inn) = 1 THEN
                c.inn
            ELSE
                ''
        END
       ) AS inn,
       ISNULL(c.kpp, '') AS kpp,
       o.book_date AS paydate,
       ROUND((o.amount_org * o.pay_rate), 2) AS fact_amt,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
            ELSE
                0
        END
       ) AS base20,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
            ELSE
                0
        END
       ) AS vat20,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
            ELSE
                0
        END
       ) AS base18,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
            ELSE
                0
        END
       ) AS vat18,
       (CASE
            WHEN p.vat_prc = 0 THEN
                ROUND((o.amount_org * o.pay_rate), 2)
            ELSE
                0
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
       0 AS prc,
       --wo.wo_account as acc,  
       o.account AS acc,
       CAST(o.trans_number AS VARCHAR(100)) AS trans,
       o.customer_code AS cust_code,
       o.comp_scala AS comp_scala,
       'Списания кредит. задолженности' AS type,
       o.amount_loc AS amount_loc,
       o.calc_rd,
       o.trans_rd,
       o.invoice_no_cred,
       o.comp_scala_cred
INTO #part4
FROM scala_sl_operations_all_lib_buf AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    LEFT OUTER JOIN invoices AS i
        ON (
               i.invoice_number = o.invoice
               AND cmp.id_company = i.id_company
           )
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN writeoff_list AS w
        ON (
               o.comp_scala = w.comp_scala
               AND o.invoice = w.invoice_number
               AND o.book_date = w.trans_date
               AND o.trans_number = w.trans_number
           )
    INNER JOIN
    (
        SELECT w.account_b,
               w.wo_type,
               w.wo_account
        FROM wo_accounts_map AS w
        WHERE w.year_v = @year1
              AND id_example IN
                  (
                      SELECT a.id_example
                      FROM company_objects_links a
                          INNER JOIN company_main AS b
                              ON a.id_company = b.id_company
                      WHERE a.id_object = 13
                            AND b.comp_scala IN
                                (
                                    SELECT m3.comp_scala FROM #master_t AS m3
                                )
                  )
    ) AS wo
        ON (
               wo.account_b = o.account
               AND wo.wo_type = w.wo_type
           )
    INNER JOIN organizations AS c
        ON o.customer_code = c.org_code
           AND id_example = @master
WHERE p.tax_pay = 1
      AND p.advance = 1
      AND o.pay_line IS NOT NULL
      AND o.comp_scala IN
          (
              SELECT m3.comp_scala FROM #master_t AS m3
          )
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1;

SELECT GETDATE(),
       7;
-- платежи рол  

SELECT NULL AS factura,
       dbo.get_last_month_date(o.book_date) AS f_date,
       NULL AS cust_name,
       NULL AS inn,
       NULL AS kpp,
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
                      WHEN p.vat_prc = 18 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 1), 2)
                      ELSE
                          0.00
                  END
                 ) AS base18,
       (-1.00) * (CASE
                      WHEN p.vat_prc = 18 THEN
                          ROUND(dbo.vat_f(ROUND((o.amount_org * o.pay_rate), 2), p.vat_prc, 2), 2)
                      ELSE
                          0.00
                  END
                 ) AS vat18,
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
       ' ' AS trans,
       o.customer_code AS cust_code,
       o.comp_scala AS comp_scala,
       'Сгруппированные платежи' AS type,
       c.report_org_id AS rep_id,
       -o.amount_loc AS amount_loc,
       o.calc_rd,
       o.trans_rd,
       o.invoice_no_cred,
       o.comp_scala_cred
INTO #temp50
FROM scala_sl_operations_all_lib_buf AS o
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = o.comp_scala
    INNER JOIN #plan1 AS p
        ON o.account = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations AS c
        ON o.customer_code = c.org_code
           AND id_example = @master
    LEFT OUTER JOIN writeoff_list AS w
        ON (
               o.comp_scala = w.comp_scala
               AND o.invoice = w.invoice_number
               AND o.book_date = w.trans_date
               AND o.trans_number = w.trans_number
           )
WHERE p.tax_pay = 1
      AND p.auto_system = 1
      AND
      (
          (
              p.advance = 1
              AND
              (
                  o.amount_org < 0
                  OR p.pl = 0
              )
              AND w.invoice_number IS NULL
          )
          OR
          (
              p.advance = 0
              AND o.pay_line IS NOT NULL
          )
      )
      AND o.comp_scala IN
          (
              SELECT m3.comp_scala FROM #master_t AS m3
          )
      AND MONTH(o.book_date) = @mnt1
      AND YEAR(o.book_date) = @year1
      AND c.organization_id <> c.report_org_id;

SELECT ('RG_' + '_' + LTRIM(RTRIM(c.org_code)) + '_' + LTRIM(RTRIM(t.acc)) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(2), MONTH(t.paydate)))) + '_'
        + LTRIM(RTRIM(CONVERT(VARCHAR(4), YEAR(t.paydate))))
       ) AS factura,
       t.f_date AS f_date,
       c.org_name AS cust_name,
       ISNULL(MIN(c.inn), '') AS inn,
       ISNULL(MIN(c.kpp), '') AS kpp,
       t.paydate AS paydate,
       SUM(t.fact_amt) AS fact_amt,
       SUM(t.base20) AS base20,
       SUM(t.vat20) AS vat20,
       SUM(t.base18) AS base18,
       SUM(t.vat18) AS vat18,
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
       CAST(t.trans AS VARCHAR(100)) AS trans,
       c.org_code AS cust_code,
       t.comp_scala AS comp_scala,
       t.type AS type,
       SUM(t.amount_loc) AS amount_loc,
       SUM(t.calc_rd) AS calc_rd,
       SUM(t.trans_rd) AS trans_rd,
       invoice_no_cred,
       comp_scala_cred
INTO #part5
FROM #temp50 AS t
    LEFT OUTER JOIN organizations AS c
        ON t.rep_id = c.organization_id
GROUP BY factura,
         f_date,
         c.org_name,
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
         c.org_code,
         t.comp_scala,
         invoice_no_cred,
         comp_scala_cred;

SELECT GETDATE(),
       11;
-- Платежи без РОЛ (special,TARAS-X из КЗ)  

SELECT t.factura,
       t.f_date,
       t.cust_name,
       t.inn,
       t.kpp,
       t.paydate,
       -t.fact_amt AS fact_amt,
       -t.base20 AS base20,
       -t.vat20 AS vat20,
       -t.base18 AS base18,
       -t.vat18 AS vat18,
       -t.base0 AS base0,
       t.export,
       t.pay_doc,
       t.inv,
       t.inv_date,
       t.cur,
       -t.inv_amt AS inv_amt,
       t.vat AS vat,
       -t.inv_base AS inv_base,
       -t.inv_vat AS inv_vat,
       t.prc,
       t.acc,
       t.trans,
       t.cust_code,
       t.comp_scala,
       'special' AS type,
       t.amount_loc AS amount_loc,
       0 AS calc_rd,
       0 AS trans_rd,
       t.invoice_no_cred,
       t.comp_scala_cred
INTO #part9
FROM fn_pl_wo_rol AS t
    INNER JOIN #SPECIAL_GL_TRANS_V AS s
        ON (
               (t.comp_scala = s.comp_scala COLLATE DATABASE_DEFAULT)
               AND (YEAR(t.f_date) = s.year_v)
               AND (t.trans = s.trans_number COLLATE DATABASE_DEFAULT)
           )
WHERE t.comp_scala IN
      (
          SELECT m3.comp_scala FROM #master_t AS m3
      )
      AND MONTH(t.f_date) = @mnt1
      AND YEAR(t.f_date) = @year1;


SELECT t.factura AS factura,
       t.paydate AS f_date,
       c.org_name AS cust_name,
       (CASE
            WHEN MAIN.dbo.fn_is_inn(c.inn) = 1 THEN
                c.inn
            ELSE
                ''
        END
       ) AS inn,
       ISNULL(c.kpp, '') AS kpp,
       t.paydate AS paydate,
       t.amount_loc AS fact_amt,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base20,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat20,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base18,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat18,
       (CASE
            WHEN p.vat_prc = 0 THEN
                ROUND((t.amount_loc), 2)
            ELSE
                0.00
        END
       ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       t.factura AS inv,
       t.paydate AS inv_date,
       cur.currency_name_rus AS cur,
       ROUND(t.inv_amt, 2) AS inv_amt,
       p.vat_prc AS vat,
       ROUND(dbo.vat_f(ROUND((t.inv_amt), 2), p.vat_prc, 1), 2) AS inv_base,
       ROUND(dbo.vat_f(ROUND((t.inv_amt), 2), p.vat_prc, 2), 2) AS inv_vat,
       NULL AS prc,
       t.acc AS acc,
       CAST(t.trans AS VARCHAR(100)) AS trans,
       c.org_code AS cust_code,
       t.comp_scala AS comp_scala,
       CASE
           WHEN t.advance_wrap IS NOT NULL THEN
               'advance_wrap'
           ELSE
               'billing_moving'
       END AS type,
       t.amount_loc AS amount_loc,
       NULL AS calc_rd,
       NULL AS trans_rd,
       NULL invoice_no_cred,
       NULL comp_scala_cred
INTO #part_adv_wrap
FROM fn_pl_wo_rol AS t
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = t.comp_scala
    INNER JOIN #plan1 AS p
        ON t.acc = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations AS c
        ON t.cust_code = c.org_code
           AND c.id_example = @master
WHERE MONTH(t.paydate) = @mnt1
      AND YEAR(t.paydate) = @year1
      AND
      (
          t.advance_wrap IS NOT NULL
          OR t.invoice_billing_moving IS NOT NULL
      );

SELECT GETDATE(),
       15;


SELECT t.g_factura AS factura,
       t.paydate AS f_date,
       c.org_name AS cust_name,
       (CASE
            WHEN MAIN.dbo.fn_is_inn(c.inn) = 1 THEN
                c.inn
            ELSE
                ''
        END
       ) AS inn,
       ISNULL(c.kpp, '') AS kpp,
       t.paydate AS paydate,
       t.amount_loc AS fact_amt,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base20,
       (CASE
            WHEN p.vat_prc = 20 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat20,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 1), 2)
            ELSE
                0.00
        END
       ) AS base18,
       (CASE
            WHEN p.vat_prc = 18 THEN
                ROUND(dbo.vat_f(ROUND((t.amount_loc), 2), p.vat_prc, 2), 2)
            ELSE
                0.00
        END
       ) AS vat18,
       (CASE
            WHEN p.vat_prc = 0 THEN
                ROUND((t.amount_loc), 2)
            ELSE
                0.00
        END
       ) AS base0,
       NULL AS export,
       NULL AS pay_doc,
       t.g_factura AS inv,
       t.paydate AS inv_date,
       cur.currency_name_rus AS cur,
       ROUND(t.inv_amt, 2) AS inv_amt,
       p.vat_prc AS vat,
       ROUND(dbo.vat_f(ROUND((t.inv_amt), 2), p.vat_prc, 1), 2) AS inv_base,
       ROUND(dbo.vat_f(ROUND((t.inv_amt), 2), p.vat_prc, 2), 2) AS inv_vat,
       NULL AS prc,
       t.acc AS acc,
       CAST(t.trans AS VARCHAR(100)) AS trans,
       c.org_code AS cust_code,
       t.comp_scala AS comp_scala,
       CASE
           WHEN t.advance_wrap IS NOT NULL THEN
               'advance_wrap'
           ELSE
               'billing_moving'
       END AS type,
       t.amount_loc AS amount_loc,
       NULL AS calc_rd,
       NULL AS trans_rd,
       NULL invoice_no_cred,
       NULL comp_scala_cred
INTO #part_adv_wrap_rol
FROM fn_pl_rol AS t
    INNER JOIN company_main AS cmp
        ON cmp.comp_scala = t.comp_scala
    INNER JOIN #plan1 AS p
        ON t.acc = p.acc
    INNER JOIN currency_list AS cur
        ON p.currency_id = cur.currency_code
    INNER JOIN organizations AS c
        ON t.g_org_code = c.org_code
           AND c.id_example = @master
WHERE MONTH(t.paydate) = @mnt1
      AND YEAR(t.paydate) = @year1
      AND
      (
          t.advance_wrap IS NOT NULL
          OR t.invoice_billing_moving IS NOT NULL
      );

SELECT GETDATE(),
       16;

---------------- Все вместе  

INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part1;

INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part1R;

INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part2;


INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part3;

INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part_storno;

INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part4;



INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part5;



INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       fact_amt AS fact_amt,
       base20 AS base20,
       vat20 AS vat20,
       base18 AS base18,
       vat18 AS vat18,
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
       comp_scala AS comp_scala,
       type AS type,
       amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part9;

INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       -fact_amt AS fact_amt,
       -base20 AS base20,
       -vat20 AS vat20,
       -base18 AS base18,
       -vat18 AS vat18,
       -base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       -inv_amt AS inv_amt,
       vat AS vat,
       -inv_base AS inv_base,
       -inv_vat AS inv_vat,
       -base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       comp_scala AS comp_scala,
       type AS type,
       -amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part_adv_wrap;
----------------------------  

INSERT INTO sl_book_sov_sl_buf
(
    factura,
    f_date,
    cust_name,
    inn,
    kpp,
    paydate,
    fact_amt,
    base20,
    vat20,
    base10,
    vat10,
    base0,
    export,
    pay_doc,
    inv,
    inv_date,
    cur,
    inv_amt,
    vat,
    inv_base,
    inv_vat,
    no_tax,
    prc,
    acc,
    trans,
    cust_code,
    comp_scala,
    type,
    amount_loc,
    calc_rd,
    trans_rd,
    invoice_no_cred,
    comp_scala_cred
)
SELECT factura AS factura,
       f_date AS f_date,
       cust_name AS cust_name,
       CONVERT(VARCHAR(20), inn) AS inn,
       kpp,
       paydate AS paydate,
       -fact_amt AS fact_amt,
       -base20 AS base20,
       -vat20 AS vat20,
       -base18 AS base18,
       -vat18 AS vat18,
       -base0 AS base0,
       export AS export,
       pay_doc AS pay_doc,
       inv AS inv,
       inv_date AS inv_date,
       cur AS cur,
       -inv_amt AS inv_amt,
       vat AS vat,
       -inv_base AS inv_base,
       -inv_vat AS inv_vat,
       -base0 AS no_tax,
       prc AS prc,
       acc AS acc,
       trans AS trans,
       cust_code AS cust_code,
       comp_scala AS comp_scala,
       type AS type,
       -amount_loc AS amount_loc,
       calc_rd,
       trans_rd,
       invoice_no_cred,
       comp_scala_cred
FROM #part_adv_wrap_rol;

-----------------------------------------
SELECT GETDATE(),
       9;


DELETE i ----------удаляем из КЗ платежи SL21 удаленные all_tran_del-------------  
FROM fn_pl_wo_rol AS i
    INNER JOIN #SL21REV AS r
        ON (i.inv = r.invoice COLLATE DATABASE_DEFAULT)
           AND (r.SL21004 = i.trans COLLATE DATABASE_DEFAULT)
           AND (i.comp_scala = r.comp_scala COLLATE DATABASE_DEFAULT);

DELETE t --------------удаляем из КЗ проводки сдкланные пользователем SPECIAL-------------------  
FROM fn_pl_wo_rol AS t
    INNER JOIN #SPECIAL_GL_TRANS_V AS s
        ON (
               (t.comp_scala = s.comp_scala COLLATE DATABASE_DEFAULT)
               AND (YEAR(t.f_date) = s.year_v)
               AND (t.trans = s.trans_number COLLATE DATABASE_DEFAULT)
           );


DELETE t -------------удаляем из КЗ переносы авансов в бил.системах----------------------  
FROM fn_pl_wo_rol AS t
WHERE invoice_billing_moving IS NOT NULL
      AND MONTH(t.paydate) = @mnt1
      AND YEAR(t.paydate) = @year1;

DELETE t -------------удаляем из КЗ переносы авансов в бил.системах----------------------  
FROM fn_pl_rol AS t
WHERE invoice_billing_moving IS NOT NULL
      AND MONTH(t.paydate) = @mnt1
      AND YEAR(t.paydate) = @year1;

DELETE t -------------удаляем из КЗ схлопы авансов с разными знаками----------------------  
FROM fn_pl_rol AS t
WHERE advance_wrap IS NOT NULL
      AND MONTH(t.paydate) = @mnt1
      AND YEAR(t.paydate) = @year1;

DELETE t -------------удаляем из КЗ схлопы авансов с разными знаками----------------------  
FROM fn_pl_wo_rol AS t
WHERE advance_wrap IS NOT NULL
      AND MONTH(t.paydate) = @mnt1
      AND YEAR(t.paydate) = @year1;
