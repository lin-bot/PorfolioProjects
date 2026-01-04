
--SUMMARY OF THE PROJECT:
--The main objective was to identify the peak sales periods. In order to accomplish this goal,
--the data was cleaned and prepared to aggregate sales over time. A monthly sales column was created to calculate total sales. Trends were  identify 
-- by calculating rolling monthly averages, and peak periods by tying them to a holiday event or season or external peak.


--1. DATA CLEANING AND PREPARATION
--Remove canceled orders and handle null values
drop table EcommerceTrendProject..clean_data
Select*
into EcommerceTrendProject..clean_data
From EcommerceTrendProject..data
Where InvoiceNo Not Like 'C%' --where invoice numbers  start with a 'c'
	and  UnitPrice is not null
	and Quantity is not null
	and CustomerID is not null
	and CustomerID != '' --where customerId is an empty space and not null
	and ISNUMERIC(Quantity) = 1
	and ISNUMERIC(unitPrice) = 1

--convert to the appropriate data type
alter table EcommerceTrendProject..clean_data 
alter column quantity INT

alter table EcommerceTrendProject..clean_data 
alter column UnitPrice decimal(10,2)

alter table EcommerceTrendProject..clean_data
alter column InvoiceNo varchar(20)

alter table EcommerceTrendProject..clean_data
alter column StockCode varchar(20)

alter table EcommerceTrendProject..clean_data
alter column Description nvarchar(255)

alter table EcommerceTrendProject..clean_data
alter column InvoiceDate datetime

alter table EcommerceTrendProject..clean_data
alter column CustomerID varchar(20)

alter table EcommerceTrendProject..clean_data
alter column Country nvarchar(20)

--create the total sales column
alter table EcommerceTrendProject..clean_data
add TotalSales decimal(10,2);

update EcommerceTrendProject..clean_data
set TotalSales = UnitPrice * Quantity;

select top 20 *
from EcommerceTrendProject..clean_data

--2. AGGREGATE SALES OVER TIME
--identify peak sales periods
--calculate total sales per day and month
select Month(InvoiceDate) as SalesMonth, Day(InvoiceDate) as SalesDay, SUM(TotalSales) as DailySales
from EcommerceTrendProject..clean_data
group by Month(InvoiceDate)
	,Day(InvoiceDate)
order by SalesMonth, SalesDay;

select Year(InvoiceDate) as SalesYear, Month(InvoiceDate) as SalesMonth, SUM(TotalSales) as MonthlySales
from EcommerceTrendProject..clean_data
group by Year(InvoiceDate)
	, Month(InvoiceDate)
order by SalesYear, SalesMonth;

--average order value per day or month
with DailySales as(
	select CAST(InvoiceDate as date) as SalesDate --separate each date
	,SUM(TotalSales) as DailySales
from EcommerceTrendProject..clean_data
group by cast(InvoiceDate as date) -- group by the date
)
select AVG(DailySales) as AvgOrderPerDay --calcualte the average
from DailySales;

with MonthlySales as(
	select Year(InvoiceDate) as SalesYear, Month(InvoiceDate) as SalesMonth, SUM(TotalSales) as MonthlySales --separate date into year and month, sum the total sales for each month
	from EcommerceTrendProject..clean_data
	group by Year(InvoiceDate) --group by the year and month
		, Month(InvoiceDate)
)
select AVG(MonthlySales) as AvgOrderPerMonth --calculate the average per month
from MonthlySales;



--3.TREND ANALYSIS
--calcalate rolling averages of daily sales
with DailySales as(
	select CAST(InvoiceDate as date) as SalesDate
	,SUM(TotalSales) as DailySales
	from EcommerceTrendProject..clean_data
	group by CAST(InvoiceDate as date)
)
select SalesDate
	, DailySales
	, AVG(DailySales) over (
		order by SalesDate rows between 6 preceding and current row
	) as RollingDailySales -- calculate the 7 day rolling average
from DailySales
order by SalesDate;

--calculate rolling averages of monthly sales
with MonthlySales as(
	select Year(InvoiceDate) as SalesYear, Month(InvoiceDate) as SalesMonth, SUM(TotalSales) as MonthlySales
	from EcommerceTrendProject..clean_data
	group by Year(InvoiceDate), MONTH(InvoiceDate)
)
select SalesYear
	, SalesMonth
	, MonthlySales
	,AVG(MonthlySales) over (
		order by SalesYear, SalesMonth rows between 11 preceding and current row --calculate the 12 month rolling average
	) as RollingMonthlySales
from MonthlySales
order by SalesYear, SalesMonth;

--calculate month-over-month growth sales
with MonthlySales as(
	select Year(InvoiceDate) as SalesYear
		, Month(InvoiceDate) as SalesMonth
		, SUM(TotalSales) as MonthlySales
		, LAG(SUM(TotalSales)) OVER (ORDER BY YEAR(InvoiceDate),MONTH(InvoiceDate)) AS PreviousMonthSales
	from EcommerceTrendProject..clean_data
	group by YEAR(InvoiceDate), MONTH(InvoiceDate)
)
select SalesYear
	, SalesMonth
	, MonthlySales
	, MonthlySales - PreviousMonthSales as MomChange
	, ((MonthlySales - PreviousMonthSales) * 1.0 / PreviousMonthSales)*100 as MomGrowthPercent
from MonthlySales

--identify top sales months
with Monthlysales as(
	select YEAR(InvoiceDate) as SalesYear
		, MONTH(InvoiceDate) as SalesMonth
		, SUM(TotalSales) as MonthlySales
	from EcommerceTrendProject..clean_data
	group by YEAR(InvoiceDate), MONTH(InvoiceDate)
),
RankedSales as(
	select SalesYear
	, SalesMonth
	, MonthlySales
	, RANK() OVER (ORDER BY MonthlySales DESC) as Rank
	from MonthlySales
)
select *
from RankedSales
where Rank <= 5
order by MonthlySales Desc;

--flag above average months
with MonthlySales as(
	select YEAR(InvoiceDate) as SalesYear
	, MONTH(InvoiceDate) as SalesMonth
	, SUM(TotalSales) as MonthlySales
	from EcommerceTrendProject..clean_data
	group by YEAR(InvoiceDate), MONTH(InvoiceDate)
)
select SalesYear
	, SalesMonth
	, MonthlySales
	,CASE 
		WHEN MonthlySales > AVG(MonthlySales) OVER() THEN 'Above Average' --when the monthly sale is above the average then it will be flagged as above average
		ELSE 'Normal'
	 END AS SalesFlag
from MonthlySales
order by SalesYear, SalesMonth;

--using rolling averages detect sustain peaks

with MonthlySales as(
	select YEAR(InvoiceDate) as SalesYear
		, MONTH(InvoiceDate) as SalesMonth
		, SUM(TotalSales) as MonthlySales
	from EcommerceTrendProject..clean_data
	group by YEAR(InvoiceDate), MONTH(InvoiceDate)
),
RollingMonthlyAvg as(
	select SalesYear
		,SalesMonth
		,MonthlySales
		,AVG(MonthlySales) OVER (
			order by SalesYear, SalesMonth ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
		) as RollingMonthlyAvg
	from MonthlySales
)
select SalesYear
	,SalesMonth
	,MonthlySales
	,RollingMonthlyAvg
	,CASE
		WHEN MonthlySales > RollingMonthlyAvg THEN 1 --identify above avergae rolling monthly averages and assigned them a 1 or 0 
		ELSE 0 
	END AS AboveRollingAvg
from RollingMonthlyAvg
order by SalesYear, SalesMonth

--tie peaks to holidays or promotions
with MonthlySales as(
	select YEAR(InvoiceDate) as SalesYear
		,MONTH(InvoiceDate) as SalesMonth
		,SUM(TotalSales) as MonthlySales
	from EcommerceTrendProject..clean_data
	group by YEAR(InvoiceDate), MONTH(InvoiceDate)
),
RollingMonthlyAvg as(
	select SalesYear
		,SalesMonth
		,MonthlySales
		,AVG(MonthlySales) OVER ( 
			ORDER BY  SalesYear, SalesMonth ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as RollingMonthlyAvg
	from MonthlySales
),
PeakPeriods as(
	select *,
		CASE
			WHEN MonthlySales > RollingMonthlyAvg THEN 1
			ELSE 0
		END AS AboveRollingAvg
	from RollingMonthlyAvg
),
Holidays as(
	select 'Black Friday / Cyber Monday' as HolidayName, 11 as StartMonth, 11 as EndMonth --assigning the holidays to months
	union all
	select 'Holiday Season', 12, 12
	union all
	select 'Valentines Day', 2, 2
)
select SalesYear
	,SalesMonth
	,MonthlySales
	,RollingMonthlyAvg
	,AboveRollingAvg
	,HolidayName
	,CASE
		WHEN AboveRollingAvg = 1 AND HolidayName IS NOT NULL THEN 'Holiday Peak' --peak type flag 
		WHEN AboveRollingAvg = 1 AND HolidayName IS NULL THEN 'Seasonal or External Peak'
		ELSE 'Normal'
	END AS PeakType
from PeakPeriods
left join Holidays
on salesMonth between StartMonth and  EndMonth
order by SalesYear, SalesMonth


