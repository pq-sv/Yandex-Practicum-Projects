/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор:Кононов С.В.
 * Дата: 12.01.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
	COUNT(payer) AS count_users,
	SUM(payer) AS count_paying_users,
	ROUND(AVG(payer) * 100 , 2) AS percentage_paying_users
FROM fantasy.users u 
ORDER BY percentage_paying_users DESC;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
	r.race,
	SUM(u.payer) AS count_paying_users,
	COUNT(u.payer) AS count_users,
	ROUND(AVG(u.payer) * 100 , 2) AS percentage_paying_users_per_race
FROM fantasy.users u 
	INNER JOIN fantasy.race r USING(race_id)
GROUP BY r.race 
ORDER BY percentage_paying_users_per_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
	COUNT(*) AS count_purchase,
	SUM(amount) AS sum_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	ROUND(AVG(amount) :: NUMERIC , 2) AS avg_amount,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount) :: NUMERIC , 2) AS median_amount,
	ROUND(STDDEV(amount) :: NUMERIC , 2) AS std_amount
FROM fantasy.events e;

-- 2.2: Аномальные нулевые покупки:
--СТЕ для расчета количетсва покупок с нулевой стоимостью
WITH buy_with_zero_price AS (SELECT 
							COUNT(*) AS count_zero_amount
							FROM fantasy.events e 
							WHERE amount = 0
							),
--СТЕ для расчета количетсва всех покупок							
			count_amount AS (SELECT COUNT(*) AS count_amount
							FROM fantasy.events e 
							)
SELECT 
	bwzp.count_zero_amount,
	bwzp.count_zero_amount :: NUMERIC / ca.count_amount * 100 AS percentage_zero_price_amount
FROM count_amount ca, buy_with_zero_price bwzp;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH paying_users AS (SELECT
						e.id ,
						COUNT(e.transaction_id) AS count_transaction,
						SUM(e.amount) AS sum_amount
					FROM fantasy.events e
						INNER JOIN fantasy.users u USING(id)
					WHERE u.payer = 1 AND e.amount != 0 --amount != 0 т.к. мы исключаем аномальные покупки с нулевой стоимостью
					GROUP BY e.id
					),
--Такая же СТЕ, только для неплатящих игроков (payer = 0)					
	non_paying_users AS (SELECT
						e.id ,
						COUNT(e.transaction_id) AS count_transaction,
						SUM(e.amount) AS sum_amount
					FROM fantasy.events e
						INNER JOIN fantasy.users u USING(id)
					WHERE u.payer = 0 AND e.amount != 0 --amount != 0 т.к. мы исключаем аномальные покупки с нулевой стоимостью
					GROUP BY e.id
					),
--запрос, который выводит для каждой группы игроков общее количество игроков, среднее количество покупок и среднюю суммарную стоимость покупок на одного игрока.
help AS (SELECT
			1 AS payer,
			COUNT(id) AS count_users,
			ROUND(AVG(count_transaction) , 2) AS avg_count_transaction,
			ROUND(AVG(sum_amount :: NUMERIC) , 2) AS avg_sum_amount
		FROM paying_users
		UNION ALL 
		SELECT 
			0 AS payer,
			COUNT(id) AS count_users,
			ROUND(AVG(count_transaction) , 2) AS avg_count_transaction,
			ROUND(AVG(sum_amount :: NUMERIC) , 2) AS avg_sum_amount
		FROM non_paying_users
		)
SELECT 
	CASE 
		WHEN payer = 1 
			THEN 'платящие'
		WHEN payer = 0 
			THEN 'не платящие'
	END	AS type_users,
	count_users,
	avg_count_transaction,
	avg_sum_amount
FROM help;

-- 2.4: Популярные эпические предметы:
--СТЕ для расчета общего количества продаж предметов
WITH all_sales AS (SELECT COUNT(*) AS count_all_sales
				   FROM fantasy.events e 
				   WHERE amount != 0 -- исключаем аномальные продажи
				  ),
--СТЕ для расчета продаж каждого предмета
item_sales AS (SELECT i.game_items , COUNT(e.transaction_id) AS absolute_count_item_sales
			   FROM fantasy.events e
			   INNER JOIN fantasy.items i USING(item_code)
			   WHERE e.amount != 0 -- исключаем аномальные продажи
			   GROUP BY i.game_items
			  ),
--CТЕ выводящее абсолютное и отсносительное значение продаж каждого предмета
count_item_sales AS (SELECT game_items, 
					 absolute_count_item_sales,
					 absolute_count_item_sales :: NUMERIC / count_all_sales * 100 AS relative_count_item_sales 
					 FROM item_sales , all_sales
					),
--СТЕ для расчета количество всех пользователей, которые хоть раз совершали покупку
total_users AS (SELECT COUNT(DISTINCT id) AS total_users
				FROM fantasy.events e
				WHERE amount != 0 -- исключаем аномальные продажи
			   ),
--СТЕ для расчета количества игроков, совершивших покупку, в разрезе каждого предмета
count_users_per_items AS (SELECT i.game_items , COUNT(DISTINCT e.id) AS count_users
						  FROM fantasy.events e
						  INNER JOIN fantasy.items i USING(item_code)
						  WHERE amount != 0 -- исключаем аномальные продажи
						  GROUP BY i.game_items
						 ),
--СТЕ для расчета доли игроков, которые хотя бы раз покупали предмет, в разрезе предметов
percentage_users_per_items AS (SELECT game_items, 
							   count_users :: NUMERIC / total_users * 100 AS percentage_users
							   FROM count_users_per_items , total_users
							  )
SELECT cis.game_items,
	absolute_count_item_sales,
	relative_count_item_sales,
	percentage_users
FROM count_item_sales cis
	INNER JOIN percentage_users_per_items pupi USING(game_items) 
ORDER BY percentage_users DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
--СТЕ для расчета количества игроков в разрезе рас
WITH total_users_per_race AS (SELECT race , COUNT(DISTINCT id)  AS total_users
							  FROM fantasy.users u 
								  INNER JOIN fantasy.race r USING(race_id)
							  GROUP BY race 	
							 ),
--СТЕ для расчета количествв игроков, совершивших внутриигровые покупки, в разрезе рас
paying_users AS (SELECT race , COUNT(DISTINCT id) AS paying_users
				 FROM fantasy.users u 
				 	INNER JOIN fantasy.race r USING(race_id)
				 		INNER JOIN fantasy.events e USING(id)
				 WHERE amount != 0 -- исключаем аномальные продажи
				 GROUP BY race
			    ),
--СТЕ для расчета платящих игроков в разрезе рас
payer_users AS (SELECT race, COUNT(DISTINCT id) AS payer_users
				FROM fantasy.users u 
				 	INNER JOIN fantasy.race r USING(race_id)
				 		INNER JOIN fantasy.events e USING(id)
				WHERE payer = 1 AND amount != 0 -- добавил условие, исплючающее аномальные покупки
				GROUP BY race	
			    ),
--СТЕ для расчета количества покупок и суммы стоимости покупок в разрезе рас
purchases AS (SELECT race, COUNT(transaction_id) AS count_purchases , SUM(amount) AS sum_cost
			  FROM fantasy.users u 
				 	INNER JOIN fantasy.race r USING(race_id)
				 		INNER JOIN fantasy.events e USING(id) 
			  GROUP BY race
			 )
SELECT 
	race,
	tupr.total_users,
	pu.paying_users,
	ROUND(pu.paying_users :: NUMERIC / tupr.total_users * 100 , 2) AS percentage_paying_users,
	ROUND(payu.payer_users :: NUMERIC / pu.paying_users * 100 , 2) AS percentage_payer_users,
	ROUND(pur.count_purchases :: NUMERIC / pu.paying_users , 2) AS avg_count_purchases_per_users,-- заменил игроков, на покупателей
	ROUND((pur.sum_cost :: NUMERIC / pur.count_purchases) , 2) AS avg_cost_one_per_users,--делю стоимость всех покупок на количество покупок(чтобы найти стоимость 1 покупки) убрал деление на  tupr.total_users
	ROUND(pur.sum_cost :: NUMERIC / pu.paying_users , 2) AS avg_sum_cost_per_users-- заменил игроков, на покупателей
FROM total_users_per_race tupr
	INNER JOIN paying_users pu USING(race)
	INNER JOIN payer_users payu USING(race)
	INNER JOIN purchases pur USING(race);
						
-- Задача 2: Частота покупок
--СТЕ для расчета покупок у каждого игрока и количества дней между покупками
WITH help1 AS (SELECT * , 
			   COALESCE(date :: date - LAG(date) OVER(PARTITION BY id ORDER BY date) :: date , '0')  AS interval_between_purchase -- вычитаю из текущей даьты смещенную предыдущую,если предыдущей даты нет, то = 0
			   FROM fantasy.events 
			   WHERE amount != 0 -- исключаем покупки с нулевой стоимостью
			  ),
--СТЕ для расчета количество покупок на 1 игрока и среднего интервала дней между покупок
help2 AS (SELECT id,
		  COUNT(transaction_id) AS count_purchase,
		  AVG(interval_between_purchase) AS avg_interval
		  FROM help1
		  GROUP BY id
		  HAVING COUNT(transaction_id) >= 25 -- отсекаем игроков которые совершили меньше 25 покупок
		 ),
--СТЕ для разбиения игроков на 3 по avg_interval		 
help3 AS (SELECT * , 
		  NTILE(3) OVER(ORDER BY avg_interval) AS group_purchase_frequency
		  FROM help2
		 ),
--СТЕ для присваивания каждой группе названия
help4 AS (SELECT help3.id, count_purchase, avg_interval, u.payer,
		  CASE 
		  	WHEN group_purchase_frequency = 1
		  		THEN 'высокая частота'
		  	WHEN group_purchase_frequency = 2
		  		THEN 'умеренная частота'
		  	WHEN group_purchase_frequency = 3
		  		THEN 'низкая частота'
		  END AS groups_purchase_frequency	  
		  FROM help3
		  	INNER JOIN fantasy.users u USING(id)
		 )
SELECT groups_purchase_frequency,
	COUNT(id) AS paying_users,
	SUM(payer) AS payer_users,
	ROUND(SUM(payer) :: NUMERIC / COUNT(id) * 100 , 2) AS percentage_payer_users,
	ROUND(SUM(count_purchase) :: NUMERIC / COUNT(id) , 2) AS avg_purchas_per_users,
	ROUND(SUM(avg_interval) :: NUMERIC / COUNT(id) , 2) AS avg_interval_per_users
FROM help4
GROUP BY groups_purchase_frequency	
ORDER BY avg_interval_per_users;
		 