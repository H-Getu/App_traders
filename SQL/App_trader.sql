SELECT DISTINCT 
name,
store,
size_mb,
price,
intial_investment,
ROUND(life_span) AS life_span,
ROUND(total_revenue) AS total_revenue,
ROUND(total_expense) AS total_expense,
content_rating,
primary_genre,
ROUND(review_count),
ROUND(ROI) AS expected_profit
FROM (
		--1)  apps that exist in only one of the stores
		
		--combine the two tables using union. use only common fields and ignore fields which will not be used for this ananlysis
		(WITH T1 AS (
					SELECT  name,
						'app_store' AS store,
							ROUND(size_bytes::"numeric"/1000000) AS size_MB, 
							price, 
							review_count::"numeric" , 
							rating, 
							content_rating, 
							primary_genre							
					FROM public.app_store_apps
					WHERE name NOT IN (SELECT a.name  
										FROM app_store_apps a INNER JOIN play_store_apps p ON LOWER(a.name) = LOWER(p.name) )-- filterout apps which exist in both stores
					
					UNION 
					
					SELECT name, 
						'play_store' AS store,
							CASE WHEN size ~ '[0-9]' THEN TRIM(size,'M,k')::"numeric" --cast all fields to similar data type 
								ELSE 0 END AS size , 
							TRIM(price,'$'):: "numeric" AS price, 
							review_count::"numeric", 
							rating, 
							content_rating, 
							genres
					FROM public.play_store_apps
					WHERE name NOT IN (SELECT a.name  
										FROM app_store_apps a INNER JOIN play_store_apps p ON LOWER(a.name) = LOWER(p.name))),-- apps which exist in both tables
		
		-- Add calculated fields
		T2 AS (
		
				select 	T1.name,						
						T1.size_MB, 
						CASE WHEN T1.price BETWEEN 0 AND 1 THEN 10000
							ELSE CEIL(T1.price)*10000 END AS intial_investment,
						CASE WHEN T1.rating= 0 THEN 1
							ELSE (T1.rating*2+1) END AS life_span
				FROM T1)
		--combine the two tables and add 
		SELECT T1.name,
				T1.store,
				T1.size_MB, 
				T1.price, 
				T2.intial_investment,
				T2.life_span,
				T1.review_count,
				T2.life_span*12*5000 AS Total_Revenue,
				T2.life_span*12*1000 AS Total_expense,
				T1.content_rating, 	
				T1.primary_genre,
				T2.life_span*12*5000 -T2.life_span*12*1000 -T2.intial_investment AS ROI
				
		FROM T1 LEFT JOIN T2 USING(name,size_MB ))
		
		UNION ALL
		
		--2)  apps that exist in both stores
		
(WITH T3 AS (SELECT  a.name,
			'both' AS store,
			ROUND(a.size_bytes::"numeric"/1000000) AS size_MB, 
			CASE WHEN a.price>=TRIM(p.price,'$')::"numeric" THEN a.price
			ELSE TRIM(p.price,'$')::"numeric" END AS price, 
			a.review_count::"numeric" + p.review_count AS review_count, 
			ROUND(((a.rating+p.rating)/2)*2,0)/2 AS rating,
			a.content_rating ||','|| p.content_rating AS content_rating,
			CASE WHEN a.primary_genre=p.genres THEN a.primary_genre
			ELSE a.primary_genre||','||p.genres END AS primary_genre
		FROM app_store_apps a JOIN play_store_apps p ON LOWER(a.name) = LOWER(p.name)),
		
	T4 AS (select 	T3.name,
			CASE WHEN T3.price BETWEEN 0 AND 1 THEN 10000
			ELSE CEIL(T3.price)*10000 END AS intial_investment,
			CASE WHEN T3.rating= 0 THEN 1
			ELSE (T3.rating*2+1) END AS life_span,
			MAX(T3.review_count) AS max_review_count
			FROM T3
			GROUP BY 1,2,3)
	
SELECT  DISTINCT T3.name,
		T3.store,
		T3.size_MB, 
		T3.price, 
		T4.max_review_count,
		T4.intial_investment,
		ROUND(T4.life_span) AS life_span,
		ROUND(T4.life_span*12*10000 ) AS Total_Revenue ,
		ROUND(T4.life_span*12*1000) AS Total_expense,
		T3.content_rating, 	
		T3.primary_genre,
		ROUND(T4.life_span*12*10000 -T4.life_span*12*1000 -T4.intial_investment) AS expected_profit
		FROM T3 LEFT JOIN T4 USING(name )
		WHERE T4.max_review_count = T3.review_count))

ORDER BY expected_profit DESC NULLs LAST;


		


