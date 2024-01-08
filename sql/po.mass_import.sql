CREATE PROCEDURE [po].[mass_import]
(
    @createdBy INT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @period VARCHAR(255);
    SELECT TOP 1 @period = period FROM po.record_temp;

    INSERT INTO po.request (po_number, category_id, period, q_type, status_id, created_at, created_by)
    SELECT TOP 10 PERCENT
        po_number,
        category_id,
        @period,
        'team' AS q_type,
        1 AS status_id,
        GETDATE() AS created_at,
        @createdBy AS created_by
    FROM
        po.record
    WHERE
        period = @period
        AND team_id NOT IN (
            SELECT team_id
            FROM po.record
            GROUP BY team_id, period
            HAVING period = @period AND COUNT(po_number) >= 500
        )
        AND po_number NOT IN (SELECT po_number FROM po.request)
        AND team_id IN (SELECT team_id FROM po.record GROUP BY team_id)
    ORDER BY NEWID();

    DECLARE @teamID INT;
    DECLARE team_cursor CURSOR FOR
        SELECT DISTINCT team_id
        FROM po.record
        WHERE period = @period;

    OPEN team_cursor;

    FETCH NEXT FROM team_cursor INTO @teamID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Customers
        INSERT INTO po.request (po_number, category_id, period, q_type, status_id, created_at, created_by)
        SELECT TOP 1
            po_number,
            category_id,
            @period,
            'team' AS q_type,
            1 AS status_id,
            GETDATE() AS created_at,
            @createdBy AS created_by
        FROM
            po.record
        WHERE
            period = @period
            AND team_id = @teamID
            AND team_id NOT IN (
                SELECT team_id
                FROM po.record
                GROUP BY team_id, period
                HAVING period = @period AND COUNT(po_number) < 500
            )
            AND po_number NOT IN (SELECT po_number FROM po.request)
            AND customer_id = (
                SELECT TOP 1 customer_id
                FROM po.record
                WHERE period = @period
                      AND team_id = @teamID
                ORDER BY NEWID()
            )
        ORDER BY NEWID();

        -- Users
        INSERT INTO po.request (po_number, category_id, period, q_type, status_id, created_at, created_by)
        SELECT TOP 1
            po_number,
            category_id,
            @period,
            'team' AS q_type,
            1 AS status_id,
            GETDATE() AS created_at,
            @createdBy AS created_by
        FROM
            po.record
        WHERE
            period = @period
            AND team_id = @teamID
            AND po_number NOT IN (SELECT po_number FROM po.request)
            AND po_created_by = (
                SELECT TOP 1 po_created_by
                FROM po.record
                WHERE period = @period
                      AND team_id = @teamID
                ORDER BY NEWID()
            )
        ORDER BY NEWID();

        FETCH NEXT FROM team_cursor INTO @teamID;
    END

    CLOSE team_cursor;
    DEALLOCATE team_cursor;
END;
