      *----------------------------------------------------------------*
      * MARAFSCR   - RAF Score Calculation Record Copybook          *
      * Domain     : Medicare Advantage / Risk Adjustment           *
      *----------------------------------------------------------------*
       01  MA-RAF-SCORE-RECORD.
           05  MRAF-HICN               PIC X(12).
           05  MRAF-MBI                PIC X(11).
           05  MRAF-CONTRACT-ID        PIC X(05).
           05  MRAF-PLAN-ID            PIC X(03).
           05  MRAF-PAYMENT-YEAR       PIC X(04).
           05  MRAF-MODEL-TYPE         PIC X(03).
               88  MRAF-CMS-HCC        VALUE 'CMS'.
               88  MRAF-RX-HCC         VALUE 'RXH'.
               88  MRAF-ESRD           VALUE 'ESD'.
           05  MRAF-RISK-SEGMENT       PIC X(03).
           05  MRAF-COMMUNITY-FACTOR   PIC S9(02)V9(06) COMP-3.
           05  MRAF-DEMOGRAPHIC-SCORE  PIC S9(02)V9(06) COMP-3.
           05  MRAF-DISEASE-SCORE      PIC S9(02)V9(06) COMP-3.
           05  MRAF-INTERACTION-SCORE  PIC S9(02)V9(06) COMP-3.
           05  MRAF-TOTAL-RAF          PIC S9(02)V9(06) COMP-3.
           05  MRAF-PRIOR-RAF          PIC S9(02)V9(06) COMP-3.
           05  MRAF-RAF-DELTA          PIC S9(02)V9(06) COMP-3.
           05  MRAF-NORMALIZATION-FCTR PIC S9(02)V9(06) COMP-3.
           05  MRAF-FRAILTY-FACTOR     PIC S9(02)V9(06) COMP-3.
           05  MRAF-NEW-ENROLLEE-IND   PIC X(01).
           05  MRAF-LIS-ADDER          PIC S9(02)V9(06) COMP-3.
           05  MRAF-DUAL-ADDER         PIC S9(02)V9(06) COMP-3.
           05  MRAF-HCC-COUNT          PIC S9(04) COMP.
           05  MRAF-HCC-TABLE.
               10  MRAF-HCC-ENTRY      OCCURS 50 TIMES
                                       INDEXED BY MRAF-HCC-IDX.
                   15  MRAF-HCC-CD     PIC X(04).
                   15  MRAF-HCC-COEFF  PIC S9(02)V9(06) COMP-3.
           05  MRAF-CALC-DATE          PIC X(08).
           05  MRAF-STATUS             PIC X(02).
           05  MRAF-FILLER             PIC X(04).
