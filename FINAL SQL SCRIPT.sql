## ATLIQ HARDWARE (( SQL FILE)) 


 
##1 BUILDING GROSS SALES MONTHLY REPORT 
USE gdb0041

##1.1 JOINING THE TABLE :
-##MONTH 
##PRODUCT NAME
##VARIANT 
##SOLD QUANTITY , GROSS PRICE PER ITEM , GROSS PRICE TOTAL
SET SESSION SQL_MODE = ''
-- a. first grab customer codes for Croma india
	SELECT * FROM dim_customer WHERE customer like "%croma%" AND market="india";

-- b. Get all the sales transaction data from fact_sales_monthly table for that customer(croma: 90002002) in the fiscal_year 2021
	SELECT * FROM fact_sales_monthly 
	WHERE 
            customer_code=90002002 AND
            YEAR(DATE_ADD(date, INTERVAL 4 MONTH))=2021 
	ORDER BY date asc
	LIMIT 100000;

-- c. create a function 'get_fiscal_year' to get fiscal year by passing the date
	CREATE FUNCTION `get_fiscal_year`(calendar_date DATE) 
	RETURNS int
    	DETERMINISTIC
	BEGIN 
        	DECLARE fiscal_year INT;
        	SET fiscal_year = YEAR(DATE_ADD(calendar_date, INTERVAL 4 MONTH));
	RETURN fiscal_year;
	END;

-- d. Replacing the function created in the step:b
	SELECT * FROM fact_sales_monthly 
	WHERE 
            customer_code=90002002 AND
            get_fiscal_year(date)=2021 
	ORDER BY date asc
	LIMIT 100000;





##1.3 Joining the table- dim_product, fact-sales_monthly , product_name
##1.4 GROSS SALES REPORT
	SELECT 
    	    s.date, 
            s.product_code, 
            p.product, 
            p.variant, 
            s.sold_quantity, 
            g.gross_price,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
            ON g.fiscal_year=get_fiscal_year(s.date)
    	AND g.product_code=s.product_code
	WHERE 
    	    customer_code=90002002 AND 
            get_fiscal_year(s.date)=2021;
    
    

set session sql_mode = '';
##1.5 TOTAL SALES AMOUNT(generate only for croma=90002002)
##the total should be generated  such that , gross_price_total for croma should be date wise 
##and sum of all the values on a particular date
select 
s.date , sum(round(g.gross_price*s.sold_quantity,2)) as gross_price_total
from fact_sales_monthly s
join fact_gross_price g 
on g.product_code = s.product_code and 
g.fiscal_year = get_fiscal_year(s.date)
where customer_code = 90002002
group by s.date
order by s.date;
    

#TASK3: YEARLY SALES REPORT FOR CROMA (FISCAL YEAR AND TOTAL GROSS SALES)
select 
g.fiscal_year , sum(round(g.gross_price*s.sold_quantity,2)) as Total_Gross_sales
 from 
fact_sales_monthly s
join fact_gross_price g
on g.product_code = s.product_code and 
g.fiscal_year = get_fiscal_year(s.date)
where customer_code = 90002002
group by fiscal_year
order by fiscal_year; 

##TASK 4: TO MAKE AN STORED PROCDEDURE S
CREATE DEFINER=`root`@`localhost` PROCEDURE `Get_monthly_sales_report_for_customer`(
		c_code int 
)
BEGIN
select 
s.date , sum(round(g.gross_price*s.sold_quantity,2)) as gross_price_total
from fact_sales_monthly s
join fact_gross_price g 
on g.product_code = s.product_code and 
g.fiscal_year = get_fiscal_year(s.date)
where customer_code = c_code
group by s.date
order by s.date;


##TASK 5## creating a stored procedure so that 
#2 or more customer can detais could be enterd and result could be pobtained
#find_in_set(90002002 , in_customer_code) >0

CREATE DEFINER=`root`@`localhost` PROCEDURE `monthly_sales_report_for_multiple_customers`(
		in_customer_codes text
)
BEGIN
	select 
s.date , sum(round(g.gross_price*s.sold_quantity,2)) as monthly_sales
from fact_sales_monthly s
join fact_gross_price g 
on g.product_code = s.product_code and 
g.fiscal_year = get_fiscal_year(s.date)
where find_in_set(s.customer_code , in_customer_codes ) > 0
group by s.date;

##TASK 6 : MARKET BUDGET (INPUT -> MARKET , FISCAL_YEAR )(OUTPUT -> MARKET BADGE )
## total qty > 5 million - Gold Badge , else silver
##CREATE A STORED PROCEDURE - FRO MARKET BADGE 

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_market_badge`(
        	IN in_market VARCHAR(45),
        	IN in_fiscal_year YEAR,
        	OUT out_level VARCHAR(45)
	)
BEGIN
             DECLARE qty INT DEFAULT 0;
    
    	     # Default market is India
    	     IF in_market = "" THEN
                  SET in_market="India";
             END IF;
    
    	     # Retrieve total sold quantity for a given market in a given year
             SELECT 
                  SUM(s.sold_quantity) INTO qty
             FROM fact_sales_monthly s
             JOIN dim_customer c
             ON s.customer_code=c.customer_code
             WHERE 
                  get_fiscal_year(s.date)=in_fiscal_year AND
                  c.market=in_market;
        
             # Determine Gold vs Silver status
             IF qty > 5000000 THEN
                  SET out_level = 'Gold';
             ELSE
                  SET out_level = 'Silver';
             END IF;
	END

 
##TASK2 : FINDING OUT NET SALES(Revenue) 
# GROSSPRICE - PRE-INVOICE DEDUCTIONS = NET INVOICE SALES 
#NET INVOICE SALES - POST-INVOICE-DEDUCTIONS = NET SALES( 4 tables join)

EXPLAIN ANALYZE
    SELECT 
    	   s.date, 
           s.product_code, 
           p.product, 
	   p.variant, 
           s.sold_quantity, 
           g.gross_price as gross_price_per_item,
           ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
           pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
    	    ON g.fiscal_year=get_fiscal_year(s.date)
    	    AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
            ON pre.customer_code = s.customer_code AND
            pre.fiscal_year=get_fiscal_year(s.date)
	WHERE 
    	    get_fiscal_year(s.date)=2021     
	LIMIT 10000000;


##performace optimizations : It took 1.125 seconds to run the query with only a specific query selected .
# Now if want to find about all the customers then it would be difficult . therefore we need to optimize the Query 

##why performance is low ? --> The reason is the filter function ( get fiscal year) , bcz it goes through whole of the 
#date column , so weed to create a solution like lookup  table
#in mysql (yyyy-mm-dd)

 explain analyze
       SELECT 
    	   s.date, 
           s.product_code, 
           p.product, 
	   p.variant, 
           s.sold_quantity, 
           g.gross_price as gross_price_per_item,
           ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
           pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN dim_date dt
			on dt.calendar_date = s.date
	JOIN fact_gross_price g
    	    ON g.fiscal_year=dt.fiscal_year
    	    AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
            ON pre.customer_code = s.customer_code AND
            pre.fiscal_year=dt.fiscal_year
	WHERE   
    	    get_fiscal_year(s.date)=2021     
	LIMIT 10000000;
    
    
    # this solution will take 1/3rd time only (created a Dim-date table )
    #storage is cheap --> for companies it is not a big deal
    
    
    ## METHOD2 : IMPROVING PERFORMANCE : ADDING A FISCAL YEAR TABLE IN SALES MONTHLY
    
SELECT 
    	   s.date, 
           s.product_code, 
           p.product, 
	   p.variant, 
           s.sold_quantity, 
           g.gross_price as gross_price_per_item,
           ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total,
           pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN dim_date dt
			on dt.calendar_date = s.date
	JOIN fact_gross_price g
    	    ON g.fiscal_year=s.fiscal_year
    	    AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions as pre
            ON pre.customer_code = s.customer_code AND
            pre.fiscal_year=s.fiscal_year
	WHERE   
    	    get_fiscal_year(s.date)=2021     
	LIMIT 10000000;
    


# 2.3 USE OF CTE AS we cannot used a derived query in the query( on gross_pice_total)
## FACTPOST-INVOICE DEDUCTIONS
## ((GROSS PRICE TOTAL - GROSS PRICE TOTAL * PRE INVOICE DEDUCTIONS ))
 
 
 
 
    
    ## 2.4 store cte1 in the database so that in future we could use it , but we dont want physical table s, so that we would store in view 
    ## i view we will add dim_customer table so tat we could also see the different markets in the join tables
    
    CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = `root`@`localhost` 
    SQL SECURITY DEFINER
VIEW `gdb0041`.`sales_preinv_discount` AS
    SELECT 
        `s`.`date` AS `date`,
        `c`.`market` AS `market`,
        `s`.`fiscal_year` AS `fiscal_year`,
        `s`.`product_code` AS `product_code`,
        `p`.`product` AS `product`,
        `p`.`variant` AS `variant`,
        `s`.`sold_quantity` AS `sold_quantity`,
        `g`.`gross_price` AS `gross_price_per_item`,
        ROUND((`s`.`sold_quantity` * `g`.`gross_price`),
                2) AS `gross_price_total`,
        `pre`.`pre_invoice_discount_pct` AS `pre_invoice_discount_pct`
    FROM
        (((((`gdb0041`.`fact_sales_monthly` `s`
        JOIN `gdb0041`.`dim_customer` `c` ON ((`s`.`customer_code` = `c`.`customer_code`)))
        JOIN `gdb0041`.`dim_product` `p` ON ((`s`.`product_code` = `p`.`product_code`)))
        JOIN `gdb0041`.`dim_date` `dt` ON ((`dt`.`calendar_date` = `s`.`date`)))
        JOIN `gdb0041`.`fact_gross_price` `g` ON (((`g`.`fiscal_year` = `s`.`fiscal_year`)
            AND (`g`.`product_code` = `s`.`product_code`))))
        JOIN `gdb0041`.`fact_pre_invoice_deductions` `pre` ON (((`pre`.`customer_code` = `s`.`customer_code`)
            AND (`pre`.`fiscal_year` = `s`.`fiscal_year`))));
    
    
    
##2.5 
#benifits of view -->> 1.the central place for your queries logic = Fewer Errors . 2.Simple Queries and 3. User Access Control
## view willl create for all the sessions . so it will be visible a Year after also
## also the query becomes very fast 
select * , (1-pre_invoice_discount_pct)*gross_price_total as Net_Invoice_Sales from 
sales_preinv_discount;
    
    
    
set session sql_mode = '';
##2.6 : JOIN fact_post_invoice_deductiions with our view table for Net Sales Finding 
	select * , (1-pre_invoice_discount_pct)*gross_price_total as Net_Invoice_Sales, 
	sum(po.discounts_pct + po.other_deductions_pct) as Post_Invoice_discounts 
	from 
sales_preinv_discount s
join fact_post_invoice_deductions po
on s.product_code = po.product_code and 
s.date = po.date and s.customer_code = po.customer_code ;

    
##2.7 CREATE A NET SALES REPORT 
	SELECT 
            *, 
    	    net_invoice_sales*(1-post_invoice_discount_pct) as net_sales
	FROM gdb0041.sales_postinvoice_discount;

-- Finally creating the view `net_sales` which inbuiltly use/include all the previous created view and gives the final result
	CREATE VIEW `net_sales` AS
	SELECT 
            *, 
    	    net_invoice_sales*(1-post_invoice_discount_pct) as net_sales
	FROM gdb0041.sales_postinv_discount;
    

## 2.8 Top Markets and Customers 
-- Get top 5 market by net sales in fiscal year 2021: 
	SELECT 
    	    market, 
            round(sum(net_sales)/1000000,2) as net_sales_mln
	FROM gdb0041.net_sales
	where fiscal_year=2021
	group by market
	order by net_sales_mln desc
	limit 5;
    ## CRAETE A STORED PRODECURE FOR FINDING THE TOP SALES 

    
##2.9 NOW WE WANT THE REPORT OF TOP CUSTOMER - STORED PROCEDURE 
# we will use net sales stored procdure and create a stored prodecure , bu joining dim_customer table in with the net sales 
# as we want report by customer name and we dont have custoemr name in our net sales colummn 

 
SELECT 
    	   c. market, 
            round(sum(net_sales)/1000000,2) as net_sales_mln
	FROM gdb0041.net_sales n 
    join dim_customer c
    on c.customer_code = n.customer_code 
	where fiscal_year=2021
	group by market
	order by net_sales_mln desc
	limit 5;
    
## 2.10 CREATE A STORED PROCEDURE (  MARKET , F.YEAR , N  ) --> REPORT OF NET SALES BY TOP CUSTOMERS 
    
 ##2.11 CREATE A STORED PROCEDURE FOR TOP PRODUCTS BY NET SALES FOR A GIVEN YEAR 
	CREATE PROCEDURE get_top_n_products_by_net_sales(
              in_fiscal_year int,
              in_top_n int
	)
	BEGIN
            select
                 product,
                 round(sum(net_sales)/1000000,2) as net_sales_mln
            from gdb041.net_sales
            where fiscal_year=in_fiscal_year
            group by product
            order by net_sales_mln desc
            limit in_top_n;
	END


##TASK : 3 CREATING CHARTS AND REPORT 
## 3. 0 create a basicc chart with the 
#help of the ms exceel and mysql for the above same distribution ( of NET-SALES)
#( NET SALES GLOBAL MARKET %) ( USING WINDOWS FUNCCTIONS )

with cte1 as (

select     customer, 
            round(sum(net_sales)/1000000,2) as net_sales_mln
	FROM gdb0041.net_sales n 
    join dim_customer c
    on c.customer_code = n.customer_code
	where fiscal_year= 2021
	group by customer
	order by net_sales_mln desc
  
) 
select * , 
net_sales_mln*100/sum(net_sales_mln) over() as pct 
from cte1 order by net_sales_mln desc


## TASK 4 : GET TOP N PRODUCTS IN EACH DIVISION BY THEIR QUANTITY SOLD
# USE OF ROW_NUMBERS , RANK AND DENSE RANK 

  with cte1 as 
(select 
			p.division , p.product , sum(sold_quantity) as Total_Qty_Sold 
			from fact_sales_monthly s
			join dim_product p 
			on p.product_code = s.product_code 
			where fiscal_year = 2021 
			group by p.product ),
	 cte2 as (
select * , 
dense_rank() over(partition by division order by Total_Qty_Sold desc ) as drnk 
from cte1 ) 
select * from cte2 	where drnk<=3;

## TASK 4.1 : TOP 2 PRODUCTS IN EVERY REGION BY THEIR GROSS SALES AMOUNT IN FY 2021
with cte1 as (
		select
			c.market,
			c.region,
			round(sum(gross_price_total)/1000000,2) as gross_sales_mln
			from gross_sales s
			join dim_customer c
			on c.customer_code=s.customer_code
			where fiscal_year=2021
			group by market
			order by gross_sales_mln desc
		),
		cte2 as (
			select *,
			dense_rank() over(partition by region order by gross_sales_mln desc) as drnk
			from cte1
		)
	select * from cte2 where drnk<=2

















 
 
 
    
    
    