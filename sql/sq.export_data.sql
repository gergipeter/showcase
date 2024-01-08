CREATE PROCEDURE [sq].[export_data_current_fy] 
AS
    BEGIN
        SET NOCOUNT ON;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] export_data procedure start');
        IF OBJECT_ID('tempdb..#data_sq_dash_current_fy') IS NOT NULL
        BEGIN
            DROP TABLE data_sq_dash_current_fy;
            PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] Dropped tmp table');
        END;

        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] main select query start');

        SELECT NULL AS [Doubles], 
                req.id [Record ID], 
                req.input_received AS [Input Received], 
                req.created_at 'Created at', 
                req.created_by AS [Created by ID], 
                CAST('' AS VARCHAR(MAX)) AS [Created by], 
                req.[start_date] AS 'Start Date', 
				CAST('' AS VARCHAR(MAX)) AS [Finished Year & Month],  
                CAST('' AS VARCHAR(4)) AS [Fiscal Year Input Received], 
                -- dbo.[_get_fiscal_month_from_date](req.input_received) as [Fiscal Month Input Received], //was commented in original function
                CAST('' AS VARCHAR(3)) AS [Month Name Input Received],
                CAST('' AS VARCHAR(4)) AS [Fiscal Year],
                CAST('' AS VARCHAR(4)) AS [Fiscal Year Record Finished],
                CAST('' AS VARCHAR(2)) AS [Fiscal Month Record Finished],
                CAST('' AS VARCHAR(3)) AS [Month Name Record Finished],
                CAST('' AS VARCHAR(50)) AS  [Fiscal Year and Month Record Finished],
			    CAST(supplier.ifa AS NVARCHAR(MAX)) AS 'IFA', 
                stat.name 'Status', 
                supplier.ifa_supplier_name AS [Supplier Name], 
                suppliercountry.title AS [Supplier Country], 
                req.expected_pvo AS [Expected PVO], 
                req.type AS [rectype],
                CAST('' AS VARCHAR(MAX)) AS [Request Type],
                dc.name AS [Delivery Center], 
                req.agent_id AS [Agent ID], 
                CAST('' AS VARCHAR(MAX)) AS [Agent name],
                CASE
                    WHEN gs.customer_id IS NOT NULL
                    THEN 'global'
                    ELSE 'local'
                END AS [Customer type], 
                cu.name 'Customer name',
                CASE
                    WHEN bu.name IS NULL
                    THEN ' Not Applicable'
                    ELSE bu.name
                END AS 'Division', 
                div.name 'Business Unit', 
                cu_country.title AS 'Customer Country', 
                country.title 'Requester Country', 
                are.name 'ARE', 
                req.updated_at 'Updated at', 
                req.updated_by AS [Updated by ID], 
                CAST('' AS VARCHAR(MAX)) AS [Updated by], 
                req.next_target_date [Next Target Date], 
                CAST('' AS NVARCHAR(MAX)) AS [Comment History],
                CASE
                    WHEN LEN(req.fss_wave) > 1
                    THEN req.fss_wave
                    ELSE ''
                END AS [FSS Wave], 
                req.comments_prioritisation AS 'Comment / Prioritisation', 
                curstep.name AS 'Current Step Temp', 
                CAST('' AS VARCHAR(50)) AS [Current Step], 
                resp.name AS 'Responsible', 
                req.next_target_date_source AS [Next Action], 
                CAST('No' AS VARCHAR(3)) AS [CoC-old Requested],
                CASE
                    WHEN Coc.is_already_done = 1
                    THEN 'Yes'
                    WHEN Coc.is_already_done = 2
                    THEN 'No'
                    WHEN Coc.is_already_done = 3
                    THEN 'Deactivated'
                    ELSE 'Unknown'
                END 'CoC-old already done', 
                Coc.finished 'CoC-old Qualification Finished', 
                req.coc_status AS 'CoC Status',
                CASE
                    WHEN cocacceptance.available = 0
                    THEN 'No'
                    WHEN cocacceptance.available = 1
                    THEN 'Yes'
                    ELSE 'Unknown'
                END 'CoC Available / Migrated',
                CASE
                    WHEN [pega_request_sent_coc] IS NOT NULL
                    THEN [pega_request_sent_coc]
                    WHEN [pega_request_sent_qual] IS NOT NULL
                    THEN [pega_request_sent_qual]
                END 'PEGA Request Sent', 
                cocacceptance.request_sent 'CoC Request Sent', 
                dbo.AddWorkDays(12, cocacceptance.request_sent) AS 'CoC Target Date',
                CASE
                    WHEN cocacceptance.[finished] IS NOT NULL
                    THEN cocacceptance.[finished]
                    WHEN cocacceptance.[finished] IS NULL
                    THEN cocacceptance.[available_date]
                END 'CoC Checked/Finished',
                CASE
                    WHEN reg.reg_already_available = 0
                    THEN 'No'
                    WHEN reg.reg_already_available = 1
                    THEN 'Yes'
                    ELSE 'Unknown'
                END 'Registration Already Available', 
                reg.request_sent 'Registration Request Sent', 
                qual.request_sent 'Qualification Request Sent', 
                dbo.AddWorkDays(20, qual.request_sent) AS 'Qualification Process Target Date', 
                CAST('' AS TINYINT) AS [Count Requested Modules], 
                CAST('' AS TINYINT) AS [Count Finished Modules],
         -- 4) Corporate Responsibility Self Assessment
                CAST('No' AS VARCHAR(3)) AS [CRSA Requested], 
                req.crsa_status AS 'CRSA Status',
                CASE
                    WHEN CRSA.is_already_done = 1
                    THEN 'Yes'
                    WHEN CRSA.is_already_done = 2
                    THEN 'No'
                    WHEN CRSA.is_already_done = 3
                    THEN 'Deactivated'
                    ELSE 'Unknown'
                END 'CRSA already done',
                CASE
                    WHEN req.cap_version = 'Version 3'
                    THEN 'CRSA v3.0'
                    WHEN req.cap_version = 'Version 4'
                    THEN 'CRSA v4.0'
                    ELSE ''
                END AS 'CRSA Version',
        /*qu.started 'Qualification Started',*/
                CRSA.finished AS 'CRSA Qualification Finished',
                CASE
                    WHEN CRSA.cap_needed = 1
                    THEN 'Yes'
                    WHEN CRSA.cap_needed = 0
                    THEN 'No'
                    WHEN CRSA.cap_needed IS NULL
                    THEN 'Unknown'
                END AS 'CRSA CAP needed', 
                CRSA.cap_implementation_month 'CRSA CAP implementation time', 
                req.cap_status AS 'CAP Status', 
                crsa.cap_finished 'CRSA CAP finished',
         -- 5) Environmental Protection, Health Management and Safety
                CAST('No' AS VARCHAR(3)) AS [SC Requested], 
                req.sc_status AS 'SC Status',
                CASE
                    WHEN SC.is_already_done = 1
                    THEN 'Yes'
                    WHEN SC.is_already_done = 2
                    THEN 'No'
                    WHEN SC.is_already_done = 3
                    THEN 'Deactivated'
                    ELSE 'Unknown'
                END 'SC already done', 
                request_to_bomcheck_sent AS [Request to Bomcheck Sent], 
                SC.finished 'SC Qualification Finished',
         -- 9) Contractor Safety
                CAST('No' AS VARCHAR(3)) AS [CS Requested], 
                req.cs_status AS 'CS Status',
                CASE
                    WHEN cs.is_already_done = 1
                    THEN 'Yes'
                    WHEN cs.is_already_done = 2
                    THEN 'No'
                    WHEN cs.is_already_done = 3
                    THEN 'Deactivated'
                    ELSE 'Unknown'
                END 'CS already done', 
                cs.request_sent 'CS Qualification Request Sent', 
                cs.ehs_officer_request_sent 'EHS Officer Request Sent', 
                cs.finished 'CS Qualification Finished', 
                e.id AS [Escalation ID], 
                NULL AS [Doubles Check Escalation], 
                et.name AS [Escalation Tab], 
                cc.name AS [Escalation Contact Category],
                CASE
                    WHEN ern.reason IS NULL
                    THEN 'null'
                    ELSE ern.reason
                END AS [Escalation Reason],
                CASE
                    WHEN ern.subreason IS NULL
                    THEN 'null'
                    ELSE ern.subreason
                END AS [Escalation Subreason], 
                ers.name AS [Escalation Response], 
                sent AS [Escalation Sent Date], 
                follow_up AS [Escalation Follow Up Date], 
                e.solved AS [Escalation Solved Date], 
                flatfile.Workingdays(e.sent, e.solved) AS [Escalation Time], 
				eo.name AS [Escalation Outcome],
				eor.name AS [Escalation Outcome Reason],
				eosr.name AS [Escalation Outcome Subreason],
				e.feedback_sent_date AS [Escalation Feedback Sent Date],
				e.escalation_outcome_solved_date AS [Escalation Outcome Solved Date],
				e.feedback_from_customer_received_date AS [Escalation Feedback From Customer Received Date],
                current_step_time_calculated AS [Current Step Time], 
                CAST('' AS VARCHAR(50)) AS [Current Step Time Threshold], 
                CAST(NULL AS INT) AS [Ageing Time], 
                CAST('' AS VARCHAR(50)) AS [Ageing Time Threshold], 
                CAST('' AS VARCHAR(50)) AS [Backlog Step], 
                CAST(NULL AS INT) AS [Backlog Step Time], 
                CAST('' AS VARCHAR(50)) AS [Backlog Step Time Threshold], 
                req.out_of_scope_date 'Out Of Scope Date', 
                req.out_of_scope_comment 'Out Of Scope Comment',
                CASE
                    WHEN qual.finished_not_qualified = 1
                    THEN 'Qualification Step'
                    WHEN cocacceptance.finished_not_qualified = 1
                    THEN 'CoC Step'
                    WHEN reg.finished_not_qualified = 1
                    THEN 'Old Registration Step'
                END 'Finished not Qualified Step', 
                finished_not_qualified_tick AS [Finished Not Qualified Date], 
                CAST('' AS VARCHAR(255)) AS [Supplier Contact Title], 
                CAST('' AS VARCHAR(255)) AS [Supplier Contact First Name], 
                CAST('' AS VARCHAR(255)) AS [Supplier Contact Last Name], 
                CAST('' AS VARCHAR(255)) AS [Supplier Contact Email], 
                CAST('' AS VARCHAR(255)) AS [Supplier Contact Phone], 
                CAST('' AS VARCHAR(255)) AS [Siemens Contact Title], 
                CAST('' AS VARCHAR(255)) AS [Siemens Contact First Name], 
                CAST('' AS VARCHAR(255)) AS [Siemens Contact Last Name], 
                CAST('' AS VARCHAR(255)) AS [Siemens Contact Email], 
                CAST('' AS VARCHAR(255)) AS [Siemens Contact Phone], 
				CAST('' AS VARCHAR(255)) AS [Siemens Contact Country],
				req.org_code AS [Buyer Org Code],
                req.next_expiration_date AS [Next Expiration Date],
                CASE
                    WHEN ISNUMERIC(req.expiration_comment) <> 1
                    THEN req.expiration_comment
                    WHEN req.expiration_comment = 0
                    THEN 'Unlimited'
                    WHEN req.expiration_comment = 1
                    THEN 'Other'
                    WHEN req.expiration_comment = 4
                    THEN 'CRSA'
                    WHEN req.expiration_comment = 5
                    THEN 'SC'
                    WHEN req.expiration_comment = 9
                    THEN 'CS'
                END 'Expiration Comment',
                CASE
                    WHEN ISNUMERIC(req.expiration_comment) = 1
                    THEN req.expiration_comment_text
                    ELSE ''
                END 'Expiration Comment Text',
                CASE
                    WHEN req.is_renewal_requested = 0
                    THEN 'No'
                    WHEN req.is_renewal_requested = 1
                    THEN 'Yes'
                    ELSE ''
                END 'Renewal Requested', 
                finished_date_computed AS [Finished Date], 
                CAST([on_hold_start] AS DATE) AS 'On Hold Start', 
                CAST([on_hold_end] AS DATE) AS 'On Hold End', 
                req.information_sent_to_supplier AS 'Information Sent To Supplier', 
                req.information_sent_to_buyer AS 'Information To Buyer Sent', 
                total_time_calculated AS [Total Time],
                CASE
                    WHEN total_time_calculated IS NULL
                    THEN 'a) blank'
                    WHEN total_time_calculated < 100
                    THEN 'b) 0-99'
                    WHEN total_time_calculated < 200
                    THEN 'c) 199 - 100'
                    WHEN total_time_calculated < 300
                    THEN 'd) 200 - 299'
                    ELSE 'e) 300 and above'
                END AS [Total Time Threshold], 
                CAST(0 AS DECIMAL(3, 1)) AS [Productivity Points], 
                flatfile.Workingdays(TRY_CAST(next_target_date AS DATETIME), GETDATE()) AS [Severity], 
                CAST(NULL AS DECIMAL(18, 2)) AS [Price in Eur],
                CASE
                    WHEN req.process_type = 0
                    THEN 'Old Process'
                    WHEN req.process_type = 1
                    THEN 'New SCM Star Process'
                END 'Process type', 
                req.expected_nr_of_po AS 'Expected Nr of PO', 
                req.esi_connection_type AS 'ESI Connection Type', 
                req.reason_for_non_incl_in_esi AS 'Reason for Non Inclusion in ESI+', 
                req.creation_reason AS 'Creation Reason', 
                req.bp_check AS 'BP Check', 
                req.bp_id AS 'BP ID (If risk Identified)',
                CASE
                    WHEN req.spillover_calculated = 0
                    THEN 'No'
                    WHEN req.spillover_calculated = 1
                    THEN 'Yes'
                    ELSE 'Unknown'
                END AS 'Spillover', 
                req.spillover_fy_calculated AS [Spillover FY], 
                req.esn_code AS [ESN Code], 
                com.name AS 'Commodity', 
                comcat.name AS 'Commodity Category',
                CASE
                    WHEN comcat.is_indirect = 0
                    THEN 'Direct Material'
                    WHEN comcat.is_indirect = 1
                    THEN 'Indirect Material'
                    ELSE 'Unknown Material Type'
                END AS 'Material Type', 
                cu.id AS 'Customer ID'
        INTO #data_sq_dash_current_fy
        FROM sq.request req
            LEFT JOIN flatfile.dc dc ON dc.id = req.delivery_center_id
            LEFT JOIN indigo.customer cu ON cu.id = req.customer_id
            LEFT JOIN flatfile.country AS cu_country ON cu_country.id = cu.country_id
            LEFT JOIN flatfile.division div ON div.id = req.division_id
            LEFT JOIN flatfile.business_unit bu ON bu.id = req.business_unit_id
            LEFT JOIN flatfile.country ON country.id = req.country_id
            LEFT JOIN flatfile.are ON are.id = req.are_id
            LEFT JOIN dbo.supplier ON supplier.id = req.supplier_id
            LEFT JOIN flatfile.country suppliercountry ON dbo.supplier.country_id = suppliercountry.id
            LEFT JOIN sq.commodity com ON com.id = req.commodity_id
            LEFT JOIN sq.commodity_category comcat ON comcat.id = com.category_id
            LEFT JOIN sq.STATUS stat ON stat.id = req.status_id
            LEFT JOIN sq.contact_category resp ON resp.id = req.responsible_id
            LEFT JOIN sq.step curstep ON curstep.id = req.current_step_id
            LEFT JOIN sq.registration_process reg ON reg.id = req.registration_process_id
            LEFT JOIN sq.coc_process cocacceptance ON cocacceptance.id = req.coc_process_id
            LEFT JOIN sq.qualification_process qual ON qual.id = req.qualification_process_id
            LEFT JOIN sq.escalation e ON e.request_id = req.id
            LEFT JOIN sq.contact_category cc ON e.contact_category_id = cc.id
            LEFT JOIN sq.escalation_reason ern ON e.reason_id = ern.id
            LEFT JOIN sq.escalation_response ers ON e.response_id = ers.id
            LEFT JOIN sq.step et ON e.step_id = et.id
			LEFT JOIN sq.escalation_outcome eo ON e.escalation_outcome_id = eo.id
			LEFT JOIN sq.escalation_outcome_reason eor ON e.escalation_outcome_reason_id = eor.id
			LEFT JOIN sq.escalation_outcome_subreason eosr ON e.escalation_outcome_subreason_id = eosr.id
             -- moduels 1 by one
             LEFT JOIN sq.qualification CoC ON CoC.qualification_process_id = req.qualification_process_id    AND CoC.module_id = 1
             LEFT JOIN sq.qualification CRSA ON CRSA.qualification_process_id = req.qualification_process_id  AND CRSA.module_id = 4
             LEFT JOIN sq.qualification SC ON SC.qualification_process_id = req.qualification_process_id      AND SC.module_id = 5
             LEFT JOIN sq.qualification CS ON CS.qualification_process_id = req.qualification_process_id      AND CS.module_id = 9

             LEFT JOIN sq.global_customer gs ON gs.customer_id = req.customer_id AND gs.is_global_customer = 1

			 WHERE status_id in (1, 2, 3, 7) or status_id in (4, 5, 6) and (SELECT 
						(CASE
							WHEN LEN(spillover_fy_calculated) > 1 
                            THEN spillover_fy_calculated
                            ELSE dbo.[_get_fiscal_year_from_date](input_received)
						END)) = dbo.[_get_fiscal_year_from_date](GETDATE());
			 
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] main select finished.');

        --update user names
        UPDATE d
        SET 
            [Created by] = uc.full_name, 
            [Updated by] = uu.full_name, 
            [Agent name] = agent.full_name
        FROM #data_sq_dash_current_fy d
            LEFT JOIN [dbo].[user] uc ON uc.id = d.[Created by ID]
            LEFT JOIN dbo.[user] uu ON uu.id = d.[Updated by ID]
            LEFT JOIN dbo.[user] agent ON agent.id = d.[Agent ID];

        ALTER TABLE #data_sq_dash_current_fy DROP COLUMN [Created by ID];
        ALTER TABLE #data_sq_dash_current_fy DROP COLUMN [Updated by ID];
        ALTER TABLE #data_sq_dash_current_fy DROP COLUMN [Agent ID];
		
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] User names updated');

        --update request types
        /*
        For detecting request type creating 4 different dataset and use table variable (dbo.idTable)
        Avoiding  use sq.getRequestType function
        */
        -- New (Modules only)
        DECLARE @dataRequestTypeMOD dbo.idTable;
        INSERT INTO @dataRequestTypeMOD(id)									
					select r.id from sq.request r
					left join sq.request_module sm on r.id = sm.request_id
					left join sq.coc_process coc on coc.id = r.coc_process_id
					where (sm.module_id in (4,5,9) and
					(coc.available = 1 or coc.available is null and r.fss_wave like '%PEGA%') and r.type = 1 or r.not_considered_request_type_calculation = 1);

        -- New (CoC+Modules)
        DECLARE @dataRequestTypeCOCMOD dbo.idTable;
        INSERT INTO @dataRequestTypeCOCMOD(id)
                    select r.id from sq.request r
					left join sq.request_module sm on r.id = sm.request_id where sm.module_id in (4,5,9) and r.type = 1;

        -- New (Coc Only)
        DECLARE @dataRequestTypeCOC dbo.idTable;
        INSERT INTO @dataRequestTypeCOC(id)
					select r.id from sq.request r
					left join sq.request_module sm on r.id = sm.request_id 
					left join sq.coc_process coc on coc.id = r.coc_process_id
					where (sm.module_id not in (4,5,9) or sm.module_id is null) and r.type = 1 and (coc.available <> 1 or coc.available is null);

        -- Check
        DECLARE @dataRequestTypeCHK dbo.idTable;
        INSERT INTO @dataRequestTypeCHK(id)										
					select r.id from sq.request r
					left join sq.request_module sm on r.id = sm.request_id
					left join sq.coc_process coc on coc.id = r.coc_process_id
					where sm.module_id is null and 
					(coc.available = 1) and r.type = 1;

        /*
        End of preparation (avoiding getRequestType function)
        */


        UPDATE dataset
        SET 
            [Request Type] =
                        CASE
                        WHEN EXISTS
                            (
                                    SELECT d.id
                                    FROM @dataRequestTypeMOD AS d
                                    WHERE d.id = dataset.[Record ID]
                            )
                                               THEN 'New (Modules only)'
                                               WHEN EXISTS
                            (
                                    SELECT d.id
                                    FROM @dataRequestTypeCOCMOD AS d
                                    WHERE d.id = dataset.[Record ID]
                            )
                                               THEN 'New (CoC+Modules)'
                                               WHEN EXISTS
                            (
                                    SELECT d.id
                                    FROM @dataRequestTypeCOC AS d
                                    WHERE d.id = dataset.[Record ID]
                            )
                                               THEN 'New (Coc Only)'
                                               WHEN EXISTS
                            (
                                    SELECT d.id
                                    FROM @dataRequestTypeCHK AS d
                                    WHERE d.id = dataset.[Record ID]
                            )
                        THEN 'Check'
                        WHEN dataset.[rectype] = 2
                        THEN 'Renewal'
                        WHEN dataset.[rectype] = 3
                        THEN 'Check'
                        WHEN dataset.[rectype] = 4
                        THEN 'Hardcopy'
                        WHEN dataset.[rectype] = 5
                        THEN 'Referencing'
						WHEN dataset.[rectype] = 6
                        THEN 'User Support'
                        ELSE ''
                    END 
        FROM #data_sq_dash_current_fy AS dataset;

        ALTER TABLE #data_sq_dash_current_fy DROP COLUMN [rectype];

        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] request types updated');

        -- update dates
        UPDATE #data_sq_dash_current_fy SET 
            [Finished Year & Month]                 = concat(YEAR([Finished Date]), '-', FORMAT([Finished Date], 'MM')),
            [Fiscal Year Input Received]            = dbo.[_get_fiscal_year_from_date]([Input Received]),
            [Month Name Input Received]             = dbo.[_getMonthName]([Input Received]),
            [Fiscal Year]                           = CASE
                                                        WHEN LEN([Spillover FY]) > 1
                                                        THEN [Spillover FY]
                                                        ELSE dbo.[_get_fiscal_year_from_date]([Input Received])
                                                    END,
            [Fiscal Year Record Finished]           = dbo.[_get_fiscal_year_from_date]([Finished Date]),
            [Fiscal Month Record Finished]          = dbo.[_get_fiscal_month_from_date]([Finished Date]),  					
            [Month Name Record Finished]            = dbo.[_getMonthName]([Finished Date]),
            [Fiscal Year and Month Record Finished] = CASE
                                                        WHEN dbo.[_get_fiscal_year_from_date]([Finished Date]) IS NULL
                                                        THEN NULL
                                                        ELSE concat('FY', RIGHT(dbo.[_get_fiscal_year_from_date]([Finished Date]), 2), ' - ', dbo.[_get_fiscal_month_from_date]([Finished Date]), ' - ', dbo._getMonthName([Finished Date]))
                                                    END;

        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] dates updated');

        -- update record duplicates
        WITH cte
             AS (SELECT [Record ID], 
                        [Doubles], 
                        ROW_NUMBER() OVER(PARTITION BY [Record ID]
                        ORDER BY [Record ID] DESC) RN
                FROM #data_sq_dash_current_fy)
            UPDATE cte
            SET 
                [Doubles] = CASE
                                WHEN RN = 1
                                THEN 0
                                ELSE 1
                            END;

        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] update record duplicates DONE');

        -- update escalation duplicates
        WITH cte
            AS (SELECT [Record ID], 
                        [Escalation ID], 
                        [Escalation Sent Date], 
                        [Doubles Check Escalation], 
                        ROW_NUMBER() OVER(PARTITION BY [Record ID], 
                                                       [Escalation ID]
                        ORDER BY [Record ID], 
                                [Escalation ID], 
                                [Escalation Sent Date] DESC) RN
                FROM #data_sq_dash_current_fy)
            UPDATE cte
              SET 
                    [Doubles Check Escalation] = CASE
                                                    WHEN RN = 1
                                                    THEN 0
                                                    ELSE 1
                                                END;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] update escalation duplicates DONE');

        -- insert default Supplier Contacts
        UPDATE ucs
        SET 
            ucs.[Supplier Contact Title] = t1.[Supplier Contact Title], 
            ucs.[Supplier Contact First Name] = t1.[Supplier Contact First Name], 
            ucs.[Supplier Contact Last Name] = t1.[Supplier Contact Last Name], 
            ucs.[Supplier Contact Email] = t1.[Supplier Contact Email], 
            ucs.[Supplier Contact Phone] = t1.[Supplier Contact Phone]
        FROM #data_sq_dash_current_fy ucs
            LEFT JOIN
            -- ----------------
            -- table with all contacts sorted  by default contacts first
            (
                SELECT TOP 100 PERCENT r.id AS [record_id], 
                                       con.title AS [Supplier Contact Title], 
                                       con.first_name AS [Supplier Contact First Name], 
                                       con.last_name AS [Supplier Contact Last Name], 
                                       con.email AS [Supplier Contact Email], 
                                       con.phone AS [Supplier Contact Phone], 
                                       current_c
                FROM sq.request r
                     LEFT JOIN sq.contact con ON r.id = con.request_id
                     LEFT JOIN sq.contact_category ccc ON con.category_id = ccc.id
                     LEFT JOIN -- find default contact id per record subtable
                (
                    SELECT DISTINCT
                           (request_id), 
                           contact_id, 
                           1 AS current_c
                    FROM sq.request_contact
                    WHERE current_contact = 1
                --group by request_id, contact_id
                ) t1 ON r.id = t1.request_id
                        AND con.id = t1.contact_id
                WHERE con.type = 'supplier' AND (con.is_cc_email is null OR con.is_cc_email = 0)
                      AND current_c = 1
                ORDER BY r.id, 
                         current_c DESC
            ) t1
            -- -----------------
            ON ucs.[Record ID] = t1.record_id AND [Doubles] IN(0, 1);
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] insert default Supplier Contacts DONE');

        -- insert default Siemens Contacts
        UPDATE ucs
            SET 
                ucs.[Siemens Contact Title] = t1.[Siemens Contact Title], 
                ucs.[Siemens Contact First Name] = t1.[Siemens Contact First Name], 
                ucs.[Siemens Contact Last Name] = t1.[Siemens Contact Last Name], 
                ucs.[Siemens Contact Email] = t1.[Siemens Contact Email], 
                ucs.[Siemens Contact Phone] = t1.[Siemens Contact Phone],
				ucs.[Siemens Contact Country] = t1.[Siemens Contact Country]
        FROM #data_sq_dash_current_fy ucs
            LEFT JOIN
            -- ----------------
            -- table with all contacts sorted  by default contacts first
            (
                SELECT TOP 100 PERCENT r.id AS [record_id], 
                                       con.title AS [Siemens Contact Title], 
                                       con.first_name AS [Siemens Contact First Name], 
                                       con.last_name AS [Siemens Contact Last Name], 
                                       con.email AS [Siemens Contact Email], 
                                       con.phone AS [Siemens Contact Phone], 
									   country.title AS [Siemens Contact Country],
                                       current_c
                FROM sq.request r
                     LEFT JOIN sq.contact con ON r.id = con.request_id
                     LEFT JOIN sq.contact_category ccc ON con.category_id = ccc.id
					 LEFT JOIN flatfile.country country ON country.short_title = con.country
                     LEFT JOIN -- find default contact id per record subtable
                (
                    SELECT DISTINCT
                           (request_id), 
                           contact_id, 
                           1 AS current_c
                    FROM sq.request_contact
                    WHERE current_contact = 1
                --group by request_id, contact_id
                ) t1 ON r.id = t1.request_id
                        AND con.id = t1.contact_id
                WHERE con.type = 'siemens' AND con.category_id = 1
                      AND current_c = 1
                ORDER BY r.id, 
                         current_c DESC
            ) t1
            -- -----------------
            ON ucs.[Record ID] = t1.record_id AND [Doubles] IN(0, 1);

        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] insert default Siemens Contacts DONE');

        -- update count requested and finished modules
        UPDATE d
        SET 
            [Count Requested Modules] = rm.[Requested modules], 
            [Count Finished Modules] = rm.[Finished modules], 
            [Productivity Points] = rm.[Sum Productivity points]
        FROM #data_sq_dash_current_fy d
             LEFT JOIN
        (
            SELECT req.id AS request_id, 
                   COUNT(DISTINCT srm.module_id) AS [Requested modules], 
                   COUNT(DISTINCT CASE
                                      WHEN(is_already_done = 2
                                           AND sqq.finished IS NOT NULL)
                                      THEN srm.module_id
                                      ELSE NULL
                                  END) AS [Finished modules]
                   ,
                   -- check always 0.5 point
                   CASE 
                                          -- request type check always 0.5 point
                       WHEN req.type = 3
                            AND req.status_id IN(4, 5)
                       THEN 0.5

            -- request type referencing always 0.5 point
                       WHEN req.type = 5
                            AND req.status_id IN(4, 5)
                       THEN 0.5 
            -- For Status finished ----------------------------------------
                       WHEN req.status_id = 4
                       THEN SUM(
                            -- COC 1 point
                            CASE 
                            -- New CoC qualification process
                                WHEN coc.available = 0
                                     AND coc.finished IS NOT NULL
                                     AND srm.[unique] = 1
                                THEN 1 
                            -- Old CoC qualification process
                                WHEN is_already_done = 2
                                     AND sqq.finished IS NOT NULL
                                     AND srm.module_id = 1
                                THEN 1
                                ELSE 0
                            END)
                            -- CRSA 1-2 point (for hardcopy)
                            + SUM(CASE
                                      WHEN is_already_done = 2
                                           AND sqq.finished IS NOT NULL
                                           AND srm.module_id = 4
                                           AND req.type IN(1, 2)
                                      THEN 1
                                      WHEN is_already_done = 2
                                           AND sqq.finished IS NOT NULL
                                           AND srm.module_id = 4
                                           AND req.type IN(4)
                                      THEN 2
                                      ELSE 0
                                  END)
        -- CRSA CAP
        + SUM(CASE
                  WHEN cap_needed = 1
                       AND cap_finished IS NOT NULL
                  THEN 1
                  ELSE 0
              END)
        -- SC 1-2 point (for hardcopy)
        + SUM(CASE
                  WHEN is_already_done = 2
                       AND sqq.finished IS NOT NULL
                       AND srm.module_id = 5
                       AND req.type IN(1, 2)
                  THEN 1
                  WHEN is_already_done = 2
                       AND sqq.finished IS NOT NULL
                       AND srm.module_id = 5
                       AND req.type IN(1, 4)
                  THEN 2
                  ELSE 0
              END)
        -- CS 1 point
        + SUM(CASE
                  WHEN is_already_done = 2
                       AND sqq.finished IS NOT NULL
                       AND srm.module_id = 9
                  THEN 1
                  ELSE 0
              END)

        -- For Status finished not qualified ----------------------------------------------
                       WHEN req.status_id = 5
                       THEN SUM(
                            -- coc 1 point if not done by pega (no matter wheter successfully finished or not)
                            CASE
                                WHEN coc.available = 1
                                     AND srm.[unique] = 1
                                THEN 0
                                WHEN(coc.available = 0
                                     OR coc.available IS NULL)
                                    AND srm.[unique] = 1
                                THEN 1
                            END)
                            -- CRSA 1 point if done in qualification step
                            + SUM(CASE
                                      WHEN qp.finished_not_qualified = 1
                                           AND srm.module_id = 4
                                      THEN 1
                                      ELSE 0
                                  END)
                            -- CRSA CAP  1 point if needed and record finished in qual step
                            + SUM(CASE
                                      WHEN qp.finished_not_qualified = 1
                                           AND srm.module_id = 4
                                           AND cap_needed = 1
                                      THEN 1
                                      ELSE 0
                                  END)
                            -- SC 1  point if done in qualification step
                            + SUM(CASE
                                      WHEN qp.finished_not_qualified = 1
                                           AND srm.module_id = 5
                                      THEN 1
                                      ELSE 0
                                  END)
                            -- cs 1 point
                            + SUM(CASE
                                      WHEN qp.finished_not_qualified = 1
                                           AND srm.module_id = 9
                                      THEN 1
                                      ELSE 0
                                  END)
                   END AS [Sum Productivity points]
            FROM sq.request req
                 LEFT JOIN
            (
                SELECT *, 
                       ROW_NUMBER() OVER(PARTITION BY [record id]
                       ORDER BY module_id DESC) AS [unique]
                FROM
                (
                    SELECT DISTINCT 
                           id AS [record id]
                    FROM sq.request
                ) sub
                LEFT JOIN sq.request_module ssrm ON ssrm.request_id = sub.[record id]
            ) srm ON srm.[record id] = req.id
                 LEFT JOIN sq.qualification sqq ON sqq.qualification_process_id = req.qualification_process_id
                                                   AND sqq.module_id = srm.module_id
                 LEFT JOIN sq.qualification_process qp ON req.qualification_process_id = qp.id
                 LEFT JOIN sq.coc_process coc ON req.coc_process_id = coc.id
                 LEFT JOIN sq.module m ON m.id = srm.module_id
                 LEFT JOIN sq.STATUS ss ON ss.id = req.status_id
            GROUP BY req.id, 
                     req.type, 
                     req.status_id
        ) rm ON d.[record id] = rm.request_id
                AND d.Doubles = 0
        WHERE rm.request_id IS NOT NULL
              AND d.STATUS != 'Out of scope';
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] update count requested and finished modules DONE');
        UPDATE d
          SET 
              [CoC-old Requested] = 'Yes'
        FROM #data_sq_dash_current_fy d
             LEFT JOIN sq.request_module sm ON d.[Record ID] = sm.request_id
        WHERE sm.module_id = 1;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] CoC-old Requested update DONE');
        UPDATE d
          SET 
              [CRSA Requested] = 'Yes'
        FROM #data_sq_dash_current_fy d
             LEFT JOIN sq.request_module sm ON d.[Record ID] = sm.request_id
        WHERE sm.module_id = 4;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] CRSA Requested update DONE');
        UPDATE d
          SET 
              [SC Requested] = 'Yes'
        FROM #data_sq_dash_current_fy d
             LEFT JOIN sq.request_module sm ON d.[Record ID] = sm.request_id
        WHERE sm.module_id = 5;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] SC Requested update DONE');
        UPDATE d
          SET 
              [CS Requested] = 'Yes'
        FROM #data_sq_dash_current_fy d
             LEFT JOIN sq.request_module sm ON d.[Record ID] = sm.request_id
        WHERE sm.module_id = 9;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] CS Requested update DONE');



        -- update Price
        UPDATE d
          SET 
              [Price in Eur] = CASE 
                               -- for Data clarification
                                   WHEN STATUS = 'out of scope'
                                   THEN 0
                                   WHEN price.[Price in Eur] IS NOT NULL
                                   THEN price.[Price in Eur]
                                   ELSE NULL
                               END
        FROM #data_sq_dash_current_fy d
             LEFT JOIN
        (
            SELECT [kt].[valid_from] AS [valid from], 
                   [kt].[valid_to] AS [valid to], 
                   dc.name AS [Delivery Center],
                   CASE
                       WHEN kn.name = 'Number of finished Supplier Qualifications (New CoC + Modules)'
                       THEN 'New (CoC+Modules)'
                       WHEN kn.name = 'Number of finished Supplier Qualifications (New CoC only)'
                       THEN 'New (Coc Only)'
                       WHEN kn.name = 'Number of finished Supplier Qualifications (New Modules only)'
                       THEN 'New (Modules only)'
                       WHEN kn.name = 'Number of finished Supplier Qualifications (Check)'
                       THEN 'Check'
                       WHEN kn.name = 'Number of finished Supplier Qualifications (Renewal)'
                       THEN 'Renewal'
                       WHEN kn.name = 'Number of finished Supplier Qualifications (Hard Copy)'
                       THEN 'Hardcopy'
                       WHEN kn.name = 'Number of finished Supplier Qualifications (Referencing)'
                       THEN 'Referencing'
                       ELSE NULL
                   END AS [Request Type], 
                   kn.name AS [kpi name], 
                   COALESCE(ktcc.id, c.id) AS [customer id], 
                   COALESCE(ktcc.name, c.name) AS [customer name], 
                   kt.price AS [Price in Eur], 
                   kt.fiscal_year_target AS [Fiscal Year Target]
            FROM [indigo].[kpi_threshold] [kt]
                 LEFT JOIN [indigo].[kpi] [k] ON kt.kpi_id = k.id
                 INNER JOIN [indigo].[team] [t] ON t.id = k.team_id
                 LEFT JOIN flatfile.dc dc ON dc.id = t.dc_id
                 INNER JOIN [indigo].[service] [s] ON s.id = k.service_id
                 INNER JOIN [indigo].[service_name] [sn] ON sn.id = s.service_name_id
                 INNER JOIN [indigo].[team_customer] [tc] ON tc.id = s.team_customer_id
                 INNER JOIN [indigo].[customer] [c] ON tc.customer_id = c.id
                                                       AND c.parent_id IS NULL
                 INNER JOIN [indigo].[kpi_name] [kn] ON k.kpi_name_id = kn.id
                 LEFT JOIN [indigo].[customer] [ktcc] ON ktcc.id = kt.customer_id
                 LEFT JOIN indigo.kpi_tag tag ON tag.kpi_name_id = kn.id
            WHERE sn.name like 'Supplier Qualification%'
                  AND tag.tag_id = 1
                  AND (kt.price IS NOT NULL
                       OR kt.fiscal_year_target IS NOT NULL)
                  AND kt.charging_type = 0

            --adding prices for modules only for FY2018 
            UNION ALL
            SELECT [kt].[valid_from] AS [valid from], 
                   [kt].[valid_to] AS [valid to], 
                   dc.name AS [Delivery Center], 
                   'New (Modules only)' AS [Request Type], 
                   kn.name AS [kpi name], 
                   COALESCE(ktcc.id, c.id) AS [customer id], 
                   COALESCE(ktcc.name, c.name) AS [customer name], 
                   kt.price AS [Price in Eur], 
                   kt.fiscal_year_target AS [Fiscal Year Target]
            FROM [indigo].[kpi_threshold] [kt]
                 LEFT JOIN [indigo].[kpi] [k] ON kt.kpi_id = k.id
                 INNER JOIN [indigo].[team] [t] ON t.id = k.team_id
                 LEFT JOIN flatfile.dc dc ON dc.id = t.dc_id
                 INNER JOIN [indigo].[service] [s] ON s.id = k.service_id
                 INNER JOIN [indigo].[service_name] [sn] ON sn.id = s.service_name_id
                 INNER JOIN [indigo].[team_customer] [tc] ON tc.id = s.team_customer_id
                 INNER JOIN [indigo].[customer] [c] ON tc.customer_id = c.id
                                                       AND c.parent_id IS NULL
                 INNER JOIN [indigo].[kpi_name] [kn] ON k.kpi_name_id = kn.id
                 LEFT JOIN [indigo].[customer] [ktcc] ON ktcc.id = kt.customer_id
                 LEFT JOIN indigo.kpi_tag tag ON tag.kpi_name_id = kn.id
            WHERE sn.name like 'Supplier Qualification%'
                  AND kn.name = 'Number of finished Supplier Qualifications (New CoC + Modules)'
                  AND [kt].[valid_to] = '20180900'
                  AND tag.tag_id = 1
                  AND (kt.price IS NOT NULL
                       OR kt.fiscal_year_target IS NOT NULL)
                  AND kt.charging_type = 0
        ) price ON d.[Delivery Center] = price.[Delivery center]
                   AND d.[Customer ID] = price.[Customer ID]
                   AND price.[Request Type] = d.[Request Type]
                   AND [indigo].[is_valid_period](price.[valid from], CONVERT(VARCHAR, concat(LEFT(price.[valid to], 6), '31'), 112), CONVERT(VARCHAR(8), COALESCE(d.[Finished Date], GETDATE()), 112)) = 1;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] price update DONE');

        -- create target table

        IF OBJECT_ID('dash2.consolidated_sq_targets', 'U') IS NOT NULL
            DROP TABLE dash2.consolidated_sq_targets;
        SELECT [indigo].[get_fiscal_year_from_period]([kt].[valid_from]) AS [fiscal year], 
               dc.name AS [Delivery Center],
               CASE
                   WHEN gc.customer_id IS NOT NULL
                   THEN 'Global'
                   ELSE 'local'
               END AS 'Customer type',
               CASE
                   WHEN kn.name = 'Number of finished Supplier Qualifications (New CoC + Modules)'
                   THEN 'New (CoC+Modules)'
                   WHEN kn.name = 'Number of finished Supplier Qualifications (New CoC only)'
                   THEN 'New (Coc Only)'
                   WHEN kn.name = 'Number of finished Supplier Qualifications (New Modules only)'
                   THEN 'New (Modules only)'
                   WHEN kn.name = 'Number of finished Supplier Qualifications (Check)'
                   THEN 'Check'
                   WHEN kn.name = 'Number of finished Supplier Qualifications (Renewal)'
                   THEN 'Renewal'
                   WHEN kn.name = 'Number of finished Supplier Qualifications (Hard Copy)'
                   THEN 'Hardcopy'
                   WHEN kn.name = 'Number of finished Supplier Qualifications (Referencing)'
                   THEN 'Referencing'
                   ELSE NULL
               END AS [Request Type], 
               kn.name AS [kpi name], 
               COALESCE(ktcc.id, c.id) AS [customer id], 
               COALESCE(ktcc.name, c.name) AS [customer name], 
               COALESCE(bu.name, 'Not Applicable') AS Division, 
               div.name AS [Business Unit], 
               ct.title AS [Customer Country], 
               kt.fiscal_year_target AS [Fiscal Year Target], 
               kt.budget_total AS [Fiscal Year Budget], 
               MIN(kt.price) AS [Price in Eur]
        INTO dash2.consolidated_sq_targets
        FROM [indigo].[kpi_threshold] [kt]
             LEFT JOIN [indigo].[kpi] [k] ON kt.kpi_id = k.id
             INNER JOIN [indigo].[team] [t] ON t.id = k.team_id
             LEFT JOIN flatfile.dc dc ON dc.id = t.dc_id
             INNER JOIN [indigo].[service] [s] ON s.id = k.service_id
             INNER JOIN [indigo].[service_name] [sn] ON sn.id = s.service_name_id
             INNER JOIN [indigo].[team_customer] [tc] ON tc.id = s.team_customer_id
             INNER JOIN [indigo].[customer] [c] ON tc.customer_id = c.id
                                                   AND c.parent_id IS NULL
             INNER JOIN [indigo].[kpi_name] [kn] ON k.kpi_name_id = kn.id
             LEFT JOIN [indigo].[customer] [ktcc] ON ktcc.id = kt.customer_id
             LEFT JOIN indigo.kpi_tag tag ON tag.kpi_name_id = kn.id
             LEFT JOIN
        (
            SELECT DISTINCT 
                   customer_id
            FROM sq.global_customer
            WHERE is_global_customer = 1
        ) gc ON ktcc.id = gc.customer_id
             LEFT JOIN flatfile.business_unit bu ON ktcc.business_unit_id = bu.id
             LEFT JOIN flatfile.division div ON ktcc.division_id = div.id
             LEFT JOIN flatfile.country ct ON ktcc.country_id = ct.id
        WHERE sn.name like 'Supplier Qualification%'
              AND tag.tag_id = 1
              AND (kt.price IS NOT NULL
                   OR kt.fiscal_year_target IS NOT NULL)
              AND kt.charging_type = 0
        GROUP BY [indigo].[get_fiscal_year_from_period]([kt].[valid_from]), 
                 dc.name, 
                 kn.name, 
                 gc.customer_id, 
                 COALESCE(ktcc.id, c.id), 
                 COALESCE(ktcc.name, c.name), 
                 kt.fiscal_year_target, 
                 kt.budget_total, 
                 COALESCE(bu.name, 'Not Applicable'), 
                 div.name, 
                 ct.title;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] create target table DONE');

        -- update current step & step time threshold
        UPDATE d
          SET 
              [Current Step] = CASE 
                               -- for Data clarification
                                   WHEN STATUS = 'Not started'
                                   THEN 'a) Not Started'
                                   WHEN STATUS = 'Finished'
                                   THEN 'f) Finished'
                                   WHEN STATUS = 'Finished not qualified'
                                   THEN 'g) Finished not qualified'
                                   WHEN STATUS = 'Out of scope'
                                   THEN 'h) Out of scope'
                                   WHEN [Escalation Tab] = 'Data Clarification'
                                        AND [Escalation Solved Date] IS NULL
                                   THEN 'b) Data clarification'
                                   WHEN [Current Step Temp] = 'CoC Acceptance'
                                   THEN 'c) CoC Acceptance'
                                   WHEN [Current Step Temp] = 'Qualification'
                                   THEN 'd) Qualification'
                                   WHEN [Current Step Temp] = 'Finalization'
                                   THEN 'e) Finalization'
                                   ELSE NULL
                               END
        FROM #data_sq_dash_current_fy d;
        UPDATE d
          SET 
              [Current Step Time Threshold] = CASE 
                                              -- for Data clarification
                                                  WHEN [Current Step Temp] = 'Data clarification'
                                                       AND [Current Step Time] <= 15
                                                  THEN 'a) < 3 weeks'
                                                  WHEN [Current Step Temp] = 'Data clarification'
                                                       AND [Current Step Time] > 15
                                                  THEN 'c) > 3 weeks'
                                              -- for Registration
                                              /*not needed or specified*/

                                              -- CoC Acceptance
                                                  WHEN [Current Step Temp] = 'CoC Acceptance'
                                                       AND [Current Step Time] <= 10
                                                  THEN 'a) < 2 weeks'
                                                  WHEN [Current Step Temp] = 'CoC Acceptance'
                                                       AND [Current Step Time] <= 20
                                                  THEN 'b) < 2-4 weeks'
                                                  WHEN [Current Step Temp] = 'CoC Acceptance'
                                                       AND [Current Step Time] > 20
                                                  THEN 'c) > 3 weeks'
                                              -- for Qualification
                                                  WHEN [Current Step Temp] = 'Qualification'
                                                       AND [Current Step Time] <= 15
                                                  THEN 'a) < 3 weeks '
                                                  WHEN [Current Step Temp] = 'Qualification'
                                                       AND [Current Step Time] <= 25
                                                  THEN 'b) 3-5 weeks'
                                                  WHEN [Current Step Temp] = 'Qualification'
                                                       AND [Current Step Time] > 25
                                                  THEN 'c) > 5 weeks'
                                              -- for Finalization
                                                  WHEN [Current Step Temp] = 'Finalization'
                                                       AND [Current Step Time] <= 5
                                                  THEN 'a) < 1 week'
                                                  WHEN [Current Step Temp] = 'Finalization'
                                                       AND [Current Step Time] > 5
                                                  THEN 'b) > 1 week'
                                                  ELSE NULL
                                              END
        FROM #data_sq_dash_current_fy d;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] update current step & step time threshold DONE');

        -- ageing time
        UPDATE d
          SET 
              [Ageing Time] = CASE 
                              -- for Data clarification
                                  WHEN [status] = 'not started'
                                  THEN [flatfile].[Workingdays3]([Input Received], GETDATE())
                                  WHEN [status] IN('in process', 'escalated')
                                  THEN [flatfile].[Workingdays3]([Start Date], GETDATE())
                                  ELSE NULL
                              END
        FROM #data_sq_dash_current_fy d
        WHERE [status] IN('not started', 'in process', 'escalated');
        UPDATE d
          SET 
              [Ageing Time Threshold] = CASE 
                                        -- for Data clarification
                                            WHEN [Ageing Time] IS NULL
                                            THEN '0) missing data'
                                            WHEN [Ageing Time] <= 5
                                            THEN 'a) less 1 weeks'
                                            WHEN [Ageing Time] <= 10
                                            THEN 'b) 1 - 2 weeks'
                                            WHEN [Ageing Time] <= 20
                                            THEN 'c) 2 - 4 weeks'
                                            WHEN [Ageing Time] <= 40
                                            THEN 'd) 4 - 8 weeks'
                                            WHEN [Ageing Time] > 40
                                            THEN 'e) more then 8 weeks'
                                        END
        FROM #data_sq_dash_current_fy d
        WHERE [status] IN('not started', 'in process', 'escalated');
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] ageing time DONE');

        -- update backlog step and time

        UPDATE d
          SET 
              [Backlog Step] = CASE 
                               -- for Data clarification
                                   WHEN STATUS IN('Finished', 'Finished not qualified', 'Out of scope')
                                   THEN NULL
                                   WHEN STATUS = 'Not started'
                                   THEN 'a) Not Started'
                                   WHEN dc.[Record ID] IS NOT NULL
                                   THEN 'b) Data Clarification Escalated'
                                   WHEN [Current Step Temp] = 'CoC Acceptancee'
                                        AND STATUS = 'In Process'
                                   THEN 'c) CoC'
                                   WHEN [Current Step Temp] = 'CoC Acceptance'
                                        AND STATUS = 'Escalated'
                                   THEN 'd) CoC Escalated'
                                   WHEN [Current Step Temp] = 'Qualification'
                                        AND STATUS = 'In Process'
                                   THEN 'e) Qualfication (CRCA SC CS)'
                                   WHEN [Current Step Temp] = 'Qualification'
                                        AND STATUS = 'Escalated'
                                   THEN 'f) Qualfication Escalated (CRCA SC CS)'
                                   WHEN [Current Step Temp] = 'Finalization'
                                   THEN 'g) Finalization'
                                   ELSE NULL
                               END
        FROM #data_sq_dash_current_fy d
             LEFT JOIN
        (
            SELECT [Record ID]
            FROM #data_sq_dash_current_fy d
            WHERE [Escalation Tab] = 'Data Clarification'
                  AND [Escalation Solved Date] IS NULL
        ) dc ON d.[Record ID] = dc.[Record ID];
        UPDATE d
          SET 
              [Backlog Step Time] = CASE 
                                    -- for Data clarification
                                        WHEN [Backlog Step] = 'a) Not Started'
                                        THEN [Ageing Time]
                                        WHEN [Backlog Step] = 'b) Data Clarification Escalated'
                                        THEN [sq].[getDataClarificationBacklogTime]([Record ID])
                                        WHEN [Backlog Step] IN('c) CoC', 'd) CoC Escalated')
                                        THEN [sq].[getCocBacklogTime]([Record ID])
                                        WHEN [Backlog Step] IN('e) Qualfication (CRCA SC CS)', 'f) Qualfication Escalated (CRCA SC CS)')
                                        THEN [sq].[getQualificationBacklogTime]([Record ID])
                                        WHEN [Backlog Step] IN('g) Finalization')
                                        THEN [sq].[getFinalizationBacklogTime]([Record ID])
                                        ELSE NULL
                                    END
        FROM #data_sq_dash_current_fy d
        WHERE [Backlog Step] IS NOT NULL;
        UPDATE d
          SET 
              [Backlog Step Time Threshold] = CASE 
                                              -- for Data clarification
                                                  WHEN [Backlog Step Time] IS NULL
                                                  THEN '0) missing data'
                                                  WHEN [Backlog Step Time] <= 5
                                                  THEN 'a) less 1 weeks'
                                                  WHEN [Backlog Step Time] <= 10
                                                  THEN 'b) 1 - 2 weeks'
                                                  WHEN [Backlog Step Time] <= 20
                                                  THEN 'c) 2 - 4 weeks'
                                                  WHEN [Backlog Step Time] <= 40
                                                  THEN 'd) 4 - 8 weeks'
                                                  WHEN [Backlog Step Time] > 40
                                                  THEN 'e) more then 8 weeks'
                                                  ELSE NULL
                                              END
        FROM #data_sq_dash_current_fy d
        WHERE [Backlog Step] IS NOT NULL;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] Backlog Step update DONE');

        -- update comments
        UPDATE d
          SET 
              [Comment History] = t1.[Comment History]
        FROM #data_sq_dash_current_fy d
             LEFT JOIN
        (
            SELECT request_id, 
                   STUFF(
            (
                SELECT ' ;; ' + SUBSTRING(CONVERT(VARCHAR, created_at, 120), 1, 16) + ' - ' + sm.name + ' - ', 
                       CAST(text AS NVARCHAR(MAX)) + CHAR(10)
                FROM sq.comment US
                     LEFT JOIN sq.step sm ON sm.id = us.step_id
                WHERE ss.request_id = US.request_id
                ORDER BY created_at DESC FOR XML PATH('')
            ), 1, 4, '') [Comment History]
            FROM sq.comment SS
            GROUP BY SS.request_id
        ) t1 ON d.[record id] = t1.request_id
                AND d.Doubles = 0;
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] update comments DONE');

        -- temp table in normal table
        IF OBJECT_ID('dash2.data_sq_dash_current_fy', 'U') IS NOT NULL
            DROP TABLE dash2.data_sq_dash_current_fy;
        ALTER TABLE #data_sq_dash_current_fy DROP COLUMN [Customer ID];
        ALTER TABLE #data_sq_dash_current_fy DROP COLUMN [Current Step Temp];
        SELECT *
        INTO dash2.data_sq_dash_current_fy
        FROM #data_sq_dash_current_fy ORDER BY [Record ID];
        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] result table  DONE');

        PRINT('[' + CAST(FORMAT(GETDATE(), 'HH:mm:ss') AS VARCHAR) + '] export_data procedure END');


		--output table create time (used for SQL agent job log)
		DECLARE @table_create_date DATETIME;
		SELECT @table_create_date = create_date FROM sys.tables WHERE [name] = 'data_sq_dash_current_fy'
		PRINT('TABLE CREATE DATE #' +  CAST(FORMAT(@table_create_date, 'yyyy-MM-dd_HH-mm') AS VARCHAR) + '#');


    END;


--	exec sq.export_data -- 01:20



--	select updated_at from sq.request where updated_at >= DATEADD(HOUR, -30, @TopOfHour) and updated_at < DATEADD(HOUR, -1, @TopOfHour) order by updated_at desc;





