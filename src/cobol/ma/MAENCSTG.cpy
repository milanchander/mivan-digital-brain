      *----------------------------------------------------------------*
      * MAENCSTG   - Encounter Staging Record Copybook              *
      * Domain     : Medicare Advantage / EDPS Submission           *
      *----------------------------------------------------------------*
       01  MA-ENCOUNTER-STAGING.
           05  MEST-ENCOUNTER-ID       PIC X(20).
           05  MEST-TRANSACTION-TYPE   PIC X(02).
               88  MEST-ORIGINAL       VALUE '01'.
               88  MEST-REPLACEMENT    VALUE '02'.
               88  MEST-VOID           VALUE '03'.
           05  MEST-SUBMISSION-TYPE    PIC X(02).
               88  MEST-PROFESSIONAL   VALUE 'PR'.
               88  MEST-INSTITUTIONAL  VALUE 'IN'.
               88  MEST-PHARMACY       VALUE 'PH'.
           05  MEST-HICN               PIC X(12).
           05  MEST-MBI                PIC X(11).
           05  MEST-CONTRACT-ID        PIC X(05).
           05  MEST-PLAN-ID            PIC X(03).
           05  MEST-BILLING-NPI        PIC X(10).
           05  MEST-RENDERING-NPI      PIC X(10).
           05  MEST-FACILITY-NPI       PIC X(10).
           05  MEST-DOS-FROM           PIC X(08).
           05  MEST-DOS-THRU           PIC X(08).
           05  MEST-DIAG-TABLE.
               10  MEST-DIAG-ENTRY     OCCURS 25 TIMES
                                       INDEXED BY MEST-DIAG-IDX.
                   15  MEST-DIAG-CODE  PIC X(07).
                   15  MEST-DIAG-POA   PIC X(01).
           05  MEST-PROC-TABLE.
               10  MEST-PROC-ENTRY     OCCURS 25 TIMES
                                       INDEXED BY MEST-PROC-IDX.
                   15  MEST-PROC-CODE  PIC X(05).
                   15  MEST-PROC-MOD   PIC X(08).
                   15  MEST-PROC-UNITS PIC S9(04) COMP.
                   15  MEST-PROC-AMT   PIC S9(07)V9(02) COMP-3.
           05  MEST-TOTAL-BILLED       PIC S9(09)V9(02) COMP-3.
           05  MEST-TOTAL-PAID         PIC S9(09)V9(02) COMP-3.
           05  MEST-SUBMISSION-STATUS  PIC X(02).
               88  MEST-PENDING        VALUE 'PE'.
               88  MEST-SUBMITTED      VALUE 'SU'.
               88  MEST-ACCEPTED       VALUE 'AC'.
               88  MEST-REJECTED       VALUE 'RJ'.
           05  MEST-CMS-ICN            PIC X(23).
           05  MEST-SUBMIT-DATE        PIC X(08).
           05  MEST-RESPONSE-DATE      PIC X(08).
           05  MEST-ERROR-CODE         PIC X(04).
           05  MEST-FILLER             PIC X(06).
