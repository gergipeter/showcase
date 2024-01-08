CREATE PROCEDURE [sq].[kpi_report_to_gloper]
( @nr_of_periods tinyint = 1 )

AS
BEGIN
SET NOCOUNT ON;


-- create list of periods
Create table #periods (period varchar(8))
WHILE (@nr_of_periods >=1)
BEGIN
insert into #periods (period)  
select CONCAT(year(DATEADD(month, -@nr_of_periods, GETDATE())),FORMAT(DATEADD(month, -@nr_of_periods, GETDATE()),'MM') ,'00')
SET @nr_of_periods = @nr_of_periods -1 
END


select ROW_NUMBER() OVER  (ORDER BY  p.period desc, cu.id desc,   kn.priority,  kn.name) as id,
cast(p.period as varchar(50)) as period ,te.name as team, sn.name as product, kn.name as KPI,
cu.name as customer_name, cast(null as float) as value
into #import_template
from [indigo].[team_customer] tc
-- join top level customer
left join indigo.customer tlc on tc.customer_id = tlc.id
-- join customer units of top level customers
left join indigo.customer cu on tlc.id = [indigo].[get_top_level_customer_id](cu.id)
-- team names
left join indigo.team te on tc.team_id = te.id
-- join team to service
left join indigo.service s on s.team_customer_id = tc.id
-- service names
left join indigo.service_name sn on sn.id = s.service_name_id
-- kpi list & names
left join indigo.kpi k on k.service_id = s.id
left join indigo.kpi_name kn on k.kpi_name_id = kn.id
-- join periods
left join #periods p on 1=1

-- hide not visible customers
left join indigo.customer_visibility cv 
on cv.team_id = tc.team_id and cv.service_name_id = sn.id 
and cv.customer_unit_id = cu.id
AND NOT ((cv.valid_from IS NULL)
OR NOT((p.period >= cv.valid_from)
AND (p.period <= cv.valid_to OR cv.valid_to IS NULL)))
where cv.id is null and 
-- hide not valid customers
(p.period >= cu.valid_from or cu.valid_from is null)
and (p.period <= cu.valid_to or cu.valid_to is null)
-- exclude consolidated level (get input level only)
and  [indigo].[get_consolidation_by_customer_child_team_service2](cu.id, te.id, sn.id, p.period) = 'inputed' 
-- hide not valid services to team
and
(p.period >= tc.valid_from or tc.valid_from is null)
and (p.period <= tc.valid_to or tc.valid_to is null)
-- hide not valid customer to service to team
and
(p.period >= s.valid_from or s.valid_from is null)
and (p.period <= s.valid_to or s.valid_to is null)
-- hide not valid kpi to customer to service to team
and
(p.period >= k.valid_from or k.valid_from is null)
and (p.period <= k.valid_to or k.valid_to is null)

-- exclude calculated kpis
and kn.kpi_kind in (1,3)
and sn.name = 'Supplier Qualification'



-- 1) Number of received Supplier Qualifications (Input)
-- -------------------------------------------------------------------------
-- values which are valid for template
update t
set value = case when [# Records] is null then 0 else [# Records] end
from  #import_template t
left join 
-- Number of received Supplier Qualifications (Input)
(select coalesce(teams.team, d.[delivery center]) as team, [Customer name], count([Record ID]) as [# Records] 
FROM  dash2.data_sq_dash d
left join #periods p on 1=1
left join 
(select t.name as team, d.name as [delivery center] from indigo.team t
left join flatfile.dc d on t.dc_id = d.id
where t.name in ('Source-2-Contract','PS1 ES2','IN-DC PS2 5','SCMS S2C MY','SCM FSS AA ASN','Supplier Qualification')) teams
on teams.[delivery center] = d.[delivery center]
WHERE
CONCAT(year([Input Received]),FORMAT([Input Received],'MM') ,'00') = p.period
and doubles = 0 --and teams.team is not null
group by d.[delivery center],teams.team,[Customer name]) kpi 
on kpi.team = t.team  and kpi.[Customer name] = t.customer_name 
where t.KPI = 'Number of received Supplier Qualifications (Input)'


-- values which does not exist in template
insert into #import_template (period, team, product, kpi, customer_name, value)
select ' - invalid combination',kpi.team, ' Supplier Qualification', 'Number of received Supplier Qualifications (Input)', 
[Customer name] , [# Records]
from  #import_template t
left join #periods p on 1=1
right join
-- Number of received Supplier Qualifications (Input)
(select coalesce(teams.team, d.[delivery center]) as team, 
[Customer name],
count([Record ID]) as [# Records] 
FROM  dash2.data_sq_dash d
left join #periods p on 1=1
left join 
(select t.name as team, d.name as [delivery center] 
from indigo.team t
left join flatfile.dc d on t.dc_id = d.id
where t.name in ('Source-2-Contract','PS1 ES2','IN-DC PS2 5','SCMS S2C MY','SCM FSS AA ASN','Supplier Qualification')) teams
on teams.[delivery center] = d.[delivery center]
WHERE
CONCAT(year([Input Received]),FORMAT([Input Received],'MM') ,'00') = p.period
and doubles = 0
group by d.[delivery center],teams.team,[Customer name]) kpi 
on kpi.team = t.team  and kpi.[Customer name] = t.customer_name 
and t.KPI = 'Number of received Supplier Qualifications (Input)'
where t.KPI is null
-- ----------------------------------------------------------------------------------

--2) Number of finished Supplier Qualifications (New)(Hard Copy)(Renewal)(Check)
-- values which are valid for template
update t
set value = case when [# Records] is null then 0 else [# Records] end 
from  #import_template t
left join 
(select coalesce(teams.team, d.[delivery center]) as team, 
[Customer name],
case when [Request Type] = 'New' then 'Number of finished Supplier Qualifications (New)' 
when [Request Type] = 'Check' then 'Number of finished Supplier Qualifications (Check)'
when [Request Type] = 'Renewal' then 'Number of finished Supplier Qualifications (Renewal)'
when [Request Type] = 'Hardcopy' then 'Number of finished Supplier Qualifications (Hardcopy)' 
end as kpi, count([Record ID]) as [# Records] 
FROM  dash2.data_sq_dash d
left join #periods p on 1=1
left join 
(select t.name as team, d.name as [delivery center] 
from indigo.team t
left join flatfile.dc d on t.dc_id = d.id
where t.name in ('Source-2-Contract','PS1 ES2','IN-DC PS2 5','SCMS S2C MY','SCM FSS AA ASN','Supplier Qualification')) teams
on teams.[delivery center] = d.[delivery center]
WHERE
CONCAT(year([Finished Date]),FORMAT([Finished Date],'MM') ,'00') = p.period
and doubles = 0 and status in ('Finished', 'Finished not qualified')
group by d.[delivery center],teams.team,[Customer name],
case when [Request Type] = 'New' then 'Number of finished Supplier Qualifications (New)' 
when [Request Type] = 'Check' then 'Number of finished Supplier Qualifications (Check)'
when [Request Type] = 'Renewal' then 'Number of finished Supplier Qualifications (Renewal)'
when [Request Type] = 'Hardcopy' then 'Number of finished Supplier Qualifications (Hardcopy)' 
end) kpi
on kpi.team = t.team  and kpi.[Customer name] = t.customer_name and kpi.kpi = t.KPI
where t.kpi in 
('Number of finished Supplier Qualifications (New)', 'Number of finished Supplier Qualifications (Check)',
'Number of finished Supplier Qualifications (Renewal)','Number of finished Supplier Qualifications (Hardcopy)')


-- values which does not exist in template
insert into #import_template (period, team, product, kpi, customer_name, value)

select ' - invalid combination',kpi.team, 'Supplier Qualification', kpi.kpi,
[Customer name], [# Records]
from  
#import_template t
left join #periods p on 1=1
right join 
(select coalesce(teams.team, d.[delivery center]) as team, 
[Customer name],
case when [Request Type] = 'New' then 'Number of finished Supplier Qualifications (New)' 
when [Request Type] = 'Check' then 'Number of finished Supplier Qualifications (Check)'
when [Request Type] = 'Renewal' then 'Number of finished Supplier Qualifications (Renewal)'
when [Request Type] = 'Hardcopy' then 'Number of finished Supplier Qualifications (Hardcopy)' 
end as kpi, count([Record ID]) as [# Records] 
FROM  dash2.data_sq_dash d
left join #periods p on 1=1
left join 
(select t.name as team, d.name as [delivery center] 
from indigo.team t
left join flatfile.dc d on t.dc_id = d.id
where t.name in ('Source-2-Contract','PS1 ES2','IN-DC PS2 5','SCMS S2C MY','SCM FSS AA ASN','Supplier Qualification')) teams
on teams.[delivery center] = d.[delivery center]
WHERE
CONCAT(year([Finished Date]),FORMAT([Finished Date],'MM') ,'00') = p.period
and doubles = 0 and status in ('Finished', 'Finished not qualified')
group by d.[delivery center],teams.team,[Customer name],
case when [Request Type] = 'New' then 'Number of finished Supplier Qualifications (New)' 
when [Request Type] = 'Check' then 'Number of finished Supplier Qualifications (Check)'
when [Request Type] = 'Renewal' then 'Number of finished Supplier Qualifications (Renewal)'
when [Request Type] = 'Hardcopy' then 'Number of finished Supplier Qualifications (Hardcopy)' 
end) kpi
on kpi.team = t.team  and kpi.[Customer name] = t.customer_name and kpi.kpi = t.KPI
where t.KPI is null



select period, team, product, kpi, customer_name, value from #import_template
order by period desc, product, team ,kpi,customer_name

END;