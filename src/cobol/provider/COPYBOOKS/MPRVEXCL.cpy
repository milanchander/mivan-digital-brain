      ******************************************************************
      * COPYBOOK : MPRVEXCL                                            *
      * PURPOSE  : Provider Exclusion / sanction record layout.       *
      *            Consolidated view over OIG LEIE, SAM, and state    *
      *            exclusion sources.                                 *
      * PROGRAMS : MPRVEXC0                                           *
      * PROGRAM TREE: Provider Data Validation                        *
      * COMPLIANCE: Federal law (42 USC 1320a-7b) prohibits payment  *
      *            to or on behalf of an excluded provider.          *
      ******************************************************************
       01  PROVIDER-EXCL-REC.
           05  EXCL-NPI            PIC X(10).
           05  EXCL-TAX-ID         PIC X(9).
           05  EXCL-SOURCE         PIC X(10).
           05  EXCL-TYPE-CD        PIC X(4).
           05  EXCL-EFFECTIVE-DT   PIC 9(8).
           05  EXCL-REINSTATE-DT   PIC 9(8).
           05  EXCL-REASON-CD      PIC X(4).
           05  EXCL-FLAG           PIC X(1).
               88  PROVIDER-EXCLUDED  VALUE 'Y'.
               88  PROVIDER-ACTIVE    VALUE 'N'.
