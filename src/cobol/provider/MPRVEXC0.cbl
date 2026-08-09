      ******************************************************************
      * PROGRAM   : MPRVEXC0                                           *
      * TITLE     : Exclusion Check Subprogram                        *
      * SYSTEM    : MiCPS - Provider Data Validation                  *
      * CALLED BY : MPRVVLDR0                                         *
      *--------------------------------------------------------------*
      * FUNCTION  : Checks the provider against every federal and      *
      *             state exclusion source:                           *
      *               - OIG LEIE (List of Excluded Individuals/       *
      *                 Entities)                                     *
      *               - SAM (System for Award Management)            *
      *               - State Medicaid exclusion lists                *
      *               - PROV-MSTR local exclusion flag                *
      *--------------------------------------------------------------*
      * ***  COMPLIANCE - CRITICAL  ***                               *
      * Federal law (42 USC 1320a-7b, 42 CFR 1001.1901) PROHIBITS    *
      * payment by any federal healthcare program to, or on behalf   *
      * of, a provider who appears on an exclusion list.  A single   *
      * exclusion hit MUST block payment.  This check may NOT be     *
      * bypassed, and its outcome is ALWAYS written to the sanction  *
      * log by MPRVSANL0.                                            *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MPRVEXC0.
       AUTHOR.        MIVAN-DIGITAL-BRAIN.
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.
      *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY MPRVEXCL.
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
       01  WS-EXCL-HITS.
           05  WS-OIG-HIT          PIC X(1)   VALUE 'N'.
           05  WS-SAM-HIT          PIC X(1)   VALUE 'N'.
           05  WS-STATE-HIT        PIC X(1)   VALUE 'N'.
           05  WS-MSTR-HIT         PIC X(1)   VALUE 'N'.
      *
       LINKAGE SECTION.
       01  LS-NPI                  PIC X(10).
       01  LS-TAX-ID               PIC X(9).
       01  LS-DOS                  PIC 9(8).
       01  LS-EXCL-REC.
           05  LS-EX-FLAG          PIC X(1).
               88  LS-IS-EXCLUDED     VALUE 'Y'.
               88  LS-NOT-EXCLUDED    VALUE 'N'.
           05  LS-EX-SOURCE        PIC X(10).
           05  LS-EX-REASON        PIC X(30).
       01  LS-RETURN-CODE          PIC S9(4) COMP.
      *
       PROCEDURE DIVISION USING LS-NPI
                                LS-TAX-ID
                                LS-DOS
                                LS-EXCL-REC
                                LS-RETURN-CODE.
      *================================================================*
       0000-MAIN.
      *================================================================*
           MOVE ZERO   TO LS-RETURN-CODE
           MOVE 'N'    TO LS-EX-FLAG
           MOVE SPACES TO LS-EX-SOURCE
           MOVE SPACES TO LS-EX-REASON
           PERFORM 3000-CHECK-OIG-LEIE
           PERFORM 3100-CHECK-SAM-EXCLUSION
           PERFORM 3200-CHECK-STATE-EXCLUSION
           PERFORM 3300-CHECK-PROV-MSTR-EXCL-FLAG
           PERFORM 3400-EVALUATE-EXCLUSION-RESULT
           PERFORM 4000-RETURN-EXCLUSION-RESULT
           GOBACK.
      *
      *================================================================*
       3000-CHECK-OIG-LEIE.
      *================================================================*
      *    OIG List of Excluded Individuals/Entities.  Match on either *
      *    NPI or Tax ID; an active (not reinstated) row is a hit.      *
           EXEC SQL
               SELECT EXCL_TYPE_CD, REASON_CD
               INTO  :EXCL-TYPE-CD, :EXCL-REASON-CD
               FROM  OIG_EXCLUSION_LIST
               WHERE (NPI = :LS-NPI OR TAX_ID = :LS-TAX-ID)
                 AND REINSTATE_DT IS NULL
                 AND EFFECTIVE_DT <= :LS-DOS
               FETCH FIRST ROW ONLY
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   MOVE 'Y' TO WS-OIG-HIT
               WHEN 100
                   MOVE 'N' TO WS-OIG-HIT
               WHEN OTHER
                   MOVE 8 TO LS-RETURN-CODE
           END-EVALUATE.
      *
      *================================================================*
       3100-CHECK-SAM-EXCLUSION.
      *================================================================*
      *    SAM (System for Award Management) debarment / exclusion.    *
           EXEC SQL
               SELECT 1
               INTO  :EXCL-FLAG
               FROM  SAM_EXCLUSION_LIST
               WHERE (NPI = :LS-NPI OR TAX_ID = :LS-TAX-ID)
                 AND REINSTATE_DT IS NULL
               FETCH FIRST ROW ONLY
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   MOVE 'Y' TO WS-SAM-HIT
               WHEN 100
                   MOVE 'N' TO WS-SAM-HIT
               WHEN OTHER
                   MOVE 8 TO LS-RETURN-CODE
           END-EVALUATE.
      *
      *================================================================*
       3200-CHECK-STATE-EXCLUSION.
      *================================================================*
      *    State Medicaid exclusion list.                              *
           EXEC SQL
               SELECT 1
               INTO  :EXCL-FLAG
               FROM  STATE_EXCLUSION_LIST
               WHERE (NPI = :LS-NPI OR TAX_ID = :LS-TAX-ID)
                 AND REINSTATE_DT IS NULL
               FETCH FIRST ROW ONLY
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   MOVE 'Y' TO WS-STATE-HIT
               WHEN 100
                   MOVE 'N' TO WS-STATE-HIT
               WHEN OTHER
                   MOVE 8 TO LS-RETURN-CODE
           END-EVALUATE.
      *
      *================================================================*
       3300-CHECK-PROV-MSTR-EXCL-FLAG.
      *================================================================*
      *    Local exclusion flag maintained on the provider master.     *
           EXEC SQL
               SELECT EXCL_FLAG
               INTO  :EXCL-FLAG
               FROM  PROVIDER_MASTER
               WHERE NPI = :LS-NPI
           END-EXEC
           IF SQLCODE = 0 AND EXCL-FLAG = 'Y'
               MOVE 'Y' TO WS-MSTR-HIT
           END-IF.
      *
      *================================================================*
       3400-EVALUATE-EXCLUSION-RESULT.
      *================================================================*
      *    Any single hit excludes the provider.  Record the source    *
      *    in precedence order OIG > SAM > STATE > MASTER.             *
           EVALUATE TRUE
               WHEN WS-OIG-HIT = 'Y'
                   MOVE 'Y'          TO LS-EX-FLAG
                   MOVE 'OIG-LEIE'   TO LS-EX-SOURCE
                   MOVE 'EXCLUDED - OIG LEIE'   TO LS-EX-REASON
               WHEN WS-SAM-HIT = 'Y'
                   MOVE 'Y'          TO LS-EX-FLAG
                   MOVE 'SAM'        TO LS-EX-SOURCE
                   MOVE 'EXCLUDED - SAM DEBARMENT' TO LS-EX-REASON
               WHEN WS-STATE-HIT = 'Y'
                   MOVE 'Y'          TO LS-EX-FLAG
                   MOVE 'STATE'      TO LS-EX-SOURCE
                   MOVE 'EXCLUDED - STATE MEDICAID' TO LS-EX-REASON
               WHEN WS-MSTR-HIT = 'Y'
                   MOVE 'Y'          TO LS-EX-FLAG
                   MOVE 'PROV-MSTR'  TO LS-EX-SOURCE
                   MOVE 'EXCLUDED - MASTER FLAG' TO LS-EX-REASON
               WHEN OTHER
                   MOVE 'N'          TO LS-EX-FLAG
           END-EVALUATE.
      *
      *================================================================*
       4000-RETURN-EXCLUSION-RESULT.
      *================================================================*
           CONTINUE.
