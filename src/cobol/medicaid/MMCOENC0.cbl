      *----------------------------------------------------------------*
      * PROGRAM:    MMCOENC0                                         *
      * PURPOSE:    State MMIS Encounter Record Builder Subprogram   *
      * CALLED BY:  MMCOCLDR0                                        *
      * JAVA EQ:    EncounterBuildService.java                       *
      *                                                              *
      * Builds state MMIS encounter record including TPL and         *
      * Medicaid liability detail. Applies state-specific edits      *
      * per STATE_CONTRACT before writing to staging ESDS.           *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MMCOENC0.
       AUTHOR.        MIVAN HEALTH PLAN.
       DATE-WRITTEN.  2026-08-08.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-PROV-NPI                 PIC X(10) VALUE SPACES.
       01  WS-DOS-FROM                 PIC 9(8)  VALUE 0.
       01  WS-DOS-TO                   PIC 9(8)  VALUE 0.
       01  WS-DIAG-1                   PIC X(7)  VALUE SPACES.
       01  WS-PROC-CD                  PIC X(5)  VALUE SPACES.
       01  WS-BILLED-AMT               PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-STATE-CD-WS              PIC X(2)  VALUE SPACES.
       01  WS-MCO-ID-WS                PIC X(10) VALUE SPACES.
       01  WS-MEMBER-ID-WS             PIC X(15) VALUE SPACES.
       01  WS-ENCOUNTER-DUE-DAYS       PIC 9(3)  VALUE 0.

       LINKAGE SECTION.
       01  LS-CLAIM-ID                 PIC X(20).
           COPY MMCOLIAB.
           COPY MMCOENCR.
       01  LS-RETURN-CODE              PIC S9(4) COMP.

       PROCEDURE DIVISION USING LS-CLAIM-ID
                                MEDICAID-LIAB-REC
                                MEDICAID-ENC-STAGE-REC
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           MOVE LS-CLAIM-ID      TO MC-ENC-CLAIM-ID
           PERFORM 3000-GET-CLAIM-DETAIL
           PERFORM 3100-GET-STATE-CONTRACT
           PERFORM 3200-FORMAT-MMIS-ENCOUNTER
           PERFORM 3300-APPLY-STATE-EDITS
           PERFORM 4000-STAGE-ENCOUNTER
           GOBACK
           .

       3000-GET-CLAIM-DETAIL.
      * Retrieve claim header details needed for MMIS encounter.
           EXEC SQL
               SELECT CH.MEMBER_ID,
                      CH.PROV_NPI,
                      CH.DOS_FROM,
                      CH.DOS_TO,
                      CH.DIAG_1,
                      CH.PROC_CD,
                      CH.BILLED_AMT,
                      ME.STATE_CD,
                      ME.MCO_ID
                 INTO :WS-MEMBER-ID-WS,
                      :WS-PROV-NPI,
                      :WS-DOS-FROM,
                      :WS-DOS-TO,
                      :WS-DIAG-1,
                      :WS-PROC-CD,
                      :WS-BILLED-AMT,
                      :WS-STATE-CD-WS,
                      :WS-MCO-ID-WS
                 FROM MIVANCPS.CLAIM_HEADER CH
                 JOIN MIVANCPS.MEDICAID_ELIGIBILITY ME
                   ON CH.MEMBER_ID = ME.MEMBER_ID
                WHERE CH.CLAIM_ID = :LS-CLAIM-ID
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE +8 TO LS-RETURN-CODE
           END-IF
           .

       3100-GET-STATE-CONTRACT.
      * Get encounter submission rules from STATE_CONTRACT.
      * Encounter timeliness rules vary by state.
           EXEC SQL
               SELECT ENCOUNTER_DUE_DAYS
                 INTO :WS-ENCOUNTER-DUE-DAYS
                 FROM MIVANCPS.STATE_CONTRACT
                WHERE STATE_CD = :WS-STATE-CD-WS
                  AND MCO_ID   = :WS-MCO-ID-WS
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 90 TO WS-ENCOUNTER-DUE-DAYS
           END-IF
           .

       3200-FORMAT-MMIS-ENCOUNTER.
      * Populate the MMIS encounter staging record.
           MOVE WS-MEMBER-ID-WS    TO MC-ENC-MEMBER-ID
           MOVE WS-STATE-CD-WS     TO MC-ENC-STATE-CD
           MOVE WS-MCO-ID-WS       TO MC-ENC-MCO-ID
           MOVE WS-PROV-NPI        TO MC-ENC-PROV-NPI
           MOVE WS-DOS-FROM        TO MC-ENC-DOS-FROM
           MOVE WS-DOS-TO          TO MC-ENC-DOS-TO
           MOVE WS-DIAG-1          TO MC-ENC-DIAG-1
           MOVE WS-PROC-CD         TO MC-ENC-PROC-CD
           MOVE WS-BILLED-AMT      TO MC-ENC-BILLED-AMT
           MOVE MC-MEDICAID-AMT    TO MC-ENC-PAID-AMT
           MOVE MC-TPL-PAID-AMT    TO MC-ENC-TPL-AMT
           MOVE 'ST'               TO MC-ENC-STATUS
           .

       3300-APPLY-STATE-EDITS.
      * Apply state-specific validation edits before staging.
      * State MMIS systems have unique edit requirements.
           IF MC-ENC-PROV-NPI = SPACES
               MOVE +4 TO LS-RETURN-CODE
           END-IF
           IF MC-ENC-DIAG-1 = SPACES
               MOVE +4 TO LS-RETURN-CODE
           END-IF
           .

       4000-STAGE-ENCOUNTER.
      * Insert encounter into staging table for MMCOSSUB0 to submit.
           EXEC SQL
               INSERT INTO MIVANCPS.MEDICAID_ENCOUNTER_STAGING
               (CLAIM_ID, MEMBER_ID, STATE_CD, MCO_ID,
                PROV_NPI, DOS_FROM, DOS_TO,
                DIAG_1, PROC_CD, BILLED_AMT, PAID_AMT,
                TPL_AMT, STATUS)
               VALUES
               (:MC-ENC-CLAIM-ID, :MC-ENC-MEMBER-ID,
                :MC-ENC-STATE-CD, :MC-ENC-MCO-ID,
                :MC-ENC-PROV-NPI, :MC-ENC-DOS-FROM,
                :MC-ENC-DOS-TO, :MC-ENC-DIAG-1,
                :MC-ENC-PROC-CD, :MC-ENC-BILLED-AMT,
                :MC-ENC-PAID-AMT, :MC-ENC-TPL-AMT,
                :MC-ENC-STATUS)
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE +8 TO LS-RETURN-CODE
           END-IF
           .
