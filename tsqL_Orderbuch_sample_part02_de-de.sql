use tempdb
GO

-- Result of part1 >>
Declare @new_OpenKurs    int = 95
      , @ask_OrderSize   int

-- ?? was "verschwindet aus dem orderbuch ?

SELECT @ask_OrderSize = cum_ask_OrderSize
FROM   tempdb.dbo.OrderListe_step04
WHERE  sort = @new_OpenKurs

SELECT @ask_OrderSize

----------------------------

UPDATE tempdb.dbo.OrderListe
   SET Order_fill = -1
 WHERE bid_OrderType = 'SchlussKurs'

-- 1st die Market-Orders
UPDATE tempdb.dbo.OrderListe
   SET Order_fill = @new_OpenKurs
 WHERE 1 = 1
   and Order_fill is NULL 
   and (  bid_OrderType = 'Market'
	   or ask_OrderType = 'Market'
	   )

UPDATE tempdb.dbo.OrderListe
   SET Order_fill = @new_OpenKurs
 WHERE Order_ID =  3 --bid_Limit
    or Order_ID =  4 --bid_Limit
	or Order_ID =  7 --ask_Limit
    or Order_ID =  8 --ask_Limit
	or Order_ID =  9 --bid_Limit
	or Order_ID = 13 --bid_Limit  -- 3700 bid-ask_Volume
-- ===================
SELECT *
FROM   tempdb.dbo.OrderListe
----
SELECT SUM(bid_OrderSize)   as 'bid_OrderSize'
     , SUM(ask_OrderSize)   as 'ask_OrderSize'
FROM   tempdb.dbo.OrderListe
WHERE  Order_fill = 95
-- ===================

SELECT *
FROM   tempdb.dbo.OrderListe
WHERE  Order_fill is NULL
ORDER  by Kurs desc

INSERT INTO tempdb.dbo.OrderListe
       ( Order_ID , Order_Time , bid_OrderType , bid_OrderSize , Kurs , ask_OrderSize , ask_OrderType, Order_fill )
VALUES (       15 ,    '09:02' ,          NULL ,          NULL ,   94 ,           100 ,      'Limit' , NULL )


-->> neuer Kurs 94 ..