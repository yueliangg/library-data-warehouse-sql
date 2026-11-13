-- ============================================================
-- ST1501 Data Engineering CA2
-- Part D: Data Warehouse Analytical Queries
-- Group: DAAA/FT/2A/03, Group 01
-- ============================================================

USE CA2DW2A0301;


-- ============================================================
-- Analysis 1: Annual Loan Volume and Its Associated Factors
-- ============================================================

SELECT
    dt.YearNumber AS `Year`,
    COUNT(DISTINCT fl.MemberKey) AS `Active Borrowers`,
    COUNT(*) AS `Total Completed Loans`,
    ROUND(
        COUNT(*)
        / COUNT(DISTINCT fl.MemberKey),
        2
    ) AS `Average Loans per Active Borrower`,
    COUNT(DISTINCT fl.BookKey) AS `Borrowed Book Copies`
FROM FactLoan AS fl
INNER JOIN DimTime AS dt
    ON fl.TimeKey = dt.TimeKey
GROUP BY
    dt.YearNumber
ORDER BY
    dt.YearNumber;


-- ============================================================
-- Analysis 2: Annual Overdue Frequency and Severity
-- ============================================================

SELECT
    dt.YearNumber AS `Year`,
    COUNT(*) AS `Total Completed Loans`,
    SUM(
        CASE
            WHEN fl.OverDueDays > 0
                THEN 1
            ELSE 0
        END
    ) AS `Overdue Loans`,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN fl.OverDueDays > 0
                    THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS `Overdue Rate (%)`,
    ROUND(
        AVG(
            CASE
                WHEN fl.OverDueDays > 0
                    THEN fl.OverDueDays
            END
        ),
        2
    ) AS `Average Days Late for Overdue Loans`
FROM FactLoan AS fl
INNER JOIN DimTime AS dt
    ON fl.TimeKey = dt.TimeKey
GROUP BY
    dt.YearNumber
ORDER BY
    dt.YearNumber;


-- ============================================================
-- Analysis 3: Normalised Monthly Borrowing Seasonality
-- ============================================================

SELECT
    MonthlyShare.MonthNumber AS `Month No.`,
    MonthlyShare.MonthName AS `Month`,
    ROUND(
        AVG(MonthlyShare.ShareOfAnnualLoans),
        2
    ) AS `Average Share of Annual Loans (%)`,
    ROUND(
        MIN(MonthlyShare.ShareOfAnnualLoans),
        2
    ) AS `Minimum Annual Share (%)`,
    ROUND(
        MAX(MonthlyShare.ShareOfAnnualLoans),
        2
    ) AS `Maximum Annual Share (%)`
FROM (
    SELECT
        MonthlyLoans.YearNumber,
        MonthlyLoans.MonthNumber,
        MonthlyLoans.MonthName,
        MonthlyLoans.MonthlyCompletedLoans * 100.0
            / SUM(MonthlyLoans.MonthlyCompletedLoans)
                OVER (
                    PARTITION BY MonthlyLoans.YearNumber
                ) AS ShareOfAnnualLoans
    FROM (
        SELECT
            dt.YearNumber,
            dt.MonthNumber,
            dt.MonthName,
            COUNT(*) AS MonthlyCompletedLoans
        FROM FactLoan AS fl
        INNER JOIN DimTime AS dt
            ON fl.TimeKey = dt.TimeKey
        GROUP BY
            dt.YearNumber,
            dt.MonthNumber,
            dt.MonthName
    ) AS MonthlyLoans
) AS MonthlyShare
GROUP BY
    MonthlyShare.MonthNumber,
    MonthlyShare.MonthName
ORDER BY
    MonthlyShare.MonthNumber;


-- ============================================================
-- Analysis 4: Genre Popularity and Borrowing Behaviour
-- ============================================================

SELECT
    db.Genre AS `Genre`,
    COUNT(DISTINCT db.BookID) AS `Number of Book Titles`,
    COUNT(*) AS `Total Completed Loans`,
    ROUND(
        COUNT(*)
        / COUNT(DISTINCT db.BookID),
        2
    ) AS `Average Loans per Book Title`,
    ROUND(
        AVG(fl.LoanDurationDay),
        2
    ) AS `Average Loan Duration (Days)`,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN fl.OverDueDays > 0
                    THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS `Overdue Rate (%)`
FROM FactLoan AS fl
INNER JOIN DimBook AS db
    ON fl.BookKey = db.BookKey
GROUP BY
    db.Genre
ORDER BY
    COUNT(*) DESC;


-- ============================================================
-- Analysis 5: Membership-Tier Borrowing and Overdue Behaviour
-- ============================================================

SELECT
    dm.TierName AS `Tier`,
    COUNT(DISTINCT dm.MemberKey) AS `Active Borrowers`,
    COUNT(*) AS `Total Completed Loans`,
    ROUND(
        COUNT(*)
        / COUNT(DISTINCT dm.MemberKey),
        2
    ) AS `Average Loans per Active Borrower`,
    ROUND(
        AVG(fl.LoanDurationDay),
        2
    ) AS `Average Loan Duration (Days)`,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN fl.OverDueDays > 0
                    THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS `Overdue Rate (%)`
FROM FactLoan AS fl
INNER JOIN DimMember AS dm
    ON fl.MemberKey = dm.MemberKey
GROUP BY
    dm.TierLevel,
    dm.TierName
ORDER BY
    dm.TierLevel;


-- ============================================================
-- Analysis 6: Genre Borrowing Patterns by Membership Tier
-- ============================================================

SELECT
    RankedTierGenres.TierName AS `Tier`,
    RankedTierGenres.GenreRank AS `Rank`,
    RankedTierGenres.Genre AS `Genre`,
    RankedTierGenres.TotalCompletedLoans
        AS `Total Completed Loans`,
    RankedTierGenres.PercentageOfTierLoans
        AS `Percentage of Tier Loans (%)`
FROM (
    SELECT
        TierGenreLoans.TierLevel,
        TierGenreLoans.TierName,
        TierGenreLoans.Genre,
        TierGenreLoans.TotalCompletedLoans,
        ROUND(
            100.0 * TierGenreLoans.TotalCompletedLoans
            / SUM(TierGenreLoans.TotalCompletedLoans)
                OVER (
                    PARTITION BY TierGenreLoans.TierLevel
                ),
            2
        ) AS PercentageOfTierLoans,
        ROW_NUMBER() OVER (
            PARTITION BY TierGenreLoans.TierLevel
            ORDER BY
                TierGenreLoans.TotalCompletedLoans DESC,
                TierGenreLoans.Genre ASC
        ) AS GenreRank
    FROM (
        SELECT
            dm.TierLevel,
            dm.TierName,
            db.Genre,
            COUNT(*) AS TotalCompletedLoans
        FROM FactLoan AS fl
        INNER JOIN DimMember AS dm
            ON fl.MemberKey = dm.MemberKey
        INNER JOIN DimBook AS db
            ON fl.BookKey = db.BookKey
        GROUP BY
            dm.TierLevel,
            dm.TierName,
            db.Genre
    ) AS TierGenreLoans
) AS RankedTierGenres
WHERE
    RankedTierGenres.GenreRank <= 3
ORDER BY
    RankedTierGenres.TierLevel,
    RankedTierGenres.GenreRank;


-- ============================================================
-- Analysis 7: Highly Active Borrowers and Return Behaviour
-- ============================================================

SELECT
    MemberStatistics.MemberID AS `Member ID`,
    MemberStatistics.MemberName AS `Member Name`,
    MemberStatistics.TierName AS `Tier`,
    MemberStatistics.TotalCompletedLoans
        AS `Total Completed Loans`,
    ROUND(
        MemberStatistics.OverallAverageLoans,
        2
    ) AS `Overall Average Loans`,
    ROUND(
        100.0 * (
            MemberStatistics.TotalCompletedLoans
            - MemberStatistics.OverallAverageLoans
        ) / MemberStatistics.OverallAverageLoans,
        2
    ) AS `Above Average (%)`,
    MemberStatistics.AverageLoanDurationDays
        AS `Average Loan Duration (Days)`,
    MemberStatistics.OverdueLoans
        AS `Overdue Loans`,
    MemberStatistics.OverdueRatePercentage
        AS `Overdue Rate (%)`
FROM (
    SELECT
        MemberLoanStatistics.*,
        AVG(MemberLoanStatistics.TotalCompletedLoans)
            OVER () AS OverallAverageLoans
    FROM (
        SELECT
            dm.MemberKey,
            dm.MemberID,
            dm.MemberName,
            dm.TierName,
            COUNT(*) AS TotalCompletedLoans,
            ROUND(
                AVG(fl.LoanDurationDay),
                2
            ) AS AverageLoanDurationDays,
            SUM(
                CASE
                    WHEN fl.OverDueDays > 0
                        THEN 1
                    ELSE 0
                END
            ) AS OverdueLoans,
            ROUND(
                100.0 * SUM(
                    CASE
                        WHEN fl.OverDueDays > 0
                            THEN 1
                        ELSE 0
                    END
                ) / COUNT(*),
                2
            ) AS OverdueRatePercentage
        FROM FactLoan AS fl
        INNER JOIN DimMember AS dm
            ON fl.MemberKey = dm.MemberKey
        GROUP BY
            dm.MemberKey,
            dm.MemberID,
            dm.MemberName,
            dm.TierName
    ) AS MemberLoanStatistics
) AS MemberStatistics
ORDER BY
    MemberStatistics.TotalCompletedLoans DESC,
    MemberStatistics.MemberID ASC
LIMIT 10;


-- ============================================================
-- Analysis 8: Staff Workload by Department and Employment Type
-- ============================================================

SELECT
    ds.Department AS `Department`,
    ds.EmploymentType AS `Employment Type`,
    COUNT(DISTINCT ds.StaffKey) AS `Active Staff`,
    COUNT(*) AS `Total Completed Loans`,
    ROUND(
        COUNT(*)
        / COUNT(DISTINCT ds.StaffKey),
        2
    ) AS `Average Loans Processed per Active Staff`
FROM FactLoan AS fl
INNER JOIN DimStaff AS ds
    ON fl.StaffKey = ds.StaffKey
GROUP BY
    ds.Department,
    ds.EmploymentType
ORDER BY
    COUNT(*) DESC,
    ds.Department ASC,
    ds.EmploymentType ASC;