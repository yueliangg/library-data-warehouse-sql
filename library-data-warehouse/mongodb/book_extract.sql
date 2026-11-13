-- Extract Book data from the OLTP database for migration to MongoDB.
-- One row per book: details, minimum membership tier, copy counts and total loans.
USE CA22A0301;

SELECT
    b.BookID          AS bookID,
    b.Title           AS title,
    b.Author          AS author,
    b.Genre           AS genre,
    mt.TierName       AS minimumMembershipTier,
    COUNT(bc.CopySeqNo) AS totalCopies,
    SUM(CASE WHEN bc.Status = 'Lost' THEN 1 ELSE 0 END) AS lostCopies,
    COALESCE(ls.totalLoanTransactions, 0) AS totalLoanTransactions
FROM Book AS b
INNER JOIN MembershipTier AS mt
    ON b.MinTierID = mt.TierID
LEFT JOIN BookCopy AS bc
    ON b.BookID = bc.BookID
LEFT JOIN (
    SELECT BookID, COUNT(*) AS totalLoanTransactions
    FROM Loan
    GROUP BY BookID
) AS ls
    ON b.BookID = ls.BookID
GROUP BY
    b.BookID, b.Title, b.Author, b.Genre, mt.TierName, ls.totalLoanTransactions
ORDER BY b.BookID;
