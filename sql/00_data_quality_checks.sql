/*
Healthcare Analytics - data-quality checks

Run this script first in HospitalDB. It confirms table availability, department
coverage, field completeness, and the meaning of the encounter ID before analysis.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Detail_Data_Dataset', N'U') IS NULL
BEGIN
    ;THROW 50001, 'Missing dbo.Detail_Data_Dataset. Import the Detail data dataset sheet first.', 1;
END;

IF OBJECT_ID(N'dbo.Department', N'U') IS NULL
BEGIN
    ;THROW 50002, 'Missing dbo.Department. Import the Department sheet first.', 1;
END;

IF OBJECT_ID(N'dbo.Staff_Detail', N'U') IS NULL
BEGIN
    ;THROW 50003, 'Missing dbo.Staff_Detail. Import the Staff_Detail sheet first.', 1;
END;

IF OBJECT_ID(N'dbo.Bed_Detail', N'U') IS NULL
BEGIN
    ;THROW 50004, 'Missing dbo.Bed_Detail. Import the Bed_Detail sheet first.', 1;
END;

-- 1. Confirm encounter-row and department counts.
SELECT
    COUNT(*) AS encounter_row_count,
    COUNT(DISTINCT Dpt_ID) AS departments_in_encounter_data,
    COUNT(DISTINCT ID) AS distinct_id_count,
    COUNT(DISTINCT Name) AS distinct_name_count
FROM dbo.Detail_Data_Dataset;

SELECT
    COUNT(*) AS department_lookup_rows,
    COUNT(DISTINCT Dpt_ID) AS distinct_departments_in_lookup
FROM dbo.Department;

-- 2. List every department represented in the encounter data.
SELECT
    detail.Dpt_ID,
    department.Department_Name,
    COUNT(*) AS encounter_count
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
GROUP BY detail.Dpt_ID, department.Department_Name
ORDER BY detail.Dpt_ID;

-- 3. Detect encounter department IDs that are missing from the lookup table.
SELECT DISTINCT
    detail.Dpt_ID AS unmatched_department_id
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
WHERE department.Dpt_ID IS NULL
ORDER BY detail.Dpt_ID;

-- 4. Review the status values used for the readmission calculation.
SELECT
    [Status],
    COUNT(*) AS status_count
FROM dbo.Detail_Data_Dataset
GROUP BY [Status]
ORDER BY status_count DESC;

-- 5. Check key fields for missing or non-convertible values.
SELECT
    SUM(CASE WHEN Dpt_ID IS NULL THEN 1 ELSE 0 END) AS missing_department_id,
    SUM(CASE WHEN TRY_CONVERT(decimal(18, 2), LOS) IS NULL THEN 1 ELSE 0 END) AS missing_or_invalid_los,
    SUM(CASE WHEN TRY_CONVERT(decimal(18, 2), ER_Time) IS NULL THEN 1 ELSE 0 END) AS missing_or_invalid_er_time,
    SUM(CASE WHEN TRY_CONVERT(decimal(18, 2), treatemencost) IS NULL THEN 1 ELSE 0 END) AS missing_or_invalid_treatment_cost,
    SUM(CASE WHEN [Date] IS NULL THEN 1 ELSE 0 END) AS missing_date
FROM dbo.Detail_Data_Dataset;

-- 6. Determine whether ID behaves like an encounter ID rather than a repeat-patient ID.
SELECT
    ID,
    COUNT(*) AS rows_per_id
FROM dbo.Detail_Data_Dataset
GROUP BY ID
HAVING COUNT(*) > 1
ORDER BY rows_per_id DESC, ID;

-- A zero-row result above means ID cannot identify repeat visits by itself.
