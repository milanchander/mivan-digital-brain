      *----------------------------------------------------------------*
      * MMCOELIG   - Medicaid Eligibility Record Copybook            *
      * Domain     : Medicaid / State Programs                       *
      * DB2 Table  : MEDICAID_ELIGIBILITY                            *
      *----------------------------------------------------------------*
       01  MEDICAID-ELIG-REC.
           05  MC-MEMBER-ID          PIC X(15).
           05  MC-STATE-CD           PIC X(2).
           05  MC-AID-CATEGORY       PIC X(4).
               88  MC-AID-TANF       VALUE 'TANF'.
               88  MC-AID-SSI        VALUE 'SSI '.
               88  MC-AID-MAGI       VALUE 'MAGI'.
               88  MC-AID-LTC        VALUE 'LTC '.
           05  MC-ELIG-FROM-DT       PIC 9(8).
           05  MC-ELIG-TO-DT         PIC 9(8).
           05  MC-MCO-ID             PIC X(10).
           05  MC-PLAN-TYPE          PIC X(4).
               88  MC-PLAN-FFS       VALUE 'FFS '.
               88  MC-PLAN-MANAGED   VALUE 'MCO '.
               88  MC-PLAN-PCCM      VALUE 'PCCM'.
           05  MC-DUAL-ELIG-IND      PIC X(1).
               88  MC-IS-DUAL        VALUE 'Y'.
               88  MC-NOT-DUAL       VALUE 'N'.
           05  MC-SPEND-DOWN-IND     PIC X(1).
               88  MC-HAS-SPEND-DOWN VALUE 'Y'.
           05  MC-SPEND-DOWN-AMT     PIC S9(7)V99 COMP-3.
           05  MC-CHIP-IND           PIC X(1).
               88  MC-IS-CHIP        VALUE 'Y'.
           05  MC-EPSDT-IND          PIC X(1).
               88  MC-EPSDT-ELIGIBLE VALUE 'Y'.
           05  MC-STATUS-CD          PIC X(2).
               88  MC-ELIG-ACTIVE    VALUE 'AC'.
               88  MC-ELIG-TERM      VALUE 'TM'.
               88  MC-ELIG-PEND      VALUE 'PE'.
               88  MC-ELIG-RETRO     VALUE 'RT'.
