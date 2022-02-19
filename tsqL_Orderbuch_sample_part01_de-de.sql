use tempDB
GO

Declare @showStep  varchar(10) = 'step03'  -- [ step01 | step02 | step03 ] 

DROP TABLE IF EXISTS tempdb.dbo.OrderListe;
DROP TABLE IF EXISTS tempdb.dbo.OrderListe_step01;
DROP TABLE IF EXISTS tempdb.dbo.OrderListe_step02;
DROP TABLE IF EXISTS tempdb.dbo.OrderListe_step03;
DROP TABLE IF EXISTS tempdb.dbo.OrderListe_step04;

CREATE TABLE tempdb.dbo.OrderListe (                      
               Order_ID        int                        
             , Order_Time      time not NULL              
             , Kurs            int  NULL  -- Market-Orders
             , bid_OrderSize   int  NULL                  
             , bid_OrderType   varchar(20) NULL           
             , ask_OrderSize   int  NULL                  
             , ask_OrderType   varchar(20) NULL           
             , Order_fill      int                        
             )                                            
----

INSERT INTO tempdb.dbo.OrderListe                                                                                  
       ( Order_ID , Order_Time , bid_OrderType , bid_OrderSize , Kurs , ask_OrderSize , ask_OrderType, Order_fill )
VALUES (        0 ,    '00:00' , 'SchlussKurs' ,          NULL ,  100 ,          NULL ,          NULL, NULL )      
                                                                                                                   
     , (        1 ,    '08:10' ,       'Limit' ,           200 ,   99 ,          NULL ,          NULL, NULL )      
     , (        2 ,    '08:20' ,          NULL ,          NULL , NULL ,           500 ,      'Market', NULL )      
     , (        3 ,    '08:21' ,       'Limit' ,          1000 ,   88 ,          NULL ,          NULL, NULL )      
                                                                                                                   
     , (        4 ,    '08:25' ,          NULL ,          NULL ,   89 ,           800 ,       'Limit', NULL )      
     , (        5 ,    '08:30' ,      'Market' ,           700 , NULL ,          NULL ,          NULL, NULL )      
     , (        6 ,    '08:30' ,       'Limit' ,            20 ,  105 ,          NULL ,          NULL, NULL )      
                                                                                                                   
     , (        7 ,    '08:35' ,          NULL ,          NULL ,   95 ,          1500 ,       'Limit', NULL )      
     , (        8 ,    '08:38' ,          NULL ,          NULL ,   92 ,           700 ,       'Limit', NULL )      
     , (        9 ,    '08:40' ,       'Limit' ,           300 ,   90 ,          NULL ,          NULL, NULL )      
                                                                                                                   
     , (       10 ,    '08:40' ,      'Market' ,          1000 , NULL ,          NULL ,          NULL, NULL )      
     , (       11 ,    '08:45' ,          NULL ,          NULL ,  125 ,           500 ,       'Limit', NULL )      
     , (       12 ,    '08:55' ,          NULL ,          NULL , NULL ,           200 ,      'Market', NULL )      
                                                                                                                   
     , (       13 ,    '08:58' ,       'Limit' ,           700 ,   95 ,          NULL ,          NULL, NULL )      
     , (       14 ,    '08:59' ,       'Limit' ,           300 ,   95 ,          NULL ,          NULL, NULL )      
----
Declare @letzterKurs  int
SET @letzterKurs = ( select Kurs from tempdb.dbo.OrderListe where bid_OrderType = 'SchlussKurs' )

;
with                      
KursListe as              
(                         
select number  as 'Kurs'  
from   master..spt_values 
where  type = 'P'         
  and  number >=  88      
  and  number <= 125      
) ,
OrderListe as
(
select Order_ID, Order_Time
     , bid_OrderType, bid_OrderSize
     , CASE
          WHEN bid_OrderType = 'Market'  THEN @letzterKurs
          WHEN ask_OrderType = 'Market'  THEN @letzterKurs
          ELSE                                 Kurs 
       END       as 'Kurs'         
     , ask_OrderSize, ask_OrderType
     , Order_fill
from   tempdb.dbo.OrderListe
where  Order_fill is NULL  -- ?!  ggf. Teilausführung ...
)
SELECT KL.Kurs as 'sort'
     , OL.Order_ID
     , Format(OL.Order_Time, 'hh\:mm') as 'Order_Time'
     , OL.bid_OrderType, OL.bid_OrderSize
     , OL.Kurs
     , OL.ask_OrderSize, OL.ask_OrderType
     , OL.Order_fill
INTO   tempdb.dbo.OrderListe_step01
FROM   KursListe KL
left   join   
       OrderListe OL
ON     KL.Kurs = OL.Kurs
WHERE  1 = 1
ORDER  by KL.Kurs desc, OL.Order_ID 

-- return step01
IF @showStep = 'step01'
BEGIN
select *
from   tempdb.dbo.OrderListe_step01
where  kurs is NOT NULL
order  by sort desc
END -- end step01

--select *
--from   tempdb.dbo.OrderListe_step01
--where  kurs is NOT NULL
--  and (
--         bid_OrderType = 'Market'
--      or ask_OrderType = 'Market'
--     )
---- and
--select *
--from   tempdb.dbo.OrderListe_step01
--where  kurs is NOT NULL
--  and (
--         bid_OrderType != 'Market'
--      or ask_OrderType != 'Market'
--    )
--order  by sort desc

----
Declare @bid_OrderSize_Market  int
      , @ask_OrderSize_Market  int


Set @bid_OrderSize_Market = (
select SUM( bid_OrderSize )
from   tempdb.dbo.OrderListe_step01
where  kurs is NOT NULL
  and (
         bid_OrderType = 'Market'
      or ask_OrderType = 'Market'
      )
)
----
Set @ask_OrderSize_Market = (
select SUM( ask_OrderSize )
from   tempdb.dbo.OrderListe_step01
where  kurs is NOT NULL
  and (
         bid_OrderType = 'Market'
      or ask_OrderType = 'Market'
      )
)

--SELECT @bid_OrderSize_Market  as 'bid_OrderSize_Market'
--     , @ask_OrderSize_Market  as 'ask_OrderSize_Market'
----
---- split Limit vs. Market Orders

select sort
--     , Order_ID, Order_Time
     , bid_OrderType
     , bid_OrderSize
     , IsNULL( SUM(bid_OrderSize) over(Order by sort desc 
                                       Range between unbounded preceding and current row) 
             , 0 )
     + @bid_OrderSize_Market   as  'cum_bid_OrderSize'
     , Kurs
     , ask_OrderSize
     , ask_OrderType
     , IsNULL( SUM(ask_OrderSize) over(Order by sort 
                                       Range between unbounded preceding and current row) 
             , 0 )
     + @ask_OrderSize_Market   as  'cum_ask_OrderSize'
     , Order_fill
into   tempdb.dbo.OrderListe_step02
from   tempdb.dbo.OrderListe_step01
where  kurs is NOT NULL
  and (
         bid_OrderType != 'Market'
      or ask_OrderType != 'Market'
      )
order  by sort desc
---- end step02 "cumulative bid+ ask_OrderSize"

---- return step02
IF @showStep = 'step02'
BEGIN

with tmpStep02 as
(
SELECT sort
     , IsNULL(bid_OrderType, 'Limit')  as 'bid_OrderType'  
     , IsNULL(bid_OrderSize, 0)        as 'bid_OrderSize'
     , cum_bid_OrderSize      
     , Kurs
     , cum_ask_OrderSize    
     , IsNULL(ask_OrderSize, 0)        as 'ask_OrderSize'
     , IsNULL(ask_OrderType, 'Limit')  as 'ask_OrderType'
FROM   tempdb.dbo.OrderListe_step02
)
SELECT sort
     , bid_OrderType
     , SUM(bid_OrderSize)         as 'bid_OrderSize'
     , AVG(cum_bid_OrderSize)     as 'cum_bid_OrderSize'
     , Kurs
     , AVG(cum_ask_OrderSize)     as 'cum_ask_OrderSize'
     , SUM(ask_OrderSize)         as 'ask_OrderSize'
     , ask_OrderType
FROM   tmpStep02
GROUP  by sort, bid_OrderType, Kurs, ask_OrderType
ORDER  by sort desc
END -- end step02


;
with tmpStep02 as
(
SELECT sort
     , IsNULL(bid_OrderType, 'Limit')  as 'bid_OrderType'  
     , IsNULL(bid_OrderSize, 0)        as 'bid_OrderSize'
     , cum_bid_OrderSize      
     , Kurs
     , cum_ask_OrderSize    
     , IsNULL(ask_OrderSize, 0)        as 'ask_OrderSize'
     , IsNULL(ask_OrderType, 'Limit')  as 'ask_OrderType'
FROM   tempdb.dbo.OrderListe_step02
)
SELECT sort
     , bid_OrderType
     , SUM(bid_OrderSize)         as 'bid_OrderSize'
     , AVG(cum_bid_OrderSize)     as 'cum_bid_OrderSize'
     , Kurs
     , AVG(cum_ask_OrderSize)     as 'cum_ask_OrderSize'
     , SUM(ask_OrderSize)         as 'ask_OrderSize'
     , ask_OrderType
into   tempdb.dbo.OrderListe_step03
FROM   tmpStep02
GROUP  by sort, bid_OrderType, Kurs, ask_OrderType

-----------------------
;
with 
tmpStep03 as
(
SELECT *
     , CASE
          WHEN cum_ask_OrderSize <= cum_bid_OrderSize THEN cum_ask_OrderSize
          ELSE cum_bid_OrderSize
       END     as 'Umsatz'
FROM   tempdb.dbo.OrderListe_step03
) , 
maxUmsatz as
(
SELECT MAX(Umsatz) as 'maxUmsatz'
FROM   tmpStep03
)
SELECT T.*
     , CASE
          WHEN Umsatz = maxUmsatz THEN Kurs
          ELSE                         NULL
       END        as 'Kurs_calc'
     , CASE
          WHEN Umsatz = maxUmsatz THEN '<<'
          ELSE                         ''
       END        as 'info_desc'
into   tempdb.dbo.OrderListe_step04
FROM   tmpStep03 T
cross  join  maxUmsatz
ORDER  by sort desc


---
IF @showStep = 'step03'
BEGIN

SELECT *
FROM   tempdb.dbo.OrderListe_step04
ORDER  by sort desc

END -- end step03

