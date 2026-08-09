      ******************************************************************
      * COPYBOOK : MPRVCRED                                            *
      * PURPOSE  : Provider Credentialing record layout.              *
      *            Maps to the DB2 PROVIDER_CREDENTIAL table.         *
      *            One provider (NPI) may hold multiple credential    *
      *            rows (license, DEA, malpractice, board cert).      *
      * PROGRAMS : MPRVCRD0                                           *
      * PROGRAM TREE: Provider Data Validation                        *
      ******************************************************************
       01  PROVIDER-CRED-REC.
           05  CRED-NPI            PIC X(10).
           05  CRED-TYPE-CD        PIC X(4).
           05  CRED-ISSUER         PIC X(40).
           05  CRED-NUMBER         PIC X(20).
           05  CRED-STATE          PIC X(2).
           05  CRED-ISSUE-DT       PIC 9(8).
           05  CRED-EXPIRY-DT      PIC 9(8).
           05  CRED-STATUS-CD      PIC X(2).
           05  CRED-VERIFIED-DT    PIC 9(8).
           05  CRED-VERIFIED-BY    PIC X(10).
           05  CRED-CAQH-ID        PIC X(10).
