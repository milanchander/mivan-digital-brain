      *----------------------------------------------------------------*
      * PROGRAM:    MAENCDR0                                        *
      * PURPOSE:    MA Encounter Data Processing Driver             *
      * DOMAIN:     Medicare Advantage                              *
      *                                                             *
      * FLOW:                                                        *
      *   1. MAELGCK0 - Eligibility verification                   *
      *   2. MAHCCVL0 - HCC diagnosis validation                   *
      *   3. MARAFCL0 - RAF score calculation                      *
      *   4. MAENCBL0 - Encounter record build                     *
      *   5. MAEDPSUB0 - EDPS submission                           *
      *                                                             *
      * JAVA EQUIVALENT: EncounterDataOrchestrator.java            *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MAENCDR0.
       AUTHOR.        MIVAN HEALTH PLAN.
       DATE-WRITTEN.  2026-08-08.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ENROLL-FILE    ASSIGN TO MAENROLL
                                 ORGANIZATION IS SEQUENTIAL
                                 ACCESS MODE  IS SEQUENTIAL
                                 FILE STATUS  IS WS-ENROLL-FS.

           SELECT STAGING-FILE   ASSIGN TO MAENCSTG
                                 ORGANIZATION IS SEQUENTIAL
                                 ACCESS MODE  IS SEQUENTIAL
                                 FILE STATUS  IS WS-STAGE-FS.

           SELECT REPORT-FILE    ASSIGN TO MAENCDRR
                                 ORGANIZATION IS SEQUENTIAL
                                 ACCESS MODE  IS SEQUENTIAL
                                 FILE STATUS  IS WS-REPORT-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  ENROLL-FILE
           LABEL RECORDS ARE STANDARD
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  ENROLL-RECORD           PIC X(150).

       FD  STAGING-FILE
           LABEL RECORDS ARE STANDARD
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  STAGING-RECORD          PIC X(400).

       FD  REPORT-FILE
           LABEL RECORDS ARE STANDARD
           RECORDING MODE IS F.
       01  REPORT-RECORD           PIC X(133).

       WORKING-STORAGE SECTION.
      *--- File status fields ---
       01  WS-FILE-STATUSES.
           05  WS-ENROLL-FS        PIC X(02) VALUE SPACES.
           05  WS-STAGE-FS         PIC X(02) VALUE SPACES.
           05  WS-REPORT-FS        PIC X(02) VALUE SPACES.

      *--- Switch / indicator fields ---
       01  WS-SWITCHES.
           05  WS-EOF-ENROLL       PIC X(01) VALUE 'N'.
               88  END-OF-ENROLL   VALUE 'Y'.
           05  WS-ABEND-IND        PIC X(01) VALUE 'N'.
               88  ABEND-REQUESTED VALUE 'Y'.

      *--- Counters ---
       01  WS-COUNTERS.
           05  WS-INPUT-CNT        PIC 9(09) VALUE ZEROS.
           05  WS-ELIGIBLE-CNT     PIC 9(09) VALUE ZEROS.
           05  WS-INELIGIBLE-CNT   PIC 9(09) VALUE ZEROS.
           05  WS-HCC-VALID-CNT    PIC 9(09) VALUE ZEROS.
           05  WS-HCC-REJECT-CNT   PIC 9(09) VALUE ZEROS.
           05  WS-ENCOUNTER-CNT    PIC 9(09) VALUE ZEROS.
           05  WS-SUBMIT-CNT       PIC 9(09) VALUE ZEROS.
           05  WS-ERROR-CNT        PIC 9(09) VALUE ZEROS.

      *--- Return codes from subprograms ---
       01  WS-RETURN-CODES.
           05  WS-ELGCK-RC         PIC S9(04) COMP VALUE +0.
           05  WS-HCCVL-RC         PIC S9(04) COMP VALUE +0.
           05  WS-RAFCL-RC         PIC S9(04) COMP VALUE +0.
           05  WS-ENCBL-RC         PIC S9(04) COMP VALUE +0.
           05  WS-EDPSUB-RC        PIC S9(04) COMP VALUE +0.

      *--- Program return code ---
       01  WS-PROGRAM-RC           PIC S9(04) COMP VALUE +0.

      *--- Copybook data areas ---
           COPY MAENROLL.
           COPY MAHCCREC.
           COPY MARAFSCR.
           COPY MAENCSTG.

      *--- Report line area ---
       01  WS-REPORT-LINE.
           05  WRL-TYPE            PIC X(02).
           05  WRL-HICN            PIC X(12).
           05  WRL-MBI             PIC X(11).
           05  WRL-STATUS          PIC X(10).
           05  WRL-RC              PIC S9(04).
           05  WRL-MSG             PIC X(94).

       01  WS-RPT-HDR.
           05  FILLER              PIC X(10) VALUE 'MAENCDR0  '.
           05  FILLER              PIC X(30)
               VALUE 'MA ENCOUNTER PROCESSING REPORT'.
           05  FILLER              PIC X(10) VALUE SPACES.
           05  WS-RPT-DATE         PIC X(08).
           05  FILLER              PIC X(75) VALUE SPACES.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS
              UNTIL END-OF-ENROLL
           PERFORM 9000-TERMINATE
           STOP RUN
           .

       1000-INITIALIZE.
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-RPT-DATE
           OPEN INPUT  ENROLL-FILE
           OPEN OUTPUT STAGING-FILE
           OPEN OUTPUT REPORT-FILE
           IF WS-ENROLL-FS NOT = '00'
               MOVE +16 TO WS-PROGRAM-RC
               PERFORM 9800-FILE-OPEN-ERROR
           END-IF
           WRITE REPORT-RECORD FROM WS-RPT-HDR
           PERFORM 1100-READ-ENROLL
           .

       1100-READ-ENROLL.
           READ ENROLL-FILE INTO MA-ENROLLMENT-RECORD
               AT END
                   MOVE 'Y' TO WS-EOF-ENROLL
               NOT AT END
                   ADD +1 TO WS-INPUT-CNT
           END-READ
           .

       2000-PROCESS.
           PERFORM 2100-CALL-ELGCK
           IF WS-ELGCK-RC = +0
               ADD +1 TO WS-ELIGIBLE-CNT
               PERFORM 2200-CALL-HCCVL
               IF WS-HCCVL-RC = +0
                   ADD +1 TO WS-HCC-VALID-CNT
                   PERFORM 2300-CALL-RAFCL
                   PERFORM 2400-CALL-ENCBL
                   IF WS-ENCBL-RC = +0
                       ADD +1 TO WS-ENCOUNTER-CNT
                       PERFORM 2500-CALL-EDPSUB
                   END-IF
               ELSE
                   ADD +1 TO WS-HCC-REJECT-CNT
               END-IF
           ELSE
               ADD +1 TO WS-INELIGIBLE-CNT
           END-IF
           PERFORM 1100-READ-ENROLL
           .

       2100-CALL-ELGCK.
           CALL 'MAELGCK0' USING MA-ENROLLMENT-RECORD
                                 WS-ELGCK-RC
           IF WS-ELGCK-RC NOT = +0
               ADD +1 TO WS-ERROR-CNT
           END-IF
           .

       2200-CALL-HCCVL.
           CALL 'MAHCCVL0' USING MA-ENROLLMENT-RECORD
                                 MA-HCC-RECORD
                                 WS-HCCVL-RC
           IF WS-HCCVL-RC NOT = +0
               ADD +1 TO WS-ERROR-CNT
           END-IF
           .

       2300-CALL-RAFCL.
           CALL 'MARAFCL0' USING MA-HCC-RECORD
                                 MA-RAF-SCORE-RECORD
                                 WS-RAFCL-RC
           IF WS-RAFCL-RC NOT = +0
               ADD +1 TO WS-ERROR-CNT
           END-IF
           .

       2400-CALL-ENCBL.
           CALL 'MAENCBL0' USING MA-ENROLLMENT-RECORD
                                 MA-HCC-RECORD
                                 MA-RAF-SCORE-RECORD
                                 MA-ENCOUNTER-STAGING
                                 WS-ENCBL-RC
           IF WS-ENCBL-RC NOT = +0
               ADD +1 TO WS-ERROR-CNT
           END-IF
           .

       2500-CALL-EDPSUB.
           CALL 'MAEDPSUB0' USING MA-ENCOUNTER-STAGING
                                  WS-EDPSUB-RC
           IF WS-EDPSUB-RC = +0
               ADD +1 TO WS-SUBMIT-CNT
           ELSE
               ADD +1 TO WS-ERROR-CNT
           END-IF
           .

       9000-TERMINATE.
           CLOSE ENROLL-FILE
           CLOSE STAGING-FILE
           CLOSE REPORT-FILE
           IF WS-ERROR-CNT > +0
               MOVE +8 TO WS-PROGRAM-RC
           END-IF
           MOVE WS-PROGRAM-RC TO RETURN-CODE
           .

       9800-FILE-OPEN-ERROR.
           DISPLAY 'MAENCDR0 - FILE OPEN ERROR: '
                   WS-ENROLL-FS
           MOVE +16 TO RETURN-CODE
           STOP RUN
           .
