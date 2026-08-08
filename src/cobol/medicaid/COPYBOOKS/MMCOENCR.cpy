      *----------------------------------------------------------------*
      * MMCOENCR   - Medicaid Encounter Staging Record Copybook      *
      * Domain     : Medicaid / State MMIS                           *
      * File       : MEDICAID-ENCOUNTER-STAGE (ESDS VSAM)           *
      *----------------------------------------------------------------*
       01  MEDICAID-ENC-STAGE-REC.
           05  MC-ENC-CLAIM-ID       PIC X(20).
           05  MC-ENC-MEMBER-ID      PIC X(15).
           05  MC-ENC-STATE-CD       PIC X(2).
           05  MC-ENC-MCO-ID         PIC X(10).
           05  MC-ENC-PROV-NPI       PIC X(10).
           05  MC-ENC-DOS-FROM       PIC 9(8).
           05  MC-ENC-DOS-TO         PIC 9(8).
           05  MC-ENC-DIAG-1         PIC X(7).
           05  MC-ENC-PROC-CD        PIC X(5).
           05  MC-ENC-BILLED-AMT     PIC S9(7)V99 COMP-3.
           05  MC-ENC-PAID-AMT       PIC S9(7)V99 COMP-3.
           05  MC-ENC-TPL-AMT        PIC S9(7)V99 COMP-3.
           05  MC-ENC-STATUS         PIC X(2).
               88  MC-ENC-STAGED     VALUE 'ST'.
               88  MC-ENC-SUBMITTED  VALUE 'SU'.
               88  MC-ENC-ACCEPTED   VALUE 'AC'.
               88  MC-ENC-REJECTED   VALUE 'RJ'.
               88  MC-ENC-PENDING    VALUE 'PE'.
