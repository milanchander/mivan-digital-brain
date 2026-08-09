      ******************************************************************
      * COPYBOOK : MPRVNETW                                            *
      * PURPOSE  : Network Contract record layout.                    *
      *            Maps to the DB2 NETWORK_CONTRACT table.            *
      *            Drives in-network / out-of-network determination,  *
      *            tier assignment, and fee schedule selection.       *
      * PROGRAMS : MPRVNET0                                           *
      * PROGRAM TREE: Provider Data Validation                        *
      ******************************************************************
       01  NETWORK-CONTRACT-REC.
           05  NET-NPI             PIC X(10).
           05  NET-CONTRACT-ID     PIC X(15).
           05  NET-NETWORK-ID      PIC X(10).
           05  NET-TIER-CD         PIC X(2).
           05  NET-FEE-SCHED-ID    PIC X(10).
           05  NET-EFFECTIVE-DT    PIC 9(8).
           05  NET-TERM-DT         PIC 9(8).
           05  NET-STATUS-CD       PIC X(2).
           05  NET-ACCEPT-NEW-PAT  PIC X(1).
