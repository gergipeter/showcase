CREATE view [po].[record_view] as 
                select c.id as category_id,c.name as category, r.[period], min(t.name) as team,
                min([sap_backend]) as [sap_backend],r.[po_number], min(r.created_at) as created_at,
                case when min(u.Name) is not null then min(u.Name) else min(r.po_created_by) end as Created_by,
                 min([ifa_number]) as [ifa_number],min([ifa_supplier_name]) as [ifa_supplier_name],
                 min(a.name) as ARE,min(customer_id) as customer_id,
                count(distinct [number_of_line_item]) as PO_items_count, min(t1.[Line Items Text]) as [Line Items Text]
                from po.record r
                left join po.category c on c.id = r.category_id
                left  join indigo.team t on r.team_id = t.id
                left join po.scm_users u on r.po_created_by = u.GID
                left join flatfile.ARE a on a.id = r.are_id
                -- want to see which line items are considered
                left join
                (SELECT 
                   po_number,period,category_id,
                   STUFF((SELECT ';' +  cast([number_of_line_item] as varchar(255)) + CHAR(10)
                          FROM po.record  US
                          WHERE ss.po_number = US.po_number
                          ORDER BY [number_of_line_item] asc
                          FOR XML PATH('')), 1, 1, '') [Line Items Text]
                FROM po.record  SS
                GROUP BY SS.po_number,ss.period,ss.category_id) t1
                on r.po_number = t1.po_number and r.period = t1.period and t1.category_id = r.category_id
                group by r.[po_number], r.[period], c.name, c.id