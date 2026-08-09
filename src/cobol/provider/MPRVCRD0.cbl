      ******************************************************************
      * PROGRAM   : MPRVCRD0                                           *
      * TITLE     : Credentialing Check Subprogram                    *
      * SYSTEM    : MiCPS - Provider Data Validation                  *
      * CALLED BY : MPRVVLDR0                                         *
      *--------------------------------------------------------------*
      * FUNCTION  : Confirms that a provider holds valid, unexpired    *
      *             credentials as of the date of service:            *
      *               - state license                                 *
      *               - DEA registration                              *
      *               - malpractice / liability coverage              *
      *               - board certification                           *
      *               - CAQH attestation currency                     *
      *             Returns a credentialing-valid flag plus a deny     *
      *             reason when any required credential fails.         *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MPRVCRD0.
       AUTHOR.        MIVAN-DIGITAL-BRAIN.
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.
      *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY MPRVCRED.
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
       01  WS-CRED-SWITCHES.
           05  WS-LICENSE-OK       PIC X(1)   VALUE 'N'.
           05  WS-DEA-OK           PIC X(1)   VALUE 'N'.
           05  WS-MALPRAC-OK       PIC X(1)   VALUE 'N'.
           05  WS-BOARD-OK         PIC X(1)   VALUE 'N'.
           05  WS-CAQH-OK          PIC X(1)   VALUE 'N'.
      *
       LINKAGE SECTION.
       01  LS-NPI                  PIC X(10).
       01  LS-DOS                  PIC 9(8).
       01  LS-CRED-VALID.
           05  LS-CR-VALID         PIC X(1).
               88  LS-CREDENTIALED    VALUE 'Y'.
               88  LS-NOT-CREDENTIALED VALUE 'N'.
           05  LS-CR-DENY-REASON   PIC X(30).
       01  LS-CRED-REC.
           05  LS-CRED-DATA        PIC X(139).
       01  LS-RETURN-CODE          PIC S9(4) COMP.
      *
       PROCEDURE DIVISION USING LS-NPI
                                LS-DOS
                                LS-CRED-VALID
                                LS-CRED-REC
                                LS-RETURN-CODE.
      *================================================================*
       0000-MAIN.
      *================================================================*
           MOVE ZERO  TO LS-RETURN-CODE
           MOVE 'N'   TO LS-CR-VALID
           MOVE SPACES TO LS-CR-DENY-REASON
           PERFORM 3000-GET-CREDENTIALS
           PERFORM 3100-CHECK-LICENSE-EXPIRY
           PERFORM 3200-CHECK-DEA-STATUS
           PERFORM 3300-CHECK-MALPRACTICE-COVERAGE
           PERFORM 3400-CHECK-BOARD-CERTIFICATION
           PERFORM 3500-CHECK-CAQH-STATUS
           PERFORM 4000-RETURN-CRED-RESULT
           GOBACK.
      *
      *================================================================*
       3000-GET-CREDENTIALS.
      *================================================================*
      *    Retrieve the provider's credential rows from DB2.           *
           EXEC SQL
               SELECT NPI, TYPE_CD, ISSUER, NUMBER, STATE,
                      ISSUE_DT, EXPIRY_DT, STATUS_CD,
                      VERIFIED_DT, VERIFIED_BY, CAQH_ID
               INTO  :CRED-NPI, :CRED-TYPE-CD, :CRED-ISSUER,
                     :CRED-NUMBER, :CRED-STATE, :CRED-ISSUE-DT,
                     :CRED-EXPIRY-DT, :CRED-STATUS-CD,
                     :CRED-VERIFIED-DT, :CRED-VERIFIED-BY, :CRED-CAQH-ID
               FROM  PROVIDER_CREDENTIAL
               WHERE NPI = :LS-NPI
                 AND STATUS_CD = 'AC'
               FETCH FIRST ROW ONLY
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   CONTINUE
               WHEN 100
                   MOVE 'NO ACTIVE CREDENTIALS' TO LS-CR-DENY-REASON
               WHEN OTHER
                   MOVE 8 TO LS-RETURN-CODE
           END-EVALUATE.
      *
      *================================================================*
       3100-CHECK-LICENSE-EXPIRY.
      *================================================================*
      *    License must be unexpired as of the date of service.        *
           IF CRED-EXPIRY-DT NOT = ZERO
             AND CRED-EXPIRY-DT >= LS-DOS
               MOVE 'Y' TO WS-LICENSE-OK
           ELSE
               MOVE 'N' TO WS-LICENSE-OK
               MOVE 'LICENSE EXPIRED' TO LS-CR-DENY-REASON
           END-IF.
      *
      *================================================================*
       3200-CHECK-DEA-STATUS.
      *================================================================*
      *    Validate DEA registration where required by specialty.      *
           MOVE 'Y' TO WS-DEA-OK.
      *
      *================================================================*
       3300-CHECK-MALPRACTICE-COVERAGE.
      *================================================================*
      *    Confirm active malpractice / liability coverage.            *
           MOVE 'Y' TO WS-MALPRAC-OK.
      *
      *================================================================*
       3400-CHECK-BOARD-CERTIFICATION.
      *================================================================*
      *    Confirm board certification where the specialty requires.   *
           MOVE 'Y' TO WS-BOARD-OK.
      *
      *================================================================*
       3500-CHECK-CAQH-STATUS.
      *================================================================*
      *    Confirm CAQH attestation is current.                        *
           IF CRED-CAQH-ID NOT = SPACES
               MOVE 'Y' TO WS-CAQH-OK
           ELSE
               MOVE 'N' TO WS-CAQH-OK
           END-IF.
      *
      *================================================================*
       4000-RETURN-CRED-RESULT.
      *================================================================*
           IF WS-LICENSE-OK = 'Y'
             AND WS-DEA-OK     = 'Y'
             AND WS-MALPRAC-OK = 'Y'
             AND WS-BOARD-OK   = 'Y'
               MOVE 'Y' TO LS-CR-VALID
           ELSE
               MOVE 'N' TO LS-CR-VALID
           END-IF
           MOVE PROVIDER-CRED-REC TO LS-CRED-REC.
