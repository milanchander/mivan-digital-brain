      *----------------------------------------------------------------*
      * MAENROLL   - MA Enrollment Record Copybook                  *
      * Domain     : Medicare Advantage                             *
      * Layer      : L2 Domain / L3 Systems                        *
      *----------------------------------------------------------------*
       01  MA-ENROLLMENT-RECORD.
           05  MAE-CONTRACT-ID         PIC X(05).
           05  MAE-PLAN-ID             PIC X(03).
           05  MAE-SEGMENT-ID          PIC X(03).
           05  MAE-HICN                PIC X(12).
           05  MAE-MBI                 PIC X(11).
           05  MAE-MEMBER-LAST-NAME    PIC X(25).
           05  MAE-MEMBER-FIRST-NAME   PIC X(20).
           05  MAE-MEMBER-MID-INIT     PIC X(01).
           05  MAE-DOB                 PIC X(08).
           05  MAE-GENDER              PIC X(01).
           05  MAE-EFFECTIVE-DATE      PIC X(08).
           05  MAE-TERM-DATE           PIC X(08).
           05  MAE-PART-A-EFF          PIC X(08).
           05  MAE-PART-B-EFF          PIC X(08).
           05  MAE-LIS-LEVEL           PIC X(02).
           05  MAE-DUAL-STATUS         PIC X(02).
           05  MAE-ESRD-IND            PIC X(01).
           05  MAE-HOSPICE-IND         PIC X(01).
           05  MAE-RISK-SCORE          PIC 9(02)V9(04) COMP-3.
           05  MAE-PAYMENT-AMOUNT      PIC 9(07)V9(02) COMP-3.
           05  MAE-COUNTY-CODE         PIC X(05).
           05  MAE-STATE-CODE          PIC X(02).
           05  MAE-PROCESS-DATE        PIC X(08).
           05  MAE-STATUS-CODE         PIC X(02).
           05  MAE-ERROR-CODE          PIC X(04).
           05  MAE-FILLER              PIC X(10).
