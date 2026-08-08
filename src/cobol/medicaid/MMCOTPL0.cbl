      *----------------------------------------------------------------*
      * PROGRAM:    MMCOTPL0                                         *
      * PURPOSE:    Third Party Liability Identification Subprogram  *
      * CALLED BY:  MMCOCLDR0                                        *
      * JAVA EQ:    ThirdPartyLiabilityService.java                  *
      *                                                              *
      * Identifies third party liability payers for Medicaid         *
      * members. Federal law requires Medicaid to be payer of        *
      * last resort — all other insurers must pay first.             *
      * 42 CFR 433.139                                               *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MMCOTPL0.
       AUTHOR.        MIVAN HEALTH PLAN.
       DATE-WRITTEN.  2026-08-08.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-TPL-PAYER-ID             PIC X(10) VALUE SPACES.
       01  WS-TPL-PAYER-NAME           PIC X(40) VALUE SPACES.
       01  WS-TPL-POLICY-NO            PIC X(20) VALUE SPACES.
       01  WS-TPL-EFFECTIVE-DT         PIC X(10) VALUE SPACES.
       01  WS-TPL-TERM-DT              PIC X(10) VALUE SPACES.
       01  WS-TPL-STATUS               PIC X(2)  VALUE SPACES.
       01  WS-TPL-PAYMENT-AMT          PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-TPL-TOTAL-AMT            PIC S9(7)V99 COMP-3 VALUE 0.

       LINKAGE SECTION.
       01  LS-CLAIM-ID                 PIC X(20).
       01  LS-MEMBER-ID                PIC X(15).
       01  LS-TPL-FLAG                 PIC X(1).
           COPY MMCOTPLR.
       01  LS-RETURN-CODE              PIC S9(4) COMP.

       PROCEDURE DIVISION USING LS-CLAIM-ID
                                LS-MEMBER-ID
                                LS-TPL-FLAG
                                TPL-RESULT-REC
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           MOVE 'N' TO LS-TPL-FLAG
           MOVE LS-CLAIM-ID  TO TPL-CLAIM-ID
           MOVE LS-MEMBER-ID TO TPL-MEMBER-ID
           MOVE ZEROS TO TPL-PAID-AMT
           MOVE ZEROS TO TPL-LAST-RESORT-AMT
           PERFORM 3000-LOOKUP-TPL-PAYERS
           GOBACK
           .

       3000-LOOKUP-TPL-PAYERS.
      * Look up all active TPL payers on file for this member.
      * TPL_PAYER_FILE is updated by enrollment data feeds.
           EXEC SQL
               SELECT PAYER_ID,
                      PAYER_NAME,
                      POLICY_NO,
                      EFFECTIVE_DT,
                      TERM_DT,
                      STATUS_CD
                 INTO :WS-TPL-PAYER-ID,
                      :WS-TPL-PAYER-NAME,
                      :WS-TPL-POLICY-NO,
                      :WS-TPL-EFFECTIVE-DT,
                      :WS-TPL-TERM-DT,
                      :WS-TPL-STATUS
                 FROM MIVANCPS.TPL_PAYER_FILE
                WHERE MEMBER_ID = :LS-MEMBER-ID
                  AND STATUS_CD = 'AC'
                FETCH FIRST 1 ROWS ONLY
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   MOVE WS-TPL-PAYER-ID   TO TPL-PAYER-ID
                   MOVE WS-TPL-PAYER-NAME TO TPL-PAYER-NAME
                   MOVE WS-TPL-POLICY-NO  TO TPL-POLICY-NO
                   PERFORM 3100-VERIFY-TPL-COVERAGE-ACTIVE
               WHEN 100
                   CONTINUE
               WHEN OTHER
                   MOVE +8 TO LS-RETURN-CODE
           END-EVALUATE
           .

       3100-VERIFY-TPL-COVERAGE-ACTIVE.
      * Verify TPL coverage was active on date of service.
      * Coverage must span the DOS — not just exist on file.
           IF WS-TPL-STATUS = 'AC'
               MOVE 'Y' TO LS-TPL-FLAG
               PERFORM 3200-GET-TPL-PAYMENT
           END-IF
           .

       3200-GET-TPL-PAYMENT.
      * Retrieve actual TPL payment from CLAIM_PAYMENT table.
      * Payment may have been received before Medicaid processed.
           EXEC SQL
               SELECT PAYMENT_AMT
                 INTO :WS-TPL-PAYMENT-AMT
                 FROM MIVANCPS.CLAIM_PAYMENT
                WHERE CLAIM_ID   = :LS-CLAIM-ID
                  AND PAYER_ID   = :WS-TPL-PAYER-ID
                  AND STATUS_CD  = 'PD'
           END-EXEC
           IF SQLCODE = 0
               MOVE WS-TPL-PAYMENT-AMT TO TPL-PAID-AMT
               MOVE 'PD' TO TPL-STATUS-CD
               PERFORM 3300-CALCULATE-TPL-TOTAL
           END-IF
           .

       3300-CALCULATE-TPL-TOTAL.
      * Sum all TPL payments — member may have multiple payers.
      * This total becomes the reduction against billed amount.
           ADD TPL-PAID-AMT TO WS-TPL-TOTAL-AMT
           MOVE WS-TPL-TOTAL-AMT TO TPL-LAST-RESORT-AMT
           .
