// MongoDB queries on the Book collection (500 documents).

// Q1: Books with more than 400 loans, highest first
db.Book.find(
  { loanCount: { $gt: 400 } },
  { _id: 0, title: 1, genre: 1, loanCount: 1 }
).sort({ loanCount: -1 }).toArray();

// Q2: Genres with more than 50 books AND an average of more than 70 loans per book
db.Book.aggregate([
  {
    $group: {
      _id: "$genre",
      numberOfBooks: { $sum: 1 },
      averageLoansPerBook: { $avg: "$loanCount" }
    }
  },
  { $match: { numberOfBooks: { $gt: 50 }, averageLoansPerBook: { $gt: 70 } } },
  {
    $project: {
      _id: 0,
      genre: "$_id",
      numberOfBooks: 1,
      averageLoansPerBook: { $round: ["$averageLoansPerBook", 2] }
    }
  },
  { $sort: { averageLoansPerBook: -1 } }
]).toArray();
