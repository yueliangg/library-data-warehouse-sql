-- ============================================================
-- ST1501 Data Engineering CA2
-- Data Warehouse Creation Script
-- Source OLTP database: CA22A0301
-- Target DW database:   CA2DW2A0301
-- Aligned with the latest Part B ERD
-- ============================================================

DROP DATABASE IF EXISTS CA2DW2A0301;
CREATE DATABASE CA2DW2A0301;
USE CA2DW2A0301;

CREATE TABLE DimMember (
    MemberKey INT AUTO_INCREMENT,
    MemberID CHAR(10) NOT NULL,
    MemberName VARCHAR(100) NOT NULL,
    Gender CHAR(1) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Occupation VARCHAR(50) NULL,
    RegistrationDate DATE NOT NULL,
    TierName VARCHAR(20) NOT NULL,
    TierLevel INT NOT NULL,
    BorrowLimit INT NOT NULL,
    CONSTRAINT PK_DimMember PRIMARY KEY (MemberKey),
    CONSTRAINT UQ_DimMember_MemberID UNIQUE (MemberID)
);

CREATE TABLE DimBook (
    BookKey INT AUTO_INCREMENT,
    BookID CHAR(10) NOT NULL,
    Title VARCHAR(200) NOT NULL,
    Author VARCHAR(100) NOT NULL,
    Genre VARCHAR(50) NOT NULL,
    MinTierName VARCHAR(20) NOT NULL,
    MinTierLevel INT NOT NULL,
    CopySeqNo INT NOT NULL,
    CONSTRAINT PK_DimBook PRIMARY KEY (BookKey),
    CONSTRAINT UQ_DimBook_BookCopy UNIQUE (BookID, CopySeqNo)
);

CREATE TABLE DimTime (
    TimeKey INT AUTO_INCREMENT,
    FullDate DATE NOT NULL,
    DayName VARCHAR(10) NOT NULL,
    DayNumber INT NOT NULL,
    WeekNumber INT NOT NULL,
    MonthNumber INT NOT NULL,
    MonthName VARCHAR(10) NOT NULL,
    QuarterNumber INT NOT NULL,
    YearNumber INT NOT NULL,
    IsWeekend BOOLEAN NOT NULL,
    DayOfWeekNumber INT NOT NULL,
    CONSTRAINT PK_DimTime PRIMARY KEY (TimeKey),
    CONSTRAINT UQ_DimTime_FullDate UNIQUE (FullDate)
);

CREATE TABLE DimStaff (
    StaffKey INT AUTO_INCREMENT,
    StaffID CHAR(10) NOT NULL,
    StaffName VARCHAR(100) NOT NULL,
    Gender CHAR(1) NOT NULL,
    EmploymentType VARCHAR(20) NOT NULL,
    StartDate DATE NOT NULL,
    Department VARCHAR(50) NOT NULL,
    CONSTRAINT PK_DimStaff PRIMARY KEY (StaffKey),
    CONSTRAINT UQ_DimStaff_StaffID UNIQUE (StaffID)
);

CREATE TABLE FactLoan (
    LoanKey INT AUTO_INCREMENT,
    MemberKey INT NOT NULL,
    StaffKey INT NOT NULL,
    BookKey INT NOT NULL,
    TimeKey INT NOT NULL,
    LoanDurationDay INT NOT NULL,
    OverDueDays INT NOT NULL,

    CONSTRAINT PK_FactLoan PRIMARY KEY (LoanKey),
    CONSTRAINT FK_FactLoan_Member FOREIGN KEY (MemberKey)
        REFERENCES DimMember(MemberKey),
    CONSTRAINT FK_FactLoan_Staff FOREIGN KEY (StaffKey)
        REFERENCES DimStaff(StaffKey),
    CONSTRAINT FK_FactLoan_Book FOREIGN KEY (BookKey)
        REFERENCES DimBook(BookKey),
    CONSTRAINT FK_FactLoan_Time FOREIGN KEY (TimeKey)
        REFERENCES DimTime(TimeKey),
    CONSTRAINT CK_FactLoan_LoanDurationDay CHECK (LoanDurationDay >= 0),
    CONSTRAINT CK_FactLoan_OverDueDays CHECK (OverDueDays >= 0)
);