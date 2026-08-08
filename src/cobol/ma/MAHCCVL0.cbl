      *----------------------------------------------------------------*
      * PROGRAM:    MAHCCVL0                                        *
      * PURPOSE:    HCC Diagnosis Validation Subprogram             *
      * CALLED BY:  MAENCDR0                                        *
      * JAVA EQ:    HccValidationService.java                       *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MAHCCVL0.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SQLCODE              PIC S9(09) COMP VALUE +0.
       01  WS-HCC-FOUND            PIC X(01)      VALUE 'N'.
       01  WS-VALIDATE-COUNT       PIC S9(04) COMP VALUE +0.

           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL
               DECLARE MA_HCC_CROSSWALK TABLE
               ( ICD10_CODE      CHAR(7)    NOT NULL,
                 HCC_CODE        CHAR(4)    NOT NULL,
                 HCC_LABEL       CHAR(60)   NOT NULL,
                 RAF_COEFFICIENT DECIMAL(8,6) NOT NULL,
                 EFF_DATE        CHAR(8)    NOT NULL,
                 TERM_DATE       CHAR(8),
                 MODEL_YEAR      CHAR(4)    NOT NULL )
           END-EXEC.

       LINKAGE SECTION.
           COPY MAENROLL.
           COPY MAHCCREC.
       01  LS-RETURN-CODE          PIC S9(04) COMP.

       PROCEDURE DIVISION USING MA-ENROLLMENT-RECORD
                                MA-HCC-RECORD
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           MOVE MAE-HICN  TO MHCC-HICN
           MOVE MAE-MBI   TO MHCC-MBI
           PERFORM 1000-VALIDATE-HCC-CODES
           GOBACK
           .

       1000-VALIDATE-HCC-CODES.
           EXEC SQL
               SELECT H.HCC_CODE,
                      H.HCC_LABEL,
                      H.RAF_COEFFICIENT,
                      H.ICD10_CODE
                 INTO :MHCC-HCC-CODE,
                      :MHCC-HCC-LABEL,
                      :MHCC-RAF-COEFFICIENT,
                      :MHCC-ICD10-CODE
                 FROM MA_HCC_CROSSWALK H
                WHERE H.ICD10_CODE  = :MHCC-ICD10-CODE
                  AND H.MODEL_YEAR  = :MHCC-MODEL-YEAR
                  AND H.EFF_DATE   <= :MHCC-DOS-FROM
                  AND (H.TERM_DATE >= :MHCC-DOS-THRU
                        OR H.TERM_DATE IS NULL)
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   MOVE 'VA' TO MHCC-VALIDATION-STATUS
               WHEN 100
                   MOVE 'IN' TO MHCC-VALIDATION-STATUS
                   MOVE +4   TO LS-RETURN-CODE
               WHEN OTHER
                   MOVE 'IN' TO MHCC-VALIDATION-STATUS
                   MOVE +8   TO LS-RETURN-CODE
           END-EVALUATE
           .

       1100-CHECK-HIERARCHY.
           PERFORM 1110-SET-HIERARCHY-FLAG
           .

       1110-SET-HIERARCHY-FLAG.
           IF MHCC-HIERARCHICAL-HCC NOT = SPACES
               MOVE 'Y' TO MHCC-HIERARCHY-IND
           ELSE
               MOVE 'N' TO MHCC-HIERARCHY-IND
           END-IF
           .
