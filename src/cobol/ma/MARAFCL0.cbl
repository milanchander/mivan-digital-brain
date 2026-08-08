      *----------------------------------------------------------------*
      * PROGRAM:    MARAFCL0                                        *
      * PURPOSE:    RAF Score Calculation Subprogram                *
      * CALLED BY:  MAENCDR0                                        *
      * JAVA EQ:    RafCalculationService.java                      *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MARAFCL0.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SQLCODE              PIC S9(09) COMP VALUE +0.
       01  WS-DEMO-SCORE           PIC S9(02)V9(06) COMP-3 VALUE ZEROS.
       01  WS-DISEASE-SCORE        PIC S9(02)V9(06) COMP-3 VALUE ZEROS.
       01  WS-INTERACTION-SCORE    PIC S9(02)V9(06) COMP-3 VALUE ZEROS.
       01  WS-NORM-FACTOR          PIC S9(02)V9(06) COMP-3 VALUE ZEROS.
       01  WS-IDX                  PIC S9(04) COMP           VALUE +0.

           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL
               DECLARE MA_DEMO_FACTORS TABLE
               ( GENDER          CHAR(1)      NOT NULL,
                 AGE_BAND        CHAR(5)      NOT NULL,
                 NEW_ENROLLEE_IND CHAR(1)     NOT NULL,
                 RISK_SEGMENT    CHAR(3)      NOT NULL,
                 DEMO_COEFFICIENT DECIMAL(8,6) NOT NULL,
                 MODEL_YEAR      CHAR(4)      NOT NULL )
           END-EXEC.

       LINKAGE SECTION.
           COPY MAHCCREC.
           COPY MARAFSCR.
       01  LS-RETURN-CODE          PIC S9(04) COMP.

       PROCEDURE DIVISION USING MA-HCC-RECORD
                                MA-RAF-SCORE-RECORD
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           MOVE MHCC-HICN        TO MRAF-HICN
           MOVE MHCC-MBI         TO MRAF-MBI
           MOVE MHCC-PAYMENT-YEAR TO MRAF-PAYMENT-YEAR
           PERFORM 1000-GET-DEMO-FACTOR
           PERFORM 2000-SUM-HCC-COEFFICIENTS
           PERFORM 3000-APPLY-INTERACTIONS
           PERFORM 4000-CALCULATE-TOTAL-RAF
           GOBACK
           .

       1000-GET-DEMO-FACTOR.
           EXEC SQL
               SELECT DEMO_COEFFICIENT
                 INTO :WS-DEMO-SCORE
                 FROM MA_DEMO_FACTORS
                WHERE GENDER           = :MHCC-VALIDATION-STATUS
                  AND NEW_ENROLLEE_IND = :MRAF-NEW-ENROLLEE-IND
                  AND RISK_SEGMENT     = :MRAF-RISK-SEGMENT
                  AND MODEL_YEAR       = :MRAF-PAYMENT-YEAR
           END-EXEC
           IF SQLCODE = 0
               MOVE WS-DEMO-SCORE TO MRAF-DEMOGRAPHIC-SCORE
           ELSE
               MOVE +4 TO LS-RETURN-CODE
           END-IF
           .

       2000-SUM-HCC-COEFFICIENTS.
           MOVE ZEROS TO WS-DISEASE-SCORE
           PERFORM VARYING WS-IDX FROM +1 BY +1
                   UNTIL WS-IDX > MRAF-HCC-COUNT
               ADD MRAF-HCC-COEFF(WS-IDX) TO WS-DISEASE-SCORE
           END-PERFORM
           MOVE WS-DISEASE-SCORE TO MRAF-DISEASE-SCORE
           .

       3000-APPLY-INTERACTIONS.
           MOVE ZEROS TO WS-INTERACTION-SCORE
           MOVE WS-INTERACTION-SCORE TO MRAF-INTERACTION-SCORE
           .

       4000-CALCULATE-TOTAL-RAF.
           COMPUTE MRAF-TOTAL-RAF =
               MRAF-DEMOGRAPHIC-SCORE +
               MRAF-DISEASE-SCORE     +
               MRAF-INTERACTION-SCORE +
               MRAF-LIS-ADDER         +
               MRAF-DUAL-ADDER
           COMPUTE MRAF-RAF-DELTA =
               MRAF-TOTAL-RAF - MRAF-PRIOR-RAF
           MOVE FUNCTION CURRENT-DATE(1:8) TO MRAF-CALC-DATE
           MOVE '00' TO MRAF-STATUS
           .
