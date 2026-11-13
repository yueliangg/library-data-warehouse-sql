-- ============================================================
-- ST1501 Data Engineering CA2
-- Data Warehouse ETL and Verification Script
-- Source OLTP database: CA22A0301
-- Target DW database:   CA2DW2A0301
-- Aligned with the latest Part B ERD
-- ============================================================

USE CA2DW2A0301;

START TRANSACTION;

INSERT INTO DimMember (
    MemberID,
    MemberName,
    Gender,
    DateOfBirth,
    Occupation,
    RegistrationDate,
    TierName,
    TierLevel,
    BorrowLimit
)
SELECT
    m.MemberID,
    m.Name AS MemberName,
    m.Gender,
    m.DOB AS DateOfBirth,
    m.Occupation,
    DATE(m.RegistrationDatetime) AS RegistrationDate,
    mt.TierName,
    mt.TierLevel,
    mt.BorrowLimit
FROM CA22A0301.Member AS m
INNER JOIN CA22A0301.MembershipTier AS mt
    ON m.TierID = mt.TierID;

INSERT INTO DimBook (
    BookID,
    Title,
    Author,
    Genre,
    MinTierName,
    MinTierLevel,
    CopySeqNo
)
SELECT
    b.BookID,
    b.Title,
    b.Author,
    b.Genre,
    mt.TierName AS MinTierName,
    mt.TierLevel AS MinTierLevel,
    bc.CopySeqNo
FROM CA22A0301.Book AS b
INNER JOIN CA22A0301.MembershipTier AS mt
    ON b.MinTierID = mt.TierID
INNER JOIN CA22A0301.BookCopy AS bc
    ON b.BookID = bc.BookID;

INSERT INTO DimStaff (
    StaffID,
    StaffName,
    Gender,
    EmploymentType,
    StartDate,
    Department
)
SELECT
    s.StaffID,
    s.Name AS StaffName,
    s.Gender,
    s.EmploymentType,
    s.StartDate,
    s.Department
FROM CA22A0301.Staff AS s;

INSERT INTO DimTime (
    FullDate,
    DayName,
    DayNumber,
    WeekNumber,
    MonthNumber,
    MonthName,
    QuarterNumber,
    YearNumber,
    IsWeekend,
    DayOfWeekNumber
)
SELECT
    d.FullDate,
    DAYNAME(d.FullDate) AS DayName,
    DAY(d.FullDate) AS DayNumber,
    WEEK(d.FullDate, 3) AS WeekNumber,
    MONTH(d.FullDate) AS MonthNumber,
    MONTHNAME(d.FullDate) AS MonthName,
    QUARTER(d.FullDate) AS QuarterNumber,
    YEAR(d.FullDate) AS YearNumber,
    CASE
        WHEN DAYOFWEEK(d.FullDate) IN (1, 7) THEN TRUE
        ELSE FALSE
    END AS IsWeekend,
    DAYOFWEEK(d.FullDate) AS DayOfWeekNum
FROM (
    SELECT DISTINCT DATE(StartDatetime) AS FullDate
    FROM CA22A0301.Loan
    WHERE ReturnDatetime IS NOT NULL
) AS d
ORDER BY d.FullDate;

INSERT INTO FactLoan (
    MemberKey,
    StaffKey,
    BookKey,
    TimeKey,
    LoanDurationDay,
    OverDueDays
)
SELECT
    dm.MemberKey,
    ds.StaffKey,
    db.BookKey,
    dt.TimeKey,
    DATEDIFF(DATE(l.ReturnDatetime), DATE(l.StartDatetime)) AS LoanDurationDay,
    GREATEST(DATEDIFF(DATE(l.ReturnDatetime), l.DueDate), 0) AS OverDueDays
FROM CA22A0301.Loan AS l
INNER JOIN DimMember AS dm
    ON l.MemberID = dm.MemberID
INNER JOIN DimStaff AS ds
    ON l.StaffID = ds.StaffID
INNER JOIN DimBook AS db
    ON l.BookID = db.BookID
   AND l.CopySeqNo = db.CopySeqNo
INNER JOIN DimTime AS dt
    ON DATE(l.StartDatetime) = dt.FullDate
WHERE l.ReturnDatetime IS NOT NULL;

COMMIT;

SELECT 'DimMember' AS TableName, COUNT(*) AS RowCount
FROM DimMember
UNION ALL
SELECT 'DimBook', COUNT(*)
FROM DimBook
UNION ALL
SELECT 'DimStaff', COUNT(*)
FROM DimStaff
UNION ALL
SELECT 'DimTime', COUNT(*)
FROM DimTime
UNION ALL
SELECT 'FactLoan', COUNT(*)
FROM FactLoan;

-- Expected:
-- DimMember = 301
-- DimBook   = 1265
-- DimStaff  = 51
-- DimTime   = 1590
-- FactLoan  = 12343

SELECT
    COUNT(*) AS TotalLoans,
    SUM(CASE WHEN ReturnDatetime IS NOT NULL THEN 1 ELSE 0 END) AS CompletedLoans,
    SUM(CASE WHEN ReturnDatetime IS NULL THEN 1 ELSE 0 END) AS ActiveLoans
FROM CA22A0301.Loan;

SELECT
    (
        SELECT COUNT(*)
        FROM CA22A0301.Loan
        WHERE ReturnDatetime IS NOT NULL
    ) AS CompletedOLTPLoans,
    (
        SELECT COUNT(*)
        FROM FactLoan
    ) AS FactLoanRows;

SELECT *
FROM FactLoan
WHERE LoanDurationDay < 0
   OR OverDueDays < 0;

SELECT
    MIN(DATE(StartDatetime)) AS OLTPFirstLoanDate,
    MAX(DATE(StartDatetime)) AS OLTPLastLoanDate
FROM CA22A0301.Loan
WHERE ReturnDatetime IS NOT NULL;

SELECT
    MIN(dt.FullDate) AS DWFirstLoanDate,
    MAX(dt.FullDate) AS DWLastLoanDate
FROM FactLoan AS fl
INNER JOIN DimTime AS dt
    ON fl.TimeKey = dt.TimeKey;

SELECT COUNT(*) AS MissingDimensionReferences
FROM FactLoan AS fl
LEFT JOIN DimMember AS dm
    ON fl.MemberKey = dm.MemberKey
LEFT JOIN DimStaff AS ds
    ON fl.StaffKey = ds.StaffKey
LEFT JOIN DimBook AS db
    ON fl.BookKey = db.BookKey
LEFT JOIN DimTime AS dt
    ON fl.TimeKey = dt.TimeKey
WHERE dm.MemberKey IS NULL
   OR ds.StaffKey IS NULL
   OR db.BookKey IS NULL
   OR dt.TimeKey IS NULL;

SELECT
    COUNT(*) AS DimBookRows,
    COUNT(DISTINCT CONCAT(BookID, '-', CopySeqNo)) AS DistinctBookCopies
FROM DimBook;