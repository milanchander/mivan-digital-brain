      ******************************************************************
      * COPYBOOK : MPRVVLDR                                            *
      * PURPOSE  : Provider validation working-storage area.          *
      *            Accumulates the results of the five validation     *
      *            steps for a single (NPI, date-of-service) request. *
      * PROGRAMS : MPRVVLDR0 (driver), all subprograms via LINKAGE   *
      * PROGRAM TREE: Provider Data Validation                        *
      ******************************************************************
       01  WS-PRV-VALIDATION.
           05  WS-PRV-NPI          PIC X(10).
           05  WS-PRV-DOS          PIC 9(8).
           05  WS-PRV-VALID-FLAG   PIC X(1).
               88  PROVIDER-VALID     VALUE 'Y'.
               88  PROVIDER-INVALID   VALUE 'N'.
           05  WS-PRV-NETWORK-IND  PIC X(3).
               88  IN-NETWORK         VALUE 'INN'.
               88  OUT-OF-NETWORK     VALUE 'OON'.
           05  WS-PRV-CRED-VALID   PIC X(1).
               88  CREDENTIALED       VALUE 'Y'.
           05  WS-PRV-EXCL-FLAG    PIC X(1).
               88  NOT-EXCLUDED       VALUE 'N'.
               88  IS-EXCLUDED        VALUE 'Y'.
           05  WS-PRV-DENY-REASON  PIC X(30).
           05  WS-PRV-TIER-CD      PIC X(2).
           05  WS-PRV-FEE-SCHED-ID PIC X(10).
