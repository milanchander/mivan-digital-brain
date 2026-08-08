      *----------------------------------------------------------------*
      * PROGRAM:    MAENCBL0                                        *
      * PURPOSE:    Encounter Record Builder Subprogram             *
      * CALLED BY:  MAENCDR0                                        *
      * JAVA EQ:    EncounterBuilderService.java                    *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    MAENCBL0.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SQLCODE              PIC S9(09) COMP VALUE +0.
       01  WS-ENCOUNTER-ID         PIC X(20)      VALUE SPACES.
       01  WS-TIMESTAMP            PIC X(26)      VALUE SPACES.
       01  WS-SEQ-NO               PIC 9(10)      VALUE ZEROS.

           EXEC SQL INCLUDE SQLCA END-EXEC.

           EXEC SQL
               DECLARE MA_ENCOUNTER_STAGING TABLE
               ( ENCOUNTER_ID      CHAR(20)     NOT NULL,
                 TRANSACTION_TYPE  CHAR(2)      NOT NULL,
                 SUBMISSION_TYPE   CHAR(2)      NOT NULL,
                 MBI               CHAR(11)     NOT NULL,
                 HICN              CHAR(12),
                 CONTRACT_ID       CHAR(5)      NOT NULL,
                 PLAN_ID           CHAR(3)      NOT NULL,
                 DOS_FROM          CHAR(8)      NOT NULL,
                 DOS_THRU          CHAR(8)      NOT NULL,
                 TOTAL_BILLED      DECIMAL(11,2),
                 TOTAL_PAID        DECIMAL(11,2),
                 SUBMISSION_STATUS CHAR(2)      NOT NULL,
                 SUBMIT_DATE       CHAR(8) )
           END-EXEC.

       LINKAGE SECTION.
           COPY MAENROLL.
           COPY MAHCCREC.
           COPY MARAFSCR.
           COPY MAENCSTG.
       01  LS-RETURN-CODE          PIC S9(04) COMP.

       PROCEDURE DIVISION USING MA-ENROLLMENT-RECORD
                                MA-HCC-RECORD
                                MA-RAF-SCORE-RECORD
                                MA-ENCOUNTER-STAGING
                                LS-RETURN-CODE.

       0000-MAIN.
           MOVE +0 TO LS-RETURN-CODE
           PERFORM 1000-GENERATE-ENCOUNTER-ID
           PERFORM 2000-BUILD-ENCOUNTER-RECORD
           PERFORM 3000-INSERT-STAGING
           GOBACK
           .

       1000-GENERATE-ENCOUNTER-ID.
           EXEC SQL
               SELECT NEXTVAL FOR MA_ENCOUNTER_SEQ
                 INTO :WS-SEQ-NO
                 FROM SYSIBM.SYSDUMMY1
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE +8 TO LS-RETURN-CODE
               GOBACK
           END-IF
           STRING MAE-CONTRACT-ID DELIMITED SIZE
                  MAE-PLAN-ID     DELIMITED SIZE
                  WS-SEQ-NO       DELIMITED SIZE
                  INTO WS-ENCOUNTER-ID
           MOVE WS-ENCOUNTER-ID TO MEST-ENCOUNTER-ID
           .

       2000-BUILD-ENCOUNTER-RECORD.
           MOVE '01' TO MEST-TRANSACTION-TYPE
           MOVE 'PR' TO MEST-SUBMISSION-TYPE
           MOVE MAE-MBI            TO MEST-MBI
           MOVE MAE-HICN           TO MEST-HICN
           MOVE MAE-CONTRACT-ID    TO MEST-CONTRACT-ID
           MOVE MAE-PLAN-ID        TO MEST-PLAN-ID
           MOVE MHCC-DOS-FROM      TO MEST-DOS-FROM
           MOVE MHCC-DOS-THRU      TO MEST-DOS-THRU
           MOVE MHCC-PROVIDER-NPI  TO MEST-BILLING-NPI
           MOVE MHCC-PROVIDER-NPI  TO MEST-RENDERING-NPI
           MOVE 'PE'               TO MEST-SUBMISSION-STATUS
           .

       3000-INSERT-STAGING.
           EXEC SQL
               INSERT INTO MA_ENCOUNTER_STAGING
               ( ENCOUNTER_ID, TRANSACTION_TYPE, SUBMISSION_TYPE,
                 MBI, HICN, CONTRACT_ID, PLAN_ID,
                 DOS_FROM, DOS_THRU, SUBMISSION_STATUS )
               VALUES
               ( :MEST-ENCOUNTER-ID, :MEST-TRANSACTION-TYPE,
                 :MEST-SUBMISSION-TYPE,
                 :MEST-MBI, :MEST-HICN,
                 :MEST-CONTRACT-ID, :MEST-PLAN-ID,
                 :MEST-DOS-FROM, :MEST-DOS-THRU,
                 :MEST-SUBMISSION-STATUS )
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE +8 TO LS-RETURN-CODE
           END-IF
           .
