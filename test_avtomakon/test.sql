-- @sqlmaster
DROP TABLE IF EXISTS #A;

CREATE TABLE #A
(
    [ID] [INT],
    [name] NVARCHAR(3)
);

INSERT INTO #A
(
    ID,
    name
)
VALUES
(1, 'AAA'),
(2, 'BBB'),
(2, 'CCC');

select * from #A
	
-- a вернет XXXX так как @name = 'XXXX'
declare @name varchar(10); select @name = 'XXXX'
select @name = name from #A where id = 0
print @name
go
-- b вернет AAA так как @name = name from A where id = 1
declare @name varchar(10); select @name = 'XXXX'
select @name = name from #A where id = 1
print @name
go
-- c вернет CCC так как @name = name from A where id = 2
declare @name varchar(10); select @name = 'XXXX'
select @name = name from #A where id = 2
print @name
go
-- d ничего, так как подзапрос (select name from A where id = 0) ничего не вернет
declare @name varchar(10); select @name = 'XXXX'
set @name = (select name from #A where id = 0)
print @name
go
-- e вернет AAA так как подзапрос (select name from A where id = 1) вернет AAA       
declare @name varchar(10); select @name = 'XXXX'
set @name = (select name from #A where id = 1)
print @name
go
-- f ошибка так как (select name from A where id = 2) вернет 2 строки
declare @name varchar(10); select @name = 'XXXX'
set @name = (select name from #A where id = 2)
print @name
GO
DROP TABLE #A

DECLARE @A TABLE
(
    [ID] [INT],
    [amount] NUMERIC(3)
);

INSERT INTO @A
(
    ID,
    amount
)
VALUES
(1, 500),
(2, 300),
(3, 100),
(4, -200),
(5, 100),
(6, 300),
(7, -200),
(8, -100);

SELECT *
FROM @A;

SELECT MIN(amount) min,
       MAX(amount) max,
       SUM(amount) sum,
       SUM(   CASE
                  WHEN amount > 0 THEN
                      amount
                  ELSE
                      0
              END
          ) [>0],
       SUM(   CASE
                  WHEN amount < 0 THEN
                      amount
                  ELSE
                      0
              END
          ) [<0],
       COUNT(DISTINCT amount)
FROM @A;

DROP TABLE IF EXISTS A;	

CREATE TABLE A( [ID] [int] IDENTITY(1,1) NOT NULL, [name] [varchar](50));


insert into a(name) values ('AAA');
insert into a(name) values ('BBB');

insert A(name) values('СССC')
print @@identity
insert A(name) values('DDDD')
print @@identity
go

/*
Table A
id	Name	 property	date
1	AAA	2	2020-10-11
2	BBB	0	2020-10-10
2	BBB	0	2020-10-10
3	CCC	3	2020-10-12
4	DDD	1	2020-10-12
4	DDD	1	2020-10-12
4	DDD	1	2020-10-12
5	EEE	2	2020-10-11
6	FFF	1	2020-10-13
*/
DECLARE @A TABLE
(
    [ID] [INT],
    [name] [VARCHAR](50),
    property INT,
    date DATE
);

INSERT INTO @A
(
    ID,
    name,
    property,
    date
)
VALUES
(1, 'AAA', 2, '2020-10-11'),
(2, 'BBB', 0, '2020-10-10'),
(2, 'BBB', 0, '2020-10-10'),
(3, 'CCC', 3, '2020-10-12'),
(4, 'DDD', 1, '2020-10-12'),
(4, 'DDD', 1, '2020-10-12'),
(4, 'DDD', 1, '2020-10-12'),
(5, 'EEE', 2, '2020-10-11'),
(6, 'FFF', 1, '2020-10-13');
--Написать запрос, который выберет такие записи. 
--Написать скрипт, который позволит избавиться от ненужных дублей (допускается модификация таблицы, использование других объектов, переименование и т.п.).
SELECT *
FROM @A;
--выводим что оставим
SELECT *
FROM
(
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ID, name, property, date ORDER BY date) N
    FROM @A
) A
WHERE A.N = 1
ORDER BY A.ID;

-- удаляем все дубликаты
DELETE A
FROM
(
    SELECT 
           ROW_NUMBER() OVER (PARTITION BY ID, name, property, date ORDER BY date) N
    FROM @A
) A
WHERE A.N > 1;

--результат без дублей
SELECT * FROM @A;



/*
Table cards_transfer
old_card	 new_card	dt
111	555	2020-01-09
222	223	2020-02-10
333	334	2020-03-11
444	222	2020-04-12
555	666	2020-05-12
666	777	2020-06-13
777	888	2020-07-14
888	000	2020-08-15
999	333	2020-09-16
223	111	2020-10-16
*/
DROP TABLE IF EXISTS cards_transfer;

CREATE TABLE cards_transfer
(
    old_card INT,
    new_card INT,
    dt DATE
);
INSERT INTO cards_transfer
(
    old_card,
    new_card,
    dt
)
VALUES
(111, 555, '2020-01-09'),
(222, 223, '2020-02-10'),
(333, 334, '2020-03-11'),
(444, 222, '2020-04-12'),
(555, 666, '2020-05-12'),
(666, 777, '2020-06-13'),
(777, 888, '2020-07-14'),
(888, 000, '2020-08-15'),
(999, 333, '2020-09-16'),
(223, 111, '2020-10-16');

SELECT *
FROM cards_transfer;


declare @n int;
set @n = 1;
declare @old_card int;
set @old_card='111';
WITH r AS (
select * from cards_transfer where old_card = @old_card
)
select *
from r; 

DROP PROCEDURE IF EXISTS change_card; 

CREATE PROC change_card
    @old_card INT,
    @new_card INT
AS
DECLARE @dt DATE;
SET @dt =
(
    SELECT a.dt
    FROM cards_transfer a
        JOIN cards_transfer b
            ON a.new_card = b.old_card
        JOIN cards_transfer c
            ON b.new_card = c.old_card
        JOIN cards_transfer d
            ON c.new_card = d.old_card
        JOIN cards_transfer e
            ON d.new_card = e.old_card
    WHERE a.old_card = @old_card
);
SELECT CASE
           WHEN @dt IS NULL THEN
               'можно менять карту'
           ELSE
       (
           SELECT DATEADD(MONTH, 12, @dt)
       )
       END;
--проверка и вывод даты возможной замены сделаны, далее логика добавления @new_card в задании это не указано, 

EXEC change_card 111, 222;

