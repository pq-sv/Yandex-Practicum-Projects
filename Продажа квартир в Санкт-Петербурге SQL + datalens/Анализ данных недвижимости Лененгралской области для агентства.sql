/* Анализ данных недвижимости Лененгралской области для агентства
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Кононов С.В.
*/

-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--разделение на категории
help1 AS (SELECT * ,
			CASE 
				WHEN days_exposition <= 30 AND days_exposition IS NOT NULL 
					THEN 'высокая'
				WHEN days_exposition <= 180 AND days_exposition IS NOT NULL 
					THEN 'средняя'
				WHEN days_exposition > 180 AND days_exposition IS NOT NULL 
					THEN 'медленная'
				ELSE 'не продано/нет информации'
			END AS активность
			FROM real_estate.advertisement
			WHERE id IN (SELECT * FROM filtered_id)
		  ),
--разбиения на Санкт-петербург и остальные города
help2 AS (SELECT * ,
		  CASE 
		  	WHEN city = 'Санкт-Петербург'
		  		THEN 'saint_peterburg'
		  	ELSE 'not_saint_peterburg'
		  END AS город		  
		  FROM real_estate.flats f
		  INNER JOIN real_estate.city c USING(city_id)
		 )
SELECT активность, город,COUNT(DISTINCT id) AS count_exposition,  ROUND(AVG(total_area) :: NUMERIC , 2) AS avg_area ,  ROUND(AVG(last_price / total_area :: NUMERIC):: NUMERIC , 2) AS avg_price_meter,
	 ROUND(percentile_cont(0.5) WITHIN GROUP(ORDER BY floor) :: NUMERIC,2) AS median_floor ,ROUND(percentile_cont(0.5) WITHIN GROUP(ORDER BY rooms) :: NUMERIC,2) AS median_rooms,
	 ROUND(percentile_cont(0.5) WITHIN GROUP(ORDER BY balcony) :: NUMERIC,2) AS median_balcony
FROM help1 AS h1
INNER JOIN help2 AS h2 USING(id)
INNER JOIN filtered_id AS fi USING(id)
GROUP BY активность , город
ORDER BY город	

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--месяцы объявлений + ранг по количеству объявлений
help1 AS (SELECT
EXTRACT(MONTH FROM a.first_day_exposition) AS month_exposition, 
COUNT(id) AS count_exposition,
ROUND(AVG(total_area) :: NUMERIC , 2) AS avg_area,
ROUND(AVG(last_price / total_area :: NUMERIC) :: NUMERIC , 2) AS avg_price,
DENSE_RANK() OVER(ORDER BY COUNT(id) DESC) AS rank_exposition
FROM real_estate.advertisement a
INNER JOIN filtered_id USING(id)
INNER JOIN real_estate.flats f USING(id)
GROUP BY month_exposition
),
--месяцы продажи + ранг по количетсву продаж
help2 AS (SELECT 
EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition * INTERVAL '1 day') AS month_sell,
COUNT(id) AS count_sell,
ROUND(AVG(total_area) :: NUMERIC , 2) AS avg_area,
ROUND(AVG(last_price / total_area :: NUMERIC) :: NUMERIC , 2) AS avg_price,
DENSE_RANK() OVER(ORDER BY COUNT(id) DESC) AS rank_sell
FROM real_estate.advertisement a
INNER JOIN filtered_id USING(id)
INNER JOIN real_estate.flats f USING(id)
WHERE EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition * INTERVAL '1 day') IS NOT NULL 
GROUP BY month_sell
)
SELECT * 
FROM help1 
INNER JOIN help2 ON month_exposition = month_sell

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--запрос для расчета объявлений, средней длительности продажи , средней площади , средней цены за кв.метр
help1 AS (SELECT city, ROUND(AVG(days_exposition) :: NUMERIC , 2) AS avg_days_exposition , ROUND(AVG(total_area) :: NUMERIC , 2) AS avg_area ,  ROUND(AVG(last_price / total_area :: NUMERIC):: NUMERIC , 2) AS avg_price_meter , COUNT(id) AS count_exposition
FROM real_estate.city c 
INNER JOIN real_estate.flats f USING(city_id)
INNER JOIN real_estate.advertisement a  USING(id )
WHERE city != 'Санкт-Петербург' AND id IN  (SELECT id FROM filtered_id)
GROUP BY city
ORDER BY count_exposition DESC 
LIMIT 15
),
-- запрос для расчета количества снятых объявлений
help2 AS (SELECT city , COUNT(id) AS count_removed_exposition
FROM real_estate.city c 
INNER JOIN real_estate.flats f USING(city_id)
INNER JOIN real_estate.advertisement a USING(id)
WHERE city != 'Санкт-Петербург' AND id IN  (SELECT id FROM filtered_id) AND days_exposition IS NOT NULL
GROUP BY city
ORDER BY count_removed_exposition DESC 
LIMIT 15
)
SELECT * , ROUND(count_removed_exposition / count_exposition :: NUMERIC * 100 , 2) AS percentage_removed_exposition 
FROM help1 
INNER JOIN help2 USING(city)
ORDER BY avg_days_exposition DESC
