-- @sqlmaster
--По таблицам Income и Outcome для каждого пункта приема найти остатки денежных средств на конец каждого дня, 
--в который выполнялись операции по приходу и/или расходу на данном пункте


WITH t
AS (SELECT point,
           date,
           inc,
           0 out
    FROM Income
    UNION ALL
    SELECT point,
           date,
           0 inc,
           out
    FROM Outcome)
SELECT t.point,
       CONVERT(VARCHAR, CAST(t.date AS DATE), 103) dat,
       (
           SELECT SUM(i.inc)FROM t i WHERE i.date <= t.date AND i.point = t.point
       ) -
       (
           SELECT SUM(i.out)FROM t i WHERE i.date <= t.date AND i.point = t.point
       ) AS ost
FROM t
GROUP BY t.point,
         t.date;


--Create an SQL query that shows the TOP 3 authors who sold the most books in total!
SELECT TOP 3
       COUNT(book_name),
       author_name
FROM Book_Authors
GROUP BY author_name
ORDER BY COUNT(book_name) DESC;


--Print every department where the average salary per employee is lower than $500!
SELECT departments.department_name,
       AVG(employees.salary) AS avgsalary
FROM departments
    INNER JOIN salaries
        ON departments.employee_id = employees.employee_id
GROUP BY departments.department_name
HAVING AVG(salaries.salary) < 500;

--Таблица T содержит дубли в поле n:
SELECT n
FROM T;

--Написать DML запрос, который очистит таблицу от старых дублей
--первый вариант
DELETE D
FROM
(SELECT n, ROW_NUMBER() OVER (ORDER BY dt) AS RowNum FROM t) D
    JOIN
    (SELECT n, ROW_NUMBER() OVER (ORDER BY dt) AS RowNum FROM t) E
        ON D.n = E.n
           AND D.RowNum < E.RowNum
           
--второй прогрессивный вариант удаления устаревших дублей
DECLARE @t TABLE
(
    n INT,
    dt DATE
);
INSERT INTO @t
VALUES
(1, '2019-07-08'),
(1, '2019-07-09'),
(2, '2019-07-08'),
(2, '2019-07-10'),
(3, '2019-07-10'),
(3, '2019-07-10');

SELECT *
FROM @t;

WITH CTE
AS (SELECT N = ROW_NUMBER() OVER (PARTITION BY n ORDER BY dt DESC),
           dt
    FROM @t)
DELETE CTE
WHERE N > 1;

SELECT *
FROM @t;



/*1)	Тест на позицию Senior DB Developer ( SQL, PL/SQL)
В High-load OLTP системе из-за несовершенства учетной системы и каналов связи в секционированной  (PARTITION BY HASH (n)) таблице T из п.1  накопилось за 5 лет 10 млрд. записей c ~30% дублей
Размер секции - 100 млн. записей,  размер поля msg = 1Кб
N принимает значения в диапазоне 0..9 999 999 999
Размер табличного пространства для хранения данных в T ограничен 10 Тб.
Написать максимально эффективную хранимую процедуру R, которая очистит таблицу от дублей до вида из п.1, с учетом следующих ограничений ресурсов
1)	размер PGA на сервере = 1 Гб и данный ресурс доступен для R монопольно в полном объеме 
2)	на диске для файлов БД свободно 100 Гб. 
3)	Объем PGA, выделяемый для WITH и/или вложенных подзапросов = сумме размеров выборок каждого подзапроса, а не размеру результирующей выборки ( внешнего запроса ), т.е. WITH a as (SELECT ‘abc’ as x FROM DUAL) SELECT x FROM a требует 6 байт ОЗУ.
4)	Размером памяти на сортировку пренебречь
СУБД – Oracle
*/
/*
При больших объемах дубликатов в данных можно рассмотреть возможность сохранения уникальных значений в промежуточную таблицу, 
очистку рабочей таблицы, и возврат оставленных уникальных записей.
В данном случае можно частями по 100к записей в цикле идти по таблице и удалять только их дубли за одну итерацию
*/