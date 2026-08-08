      *----------------------------------------------------------------*
      * MMCOLIAB   - Medicaid Liability Record Copybook              *
      * Domain     : Medicaid / Payer of Last Resort                 *
      * DB2 Table  : MEDICAID_LIABILITY                              *
      * CFR Ref    : 42 CFR 433.139                                  *
      *----------------------------------------------------------------*
       01  MEDICAID-LIAB-REC.
           05  MC-LIAB-CLAIM-ID      PIC X(20).
           05  MC-LIAB-MEMBER-ID     PIC X(15).
           05  MC-LIAB-STATE-CD      PIC X(2).
           05  MC-BILLED-AMT         PIC S9(7)V99 COMP-3.
           05  MC-TPL-PAID-AMT       PIC S9(7)V99 COMP-3.
           05  MC-MEMBER-RESP-AMT    PIC S9(7)V99 COMP-3.
           05  MC-MEDICAID-AMT       PIC S9(7)V99 COMP-3.
           05  MC-CALC-DT            PIC 9(8).
           05  MC-STATUS-CD          PIC X(2).
               88  MC-LIAB-COMPLETE  VALUE 'CM'.
               88  MC-LIAB-PENDING   VALUE 'PE'.
               88  MC-LIAB-ERROR     VALUE 'ER'.
               88  MC-LIAB-ZERO      VALUE 'ZR'.
