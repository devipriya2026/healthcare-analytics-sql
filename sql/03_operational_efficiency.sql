/*
Healthcare Analytics - operational-efficiency analysis

This script corrects the original ranking logic by aggregating treatment cost by
department first and ranking the aggregated totals.
*/

SET NOCOUNT ON;

-- 1. Average treatment cost by department.
SELECT
    detail.Dpt_ID,
    department.Department_Name,
    COUNT(*) AS encounter_count,
    AVG(TRY_CONVERT(decimal(18, 2), detail.treatemencost)) AS average_treatment_cost
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
GROUP BY detail.Dpt_ID, department.Department_Name
ORDER BY average_treatment_cost DESC;

-- 2. Departments whose average ER time is greater than 40 minutes.
SELECT
    detail.Dpt_ID,
    department.Department_Name,
    COUNT(TRY_CONVERT(decimal(18, 2), detail.ER_Time)) AS encounters_with_er_time,
    AVG(TRY_CONVERT(decimal(18, 2), detail.ER_Time)) AS average_er_minutes
FROM dbo.Detail_Data_Dataset AS detail
LEFT JOIN dbo.Department AS department
    ON detail.Dpt_ID = department.Dpt_ID
GROUP BY detail.Dpt_ID, department.Department_Name
HAVING AVG(TRY_CONVERT(decimal(18, 2), detail.ER_Time)) > 40
ORDER BY average_er_minutes DESC;

-- 3. Corrected department ranking by total treatment cost.
WITH DepartmentCost AS
(
    SELECT
        detail.Dpt_ID,
        department.Department_Name,
        SUM(TRY_CONVERT(decimal(18, 2), detail.treatemencost)) AS total_treatment_cost
    FROM dbo.Detail_Data_Dataset AS detail
    LEFT JOIN dbo.Department AS department
        ON detail.Dpt_ID = department.Dpt_ID
    GROUP BY detail.Dpt_ID, department.Department_Name
)
SELECT
    Dpt_ID,
    Department_Name,
    total_treatment_cost,
    DENSE_RANK() OVER (ORDER BY total_treatment_cost DESC) AS treatment_cost_rank
FROM DepartmentCost
ORDER BY treatment_cost_rank, Dpt_ID;

-- 4. Top three department ranks by encounter count, including ties.
WITH DepartmentEncounters AS
(
    SELECT
        detail.Dpt_ID,
        department.Department_Name,
        COUNT(*) AS encounter_count
    FROM dbo.Detail_Data_Dataset AS detail
    LEFT JOIN dbo.Department AS department
        ON detail.Dpt_ID = department.Dpt_ID
    GROUP BY detail.Dpt_ID, department.Department_Name
),
RankedDepartments AS
(
    SELECT
        Dpt_ID,
        Department_Name,
        encounter_count,
        DENSE_RANK() OVER (ORDER BY encounter_count DESC) AS encounter_count_rank
    FROM DepartmentEncounters
)
SELECT
    Dpt_ID,
    Department_Name,
    encounter_count,
    encounter_count_rank
FROM RankedDepartments
WHERE encounter_count_rank <= 3
ORDER BY encounter_count_rank, Dpt_ID;

-- 5. Running total of treatment cost by date after daily aggregation.
WITH DailyCost AS
(
    SELECT
        CAST([Date] AS date) AS admission_date,
        SUM(TRY_CONVERT(decimal(18, 2), treatemencost)) AS daily_treatment_cost
    FROM dbo.Detail_Data_Dataset
    WHERE [Date] IS NOT NULL
    GROUP BY CAST([Date] AS date)
)
SELECT
    admission_date,
    daily_treatment_cost,
    SUM(daily_treatment_cost) OVER
    (
        ORDER BY admission_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_treatment_cost
FROM DailyCost
ORDER BY admission_date;

-- 6. Encounters with ER time above the overall valid-record average.
WITH ValidERTime AS
(
    SELECT
        ID,
        Name,
        Dpt_ID,
        TRY_CONVERT(decimal(18, 2), ER_Time) AS er_minutes
    FROM dbo.Detail_Data_Dataset
    WHERE TRY_CONVERT(decimal(18, 2), ER_Time) IS NOT NULL
)
SELECT
    ID,
    Name,
    Dpt_ID,
    er_minutes
FROM ValidERTime
WHERE er_minutes > (SELECT AVG(er_minutes) FROM ValidERTime)
ORDER BY er_minutes DESC, ID;

-- 7. Check whether the encounter ID repeats.
SELECT
    ID,
    COUNT(*) AS id_occurrence_count
FROM dbo.Detail_Data_Dataset
GROUP BY ID
HAVING COUNT(*) > 1
ORDER BY id_occurrence_count DESC, ID;

-- A zero-row result means ID is not a usable repeat-patient identifier.
-- Names are not a safe substitute because different people can share a name.
