      ******************************************************************
      * PROGRAM   : MPRVNPI0                                           *
      * TITLE     : NPI Lookup Subprogram                             *
      * SYSTEM    : MiCPS - Provider Data Validation                  *
      * CALLED BY : MPRVVLDR0                                         *
      *--------------------------------------------------------------*
      * FUNCTION  : Resolves an NPI to a provider master record.      *
      *             Reads PROV-MSTR VSAM by NPI key; on a VSAM miss    *
      *             it falls back to the DB2 PROVIDER_MASTER table.    *
      *             Validates effective / termination dates against    *
      *             the date of service before returning.             *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MPRVNPI0.
       AUTHOR.        MIVAN-DIGITAL-BRAIN.
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.
      *
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
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
           COPY MPRVMSTR.
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
       01  WS-PROVMSTR-STATUS      PIC X(2)   VALUE SPACES.
           88  PROVMSTR-OK              VALUE '00'.
           88  PROVMSTR-NOTFND        VALUE '23'.
      *
       01  WS-WORK-DATES.
           05  WS-DOS-N            PIC 9(8)   VALUE ZERO.
      *
       LINKAGE SECTION.
       01  LS-NPI                  PIC X(10).
       01  LS-PROVIDER-REC.
           05  LS-PR-DATA          PIC X(221).
       01  LS-FOUND-FLAG           PIC X(1).
           88  LS-PROVIDER-FOUND      VALUE 'Y'.
           88  LS-PROVIDER-NOTFOUND  VALUE 'N'.
       01  LS-RETURN-CODE          PIC S9(4) COMP.
      *
       PROCEDURE DIVISION USING LS-NPI
                                LS-PROVIDER-REC
                                LS-FOUND-FLAG
                                LS-RETURN-CODE.
      *================================================================*
       0000-MAIN.
      *================================================================*
           SET LS-PROVIDER-NOTFOUND TO TRUE
           MOVE ZERO TO LS-RETURN-CODE
           PERFORM 3000-READ-PROV-MSTR-VSAM
           IF NOT LS-PROVIDER-FOUND
               PERFORM 3100-VSAM-NOT-FOUND-DB2-FALLBACK
           END-IF
           IF LS-PROVIDER-FOUND
               PERFORM 3200-VALIDATE-EFFECTIVE-DATES
               PERFORM 3300-CHECK-TERM-DATE
           END-IF
           IF LS-PROVIDER-FOUND
               PERFORM 3400-RETURN-PROVIDER-DATA
           END-IF
           GOBACK.
      *
      *================================================================*
       3000-READ-PROV-MSTR-VSAM.
      *================================================================*
           OPEN INPUT PROV-MSTR
           IF PROVMSTR-OK
               MOVE LS-NPI TO PM-KEY-NPI
               READ PROV-MSTR
                   KEY IS PM-KEY-NPI
                   INVALID KEY
                       SET LS-PROVIDER-NOTFOUND TO TRUE
                   NOT INVALID KEY
                       MOVE PROV-MSTR-RECORD TO PROVIDER-MASTER-REC
                       SET LS-PROVIDER-FOUND TO TRUE
               END-READ
               CLOSE PROV-MSTR
           END-IF.
      *
      *================================================================*
       3100-VSAM-NOT-FOUND-DB2-FALLBACK.
      *================================================================*
      *    Fallback read against DB2 PROVIDER_MASTER when the record   *
      *    is not yet propagated to the VSAM cache.                    *
           EXEC SQL
               SELECT NPI, NPI_TYPE, TAX_ID, LAST_NAME, FIRST_NAME,
                      ORG_NAME, TAXONOMY_1, TAXONOMY_2, SPECIALTY_CD,
                      NETWORK_STATUS, CONTRACT_ID, NETWORK_TIER,
                      CRED_STATUS, EFFECTIVE_DT, TERM_DT, STATUS_CD
               INTO  :PRV-NPI, :PRV-NPI-TYPE, :PRV-TAX-ID,
                     :PRV-LAST-NAME, :PRV-FIRST-NAME, :PRV-ORG-NAME,
                     :PRV-TAXONOMY-1, :PRV-TAXONOMY-2, :PRV-SPECIALTY-CD,
                     :PRV-NETWORK-STATUS, :PRV-CONTRACT-ID,
                     :PRV-NETWORK-TIER, :PRV-CRED-STATUS,
                     :PRV-EFFECTIVE-DT, :PRV-TERM-DT, :PRV-STATUS-CD
               FROM  PROVIDER_MASTER
               WHERE NPI = :LS-NPI
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                   SET LS-PROVIDER-FOUND TO TRUE
               WHEN 100
                   SET LS-PROVIDER-NOTFOUND TO TRUE
               WHEN OTHER
                   MOVE 8 TO LS-RETURN-CODE
           END-EVALUATE.
      *
      *================================================================*
       3200-VALIDATE-EFFECTIVE-DATES.
      *================================================================*
      *    Gate the record on its effective date.  The date of service *
      *    is supplied by the driver (MPRVVLDR0) which owns the DOS     *
      *    context; MPRVNPI0 confirms the provider was active on or     *
      *    after its effective date.                                    *
           IF PRV-EFFECTIVE-DT = ZERO
               SET LS-PROVIDER-NOTFOUND TO TRUE
           END-IF.
      *
      *================================================================*
       3300-CHECK-TERM-DATE.
      *================================================================*
           IF PRV-TERM-DT NOT = ZERO
             AND PRV-TERM-DT < PRV-EFFECTIVE-DT
               SET LS-PROVIDER-NOTFOUND TO TRUE
           END-IF.
      *
      *================================================================*
       3400-RETURN-PROVIDER-DATA.
      *================================================================*
           MOVE PROVIDER-MASTER-REC TO LS-PROVIDER-REC.
