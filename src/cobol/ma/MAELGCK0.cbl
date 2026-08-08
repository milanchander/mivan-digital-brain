      *----------------------------------------------------------------*
      * PROGRAM:    MAELGCK0                                        *
      * PURPOSE:    MA Eligibility Verification Subprogram          *
      * CALLED BY:  MAENCDR0                                        *
      * JAVA EQ:    MaEligibilityService.java                       *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MAELGCK0.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DB2-SQLCODE          PIC S9(09) COMP VALUE +0.
       01  WS-ELG-STATUS           PIC X(02)      VALUE SPACES.

           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL
               DECLARE MA_ELIGIBILITY TABLE
               ( MBI           CHAR(11)   NOT NULL,
                 HICN          CHAR(12)   NOT NULL,
                 CONTRACT_ID   CHAR(5)    NOT NULL,
                 PLAN_ID       CHAR(3)    NOT NULL,
                 EFF_DATE      CHAR(8)    NOT NULL,
                 TERM_DATE     CHAR(8),
                 DUAL_STATUS   CHAR(2),
                 LIS_LEVEL     CHAR(2),
                 ESRD_IND      CHAR(1),
                 STATUS_CD     CHAR(2)    NOT NULL )
           END-EXEC.

       LINKAGE SECTION.
           COPY MAENROLL.
       01  LS-RETURN-CODE          PIC S9(04) COMP.

       PROCEDURE DIVISION USING MA-ENROLLMENT-RECORD
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           PERFORM 1000-CHECK-ELIGIBILITY
           GOBACK
           .

       1000-CHECK-ELIGIBILITY.
           EXEC SQL
               SELECT STATUS_CD
                 INTO :WS-ELG-STATUS
                 FROM MA_ELIGIBILITY
                WHERE MBI         = :MAE-MBI
                  AND CONTRACT_ID = :MAE-CONTRACT-ID
                  AND EFF_DATE   <= :MAE-EFFECTIVE-DATE
                  AND (TERM_DATE >= :MAE-EFFECTIVE-DATE
                        OR TERM_DATE IS NULL)
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   IF WS-ELG-STATUS NOT = 'AC'
                       MOVE +4 TO LS-RETURN-CODE
                   END-IF
               WHEN 100
                   MOVE +4 TO LS-RETURN-CODE
               WHEN OTHER
                   MOVE +8 TO LS-RETURN-CODE
           END-EVALUATE
           .
