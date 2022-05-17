-------------------------------------------------------------------------------
-- Conservation Water Connections Report
-- Date written: 02/17/2022
-- By Teo Espero (IT Administrator, MCWD)
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- PRE-REQUISITES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Water service codes
--	These are the service rate codes that are attached to a water concection 
--	account...
-------------------------------------------------------------------------------
select 
distinct
	SUBSTRING(service_code,1,2) as ServicePrefix,
	[description]
from ub_service
where
	bill_type like 'Water'
order by
	[description]

-------------------------------------------------------------------------------
-- select service rates that we will be using
-- all water excluding:
--		- Cap S/Chg
--		- Recycled Water
--		- TA
-------------------------------------------------------------------------------
select 
distinct
	service_code,
	[description]
	into #waterServiceCodes
from ub_service
where
	bill_type like 'Water'
	and service_code not like 'WC%'
	and service_code not like 'RW%'
	and service_code not like 'TA%'

select *
from #waterServiceCodes


-------------------------------------------------------------------------------
-- 1 generate a list of accounts that are water only
-------------------------------------------------------------------------------

select 
	distinct
	replicate('0', 6 - len(srv.cust_no)) + cast (srv.cust_no as varchar)+ '-'+replicate('0', 3 - len(srv.cust_sequence)) + cast (srv.cust_sequence as varchar) as AccountNum
	into #water01
from ub_service_rate srv
where
	(rate_connect_date<>rate_final_date or rate_final_date is null)
	and service_code in (
	select 
		service_code
	from #waterServiceCodes
	)
order by
	replicate('0', 6 - len(srv.cust_no)) + cast (srv.cust_no as varchar)+ '-'+replicate('0', 3 - len(srv.cust_sequence)) + cast (srv.cust_sequence as varchar)

select *
from #water01

-------------------------------------------------------------------------------
-- 2 using the list of accounts, generate a table that contains their lot no
-------------------------------------------------------------------------------

select 
	distinct
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) as accountnum,
	mast.connect_date,
	mast.final_date,
	mast.lot_no
	into #water02
from ub_master mast
where
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) in (
	select AccountNum from #water01
	)
order by
	mast.lot_no

select *
from #water02

-------------------------------------------------------------------------------
-- 3 gather rows that are connected before EOY 2021
-- filter between
--		connect date < 12/31/2021
--		final date is null or 
--		FinalDate >= '01/01/2021' and FinalDate <= '12/31/2021'
-------------------------------------------------------------------------------
select *
into #water03
from #water02
where
	(connect_date <= '03/31/2022')
	and ((final_date >= '01/01/2022' and final_date <= '03/31/2022') or final_date is null)
order by
	lot_no

select *
from #water03
order by
	lot_no,
	connect_date,
	final_date

-------------------------------------------------------------------------------
-- 4 get the latest lot connectdate
-- note that a series of lot may have several accounts attached to it
-- but we will only get the account that is the latest for that lot no
-------------------------------------------------------------------------------
select 
	t.accountnum,
	t.connect_date,
	t.final_date,
	t.lot_no
	into #water04
from #water03 t
inner join (
	select lot_no, 
	max(connect_date) as MaxDate
	--max(transaction_id) as MaxTrans
    from #water03
    group by lot_no
) tm 
on 
	t.lot_no = tm.lot_no
	--and t.tran_date = tm.MaxDate 
	and t.connect_date=tm.MaxDate
--and t.AccountNum = '017226-000'
order by
	t.lot_no,
	t.connect_date

select *
from #water04
order by lot_no

-------------------------------------------------------------------------------
-- 5 generate our  table
--		Note that only the main account for Bay View is listed
-------------------------------------------------------------------------------
select 
	lot.misc_2 as STCategory,
	lot.misc_1 as Boundary,
	lot.misc_5 as Subdvision,
	lot.misc_16 as Irrigation,
	lot.lot_no,
	w.accountnum,
	CONVERT(varchar(10),w.connect_date,101) as connect_date,
	CONVERT(varchar(10),w.final_date,101) as final_date,
	lot.lot_status,
	lot.street_number + lot.street_name + lot.addr_2+lot.description as [Other info about connection]
	into #water05
from #water04 w
inner join lot
	on lot.lot_no=w.lot_no
	and (w.final_date between '01/01/2022' and '03/31/2022' or w.final_date is null)
	and lot.misc_5 <> 'Bay View'
union
select 
	lot.misc_2 as STCategory,
	lot.misc_1 as Boundary,
	lot.misc_5 as Subdvision,
	lot.misc_16 as Irrigation,
	lot.lot_no,
	w.accountnum,
	CONVERT(varchar(10),w.connect_date,101) as connect_date,
	CONVERT(varchar(10),w.final_date,101) as final_date,
	lot.lot_status,
	lot.street_number + lot.street_name + lot.addr_2+lot.description as [Other info about connection]
from #water04 w
inner join lot
	on lot.lot_no=w.lot_no
	and (w.final_date between '01/01/2022' and '03/31/2022' or w.final_date is null)
	and accountnum='000990-000'
order by
	lot.misc_2

select *
from #water05
	

-------------------------------------------------------------------------------
-- 6 get meter information
--		Note that only the main account for Bay View is listed
-------------------------------------------------------------------------------

--6a Generate account device ids
select 
	w5.STCategory,
	w5.Boundary,
	w5.Subdvision,
	w5.Irrigation,
	w5.lot_no,
	w5.accountnum,
	w5.connect_date,
	w5.final_date,
	w5.lot_status,
	w5.[Other info about connection],
	m.install_date,
	m.remove_date,
	m.ub_device_id
	into #water06
from #water05 w5
inner join
	ub_meter_con m
	on m.lot_no=w5.lot_no
order by
	w5.accountnum,
	m.ub_device_id

select *
from #water06

-- 6b generate the rows with the latest device IDs (meters)
select 
	t.accountnum,
	t.STCategory,
	t.Boundary,
	t.Subdvision,
	t.Irrigation,
	t.lot_no,
	t.connect_date,
	t.final_date,
	t.lot_status,
	t.[Other info about connection],
	t.install_date,
	t.remove_date,
	t.ub_device_id
	into #water07
from #water06 t
inner join (
	select accountnum, 
	max(ub_device_id) as MaxDeviceID
	--max(transaction_id) as MaxTrans
    from #water06
    group by accountnum
) tm 
on 
	t.accountnum = tm.accountnum
	--and t.tran_date = tm.MaxDate 
	and t.ub_device_id=tm.MaxDeviceID
	--and t.ub_device_id='96f8d076-aa95-4f43-9cdb-4eba51af19ec'
--and t.AccountNum = '017226-000'
order by
	t.accountnum

-- 6c get meter infos
select
	w7.STCategory,
	w7.Boundary,
	w7.Subdvision,
	w7.Irrigation,
	w7.lot_no,
	w7.accountnum,
	w7.connect_date,
	w7.final_date,
	w7.lot_status,
	w7.[Other info about connection],
	w7.ub_device_id,
	t.device_type,
	t.device_size,
	t.manufacturer,
	d.serial_no,
	w7.install_date,
	w7.remove_date,
	mast.billing_cycle
from ub_device d
inner join
	#water07 w7
	on w7.ub_device_id=d.ub_device_id
inner join
	ub_device_type t
	on d.ub_device_type_id=t.ub_device_type_id
inner join
	ub_master mast
	on replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar)=w7.accountnum

-------------------------------------------------------------------------------
-- Temporary Table Cleanup
-------------------------------------------------------------------------------
drop table #water01
drop table #water02
drop table #water03
drop table #water04
drop table #water05
drop table #water06
drop table #water07
drop table #waterServiceCodes
-------------------------------------------------------------------------------