      *----------------------------------------------------------------*
      * CLMPAYRC  Host variable layout for MIVANCPS.CLAIM_PAYMENT      *
      *----------------------------------------------------------------*
       01  CLAIM-PAYMENT-REC.
           05  CLAIM-ID              PIC X(20).
           05  MEMBER-ID             PIC X(15).
           05  PROV-NPI              PIC X(10).
           05  DOS-FROM              PIC 9(8).
           05  DOS-TO                PIC 9(8).
           05  CPT-CD                PIC X(5).
           05  MODIFIER-1            PIC X(2).
           05  MODIFIER-2            PIC X(2).
           05  CHARGE-AMT            PIC S9(7)V99  COMP-3.
           05  PAID-AMT              PIC S9(7)V99  COMP-3.
           05  PAYMENT-STATUS-CD     PIC X(2).
           05  PAYMENT-DT            PIC 9(8).