      *----------------------------------------------------------------*
      * MMCOTPLR   - Third Party Liability Result Copybook           *
      * Domain     : Medicaid / TPL                                  *
      * DB2 Table  : TPL_RESULT                                      *
      * CFR Ref    : 42 CFR 433.139 — Medicaid payer of last resort  *
      *----------------------------------------------------------------*
       01  TPL-RESULT-REC.
           05  TPL-CLAIM-ID          PIC X(20).
           05  TPL-MEMBER-ID         PIC X(15).
           05  TPL-PAYER-ID          PIC X(10).
           05  TPL-PAYER-NAME        PIC X(40).
           05  TPL-POLICY-NO         PIC X(20).
           05  TPL-PAID-AMT          PIC S9(7)V99 COMP-3.
           05  TPL-PAID-DT           PIC 9(8).
           05  TPL-LAST-RESORT-AMT   PIC S9(7)V99 COMP-3.
           05  TPL-STATUS-CD         PIC X(2).
               88  TPL-PAID          VALUE 'PD'.
               88  TPL-PENDING       VALUE 'PE'.
               88  TPL-DENIED        VALUE 'DN'.
               88  TPL-NOT-COVERED   VALUE 'NC'.
