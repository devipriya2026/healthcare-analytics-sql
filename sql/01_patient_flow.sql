/*
Healthcare Analytics - patient-flow analysis
*/

SET NOCOUNT ON;

-- 1. Average length of stay by department.
SELECT
    detail.Dpt_ID,
    department.Department_Name,
    COUNT(*) AS encounter_count,
    AVG(TRY_CONVERT(decimal(18, 2), detail.LOS)) AS average_length_of_stay
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
GROUP BY detail.Dpt_ID, department.Department_Name
ORDER BY average_length_of_stay DESC;

-- 2. Admission activity by weekday.
SELECT
    DATENAME(WEEKDAY, [Date]) AS admission_weekday,
    COUNT(*) AS encounter_count
FROM dbo.Detail_Data_Dataset
WHERE [Date] IS NOT NULL
GROUP BY DATENAME(WEEKDAY, [Date])
ORDER BY encounter_count DESC;

-- 3. Check whether the Date field contains time-of-day information.
SELECT
    COUNT(DISTINCT CONVERT(time, [Date])) AS distinct_time_values,
    MIN(CONVERT(time, [Date])) AS earliest_time_value,
    MAX(CONVERT(time, [Date])) AS latest_time_value
FROM dbo.Detail_Data_Dataset
WHERE [Date] IS NOT NULL;

-- If the only time is 00:00:00, the dataset cannot support a peak-admission-time claim.

-- 4. Readmission rate by department using Status = Readmit.
SELECT
    detail.Dpt_ID,
    department.Department_Name,
    COUNT(*) AS encounter_count,
    SUM
    (
        CASE WHEN LOWER(LTRIM(RTRIM(detail.[Status]))) = 'readmit' THEN 1 ELSE 0 END
    ) AS readmission_count,
    CAST
    (
        100.0 * SUM
        (
            CASE WHEN LOWER(LTRIM(RTRIM(detail.[Status]))) = 'readmit' THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0)
        AS decimal(8, 2)
    ) AS readmission_rate_percent
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
GROUP BY detail.Dpt_ID, department.Department_Name
ORDER BY readmission_rate_percent DESC, detail.Dpt_ID;
