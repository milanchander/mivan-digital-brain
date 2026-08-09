      ******************************************************************
      * PROGRAM   : MPRVNET0                                           *
      * TITLE     : Network Verification Subprogram                   *
      * SYSTEM    : MiCPS - Provider Data Validation                  *
      * CALLED BY : MPRVVLDR0                                         *
      *--------------------------------------------------------------*
      * FUNCTION  : Determines the provider's network participation    *
      *             for the date of service and returns:              *
      *               - network indicator (INN / OON)                 *
      *               - network tier code                             *
      *               - fee schedule pointer                          *
      *               - whether the provider accepts new patients     *
      *             Reads the DB2 NETWORK_CONTRACT table.             *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MPRVNET0.
       AUTHOR.        MIVAN-DIGITAL-BRAIN.
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.
      *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY MPRVNETW.
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
       01  WS-NET-SWITCHES.
           05  WS-CONTRACT-FOUND   PIC X(1)   VALUE 'N'.
               88  CONTRACT-FOUND      VALUE 'Y'.
      *
       LINKAGE SECTION.
       01  LS-NPI                  PIC X(10).
       01  LS-DOS                  PIC 9(8).
       01  LS-NETWORK-IND          PIC X(3).
           88  LS-IN-NETWORK          VALUE 'INN'.
           88  LS-OUT-OF-NETWORK      VALUE 'OON'.
       01  LS-TIER-CD              PIC X(2).
       01  LS-FEE-SCHED-ID        PIC X(10).
       01  LS-NET-REC.
           05  LS-NET-DATA        PIC X(72).
       01  LS-RETURN-CODE          PIC S9(4) COMP.
      *
       PROCEDURE DIVISION USING LS-NPI
                                LS-DOS
                                LS-NETWORK-IND
                                LS-TIER-CD
                                LS-FEE-SCHED-ID
                                LS-NET-REC
                                LS-RETURN-CODE.
      *================================================================*
       0000-MAIN.
      *================================================================*
           MOVE ZERO   TO LS-RETURN-CODE
           MOVE 'OON'  TO LS-NETWORK-IND
           MOVE SPACES TO LS-TIER-CD
           MOVE SPACES TO LS-FEE-SCHED-ID
           PERFORM 3000-LOOKUP-NETWORK-CONTRACT
           IF CONTRACT-FOUND
               PERFORM 3100-VALIDATE-CONTRACT-DATES
           END-IF
           IF CONTRACT-FOUND
               PERFORM 3200-GET-NETWORK-TIER
               PERFORM 3300-GET-FEE-SCHEDULE-POINTER
               PERFORM 3400-CHECK-ACCEPTING-PATIENTS
           END-IF
           PERFORM 4000-RETURN-NETWORK-RESULT
           GOBACK.
      *
      *================================================================*
       3000-LOOKUP-NETWORK-CONTRACT.
      *================================================================*
           EXEC SQL
               SELECT NPI, CONTRACT_ID, NETWORK_ID, TIER_CD,
                      FEE_SCHED_ID, EFFECTIVE_DT, TERM_DT,
                      STATUS_CD, ACCEPT_NEW_PAT
               INTO  :NET-NPI, :NET-CONTRACT-ID, :NET-NETWORK-ID,
                     :NET-TIER-CD, :NET-FEE-SCHED-ID,
                     :NET-EFFECTIVE-DT, :NET-TERM-DT,
                     :NET-STATUS-CD, :NET-ACCEPT-NEW-PAT
               FROM  NETWORK_CONTRACT
               WHERE NPI = :LS-NPI
                 AND STATUS_CD = 'AC'
                 AND EFFECTIVE_DT <= :LS-DOS
               ORDER BY EFFECTIVE_DT DESC
               FETCH FIRST ROW ONLY
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   SET CONTRACT-FOUND TO TRUE
               WHEN 100
                   MOVE 'N' TO WS-CONTRACT-FOUND
               WHEN OTHER
                   MOVE 8 TO LS-RETURN-CODE
           END-EVALUATE.
      *
      *================================================================*
       3100-VALIDATE-CONTRACT-DATES.
      *================================================================*
      *    Contract must be effective and not terminated before DOS.   *
           IF NET-TERM-DT NOT = ZERO
             AND NET-TERM-DT < LS-DOS
               MOVE 'N' TO WS-CONTRACT-FOUND
           END-IF.
      *
      *================================================================*
       3200-GET-NETWORK-TIER.
      *================================================================*
           SET LS-IN-NETWORK TO TRUE
           MOVE NET-TIER-CD TO LS-TIER-CD.
      *
      *================================================================*
       3300-GET-FEE-SCHEDULE-POINTER.
      *================================================================*
           MOVE NET-FEE-SCHED-ID TO LS-FEE-SCHED-ID.
      *
      *================================================================*
       3400-CHECK-ACCEPTING-PATIENTS.
      *================================================================*
      *    Informational only; does not change INN/OON determination.  *
           IF NET-ACCEPT-NEW-PAT = 'N'
               CONTINUE
           END-IF.
      *
      *================================================================*
       4000-RETURN-NETWORK-RESULT.
      *================================================================*
           IF NOT CONTRACT-FOUND
               MOVE 'OON' TO LS-NETWORK-IND
           END-IF
           MOVE NETWORK-CONTRACT-REC TO LS-NET-REC.
