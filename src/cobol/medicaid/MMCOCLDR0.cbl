      *================================================================*
      * PROGRAM:    MMCOCLDR0                                        *
      * PURPOSE:    Medicaid Claim Processing Driver                 *
      * AUTHOR:     MIVAN HEALTH PLAN                                *
      * DATE:       2026-08-08                                       *
      *                                                              *
      * PURPOSE: Orchestrates Medicaid claim processing pipeline.    *
      *          Verifies Medicaid eligibility, identifies TPL       *
      *          payers, applies payer-of-last-resort logic,         *
      *          calculates Medicaid liability, builds encounter      *
      *          records, and submits to state MMIS.                 *
      *                                                              *
      * PROGRAM TREE:                                                *
      *   MMCOCLDR0 (this driver)                                    *
      *   +-- MMCOELV0  Medicaid eligibility verification            *
      *   +-- MMCOTPL0  Third party liability identification         *
      *   +-- MMCOLRP0  Payer of last resort calculation             *
      *   +-- MMCOENC0  Encounter record builder                     *
      *   +-- MMCOSSUB0 State MMIS submission                       *
      *                                                              *
      * DB2 TABLES ACCESSED:                                         *
      *   MEDICAID_ELIGIBILITY  - State Medicaid eligibility         *
      *   STATE_CONTRACT        - MCO state contract terms           *
      *   TPL_PAYER_FILE        - Known TPL payers by member         *
      *   TPL_RESULT            - TPL calculation results            *
      *   MEDICAID_LIABILITY    - Final Medicaid payment amounts      *
      *   CLAIM_HEADER          - Source claim records               *
      *   CLAIM_PAYMENT         - Primary payer payment amounts      *
      *                                                              *
      * VSAM FILES:                                                   *
      *   MEDICAID-ENCOUNTER-STAGE (ESDS)                            *
      *                                                              *
      * JCL JOB: MMCOJB00                                            *
      * SCHEDULE: Nightly - after MADJMN00 completes                 *
      * UPSTREAM:   MADJMN00 (adjudication)                          *
      * DOWNSTREAM: State MMIS submission                            *
      *                                                              *
      * KEY COMPLEXITY:                                               *
      *   Monthly eligibility churn - members may gain/lose          *
      *   eligibility between claim submission and processing.        *
      *   Retroactive eligibility changes trigger reprocessing.       *
      *   Medicaid is ALWAYS payer of last resort - federal law.     *
      *   42 CFR 433.139                                             *
      *                                                              *
      * JAVA EQUIVALENT: MedicaidClaimOrchestrator.java             *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MMCOCLDR0.
       AUTHOR.        MIVAN HEALTH PLAN.
       DATE-WRITTEN.  2026-08-08.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MEDICAID-ENCOUNTER-STAGE
               ASSIGN TO MMCOENCR
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-ENCSTG-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  MEDICAID-ENCOUNTER-STAGE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  ENC-STAGE-RECORD            PIC X(256).

       WORKING-STORAGE SECTION.

           COPY MMCOELIG.
           COPY MMCOTPLR.
           COPY MMCOLIAB.
           COPY MMCOENCR.

       01  WS-PROGRAM-CONSTANTS.
           05  WS-PROGRAM-ID           PIC X(8)  VALUE 'MMCOCLDR0'.
           05  WS-LAST-RESORT-IND      PIC X(1)  VALUE 'Y'.

       01  WS-FILE-STATUS.
           05  WS-ENCSTG-STATUS        PIC X(2)  VALUE SPACES.

       01  WS-HOST-VARIABLES.
           05  WS-CLAIM-ID             PIC X(20).
           05  WS-MEMBER-ID            PIC X(15).
           05  WS-PROV-NPI             PIC X(10).
           05  WS-DOS-FROM             PIC X(10).
           05  WS-DOS-TO               PIC X(10).
           05  WS-STATE-CD             PIC X(2).
           05  WS-MCO-ID               PIC X(10).
           05  WS-DUAL-ELIG-IND        PIC X(1).
           05  WS-EPSDT-IND            PIC X(1).

       01  WS-COUNTERS.
           05  WS-CLAIMS-READ          PIC 9(9)  COMP VALUE 0.
           05  WS-ELIG-VALID           PIC 9(9)  COMP VALUE 0.
           05  WS-ELIG-REJECT          PIC 9(9)  COMP VALUE 0.
           05  WS-TPL-FOUND            PIC 9(9)  COMP VALUE 0.
           05  WS-TPL-NOT-FOUND        PIC 9(9)  COMP VALUE 0.
           05  WS-MC-LIABILITY         PIC 9(9)  COMP VALUE 0.
           05  WS-ENC-BUILT            PIC 9(9)  COMP VALUE 0.
           05  WS-STATE-SUBMIT         PIC 9(9)  COMP VALUE 0.
           05  WS-ERRORS               PIC 9(7)  COMP VALUE 0.

       01  WS-FLAGS.
           05  WS-EOF-FLAG             PIC X(1)  VALUE 'N'.
               88  END-OF-FILE                   VALUE 'Y'.
           05  WS-MC-ELIG-FLAG         PIC X(1)  VALUE 'N'.
               88  MC-ELIGIBLE                   VALUE 'Y'.
           05  WS-TPL-FLAG             PIC X(1)  VALUE 'N'.
               88  TPL-EXISTS                    VALUE 'Y'.

       01  WS-RETURN-CODE              PIC S9(4) COMP VALUE 0.
       01  WS-ABEND-MSG                PIC X(80) VALUE SPACES.

           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL
               DECLARE MEDICAID_ELIGIBILITY TABLE
               (MEMBER_ID        CHAR(15)       NOT NULL,
                STATE_CD         CHAR(2)        NOT NULL,
                AID_CATEGORY     CHAR(4),
                ELIG_FROM_DT     DATE           NOT NULL,
                ELIG_TO_DT       DATE,
                MCO_ID           CHAR(10),
                PLAN_TYPE        CHAR(4),
                DUAL_ELIG_IND    CHAR(1),
                SPEND_DOWN_IND   CHAR(1),
                SPEND_DOWN_AMT   DECIMAL(9,2),
                CHIP_IND         CHAR(1),
                EPSDT_IND        CHAR(1),
                STATUS_CD        CHAR(2))
           END-EXEC.

           EXEC SQL
               DECLARE TPL_PAYER_FILE TABLE
               (MEMBER_ID        CHAR(15)       NOT NULL,
                PAYER_ID         CHAR(10)       NOT NULL,
                PAYER_NAME       VARCHAR(40),
                POLICY_NO        CHAR(20),
                EFFECTIVE_DT     DATE,
                TERM_DT          DATE,
                STATUS_CD        CHAR(2))
           END-EXEC.

           EXEC SQL
               DECLARE STATE_CONTRACT TABLE
               (STATE_CD         CHAR(2)        NOT NULL,
                MCO_ID           CHAR(10)       NOT NULL,
                CONTRACT_ID      CHAR(15),
                CAPITATION_RATE  DECIMAL(9,2),
                TIMELY_FILING_DAYS INTEGER,
                ENCOUNTER_DUE_DAYS INTEGER,
                EFFECTIVE_DT     DATE,
                TERM_DT          DATE)
           END-EXEC.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS
               UNTIL END-OF-FILE
           PERFORM 9000-FINALIZE
           STOP RUN
           .

       1000-INIT.
      * Initialize counters, open files, establish cursors
           OPEN OUTPUT MEDICAID-ENCOUNTER-STAGE
           IF WS-ENCSTG-STATUS NOT = '00'
               MOVE 'OPEN FAILED: MEDICAID-ENCOUNTER-STAGE'
                   TO WS-ABEND-MSG
               PERFORM 9999-ABEND
           END-IF
           EXEC SQL
               DECLARE MC-CLAIM-CURSOR CURSOR FOR
               SELECT CH.CLAIM_ID,
                      CH.MEMBER_ID,
                      CH.PROV_NPI,
                      CH.DOS_FROM,
                      CH.DOS_TO,
                      ME.STATE_CD,
                      ME.MCO_ID,
                      ME.DUAL_ELIG_IND,
                      ME.EPSDT_IND
               FROM   MIVANCPS.CLAIM_HEADER CH
               INNER JOIN MIVANCPS.MEDICAID_ELIGIBILITY ME
                      ON CH.MEMBER_ID = ME.MEMBER_ID
               WHERE  CH.STATUS_CD  = 'PD'
               AND    ME.STATUS_CD  = 'AC'
               AND    CH.DOS_FROM BETWEEN ME.ELIG_FROM_DT
                                      AND ME.ELIG_TO_DT
           END-EXEC
           EXEC SQL OPEN MC-CLAIM-CURSOR END-EXEC
           IF SQLCODE NOT = 0
               MOVE 'CURSOR OPEN FAILED: MC-CLAIM-CURSOR'
                   TO WS-ABEND-MSG
               PERFORM 9999-ABEND
           END-IF
           .

       2000-PROCESS.
      * Main processing loop — mirrors MedicaidClaimOrchestrator
           EXEC SQL
               FETCH MC-CLAIM-CURSOR
               INTO :WS-CLAIM-ID,
                    :WS-MEMBER-ID,
                    :WS-PROV-NPI,
                    :WS-DOS-FROM,
                    :WS-DOS-TO,
                    :WS-STATE-CD,
                    :WS-MCO-ID,
                    :WS-DUAL-ELIG-IND,
                    :WS-EPSDT-IND
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   ADD 1 TO WS-CLAIMS-READ
                   PERFORM 3000-VERIFY-MC-ELIGIBILITY
                   IF MC-ELIGIBLE
                       PERFORM 3100-IDENTIFY-TPL
                       PERFORM 3200-APPLY-LAST-RESORT
                       PERFORM 4000-BUILD-ENCOUNTER
                       PERFORM 4100-WRITE-ENCOUNTER
                   END-IF
               WHEN +100
                   MOVE 'Y' TO WS-EOF-FLAG
               WHEN OTHER
                   ADD 1 TO WS-ERRORS
                   PERFORM 9100-LOG-DB2-ERROR
           END-EVALUATE
           .

       3000-VERIFY-MC-ELIGIBILITY.
      * Verify Medicaid eligibility — handles monthly churn.
      * KEY COMPLEXITY: Medicaid eligibility changes monthly.
      * A member active today may have been inactive on DOS.
      * Retroactive eligibility handled by MRETROE0.
      * Java: MedicaidEligibilityService.verifyEligibility()
           MOVE 'N' TO WS-MC-ELIG-FLAG
           CALL 'MMCOELV0' USING WS-MEMBER-ID
                                  WS-DOS-FROM
                                  WS-STATE-CD
                                  WS-MC-ELIG-FLAG
                                  WS-RETURN-CODE
           IF MC-ELIGIBLE
               ADD 1 TO WS-ELIG-VALID
           ELSE
               ADD 1 TO WS-ELIG-REJECT
           END-IF
           .

       3100-IDENTIFY-TPL.
      * Identify third party liability payers.
      * KEY RULE: Medicaid is ALWAYS payer of last resort.
      * All other coverage must pay before Medicaid.
      * Federal law — 42 CFR 433.139.
      * Java: ThirdPartyLiabilityService.identifyTpl()
           MOVE 'N' TO WS-TPL-FLAG
           CALL 'MMCOTPL0' USING WS-CLAIM-ID
                                  WS-MEMBER-ID
                                  WS-TPL-FLAG
                                  TPL-RESULT-REC
                                  WS-RETURN-CODE
           IF TPL-EXISTS
               ADD 1 TO WS-TPL-FOUND
           ELSE
               ADD 1 TO WS-TPL-NOT-FOUND
           END-IF
           .

       3200-APPLY-LAST-RESORT.
      * Calculate Medicaid liability as payer of last resort.
      * Java: PayerOfLastResortService.calculateMedicaidLiability()
           CALL 'MMCOLRP0' USING WS-CLAIM-ID
                                  TPL-RESULT-REC
                                  MEDICAID-LIAB-REC
                                  WS-RETURN-CODE
           ADD 1 TO WS-MC-LIABILITY
           .

       4000-BUILD-ENCOUNTER.
      * Build state MMIS encounter record.
      * Java: EncounterBuildService.buildEncounter()
           CALL 'MMCOENC0' USING WS-CLAIM-ID
                                  MEDICAID-LIAB-REC
                                  MEDICAID-ENC-STAGE-REC
                                  WS-RETURN-CODE
           .

       4100-WRITE-ENCOUNTER.
           WRITE ENC-STAGE-RECORD FROM MEDICAID-ENC-STAGE-REC
           IF WS-ENCSTG-STATUS NOT = '00'
               MOVE 'WRITE FAILED: MEDICAID-ENCOUNTER-STAGE'
                   TO WS-ABEND-MSG
               PERFORM 9999-ABEND
           END-IF
           ADD 1 TO WS-ENC-BUILT
           .

       9000-FINALIZE.
           EXEC SQL CLOSE MC-CLAIM-CURSOR END-EXEC
           CLOSE MEDICAID-ENCOUNTER-STAGE
           DISPLAY 'MMCOCLDR0 COMPLETE'
           DISPLAY 'CLAIMS READ:    ' WS-CLAIMS-READ
           DISPLAY 'ELIG VALID:     ' WS-ELIG-VALID
           DISPLAY 'ELIG REJECTED:  ' WS-ELIG-REJECT
           DISPLAY 'TPL FOUND:      ' WS-TPL-FOUND
           DISPLAY 'MC LIABILITY:   ' WS-MC-LIABILITY
           DISPLAY 'ENC BUILT:      ' WS-ENC-BUILT
           DISPLAY 'ERRORS:         ' WS-ERRORS
           MOVE WS-ERRORS TO RETURN-CODE
           .

       9100-LOG-DB2-ERROR.
           DISPLAY 'DB2 ERROR: SQLCODE=' SQLCODE
                   ' PROGRAM=' WS-PROGRAM-ID
           .

       9999-ABEND.
           DISPLAY 'ABEND: ' WS-ABEND-MSG
           MOVE 16 TO RETURN-CODE
           STOP RUN
           .
