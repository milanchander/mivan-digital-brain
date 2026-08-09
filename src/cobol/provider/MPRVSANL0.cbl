      ******************************************************************
      * PROGRAM   : MPRVSANL0                                          *
      * TITLE     : Sanction Logging Subprogram                       *
      * SYSTEM    : MiCPS - Provider Data Validation                  *
      * CALLED BY : MPRVVLDR0                                         *
      *--------------------------------------------------------------*
      * FUNCTION  : Writes the mandatory audit trail for a provider    *
      *             validation.  ALWAYS executes - both for clean      *
      *             validations and for exclusion hits - so that a     *
      *             complete, immutable record exists for every        *
      *             provider evaluated for payment.                    *
      *             Writes to the DB2 PROVIDER_SANCTION_LOG table and  *
      *             maintains the exclusion flag on the provider       *
      *             master when an exclusion is recorded.              *
      *--------------------------------------------------------------*
      * COMPLIANCE: This audit trail supports CMS / OIG program-       *
      *             integrity requirements and MUST NOT be skipped.    *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MPRVSANL0.
       AUTHOR.        MIVAN-DIGITAL-BRAIN.
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.
      *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY MPRVVLDR.
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
       01  WS-SANCTION-RECORD.
           05  WS-SL-NPI           PIC X(10).
           05  WS-SL-EVENT-CD      PIC X(4).
           05  WS-SL-VALID-FLAG    PIC X(1).
           05  WS-SL-EXCL-FLAG     PIC X(1).
           05  WS-SL-DENY-REASON   PIC X(30).
           05  WS-SL-NETWORK-IND   PIC X(3).
           05  WS-SL-TIER-CD       PIC X(2).
           05  WS-SL-TIMESTAMP     PIC X(26).
      *
       LINKAGE SECTION.
       01  LS-EVENT-CD             PIC X(4).
       01  LS-VALIDATION-AREA.
           05  LS-VA-NPI           PIC X(10).
           05  LS-VA-DOS           PIC 9(8).
           05  LS-VA-VALID-FLAG    PIC X(1).
           05  LS-VA-NETWORK-IND   PIC X(3).
           05  LS-VA-CRED-VALID    PIC X(1).
           05  LS-VA-EXCL-FLAG     PIC X(1).
           05  LS-VA-DENY-REASON   PIC X(30).
           05  LS-VA-TIER-CD       PIC X(2).
           05  LS-VA-FEE-SCHED-ID  PIC X(10).
       01  LS-RETURN-CODE          PIC S9(4) COMP.
      *
       PROCEDURE DIVISION USING LS-EVENT-CD
                                LS-VALIDATION-AREA
                                LS-RETURN-CODE.
      *================================================================*
       0000-MAIN.
      *================================================================*
           MOVE ZERO TO LS-RETURN-CODE
           PERFORM 3000-BUILD-SANCTION-RECORD
           PERFORM 3100-WRITE-SANCTION-LOG
           IF LS-VA-EXCL-FLAG = 'Y'
               PERFORM 3200-UPDATE-PROV-MSTR-FLAG
           END-IF
           GOBACK.
      *
      *================================================================*
       3000-BUILD-SANCTION-RECORD.
      *================================================================*
           MOVE LS-VA-NPI          TO WS-SL-NPI
           MOVE LS-EVENT-CD        TO WS-SL-EVENT-CD
           MOVE LS-VA-VALID-FLAG   TO WS-SL-VALID-FLAG
           MOVE LS-VA-EXCL-FLAG    TO WS-SL-EXCL-FLAG
           MOVE LS-VA-DENY-REASON  TO WS-SL-DENY-REASON
           MOVE LS-VA-NETWORK-IND  TO WS-SL-NETWORK-IND
           MOVE LS-VA-TIER-CD      TO WS-SL-TIER-CD
           MOVE FUNCTION CURRENT-DATE TO WS-SL-TIMESTAMP.
      *
      *================================================================*
       3100-WRITE-SANCTION-LOG.
      *================================================================*
           EXEC SQL
               INSERT INTO PROVIDER_SANCTION_LOG
                     ( NPI, EVENT_CD, VALID_FLAG, EXCL_FLAG,
                       DENY_REASON, NETWORK_IND, TIER_CD, LOG_TS )
               VALUES
                     ( :WS-SL-NPI, :WS-SL-EVENT-CD, :WS-SL-VALID-FLAG,
                       :WS-SL-EXCL-FLAG, :WS-SL-DENY-REASON,
                       :WS-SL-NETWORK-IND, :WS-SL-TIER-CD,
                       CURRENT TIMESTAMP )
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 8 TO LS-RETURN-CODE
               DISPLAY 'MPRVSANL0 - SANCTION LOG INSERT FAILED SQLCODE='
                       SQLCODE
           END-IF.
      *
      *================================================================*
       3200-UPDATE-PROV-MSTR-FLAG.
      *================================================================*
      *    Persist the exclusion flag on the provider master so that   *
      *    subsequent runs see the local hit immediately.             *
           EXEC SQL
               UPDATE PROVIDER_MASTER
                  SET EXCL_FLAG = 'Y',
                      EXCL_DT   = CURRENT DATE
               WHERE NPI = :LS-VA-NPI
           END-EXEC
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
               MOVE 8 TO LS-RETURN-CODE
               DISPLAY 'MPRVSANL0 - PROV-MSTR FLAG UPDATE FAILED '
                       'SQLCODE=' SQLCODE
           END-IF.
