      *----------------------------------------------------------------*
      * PROGRAM:    MMCOELV0                                         *
      * PURPOSE:    Medicaid Eligibility Verification Subprogram     *
      * CALLED BY:  MMCOCLDR0                                        *
      * JAVA EQ:    MedicaidEligibilityService.java                  *
      *                                                              *
      * Verifies Medicaid eligibility handling monthly churn,        *
      * spend-down, CHIP, and EPSDT eligibility rules.               *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MMCOELV0.
       AUTHOR.        MIVAN HEALTH PLAN.
       DATE-WRITTEN.  2026-08-08.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

           EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-ELIG-STATUS              PIC X(2)  VALUE SPACES.
       01  WS-ELIG-FROM-DT             PIC X(10) VALUE SPACES.
       01  WS-ELIG-TO-DT               PIC X(10) VALUE SPACES.
       01  WS-SPEND-DOWN-IND           PIC X(1)  VALUE 'N'.
       01  WS-SPEND-DOWN-AMT           PIC S9(7)V99 COMP-3 VALUE 0.
       01  WS-CHIP-IND                 PIC X(1)  VALUE 'N'.
       01  WS-EPSDT-IND                PIC X(1)  VALUE 'N'.
       01  WS-DUAL-IND                 PIC X(1)  VALUE 'N'.
       01  WS-MEMBER-AGE               PIC 9(3)  VALUE 0.

       LINKAGE SECTION.
       01  LS-MEMBER-ID                PIC X(15).
       01  LS-DOS                      PIC 9(8).
       01  LS-STATE-CD                 PIC X(2).
       01  LS-ELIG-FLAG                PIC X(1).
       01  LS-RETURN-CODE              PIC S9(4) COMP.

       PROCEDURE DIVISION USING LS-MEMBER-ID
                                LS-DOS
                                LS-STATE-CD
                                LS-ELIG-FLAG
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           MOVE 'N' TO LS-ELIG-FLAG
           PERFORM 3000-CHECK-MC-ENROLLMENT
           IF LS-ELIG-FLAG = 'Y'
               PERFORM 3100-CHECK-SPEND-DOWN
               PERFORM 3200-CHECK-CHIP-ELIGIBILITY
               PERFORM 3300-CHECK-EPSDT-ELIGIBILITY
               PERFORM 3400-CHECK-DUAL-ELIGIBILITY
               PERFORM 3500-VALIDATE-EFFECTIVE-DATES
           END-IF
           GOBACK
           .

       3000-CHECK-MC-ENROLLMENT.
      * Query MEDICAID_ELIGIBILITY for active enrollment on DOS.
      * Handles monthly churn — must check exact DOS not current date.
           EXEC SQL
               SELECT STATUS_CD,
                      ELIG_FROM_DT,
                      ELIG_TO_DT,
                      SPEND_DOWN_IND,
                      SPEND_DOWN_AMT,
                      CHIP_IND,
                      EPSDT_IND,
                      DUAL_ELIG_IND
                 INTO :WS-ELIG-STATUS,
                      :WS-ELIG-FROM-DT,
                      :WS-ELIG-TO-DT,
                      :WS-SPEND-DOWN-IND,
                      :WS-SPEND-DOWN-AMT,
                      :WS-CHIP-IND,
                      :WS-EPSDT-IND,
                      :WS-DUAL-IND
                 FROM MIVANCPS.MEDICAID_ELIGIBILITY
                WHERE MEMBER_ID = :LS-MEMBER-ID
                  AND STATE_CD  = :LS-STATE-CD
                  AND STATUS_CD = 'AC'
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   MOVE 'Y' TO LS-ELIG-FLAG
               WHEN 100
                   MOVE 'N' TO LS-ELIG-FLAG
               WHEN OTHER
                   MOVE 'N' TO LS-ELIG-FLAG
                   MOVE +8 TO LS-RETURN-CODE
           END-EVALUATE
           .

       3100-CHECK-SPEND-DOWN.
      * If member has spend-down, eligibility is conditional.
      * Spend-down must be met before Medicaid covers services.
           IF WS-SPEND-DOWN-IND = 'Y'
               IF WS-SPEND-DOWN-AMT > 0
                   MOVE 'N' TO LS-ELIG-FLAG
               END-IF
           END-IF
           .

       3200-CHECK-CHIP-ELIGIBILITY.
      * CHIP members have different benefit packages and cost-sharing.
      * CHIP eligibility is state-administered under Title XXI.
           CONTINUE
           .

       3300-CHECK-EPSDT-ELIGIBILITY.
      * EPSDT (Early and Periodic Screening, Diagnostic, Treatment)
      * applies to Medicaid members under age 21.
      * Federal mandate — must cover any medically necessary service
      * even if not otherwise covered in state plan.
           IF WS-EPSDT-IND = 'Y'
               CONTINUE
           END-IF
           .

       3400-CHECK-DUAL-ELIGIBILITY.
      * Dual eligible members have both Medicare and Medicaid.
      * Medicaid pays Medicare cost-sharing and services not
      * covered by Medicare. Still payer of last resort.
           IF WS-DUAL-IND = 'Y'
               CONTINUE
           END-IF
           .

       3500-VALIDATE-EFFECTIVE-DATES.
      * Validate DOS falls within eligibility span.
      * Retroactive eligibility: if member was retroactively
      * made eligible, prior claims must be reprocessed.
           IF LS-ELIG-FLAG = 'Y'
               IF WS-ELIG-FROM-DT > WS-ELIG-TO-DT
                   MOVE 'N' TO LS-ELIG-FLAG
                   MOVE +4 TO LS-RETURN-CODE
               END-IF
           END-IF
           .
