      *----------------------------------------------------------------*
      * NDUPQREC  Record layout for MIVANCPS.NEAR_DUP_QUEUE            *
      *----------------------------------------------------------------*
       01  NEAR-DUP-QUEUE-REC.
           05  NDUP-CLAIM-ID         PIC X(20).
           05  NDUP-ORIG-CLAIM-ID    PIC X(20).
           05  NDUP-MEMBER-ID        PIC X(15).
           05  NDUP-PROV-NPI         PIC X(10).
           05  NDUP-DOS              PIC 9(8).
           05  NDUP-CPT-CD           PIC X(5).
           05  NDUP-CHARGE-AMT       PIC S9(7)V99  COMP-3.
           05  NDUP-MATCH-TYPE       PIC X(10).
           05  NDUP-PEND-REASON      PIC X(20)     VALUE 'NEAR-DUP-REVIEW'.
           05  NDUP-CREATE-DT        PIC 9(8).
           05  NDUP-STATUS           PIC X(1)      VALUE 'P'.