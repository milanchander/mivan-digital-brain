      *----------------------------------------------------------------*
      * MOVPDUP1  Working storage for near-dup detection               *
      *----------------------------------------------------------------*
       01  WS-MOVPDUP1-FIELDS.
           05  WS-PROGRAM-NAME       PIC X(8)      VALUE 'MOVPDUP1'.
           05  WS-CURRENT-DATE-NUM   PIC 9(8).
           05  WS-RETURN-CODE        PIC S9(4)      COMP.
           05  WS-CLAIM-COUNT        PIC 9(9)       COMP.
           05  WS-DUP-COUNT          PIC 9(7)       COMP.
           05  WS-NEAR-DUP-COUNT     PIC 9(7)       COMP.
           05  WS-DOS-LOW            PIC 9(8)       COMP.
           05  WS-DOS-HIGH           PIC 9(8)       COMP.
           05  WS-10-PCT             PIC S9(3)V99   COMP-3 VALUE 0.10.
           05  WS-CHARGE-DIFF        PIC S9(7)V99   COMP-3.
           05  WS-CHARGE-PCT         PIC S9(3)V99   COMP-3.
           05  WS-NEAR-DUP-FOUND     PIC X(1).
               88  NEAR-DUP-FOUND        VALUE 'Y'.
               88  NEAR-DUP-NOT-FOUND    VALUE 'N'.
           05  WS-MATCH-TYPE         PIC X(10).