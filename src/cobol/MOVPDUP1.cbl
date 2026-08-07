      *----------------------------------------------------------------*
      * MOVPDUP1  Near-Duplicate Claim Detection                       *
      * System  : MiCPS — Mivan Claims Processing System              *
      * Story   : MICPS-4471                                           *
      * Logic   : For each paid claim, search CLAIM_PAYMENT for        *
      *           near-matches: same MBR+NPI+CPT, DOS +-1 day,         *
      *           charge variance <=10%. Flag as NEAR-DUP if found.    *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MOVPDUP1.
       AUTHOR.        MIVAN-DIGITAL-BRAIN.
       DATE-WRITTEN.  2026-08-07.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CLAIM-WRK-FILE ASSIGN TO CLMWRK
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  CLAIM-WRK-FILE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  CLAIM-WRK-REC             PIC X(500).

       WORKING-STORAGE SECTION.
           COPY MOVPDUP1.
           COPY CLMPAYRC.
           COPY NDUPQREC.

       01  WS-FILE-STATUS            PIC X(2).
       01  WS-SQLCODE-SAVE           PIC S9(9)      COMP.
       01  WS-DATE-WORK.
           05  WS-DATE-YMD           PIC 9(8).

       EXEC SQL
           INCLUDE SQLCA
       END-EXEC.

       EXEC SQL
           DECLARE TABLE MIVANCPS.CLAIM_PAYMENT (
               CLAIM_ID           CHAR(20)     NOT NULL,
               MEMBER_ID          CHAR(15)     NOT NULL,
               PROV_NPI           CHAR(10)     NOT NULL,
               DOS_FROM           DECIMAL(8,0) NOT NULL,
               DOS_TO             DECIMAL(8,0),
               CPT_CD             CHAR(5)      NOT NULL,
               MODIFIER_1         CHAR(2),
               MODIFIER_2         CHAR(2),
               CHARGE_AMT         DECIMAL(9,2) NOT NULL,
               PAID_AMT           DECIMAL(9,2),
               PAYMENT_STATUS_CD  CHAR(2),
               PAYMENT_DT         DECIMAL(8,0)
           )
       END-EXEC.

       EXEC SQL
           DECLARE TABLE MIVANCPS.NEAR_DUP_QUEUE (
               NDUP_CLAIM_ID      CHAR(20)     NOT NULL,
               NDUP_ORIG_CLAIM_ID CHAR(20)     NOT NULL,
               NDUP_MEMBER_ID     CHAR(15)     NOT NULL,
               NDUP_PROV_NPI      CHAR(10)     NOT NULL,
               NDUP_DOS           DECIMAL(8,0) NOT NULL,
               NDUP_CPT_CD        CHAR(5)      NOT NULL,
               NDUP_CHARGE_AMT    DECIMAL(9,2) NOT NULL,
               NDUP_MATCH_TYPE    CHAR(10)     NOT NULL,
               NDUP_PEND_REASON   CHAR(20)     NOT NULL,
               NDUP_CREATE_DT     DECIMAL(8,0) NOT NULL,
               NDUP_STATUS        CHAR(1)      NOT NULL
           )
       END-EXEC.

       EXEC SQL
           DECLARE PAID-CLAIMS-CUR CURSOR FOR
               SELECT CLAIM_ID, MEMBER_ID, PROV_NPI,
                      DOS_FROM, DOS_TO, CPT_CD,
                      MODIFIER_1, MODIFIER_2,
                      CHARGE_AMT, PAID_AMT,
                      PAYMENT_STATUS_CD
               FROM   MIVANCPS.CLAIM_PAYMENT
               WHERE  PAYMENT_STATUS_CD = 'PD'
               FOR    READ ONLY
       END-EXEC.

       EXEC SQL
           DECLARE NEAR-DUP-CUR CURSOR FOR
               SELECT CLAIM_ID, CHARGE_AMT, MODIFIER_1, MODIFIER_2,
                      DOS_FROM
               FROM   MIVANCPS.CLAIM_PAYMENT
               WHERE  MEMBER_ID          = :MEMBER-ID
                 AND  PROV_NPI           = :PROV-NPI
                 AND  CPT_CD             = :CPT-CD
                 AND  DOS_FROM BETWEEN :WS-DOS-LOW AND :WS-DOS-HIGH
                 AND  PAYMENT_STATUS_CD  = 'PD'
                 AND  CLAIM_ID          <> :CLAIM-ID
               FOR    READ ONLY
       END-EXEC.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS        UNTIL SQLCODE = 100
           PERFORM 9000-TERMINATE
           STOP RUN.

       1000-INITIALIZE.
           MOVE FUNCTION CURRENT-DATE(1:8)
               TO WS-CURRENT-DATE-NUM
           MOVE ZEROES TO WS-CLAIM-COUNT
                          WS-DUP-COUNT
                          WS-NEAR-DUP-COUNT
                          WS-RETURN-CODE
           EXEC SQL
               OPEN PAID-CLAIMS-CUR
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE SQLCODE TO WS-SQLCODE-SAVE
               DISPLAY 'MOVPDUP1: OPEN PAID-CLAIMS-CUR FAILED '
                       WS-SQLCODE-SAVE
               MOVE 8 TO WS-RETURN-CODE
               PERFORM 9000-TERMINATE
               STOP RUN
           END-IF.

       2000-PROCESS.
           EXEC SQL
               FETCH PAID-CLAIMS-CUR
               INTO  :CLAIM-ID, :MEMBER-ID, :PROV-NPI,
                     :DOS-FROM, :DOS-TO, :CPT-CD,
                     :MODIFIER-1, :MODIFIER-2,
                     :CHARGE-AMT, :PAID-AMT,
                     :PAYMENT-STATUS-CD
           END-EXEC
           IF SQLCODE = 100
               GO TO 2000-PROCESS-EXIT
           END-IF
           IF SQLCODE NOT = 0
               MOVE SQLCODE TO WS-SQLCODE-SAVE
               DISPLAY 'MOVPDUP1: FETCH ERROR ' WS-SQLCODE-SAVE
               MOVE 8 TO WS-RETURN-CODE
               GO TO 2000-PROCESS-EXIT
           END-IF
           ADD 1 TO WS-CLAIM-COUNT
           IF PAYMENT-STATUS-CD = 'ED'
               GO TO 2000-PROCESS-EXIT
           END-IF
           PERFORM 2100-SET-DOS-RANGE
           PERFORM 2200-FIND-NEAR-DUP
           .
       2000-PROCESS-EXIT.
           EXIT.

       2100-SET-DOS-RANGE.
           COMPUTE WS-DOS-LOW  = DOS-FROM - 1
           COMPUTE WS-DOS-HIGH = DOS-FROM + 1.

       2200-FIND-NEAR-DUP.
           SET NEAR-DUP-NOT-FOUND TO TRUE
           EXEC SQL
               OPEN NEAR-DUP-CUR
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE SQLCODE TO WS-SQLCODE-SAVE
               DISPLAY 'MOVPDUP1: OPEN NEAR-DUP-CUR FAILED '
                       WS-SQLCODE-SAVE
               MOVE 8 TO WS-RETURN-CODE
               GO TO 2200-FIND-EXIT
           END-IF
           PERFORM 2210-FETCH-CANDIDATE
               UNTIL NEAR-DUP-FOUND OR SQLCODE = 100
           EXEC SQL
               CLOSE NEAR-DUP-CUR
           END-EXEC
           IF NEAR-DUP-FOUND
               PERFORM 3000-FLAG-NEAR-DUP
           END-IF
           .
       2200-FIND-EXIT.
           EXIT.

       2210-FETCH-CANDIDATE.
           EXEC SQL
               FETCH NEAR-DUP-CUR
               INTO  :NDUP-CLAIM-ID,
                     :NDUP-CHARGE-AMT,
                     :NDUP-MATCH-TYPE,
                     :MODIFIER-2,
                     :NDUP-DOS
           END-EXEC
           IF SQLCODE = 100 OR SQLCODE NOT = 0
               EXIT
           END-IF
           PERFORM 3100-EVALUATE-MATCH.

       3000-FLAG-NEAR-DUP.
           MOVE CLAIM-ID         TO NDUP-CLAIM-ID
           MOVE MEMBER-ID        TO NDUP-MEMBER-ID
           MOVE PROV-NPI         TO NDUP-PROV-NPI
           MOVE DOS-FROM         TO NDUP-DOS
           MOVE CPT-CD           TO NDUP-CPT-CD
           MOVE CHARGE-AMT       TO NDUP-CHARGE-AMT
           MOVE WS-CURRENT-DATE-NUM TO NDUP-CREATE-DT
           EXEC SQL
               INSERT INTO MIVANCPS.NEAR_DUP_QUEUE (
                   NDUP_CLAIM_ID, NDUP_ORIG_CLAIM_ID,
                   NDUP_MEMBER_ID, NDUP_PROV_NPI, NDUP_DOS,
                   NDUP_CPT_CD, NDUP_CHARGE_AMT, NDUP_MATCH_TYPE,
                   NDUP_PEND_REASON, NDUP_CREATE_DT, NDUP_STATUS)
               VALUES (
                   :NDUP-CLAIM-ID, :NDUP-ORIG-CLAIM-ID,
                   :NDUP-MEMBER-ID, :NDUP-PROV-NPI, :NDUP-DOS,
                   :NDUP-CPT-CD, :NDUP-CHARGE-AMT, :NDUP-MATCH-TYPE,
                   :NDUP-PEND-REASON, :NDUP-CREATE-DT, :NDUP-STATUS)
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE SQLCODE TO WS-SQLCODE-SAVE
               DISPLAY 'MOVPDUP1: INSERT NEAR_DUP_QUEUE FAILED '
                       WS-SQLCODE-SAVE
               MOVE 8 TO WS-RETURN-CODE
           ELSE
               ADD 1 TO WS-NEAR-DUP-COUNT
           END-IF.

       3100-EVALUATE-MATCH.
           COMPUTE WS-CHARGE-DIFF =
               FUNCTION ABS(CHARGE-AMT - NDUP-CHARGE-AMT)
           IF NDUP-CHARGE-AMT > ZEROES
               COMPUTE WS-CHARGE-PCT =
                   WS-CHARGE-DIFF / NDUP-CHARGE-AMT
           ELSE
               MOVE ZEROES TO WS-CHARGE-PCT
           END-IF
           IF WS-CHARGE-PCT > WS-10-PCT
               EXIT
           END-IF
           EVALUATE TRUE
               WHEN MODIFIER-1 NOT = NDUP-MATCH-TYPE
                   MOVE 'MODIFIER'   TO WS-MATCH-TYPE
               WHEN DOS-FROM NOT = NDUP-DOS
                   MOVE 'DATE-DRIFT' TO WS-MATCH-TYPE
               WHEN WS-CHARGE-PCT > ZEROES
                   MOVE 'AMT-VAR'    TO WS-MATCH-TYPE
               WHEN OTHER
                   EXIT
           END-EVALUATE
           MOVE WS-MATCH-TYPE  TO NDUP-MATCH-TYPE
           SET NEAR-DUP-FOUND  TO TRUE.

       9000-TERMINATE.
           EXEC SQL
               CLOSE PAID-CLAIMS-CUR
           END-EXEC
           DISPLAY 'MOVPDUP1 COMPLETE'
           DISPLAY '  CLAIMS PROCESSED : ' WS-CLAIM-COUNT
           DISPLAY '  NEAR-DUPS FOUND  : ' WS-NEAR-DUP-COUNT
           MOVE WS-RETURN-CODE TO RETURN-CODE.