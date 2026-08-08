      *----------------------------------------------------------------*
      * PROGRAM:    MMCOSSUB0                                        *
      * PURPOSE:    State MMIS Submission Subprogram                 *
      * CALLED BY:  MMCOCLDR0 (indirectly via JCL STEP050)          *
      * JAVA EQ:    StateSubmissionService.java                      *
      *                                                              *
      * Submits encounter staging file to state MMIS per state       *
      * contract requirements. Reads MEDICAID-ENCOUNTER-STAGE        *
      * ESDS, applies final state edits, writes to state output,     *
      * and generates submission report.                             *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MMCOSSUB0.
       AUTHOR.        MIVAN HEALTH PLAN.
       DATE-WRITTEN.  2026-08-08.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT STAGING-INPUT
               ASSIGN TO MMCOENCR
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-STAGE-FS.

           SELECT STATE-OUTPUT
               ASSIGN TO MMCOSTOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-STATE-FS.

           SELECT SUBMIT-REPORT
               ASSIGN TO MMCOSRPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-RPT-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  STAGING-INPUT
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  STAGING-IN-REC              PIC X(256).

       FD  STATE-OUTPUT
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  STATE-OUT-REC               PIC X(512).

       FD  SUBMIT-REPORT
           RECORDING MODE IS F.
       01  REPORT-LINE                 PIC X(133).

       WORKING-STORAGE SECTION.

           EXEC SQL INCLUDE SQLCA END-EXEC.
           COPY MMCOENCR.

       01  WS-FILE-STATUS.
           05  WS-STAGE-FS             PIC X(2) VALUE SPACES.
           05  WS-STATE-FS             PIC X(2) VALUE SPACES.
           05  WS-RPT-FS               PIC X(2) VALUE SPACES.

       01  WS-COUNTERS.
           05  WS-RECORDS-READ         PIC 9(9) COMP VALUE 0.
           05  WS-RECORDS-WRITTEN      PIC 9(9) COMP VALUE 0.
           05  WS-RECORDS-REJECTED     PIC 9(9) COMP VALUE 0.
           05  WS-EDIT-ERRORS          PIC 9(7) COMP VALUE 0.

       01  WS-FLAGS.
           05  WS-EOF-FLAG             PIC X(1) VALUE 'N'.
               88  END-OF-FILE                  VALUE 'Y'.
           05  WS-EDIT-PASS-FLAG       PIC X(1) VALUE 'N'.
               88  EDITS-PASSED                 VALUE 'Y'.

       01  WS-STATE-RULES.
           05  WS-TIMELY-DAYS          PIC 9(3) VALUE 90.
           05  WS-ENCOUNTER-DUE        PIC 9(3) VALUE 90.
           05  WS-STATE-FORMAT         PIC X(3) VALUE '837'.

       01  WS-RETURN-CODE              PIC S9(4) COMP VALUE 0.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS
               UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN
           .

       1000-INIT.
           OPEN INPUT  STAGING-INPUT
           OPEN OUTPUT STATE-OUTPUT
           OPEN OUTPUT SUBMIT-REPORT
           IF WS-STAGE-FS NOT = '00'
               DISPLAY 'MMCOSSUB0: STAGING INPUT OPEN FAILED'
               MOVE 16 TO RETURN-CODE
               STOP RUN
           END-IF
           PERFORM 1100-READ-STAGING
           .

       1100-READ-STAGING.
           READ STAGING-INPUT INTO MEDICAID-ENC-STAGE-REC
               AT END
                   MOVE 'Y' TO WS-EOF-FLAG
               NOT AT END
                   ADD 1 TO WS-RECORDS-READ
           END-READ
           .

       2000-PROCESS.
           PERFORM 3000-READ-STAGING-FILE
           IF EDITS-PASSED
               PERFORM 3200-FORMAT-STATE-RECORD
               PERFORM 4000-WRITE-STATE-OUTPUT
           ELSE
               ADD 1 TO WS-RECORDS-REJECTED
           END-IF
           PERFORM 1100-READ-STAGING
           .

       3000-READ-STAGING-FILE.
      * Validate staged record before state submission.
           MOVE 'Y' TO WS-EDIT-PASS-FLAG
           PERFORM 3100-GET-STATE-SUBMISSION-RULES
           PERFORM 3300-VALIDATE-STATE-EDITS
           .

       3100-GET-STATE-SUBMISSION-RULES.
      * Get state-specific submission format requirements.
      * Each state MMIS has different file format expectations.
           EXEC SQL
               SELECT ENCOUNTER_DUE_DAYS,
                      TIMELY_FILING_DAYS
                 INTO :WS-ENCOUNTER-DUE,
                      :WS-TIMELY-DAYS
                 FROM MIVANCPS.STATE_CONTRACT
                WHERE STATE_CD = :MC-ENC-STATE-CD
                  AND MCO_ID   = :MC-ENC-MCO-ID
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 90 TO WS-ENCOUNTER-DUE
               MOVE 90 TO WS-TIMELY-DAYS
           END-IF
           .

       3200-FORMAT-STATE-RECORD.
      * Format encounter for state MMIS submission.
      * State output format is 837-based but state-specific.
           MOVE SPACES TO STATE-OUT-REC
           STRING MC-ENC-CLAIM-ID  DELIMITED SIZE
                  MC-ENC-MEMBER-ID DELIMITED SIZE
                  MC-ENC-PROV-NPI  DELIMITED SIZE
                  INTO STATE-OUT-REC
           .

       3300-VALIDATE-STATE-EDITS.
      * Apply mandatory state edit checks before submission.
           IF MC-ENC-MEMBER-ID = SPACES
               MOVE 'N' TO WS-EDIT-PASS-FLAG
               ADD 1 TO WS-EDIT-ERRORS
           END-IF
           IF MC-ENC-PROV-NPI = SPACES
               MOVE 'N' TO WS-EDIT-PASS-FLAG
               ADD 1 TO WS-EDIT-ERRORS
           END-IF
           IF MC-ENC-DOS-FROM = 0
               MOVE 'N' TO WS-EDIT-PASS-FLAG
               ADD 1 TO WS-EDIT-ERRORS
           END-IF
           .

       4000-WRITE-STATE-OUTPUT.
           WRITE STATE-OUT-REC
           IF WS-STATE-FS NOT = '00'
               DISPLAY 'MMCOSSUB0: STATE OUTPUT WRITE FAILED'
               MOVE 8 TO WS-RETURN-CODE
           ELSE
               ADD 1 TO WS-RECORDS-WRITTEN
               PERFORM 4100-GENERATE-SUBMISSION-REPORT
           END-IF
           .

       4100-GENERATE-SUBMISSION-REPORT.
      * Write submission audit record to report file.
           MOVE MC-ENC-CLAIM-ID TO REPORT-LINE
           WRITE REPORT-LINE
           .

       9000-FINALIZE.
           CLOSE STAGING-INPUT
           CLOSE STATE-OUTPUT
           CLOSE SUBMIT-REPORT
           DISPLAY 'MMCOSSUB0 COMPLETE'
           DISPLAY 'RECORDS READ:     ' WS-RECORDS-READ
           DISPLAY 'RECORDS WRITTEN:  ' WS-RECORDS-WRITTEN
           DISPLAY 'RECORDS REJECTED: ' WS-RECORDS-REJECTED
           DISPLAY 'EDIT ERRORS:      ' WS-EDIT-ERRORS
           MOVE WS-RETURN-CODE TO RETURN-CODE
           .
