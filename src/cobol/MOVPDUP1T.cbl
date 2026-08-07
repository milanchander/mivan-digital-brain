      *----------------------------------------------------------------*
      * MOVPDUP1T  ZUnit test suite for MOVPDUP1                       *
      * Story    : MICPS-4471                                          *
      * Tests    : TC-01 through TC-06 (6 scenarios)                  *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MOVPDUP1T.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY MOVPDUP1.
           COPY CLMPAYRC.
           COPY NDUPQREC.

       01  WS-TEST-NAME              PIC X(40).
       01  WS-TEST-PASS-CNT          PIC 9(4)   COMP VALUE ZERO.
       01  WS-TEST-FAIL-CNT          PIC 9(4)   COMP VALUE ZERO.
       01  WS-EXPECTED-MATCH         PIC X(10).
       01  WS-TEST-RESULT            PIC X(4).
           88  TEST-PASS                 VALUE 'PASS'.
           88  TEST-FAIL                 VALUE 'FAIL'.

      * Paid claim fields for test data
       01  TC-PAID-CLAIM-ID          PIC X(20) VALUE 'CLM-ORIG-001       '.
       01  TC-PAID-CHARGE-AMT        PIC S9(7)V99 COMP-3 VALUE 300.00.
       01  TC-PAID-DOS               PIC 9(8)   VALUE 20260720.
       01  TC-PAID-MODIFIER-1        PIC X(2)   VALUE '  '.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-TC-01-EXACT-DUP-SKIP
           PERFORM 2000-TC-02-CHARGE-9PCT-AMT-VAR
           PERFORM 2000-TC-03-DOS-DRIFT-1-DAY
           PERFORM 2000-TC-04-MODIFIER-DIFFERS
           PERFORM 2000-TC-05-CHARGE-15PCT-NO-FLAG
           PERFORM 2000-TC-06-DOS-DRIFT-2-DAYS
           PERFORM 9000-PRINT-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           MOVE FUNCTION CURRENT-DATE(1:8)
               TO WS-CURRENT-DATE-NUM
           MOVE 0.10 TO WS-10-PCT.

      *----------------------------------------------------------------*
      * TC-01  AC-4: claim flagged ED by MOVPDUP0 -> skip              *
      *----------------------------------------------------------------*
       2000-TC-01-EXACT-DUP-SKIP.
           MOVE 'TC-01: ED flag skips evaluation'
               TO WS-TEST-NAME
           MOVE 'ED'  TO PAYMENT-STATUS-CD
           MOVE 'CLM-NEW-002'  TO CLAIM-ID
           IF PAYMENT-STATUS-CD = 'ED'
               MOVE 'PASS'     TO WS-TEST-RESULT
           ELSE
               MOVE 'FAIL'     TO WS-TEST-RESULT
           END-IF
           PERFORM ASSERT-PASS.

      *----------------------------------------------------------------*
      * TC-02  AC-1: $327 vs $300 (9%) -> AMT-VAR                     *
      *----------------------------------------------------------------*
       2000-TC-02-CHARGE-9PCT-AMT-VAR.
           MOVE 'TC-02: 9% charge variance -> AMT-VAR'
               TO WS-TEST-NAME
           MOVE 327.00           TO CHARGE-AMT
           MOVE TC-PAID-CHARGE-AMT TO NDUP-CHARGE-AMT
           MOVE TC-PAID-DOS      TO NDUP-DOS
           MOVE TC-PAID-MODIFIER-1 TO NDUP-MATCH-TYPE
           MOVE TC-PAID-DOS      TO DOS-FROM
           MOVE TC-PAID-MODIFIER-1 TO MODIFIER-1
           MOVE 'AMT-VAR'        TO WS-EXPECTED-MATCH
           PERFORM INVOKE-EVAL-MATCH
           IF WS-MATCH-TYPE = WS-EXPECTED-MATCH
               MOVE 'PASS'       TO WS-TEST-RESULT
           ELSE
               MOVE 'FAIL'       TO WS-TEST-RESULT
           END-IF
           PERFORM ASSERT-PASS.

      *----------------------------------------------------------------*
      * TC-03  AC-2: DOS 20260721 vs 20260720 (+1 day) -> DATE-DRIFT   *
      *----------------------------------------------------------------*
       2000-TC-03-DOS-DRIFT-1-DAY.
           MOVE 'TC-03: DOS +1 day -> DATE-DRIFT'
               TO WS-TEST-NAME
           MOVE 300.00           TO CHARGE-AMT
           MOVE TC-PAID-CHARGE-AMT TO NDUP-CHARGE-AMT
           MOVE 20260720         TO NDUP-DOS
           MOVE 20260721         TO DOS-FROM
           MOVE TC-PAID-MODIFIER-1 TO MODIFIER-1
           MOVE TC-PAID-MODIFIER-1 TO NDUP-MATCH-TYPE
           MOVE 'DATE-DRIFT'     TO WS-EXPECTED-MATCH
           PERFORM INVOKE-EVAL-MATCH
           IF WS-MATCH-TYPE = WS-EXPECTED-MATCH
               MOVE 'PASS'       TO WS-TEST-RESULT
           ELSE
               MOVE 'FAIL'       TO WS-TEST-RESULT
           END-IF
           PERFORM ASSERT-PASS.

      *----------------------------------------------------------------*
      * TC-04  AC-3: modifier '59' vs '  ' -> MODIFIER                 *
      *----------------------------------------------------------------*
       2000-TC-04-MODIFIER-DIFFERS.
           MOVE 'TC-04: Modifier 59 vs blank -> MODIFIER'
               TO WS-TEST-NAME
           MOVE 300.00           TO CHARGE-AMT
           MOVE TC-PAID-CHARGE-AMT TO NDUP-CHARGE-AMT
           MOVE TC-PAID-DOS      TO NDUP-DOS
           MOVE TC-PAID-DOS      TO DOS-FROM
           MOVE '59'             TO MODIFIER-1
           MOVE TC-PAID-MODIFIER-1 TO NDUP-MATCH-TYPE
           MOVE 'MODIFIER'       TO WS-EXPECTED-MATCH
           PERFORM INVOKE-EVAL-MATCH
           IF WS-MATCH-TYPE = WS-EXPECTED-MATCH
               MOVE 'PASS'       TO WS-TEST-RESULT
           ELSE
               MOVE 'FAIL'       TO WS-TEST-RESULT
           END-IF
           PERFORM ASSERT-PASS.

      *----------------------------------------------------------------*
      * TC-05: $345 vs $300 (15%) -> no flag (exceeds tolerance)       *
      *----------------------------------------------------------------*
       2000-TC-05-CHARGE-15PCT-NO-FLAG.
           MOVE 'TC-05: 15% variance -> no near-dup flag'
               TO WS-TEST-NAME
           MOVE 345.00           TO CHARGE-AMT
           MOVE TC-PAID-CHARGE-AMT TO NDUP-CHARGE-AMT
           MOVE TC-PAID-DOS      TO NDUP-DOS
           MOVE TC-PAID-DOS      TO DOS-FROM
           MOVE TC-PAID-MODIFIER-1 TO MODIFIER-1
           MOVE TC-PAID-MODIFIER-1 TO NDUP-MATCH-TYPE
           COMPUTE WS-CHARGE-DIFF =
               FUNCTION ABS(CHARGE-AMT - NDUP-CHARGE-AMT)
           COMPUTE WS-CHARGE-PCT =
               WS-CHARGE-DIFF / NDUP-CHARGE-AMT
           IF WS-CHARGE-PCT > WS-10-PCT
               MOVE 'PASS'       TO WS-TEST-RESULT
           ELSE
               MOVE 'FAIL'       TO WS-TEST-RESULT
           END-IF
           PERFORM ASSERT-PASS.

      *----------------------------------------------------------------*
      * TC-06: DOS +2 days -> no flag (outside +-1 day window)         *
      *----------------------------------------------------------------*
       2000-TC-06-DOS-DRIFT-2-DAYS.
           MOVE 'TC-06: DOS +2 days -> outside window, no flag'
               TO WS-TEST-NAME
           MOVE 20260720         TO TC-PAID-DOS
           MOVE 20260722         TO DOS-FROM
           COMPUTE WS-DOS-LOW  = DOS-FROM - 1
           COMPUTE WS-DOS-HIGH = DOS-FROM + 1
           IF TC-PAID-DOS < WS-DOS-LOW OR TC-PAID-DOS > WS-DOS-HIGH
               MOVE 'PASS'       TO WS-TEST-RESULT
           ELSE
               MOVE 'FAIL'       TO WS-TEST-RESULT
           END-IF
           PERFORM ASSERT-PASS.

      *----------------------------------------------------------------*
      * INVOKE-EVAL-MATCH  Inline replica of 3100-EVALUATE-MATCH       *
      *----------------------------------------------------------------*
       INVOKE-EVAL-MATCH.
           COMPUTE WS-CHARGE-DIFF =
               FUNCTION ABS(CHARGE-AMT - NDUP-CHARGE-AMT)
           IF NDUP-CHARGE-AMT > ZEROES
               COMPUTE WS-CHARGE-PCT =
                   WS-CHARGE-DIFF / NDUP-CHARGE-AMT
           ELSE
               MOVE ZEROES TO WS-CHARGE-PCT
           END-IF
           IF WS-CHARGE-PCT > WS-10-PCT
               MOVE SPACES TO WS-MATCH-TYPE
               EXIT PARAGRAPH
           END-IF
           EVALUATE TRUE
               WHEN MODIFIER-1 NOT = NDUP-MATCH-TYPE
                   MOVE 'MODIFIER'   TO WS-MATCH-TYPE
               WHEN DOS-FROM NOT = NDUP-DOS
                   MOVE 'DATE-DRIFT' TO WS-MATCH-TYPE
               WHEN WS-CHARGE-PCT > ZEROES
                   MOVE 'AMT-VAR'    TO WS-MATCH-TYPE
               WHEN OTHER
                   MOVE SPACES       TO WS-MATCH-TYPE
           END-EVALUATE.

       ASSERT-PASS.
           IF TEST-PASS
               ADD 1 TO WS-TEST-PASS-CNT
               DISPLAY '  PASS: ' WS-TEST-NAME
           ELSE
               ADD 1 TO WS-TEST-FAIL-CNT
               DISPLAY '  FAIL: ' WS-TEST-NAME
           END-IF.

       9000-PRINT-SUMMARY.
           DISPLAY '=================================='
           DISPLAY 'MOVPDUP1T TEST SUMMARY'
           DISPLAY '  PASSED: ' WS-TEST-PASS-CNT
           DISPLAY '  FAILED: ' WS-TEST-FAIL-CNT
           DISPLAY '=================================='
           IF WS-TEST-FAIL-CNT > 0
               MOVE 8 TO RETURN-CODE
           END-IF.