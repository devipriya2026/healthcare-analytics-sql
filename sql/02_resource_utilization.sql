/*
Healthcare Analytics - resource-utilization analysis

The source workbook does not provide a clean department-capacity table. The first
query therefore reports the share of encounter records marked "occupied". It must
not be described as a verified physical bed-capacity rate without additional data.
*/

SET NOCOUNT ON;

-- 1. Encounter records marked as occupied, by department.
SELECT
    detail.Dpt_ID,
    department.Department_Name,
    COUNT(*) AS encounter_records,
    SUM
    (
        CASE WHEN LOWER(LTRIM(RTRIM(detail.Bed))) = 'occupied' THEN 1 ELSE 0 END
    ) AS occupied_records,
    CAST
    (
        100.0 * SUM
        (
            CASE WHEN LOWER(LTRIM(RTRIM(detail.Bed))) = 'occupied' THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0)
        AS decimal(8, 2)
    ) AS occupied_record_percent
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
GROUP BY detail.Dpt_ID, department.Department_Name
ORDER BY occupied_record_percent DESC, detail.Dpt_ID;

-- 2. Distinct staff per encounter record and average rating, by department.
SELECT
    detail.Dpt_ID,
    department.Department_Name,
    COUNT(*) AS encounter_records,
    COUNT(DISTINCT detail.Staff_Id) AS distinct_staff,
    CAST
    (
        1.0 * COUNT(DISTINCT detail.Staff_Id) / NULLIF(COUNT(*), 0)
        AS decimal(10, 4)
    ) AS distinct_staff_per_encounter,
    AVG(TRY_CONVERT(decimal(18, 2), detail.Rating)) AS average_rating
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
GROUP BY detail.Dpt_ID, department.Department_Name
ORDER BY distinct_staff_per_encounter DESC, detail.Dpt_ID;

-- 3. Confirm how many bed IDs exist in the lookup and encounter tables.
SELECT
    (SELECT COUNT(DISTINCT Bed_ID) FROM dbo.Bed_Detail) AS bed_ids_in_lookup,
    (SELECT COUNT(DISTINCT Bed_ID) FROM dbo.Detail_Data_Dataset WHERE Bed_ID IS NOT NULL) AS bed_ids_in_encounters;
