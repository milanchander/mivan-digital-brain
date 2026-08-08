      *----------------------------------------------------------------*
      * PROGRAM:    MMCOLRP0                                         *
      * PURPOSE:    Payer of Last Resort Calculation Subprogram      *
      * CALLED BY:  MMCOCLDR0                                        *
      * JAVA EQ:    PayerOfLastResortService.java                    *
      *                                                              *
      * Applies 42 CFR 433.139 payer of last resort rules.          *
      * Medicaid pays only what remains after all other payers       *
      * have paid. State-specific rules applied per STATE_CONTRACT.  *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MMCOLRP0.
       AUTHOR.        MIVAN HEALTH PLAN.
       DATE-WRITTEN.  2026-08-08.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-BILLED-AMT               PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-PRIMARY-PAID-AMT         PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-REMAINING-AMT            PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-STATE-MAX-AMT            PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-COPAY-AMT                PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-STATE-CD-WS              PIC X(2)  VALUE SPACES.
       01  WS-MCO-ID-WS                PIC X(10) VALUE SPACES.
       01  WS-TIMELY-FILING-DAYS       PIC 9(3)  VALUE 0.

       LINKAGE SECTION.
       01  LS-CLAIM-ID                 PIC X(20).
           COPY MMCOTPLR.
           COPY MMCOLIAB.
       01  LS-RETURN-CODE              PIC S9(4) COMP.

       PROCEDURE DIVISION USING LS-CLAIM-ID
                                TPL-RESULT-REC
                                MEDICAID-LIAB-REC
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           MOVE LS-CLAIM-ID         TO MC-LIAB-CLAIM-ID
           MOVE ZEROS               TO MC-BILLED-AMT
           MOVE ZEROS               TO MC-TPL-PAID-AMT
           MOVE ZEROS               TO MC-MEMBER-RESP-AMT
           MOVE ZEROS               TO MC-MEDICAID-AMT
           MOVE FUNCTION CURRENT-DATE(1:8)
                                    TO MC-CALC-DT
           PERFORM 3000-GET-PRIMARY-PAYMENT
           PERFORM 3100-GET-TPL-PAYMENTS
           PERFORM 3200-CALCULATE-REMAINING-LIABILITY
           PERFORM 3300-APPLY-STATE-SPECIFIC-RULES
           PERFORM 4000-WRITE-MEDICAID-LIABILITY
           GOBACK
           .

       3000-GET-PRIMARY-PAYMENT.
      * Retrieve billed amount and primary payer payment
      * from CLAIM_HEADER and CLAIM_PAYMENT.
           EXEC SQL
               SELECT CH.BILLED_AMT,
                      ME.STATE_CD,
                      ME.MCO_ID
                 INTO :WS-BILLED-AMT,
                      :WS-STATE-CD-WS,
                      :WS-MCO-ID-WS
                 FROM MIVANCPS.CLAIM_HEADER CH
                 JOIN MIVANCPS.MEDICAID_ELIGIBILITY ME
                   ON CH.MEMBER_ID = ME.MEMBER_ID
                WHERE CH.CLAIM_ID = :LS-CLAIM-ID
           END-EXEC
           IF SQLCODE = 0
               MOVE WS-BILLED-AMT   TO MC-BILLED-AMT
               MOVE WS-STATE-CD-WS  TO MC-LIAB-STATE-CD
           ELSE
               MOVE +8 TO LS-RETURN-CODE
           END-IF
           .

       3100-GET-TPL-PAYMENTS.
      * Move TPL amounts from TPL-RESULT-REC into liability record.
      * Federal law 42 CFR 433.139: all TPL must pay first.
           MOVE TPL-PAID-AMT TO MC-TPL-PAID-AMT
           .

       3200-CALCULATE-REMAINING-LIABILITY.
      * Medicaid liability = billed - TPL paid - member copay.
      * Result cannot be negative — Medicaid does not recover.
           COMPUTE WS-REMAINING-AMT =
               MC-BILLED-AMT - MC-TPL-PAID-AMT - WS-COPAY-AMT
           IF WS-REMAINING-AMT < 0
               MOVE ZEROS TO WS-REMAINING-AMT
               MOVE 'ZR' TO MC-STATUS-CD
           ELSE
               MOVE WS-REMAINING-AMT TO MC-MEDICAID-AMT
               MOVE 'CM' TO MC-STATUS-CD
           END-IF
           .

       3300-APPLY-STATE-SPECIFIC-RULES.
      * Apply state-specific payment limits from STATE_CONTRACT.
      * Each state Medicaid program has unique fee schedules.
           EXEC SQL
               SELECT TIMELY_FILING_DAYS
                 INTO :WS-TIMELY-FILING-DAYS
                 FROM MIVANCPS.STATE_CONTRACT
                WHERE STATE_CD = :MC-LIAB-STATE-CD
                  AND MCO_ID   = :WS-MCO-ID-WS
                  AND STATUS_CD = 'AC'
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 0 TO WS-TIMELY-FILING-DAYS
           END-IF
           .

       4000-WRITE-MEDICAID-LIABILITY.
      * Insert computed liability into MEDICAID_LIABILITY table.
           EXEC SQL
               INSERT INTO MIVANCPS.MEDICAID_LIABILITY
               (CLAIM_ID, MEMBER_ID, STATE_CD, BILLED_AMT,
                TPL_PAID_AMT, MEMBER_RESP_AMT, MEDICAID_AMT,
                CALC_DT, STATUS_CD)
               VALUES
               (:MC-LIAB-CLAIM-ID, :MC-LIAB-MEMBER-ID,
                :MC-LIAB-STATE-CD, :MC-BILLED-AMT,
                :MC-TPL-PAID-AMT, :MC-MEMBER-RESP-AMT,
                :MC-MEDICAID-AMT,
                :MC-CALC-DT, :MC-STATUS-CD)
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE +8 TO LS-RETURN-CODE
           END-IF
           .
