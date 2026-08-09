      ******************************************************************
      * PROGRAM   : MPRVVLDR0                                          *
      * TITLE     : Provider Validation Driver                        *
      * SYSTEM    : MiCPS - Mivan Claims Processing System            *
      * DOMAIN    : Provider                                          *
      * LANGUAGE  : IBM Enterprise COBOL for z/OS 6.x                 *
      *--------------------------------------------------------------*
      * PROGRAM TREE : Provider Data Validation                       *
      *                                                              *
      *   MPRVVLDR0  (this program - driver)                         *
      *     +-- MPRVNPI0   NPI lookup                                *
      *     +-- MPRVCRD0   Credentialing check                       *
      *     +-- MPRVEXC0   Exclusion check   (OIG/SAM/state)         *
      *     +-- MPRVNET0   Network verification                      *
      *     +-- MPRVSANL0  Sanction logging  (always runs)           *
      *--------------------------------------------------------------*
      * FUNCTION  : Validates that a provider (identified by NPI) is  *
      *             eligible to be paid for a claim on a given date   *
      *             of service.  Runs the five-step validation        *
      *             sequence, short-circuiting immediately when the   *
      *             provider is found on any exclusion list.          *
      *--------------------------------------------------------------*
      * COMPLIANCE: 42 USC 1320a-7b prohibits payment to or on       *
      *             behalf of a provider excluded from federal        *
      *             healthcare programs.  The exclusion check         *
      *             (MPRVEXC0) is mandatory and its result is         *
      *             always written to the sanction log (MPRVSANL0).   *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MPRVVLDR0.
       AUTHOR.        MIVAN-DIGITAL-BRAIN.
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.
      *
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      *---------------------------------------------------------------*
      * PROV-MSTR : Provider Master VSAM KSDS, keyed on NPI.          *
      *---------------------------------------------------------------*
           SELECT PROV-MSTR
               ASSIGN TO PROVMSTR
               ORGANIZATION IS INDEXED
               ACCESS MODE  IS RANDOM
               RECORD KEY   IS PM-KEY-NPI
               FILE STATUS  IS WS-PROVMSTR-STATUS.
      *
       DATA DIVISION.
       FILE SECTION.
       FD  PROV-MSTR.
       01  PROV-MSTR-RECORD.
           05  PM-KEY-NPI          PIC X(10).
           05  PM-REST-OF-REC      PIC X(211).
      *
       WORKING-STORAGE SECTION.
      *---------------------------------------------------------------*
      * Copybooks                                                     *
      *---------------------------------------------------------------*
       COPY MPRVMSTR.
       COPY MPRVCRED.
       COPY MPRVEXCL.
       COPY MPRVNETW.
       COPY MPRVVLDR.
      *
      *---------------------------------------------------------------*
      * DB2 host-variable declarations (SQLCA + table declares)       *
      *---------------------------------------------------------------*
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
           EXEC SQL DECLARE PROVIDER_MASTER TABLE
              ( NPI            CHAR(10)   NOT NULL,
                NPI_TYPE       CHAR(1),
                TAX_ID         CHAR(9),
                LAST_NAME      CHAR(35),
                FIRST_NAME     CHAR(25),
                ORG_NAME       CHAR(60),
                TAXONOMY_1     CHAR(10),
                TAXONOMY_2     CHAR(10),
                SPECIALTY_CD   CHAR(4),
                NETWORK_STATUS CHAR(3),
                CONTRACT_ID    CHAR(15),
                NETWORK_TIER   CHAR(2),
                CRED_STATUS    CHAR(2),
                CRED_EXP_DT    DATE,
                EXCL_FLAG      CHAR(1),
                EXCL_DT        DATE,
                EFFECTIVE_DT   DATE,
                TERM_DT        DATE,
                STATUS_CD      CHAR(2)
              ) END-EXEC.
      *
           EXEC SQL DECLARE OIG_EXCLUSION_LIST TABLE
              ( NPI            CHAR(10),
                TAX_ID         CHAR(9),
                EXCL_TYPE_CD   CHAR(4),
                EFFECTIVE_DT   DATE,
                REINSTATE_DT   DATE,
                REASON_CD      CHAR(4)
              ) END-EXEC.
      *
           EXEC SQL DECLARE NETWORK_CONTRACT TABLE
              ( NPI            CHAR(10)   NOT NULL,
                CONTRACT_ID    CHAR(15),
                NETWORK_ID     CHAR(10),
                TIER_CD        CHAR(2),
                FEE_SCHED_ID   CHAR(10),
                EFFECTIVE_DT   DATE,
                TERM_DT        DATE,
                STATUS_CD      CHAR(2),
                ACCEPT_NEW_PAT CHAR(1)
              ) END-EXEC.
      *
      *---------------------------------------------------------------*
      * File status                                                   *
      *---------------------------------------------------------------*
       01  WS-PROVMSTR-STATUS      PIC X(2)   VALUE SPACES.
           88  PROVMSTR-OK              VALUE '00'.
           88  PROVMSTR-EOF            VALUE '10'.
           88  PROVMSTR-NOTFND        VALUE '23'.
      *
      *---------------------------------------------------------------*
      * Run-time counters and flags                                   *
      *---------------------------------------------------------------*
       01  WS-COUNTERS.
           05  WS-CNT-PROCESSED    PIC 9(9)   VALUE ZERO.
           05  WS-CNT-VALID        PIC 9(9)   VALUE ZERO.
           05  WS-CNT-INVALID      PIC 9(9)   VALUE ZERO.
           05  WS-CNT-EXCLUDED     PIC 9(9)   VALUE ZERO.
           05  WS-CNT-OON          PIC 9(9)   VALUE ZERO.
           05  WS-CNT-DB2-ERRORS   PIC 9(9)   VALUE ZERO.
      *
       01  WS-SWITCHES.
           05  WS-END-OF-INPUT     PIC X(1)   VALUE 'N'.
               88  END-OF-INPUT        VALUE 'Y'.
           05  WS-ABEND-SW         PIC X(1)   VALUE 'N'.
               88  ABEND-REQUESTED    VALUE 'Y'.
      *
       01  WS-RETURN-CODES.
           05  WS-SUB-RETURN-CODE  PIC S9(4) COMP VALUE ZERO.
           05  WS-FOUND-FLAG       PIC X(1)  VALUE 'N'.
               88  PROVIDER-FOUND      VALUE 'Y'.
               88  PROVIDER-NOTFOUND  VALUE 'N'.
      *
      *---------------------------------------------------------------*
      * Sub-program parameter areas (passed via CALL ... USING)       *
      *---------------------------------------------------------------*
       01  WS-CRED-RESULT.
           05  WS-CR-VALID         PIC X(1)   VALUE 'N'.
           05  WS-CR-DENY-REASON   PIC X(30)  VALUE SPACES.
      *
       01  WS-EXCL-RESULT.
           05  WS-EX-FLAG          PIC X(1)   VALUE 'N'.
           05  WS-EX-SOURCE        PIC X(10)  VALUE SPACES.
           05  WS-EX-REASON        PIC X(30)  VALUE SPACES.
      *
       01  WS-NET-RESULT.
           05  WS-NR-NETWORK-IND   PIC X(3)   VALUE SPACES.
           05  WS-NR-TIER-CD       PIC X(2)   VALUE SPACES.
           05  WS-NR-FEE-SCHED-ID  PIC X(10)  VALUE SPACES.
      *
       01  WS-SANCTION-EVENT       PIC X(4)   VALUE SPACES.
           88  EVT-VALIDATION          VALUE 'VALD'.
           88  EVT-EXCLUSION          VALUE 'EXCL'.
      *
       01  WS-ABEND-CODE           PIC S9(4) COMP VALUE ZERO.
      *
       PROCEDURE DIVISION.
      *================================================================*
       0000-MAIN.
      *================================================================*
           PERFORM 1000-INIT
           PERFORM 2000-VALIDATE-PROVIDER
               UNTIL END-OF-INPUT
                  OR ABEND-REQUESTED
           IF ABEND-REQUESTED
               PERFORM 9999-ABEND
           END-IF
           PERFORM 9000-FINALIZE
           GOBACK.
      *
      *================================================================*
       1000-INIT.
      *================================================================*
      *    Open the Provider Master VSAM file and initialise state.    *
           OPEN INPUT PROV-MSTR
           IF NOT PROVMSTR-OK
               DISPLAY 'MPRVVLDR0 - OPEN PROV-MSTR FAILED, STATUS='
                       WS-PROVMSTR-STATUS
               MOVE 16 TO WS-ABEND-CODE
               SET ABEND-REQUESTED TO TRUE
           END-IF
           INITIALIZE WS-COUNTERS.
      *
      *================================================================*
       2000-VALIDATE-PROVIDER.
      *================================================================*
      *    Drives the five-step validation sequence for one request.   *
      *    (Request acquisition - MQ/file/CICS - is stubbed here; the  *
      *     production driver populates WS-PRV-NPI / WS-PRV-DOS from    *
      *     the inbound claim.)                                        *
           PERFORM 2100-ACCEPT-REQUEST
           IF END-OF-INPUT
               GO TO 2000-EXIT
           END-IF
      *
           ADD 1 TO WS-CNT-PROCESSED
           INITIALIZE WS-PRV-VALIDATION
                      WS-CRED-RESULT
                      WS-EXCL-RESULT
                      WS-NET-RESULT
           MOVE WS-PRV-NPI TO WS-PRV-NPI
      *
      *    Step 1 : locate the provider.                               *
           PERFORM 3000-LOOKUP-NPI
           IF PROVIDER-NOTFOUND
               SET PROVIDER-INVALID TO TRUE
               MOVE 'PROVIDER NOT FOUND'   TO WS-PRV-DENY-REASON
               PERFORM 4000-LOG-VALIDATION
               ADD 1 TO WS-CNT-INVALID
               GO TO 2000-EXIT
           END-IF
      *
      *    Step 2 : credentialing.                                     *
           PERFORM 3100-CHECK-CREDENTIALS
      *
      *    Step 3 : exclusions (mandatory, short-circuits on hit).     *
           PERFORM 3200-CHECK-EXCLUSIONS
           IF IS-EXCLUDED
               SET PROVIDER-INVALID TO TRUE
               MOVE 'PROVIDER EXCLUDED - NO PAYMENT'
                    TO WS-PRV-DENY-REASON
               ADD 1 TO WS-CNT-EXCLUDED
               PERFORM 4100-LOG-EXCLUSION
               GO TO 2000-EXIT
           END-IF
      *
      *    Step 4 : network participation and tier.                    *
           PERFORM 3300-VERIFY-NETWORK
           IF OUT-OF-NETWORK
               ADD 1 TO WS-CNT-OON
           END-IF
      *
      *    Consolidate outcome.                                        *
           IF CREDENTIALED AND NOT-EXCLUDED
               SET PROVIDER-VALID TO TRUE
               ADD 1 TO WS-CNT-VALID
           ELSE
               SET PROVIDER-INVALID TO TRUE
               ADD 1 TO WS-CNT-INVALID
           END-IF
      *
      *    Step 5 : mandatory audit trail.                             *
           PERFORM 4000-LOG-VALIDATION
           .
       2000-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------*
       2100-ACCEPT-REQUEST.
      *----------------------------------------------------------------*
      *    Placeholder request acquisition.  In production this reads   *
      *    the next provider-validation request from the inbound        *
      *    channel; here it simply signals end-of-input.               *
           SET END-OF-INPUT TO TRUE.
      *
      *================================================================*
       3000-LOOKUP-NPI.
      *================================================================*
      *    Calls MPRVNPI0 to resolve the NPI to a provider record.     *
           SET PROVIDER-NOTFOUND TO TRUE
           CALL 'MPRVNPI0' USING WS-PRV-NPI
                                 PROVIDER-MASTER-REC
                                 WS-FOUND-FLAG
                                 WS-SUB-RETURN-CODE
           IF WS-SUB-RETURN-CODE > 4
               PERFORM 9100-LOG-DB2-ERROR
           END-IF.
      *
      *================================================================*
       3100-CHECK-CREDENTIALS.
      *================================================================*
      *    Calls MPRVCRD0 (license/DEA/malpractice/board cert).        *
           CALL 'MPRVCRD0' USING WS-PRV-NPI
                                 WS-PRV-DOS
                                 WS-CRED-RESULT
                                 PROVIDER-CRED-REC
                                 WS-SUB-RETURN-CODE
           MOVE WS-CR-VALID TO WS-PRV-CRED-VALID
           IF WS-CR-VALID NOT = 'Y'
               MOVE WS-CR-DENY-REASON TO WS-PRV-DENY-REASON
           END-IF
           IF WS-SUB-RETURN-CODE > 4
               PERFORM 9100-LOG-DB2-ERROR
           END-IF.
      *
      *================================================================*
       3200-CHECK-EXCLUSIONS.
      *================================================================*
      *    Calls MPRVEXC0 (OIG LEIE / SAM / state exclusion lists).    *
      *    COMPLIANCE-CRITICAL: any hit blocks payment.                *
           CALL 'MPRVEXC0' USING WS-PRV-NPI
                                 PRV-TAX-ID
                                 WS-PRV-DOS
                                 WS-EXCL-RESULT
                                 WS-SUB-RETURN-CODE
           MOVE WS-EX-FLAG TO WS-PRV-EXCL-FLAG
           IF IS-EXCLUDED
               MOVE WS-EX-REASON TO WS-PRV-DENY-REASON
           END-IF
           IF WS-SUB-RETURN-CODE > 4
               PERFORM 9100-LOG-DB2-ERROR
           END-IF.
      *
      *================================================================*
       3300-VERIFY-NETWORK.
      *================================================================*
      *    Calls MPRVNET0 to determine INN/OON, tier, and fee sched.   *
           CALL 'MPRVNET0' USING WS-PRV-NPI
                                 WS-PRV-DOS
                                 WS-NR-NETWORK-IND
                                 WS-NR-TIER-CD
                                 WS-NR-FEE-SCHED-ID
                                 NETWORK-CONTRACT-REC
                                 WS-SUB-RETURN-CODE
           MOVE WS-NR-NETWORK-IND  TO WS-PRV-NETWORK-IND
           MOVE WS-NR-TIER-CD      TO WS-PRV-TIER-CD
           MOVE WS-NR-FEE-SCHED-ID TO WS-PRV-FEE-SCHED-ID
           IF WS-SUB-RETURN-CODE > 4
               PERFORM 9100-LOG-DB2-ERROR
           END-IF.
      *
      *================================================================*
       4000-LOG-VALIDATION.
      *================================================================*
      *    Mandatory audit trail for a completed validation.           *
           SET EVT-VALIDATION TO TRUE
           CALL 'MPRVSANL0' USING WS-SANCTION-EVENT
                                  WS-PRV-VALIDATION
                                  WS-SUB-RETURN-CODE
           IF WS-SUB-RETURN-CODE > 4
               PERFORM 9100-LOG-DB2-ERROR
           END-IF.
      *
      *================================================================*
       4100-LOG-EXCLUSION.
      *================================================================*
      *    Mandatory audit trail for an exclusion hit.                 *
           SET EVT-EXCLUSION TO TRUE
           CALL 'MPRVSANL0' USING WS-SANCTION-EVENT
                                  WS-PRV-VALIDATION
                                  WS-SUB-RETURN-CODE
           IF WS-SUB-RETURN-CODE > 4
               PERFORM 9100-LOG-DB2-ERROR
           END-IF.
      *
      *================================================================*
       9000-FINALIZE.
      *================================================================*
           IF PROVMSTR-OK OR PROVMSTR-EOF
               CLOSE PROV-MSTR
           END-IF
           DISPLAY '****************************************************'
           DISPLAY 'MPRVVLDR0 - PROVIDER VALIDATION RUN SUMMARY'
           DISPLAY '  PROCESSED  : ' WS-CNT-PROCESSED
           DISPLAY '  VALID      : ' WS-CNT-VALID
           DISPLAY '  INVALID    : ' WS-CNT-INVALID
           DISPLAY '  EXCLUDED   : ' WS-CNT-EXCLUDED
           DISPLAY '  OUT-OF-NET : ' WS-CNT-OON
           DISPLAY '  DB2 ERRORS : ' WS-CNT-DB2-ERRORS
           DISPLAY '****************************************************'.
      *
      *================================================================*
       9100-LOG-DB2-ERROR.
      *================================================================*
           ADD 1 TO WS-CNT-DB2-ERRORS
           DISPLAY 'MPRVVLDR0 - DB2/SUBPGM ERROR, SQLCODE='
                   SQLCODE ' RC=' WS-SUB-RETURN-CODE
           IF SQLCODE < -799
               MOVE 12 TO WS-ABEND-CODE
               SET ABEND-REQUESTED TO TRUE
           END-IF.
      *
      *================================================================*
       9999-ABEND.
      *================================================================*
           DISPLAY 'MPRVVLDR0 - ABENDING, CODE=' WS-ABEND-CODE
           IF PROVMSTR-OK OR PROVMSTR-EOF
               CLOSE PROV-MSTR
           END-IF
           CALL 'ILBOABN0' USING WS-ABEND-CODE.
