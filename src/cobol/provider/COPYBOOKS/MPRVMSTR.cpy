      ******************************************************************
      * COPYBOOK : MPRVMSTR                                            *
      * PURPOSE  : Provider Master record layout.                     *
      *            Maps to PROV-MSTR VSAM KSDS (key = PRV-NPI) and    *
      *            the DB2 PROVIDER_MASTER table.                     *
      * PROGRAMS : MPRVVLDR0, MPRVNPI0, MPRVSANL0                     *
      * PROGRAM TREE: Provider Data Validation                        *
      ******************************************************************
       01  PROVIDER-MASTER-REC.
           05  PRV-NPI             PIC X(10).
           05  PRV-NPI-TYPE        PIC X(1).
           05  PRV-TAX-ID          PIC X(9).
           05  PRV-LAST-NAME       PIC X(35).
           05  PRV-FIRST-NAME      PIC X(25).
           05  PRV-ORG-NAME        PIC X(60).
           05  PRV-TAXONOMY-1      PIC X(10).
           05  PRV-TAXONOMY-2      PIC X(10).
           05  PRV-SPECIALTY-CD    PIC X(4).
           05  PRV-NETWORK-STATUS  PIC X(3).
           05  PRV-CONTRACT-ID     PIC X(15).
           05  PRV-NETWORK-TIER    PIC X(2).
           05  PRV-CRED-STATUS     PIC X(2).
           05  PRV-CRED-EXP-DT     PIC 9(8).
           05  PRV-EXCL-FLAG       PIC X(1).
           05  PRV-EXCL-DT         PIC 9(8).
           05  PRV-EFFECTIVE-DT    PIC 9(8).
           05  PRV-TERM-DT         PIC 9(8).
           05  PRV-STATUS-CD       PIC X(2).
