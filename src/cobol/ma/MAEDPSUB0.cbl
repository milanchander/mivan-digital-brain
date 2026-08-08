      *----------------------------------------------------------------*
      * PROGRAM:    MAEDPSUB0                                       *
      * PURPOSE:    EDPS Encounter Submission Subprogram            *
      * CALLED BY:  MAENCDR0                                        *
      * JAVA EQ:    EdpsSubmissionService.java                      *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MAEDPSUB0.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SQLCODE              PIC S9(09) COMP VALUE +0.
       01  WS-SUBMIT-DATE          PIC X(08)      VALUE SPACES.
       01  WS-MQ-CC                PIC S9(04) COMP VALUE +0.
       01  WS-EDPS-RESPONSE        PIC X(23)      VALUE SPACES.

           EXEC SQL INCLUDE SQLCA END-EXEC.

       LINKAGE SECTION.
           COPY MAENCSTG.
       01  LS-RETURN-CODE          PIC S9(04) COMP.

       PROCEDURE DIVISION USING MA-ENCOUNTER-STAGING
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           PERFORM 1000-VALIDATE-STAGING-RECORD
           IF LS-RETURN-CODE = +0
               PERFORM 2000-SUBMIT-TO-EDPS
               PERFORM 3000-UPDATE-STAGING-STATUS
           END-IF
           GOBACK
           .

       1000-VALIDATE-STAGING-RECORD.
           IF MEST-MBI = SPACES
               MOVE +4 TO LS-RETURN-CODE
           END-IF
           IF MEST-CONTRACT-ID = SPACES
               MOVE +4 TO LS-RETURN-CODE
           END-IF
           IF MEST-DOS-FROM = SPACES
               MOVE +4 TO LS-RETURN-CODE
           END-IF
           .

       2000-SUBMIT-TO-EDPS.
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-SUBMIT-DATE
           MOVE WS-SUBMIT-DATE TO MEST-SUBMIT-DATE
           MOVE 'SU' TO MEST-SUBMISSION-STATUS
           .

       3000-UPDATE-STAGING-STATUS.
           EXEC SQL
               UPDATE MA_ENCOUNTER_STAGING
                  SET SUBMISSION_STATUS = :MEST-SUBMISSION-STATUS,
                      SUBMIT_DATE       = :MEST-SUBMIT-DATE
                WHERE ENCOUNTER_ID = :MEST-ENCOUNTER-ID
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE +8 TO LS-RETURN-CODE
           END-IF
           .

       3100-HANDLE-EDPS-RESPONSE.
           EVALUATE MEST-SUBMISSION-STATUS
               WHEN 'AC'
                   CONTINUE
               WHEN 'RJ'
                   MOVE +4 TO LS-RETURN-CODE
               WHEN OTHER
                   MOVE +8 TO LS-RETURN-CODE
           END-EVALUATE
           .
