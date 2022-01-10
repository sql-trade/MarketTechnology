use tempDB
GO

Declare @showStep  varchar(10) = 'step03'  -- [ step01 | step02 | step03 ] 

DROP TABLE IF EXISTS tempdb.dbo.OrderList;         
DROP TABLE IF EXISTS tempdb.dbo.OrderList_step01;  
DROP TABLE IF EXISTS tempdb.dbo.OrderList_step02;  
DROP TABLE IF EXISTS tempdb.dbo.OrderList_step03;  

CREATE TABLE tempdb.dbo.OrderList (            
               Order_ID        int             
             , Order_Time      time not NULL   
             , Quote           int  NULL  -- Market-Orders
             , bid_OrderSize   int  NULL       
             , bid_OrderType   varchar(20) NULL
             , ask_OrderSize   int  NULL       
             , ask_OrderType   varchar(20) NULL
             )                                 
----

INSERT INTO tempdb.dbo.OrderList                                                                         
       ( Order_ID , Order_Time ,  bid_OrderType , bid_OrderSize , Quote , ask_OrderSize , ask_OrderType )
VALUES (        0 ,    '00:00' ,        'Close' ,          NULL ,   100 ,          NULL ,          NULL )

     , (        1 ,    '08:10' ,        'Limit' ,           200 ,    99 ,          NULL ,          NULL )
     , (        2 ,    '08:20' ,           NULL ,          NULL ,  NULL ,           500 ,      'Market' )
     , (        3 ,    '08:21' ,        'Limit' ,          1000 ,    88 ,          NULL ,          NULL )

     , (        4 ,    '08:25' ,           NULL ,          NULL ,    89 ,           800 ,       'Limit' )
     , (        5 ,    '08:30' ,       'Market' ,           700 ,  NULL ,          NULL ,          NULL )
     , (        6 ,    '08:30' ,        'Limit' ,            20 ,   105 ,          NULL ,          NULL )

     , (        7 ,    '08:35' ,           NULL ,          NULL ,    95 ,          1500 ,       'Limit' )
     , (        8 ,    '08:38' ,           NULL ,          NULL ,    92 ,           700 ,       'Limit' )
     , (        9 ,    '08:40' ,        'Limit' ,           300 ,    90 ,          NULL ,          NULL )

     , (       10 ,    '08:40' ,       'Market' ,          1000 ,  NULL ,          NULL ,          NULL )
     , (       11 ,    '08:45' ,           NULL ,          NULL ,   125 ,           500 ,       'Limit' )
     , (       12 ,    '08:55' ,           NULL ,          NULL ,  NULL ,           200 ,      'Market' )
     , (       13 ,    '08:58' ,        'Limit' ,          1000 ,    95 ,          NULL ,          NULL )

----
Declare @lastQuote  int
SET @lastQuote = ( select Quote from tempdb.dbo.OrderList where bid_OrderType = 'Close' )

;
with 
QuoteList as 
(
select number  as 'Quote'
from   master..spt_values
where  type = 'P'
  and  number >=  88
  and  number <= 125
) ,
OrderList as
(
select Order_ID, Order_Time
     , bid_OrderType, bid_OrderSize
     , CASE                                             
          WHEN bid_OrderType = 'Market'  THEN @lastQuote
          WHEN ask_OrderType = 'Market'  THEN @lastQuote
          ELSE                                     Quote
       END       as 'Quote'                             
     , ask_OrderSize, ask_OrderType                     
from   tempdb.dbo.OrderList
)
SELECT QL.Quote as 'sort'                             
     , OL.Order_ID                                    
     , Format(OL.Order_Time, 'hh\:mm') as 'Order_Time'
     , OL.bid_OrderType, OL.bid_OrderSize             
     , OL.Quote                                       
     , OL.ask_OrderSize, OL.ask_OrderType             
INTO   tempdb.dbo.OrderList_step01                    
FROM   QuoteList QL       
left   join               
       OrderList OL       
ON     QL.Quote = OL.Quote
WHERE  1 = 1              
ORDER  by QL.Quote desc, OL.Order_ID 

-- return step01
IF @showStep = 'step01'
BEGIN
select *
from   tempdb.dbo.OrderList_step01
where  Quote is NOT NULL
order  by sort desc
END -- end step01

--select *
--from   tempdb.dbo.OrderList_step01
--where  Quote is NOT NULL
--  and (
--         bid_OrderType = 'Market'
--      or ask_OrderType = 'Market'
--    )
---- and
--select *
--from   tempdb.dbo.OrderList_step01
--where  Quote is NOT NULL
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
from   tempdb.dbo.OrderList_step01
where  Quote is NOT NULL
  and (
         bid_OrderType = 'Market'
      or ask_OrderType = 'Market'
      )
)
----
Set @ask_OrderSize_Market = (
select SUM( ask_OrderSize )
from   tempdb.dbo.OrderList_step01
where  Quote is NOT NULL
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
--   , Order_ID, Order_Time
     , bid_OrderType
     , bid_OrderSize
     , IsNULL( SUM(bid_OrderSize) over(Order by sort desc 
                                       Range between unbounded preceding and current row) 
             , 0 )
     + @bid_OrderSize_Market   as  'cum_bid_OrderSize'
     , Quote
     , ask_OrderSize
     , ask_OrderType
     , IsNULL( SUM(ask_OrderSize) over(Order by sort 
                                       Range between unbounded preceding and current row) 
             , 0 )
     + @ask_OrderSize_Market   as  'cum_ask_OrderSize'
into   tempdb.dbo.OrderList_step02
from   tempdb.dbo.OrderList_step01
where  Quote is NOT NULL
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
     , Quote                                             
     , cum_ask_OrderSize                                 
     , IsNULL(ask_OrderSize, 0)        as 'ask_OrderSize'
     , IsNULL(ask_OrderType, 'Limit')  as 'ask_OrderType'
FROM   tempdb.dbo.OrderList_step02                       
)
SELECT sort                                              
     , bid_OrderType                                     
     , SUM(bid_OrderSize)         as 'bid_OrderSize'     
     , AVG(cum_bid_OrderSize)     as 'cum_bid_OrderSize' 
     , Quote                                             
     , AVG(cum_ask_OrderSize)     as 'cum_ask_OrderSize' 
     , SUM(ask_OrderSize)         as 'ask_OrderSize'     
     , ask_OrderType                                     
FROM   tmpStep02                                         
GROUP  by sort, bid_OrderType, Quote, ask_OrderType      
ORDER  by sort desc                                      
END -- end step02


;
with tmpStep02 as
(
SELECT sort                                              
     , IsNULL(bid_OrderType, 'Limit')  as 'bid_OrderType'
     , IsNULL(bid_OrderSize, 0)        as 'bid_OrderSize'
     , cum_bid_OrderSize                                 
     , Quote                                             
     , cum_ask_OrderSize                                 
     , IsNULL(ask_OrderSize, 0)        as 'ask_OrderSize'
     , IsNULL(ask_OrderType, 'Limit')  as 'ask_OrderType'
FROM   tempdb.dbo.OrderList_step02                       
)
SELECT sort                                              
     , bid_OrderType                                     
     , SUM(bid_OrderSize)         as 'bid_OrderSize'     
     , AVG(cum_bid_OrderSize)     as 'cum_bid_OrderSize' 
     , Quote                                             
     , AVG(cum_ask_OrderSize)     as 'cum_ask_OrderSize' 
     , SUM(ask_OrderSize)         as 'ask_OrderSize'     
     , ask_OrderType                                     
into   tempdb.dbo.OrderList_step03                       
FROM   tmpStep02                                         
GROUP  by sort, bid_OrderType, Quote, ask_OrderType      

-----------------------
IF @showStep = 'step03'
BEGIN

;
with 
tmpStep03 as
(
SELECT *
     , CASE
          WHEN cum_ask_OrderSize <= cum_bid_OrderSize THEN cum_ask_OrderSize
          ELSE cum_bid_OrderSize
       END   as 'Umsatz'
FROM   tempdb.dbo.OrderList_step03
) , 
maxUmsatz as
(
SELECT MAX(Umsatz) as 'maxUmsatz'
FROM   tmpStep03
)
SELECT T.*
     , CASE
          WHEN Umsatz = maxUmsatz THEN Quote
          ELSE                         NULL
       END        as 'info'
     , CASE
          WHEN Umsatz = maxUmsatz THEN '<<'
          ELSE                         ''
       END        as 'info'
FROM   tmpStep03 T
cross  join  maxUmsatz
ORDER  by sort desc

END -- end step03
---