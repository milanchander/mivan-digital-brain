      *----------------------------------------------------------------*
      * MAHCCREC   - HCC Validation Record Copybook                 *
      * Domain     : Medicare Advantage / Risk Adjustment           *
      *----------------------------------------------------------------*
       01  MA-HCC-RECORD.
           05  MHCC-HICN               PIC X(12).
           05  MHCC-MBI                PIC X(11).
           05  MHCC-PAYMENT-YEAR       PIC X(04).
           05  MHCC-MODEL-YEAR         PIC X(04).
           05  MHCC-HCC-CODE           PIC X(04).
           05  MHCC-HCC-LABEL          PIC X(60).
           05  MHCC-ICD10-CODE         PIC X(07).
           05  MHCC-ICD10-DESC         PIC X(80).
           05  MHCC-DOS-FROM           PIC X(08).
           05  MHCC-DOS-THRU           PIC X(08).
           05  MHCC-PROVIDER-NPI       PIC X(10).
           05  MHCC-PROVIDER-SPECIALTY PIC X(03).
           05  MHCC-ENCOUNTER-ID       PIC X(20).
           05  MHCC-CLAIM-TYPE         PIC X(02).
           05  MHCC-HIERARCHY-IND      PIC X(01).
           05  MHCC-HIERARCHICAL-HCC   PIC X(04).
           05  MHCC-RAF-COEFFICIENT    PIC S9(02)V9(06) COMP-3.
           05  MHCC-VALIDATION-STATUS  PIC X(02).
               88  MHCC-VALID          VALUE 'VA'.
               88  MHCC-INVALID        VALUE 'IN'.
               88  MHCC-DUPLICATE      VALUE 'DU'.
               88  MHCC-PENDING        VALUE 'PE'.
           05  MHCC-REJECT-REASON      PIC X(04).
           05  MHCC-PROCESS-DTTM       PIC X(26).
           05  MHCC-FILLER             PIC X(05).
