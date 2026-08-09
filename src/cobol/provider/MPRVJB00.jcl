//MPRVJB00 JOB (MICPS),'PROVIDER VALIDATION',CLASS=A,
//             MSGCLASS=X,MSGLEVEL=(1,1),NOTIFY=&SYSUID,
//             REGION=0M
//*********************************************************************
//* JOB      : MPRVJB00                                              *
//* SYSTEM   : MiCPS - Provider Data Validation                     *
//* PURPOSE  : Runs the five-step provider validation program tree. *
//*                                                                 *
//*   STEP010  MPRVNPI0   NPI lookup                                *
//*   STEP020  MPRVCRD0   Credentialing check                      *
//*   STEP030  MPRVEXC0   Exclusion check (OIG/SAM/state)          *
//*   STEP040  MPRVNET0   Network verification                     *
//*   STEP050  MPRVSANL0  Sanction logging (ALWAYS runs)           *
//*                                                                 *
//* FLOW     : Each step is conditioned on RC <= 4 from all prior  *
//*            steps.  STEP050 (sanction logging) is a mandatory   *
//*            audit trail and runs unconditionally via EVEN so    *
//*            that a record exists even when an upstream step      *
//*            abends.                                             *
//*                                                                 *
//* COMPLIANCE: Federal law prohibits payment to excluded          *
//*            providers.  STEP030 must complete and STEP050 must  *
//*            always record the outcome.                          *
//*********************************************************************
//         SET HLQ=MICPS.PROD
//         SET LOADLIB=MICPS.PROD.LOADLIB
//         SET DB2SYS=DB2P
//         SET DB2PLAN=MPRVVLDR
//*
//*-------------------------------------------------------------------*
//* STEP010 - NPI LOOKUP                                             *
//*-------------------------------------------------------------------*
//STEP010  EXEC PGM=IKJEFT01,DYNAMNBR=20,COND=(4,LT)
//STEPLIB  DD DSN=&LOADLIB,DISP=SHR
//         DD DSN=DSN.&DB2SYS..SDSNLOAD,DISP=SHR
//*  Provider Master VSAM KSDS (keyed on NPI)                        *
//PROVMSTR DD DSN=&HLQ..PROV.MSTR.KSDS,DISP=SHR
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MPRVNPI0) PLAN(MPRVVLDR) -
      LIB('MICPS.PROD.LOADLIB')
  END
/*
//*-------------------------------------------------------------------*
//* STEP020 - CREDENTIALING CHECK                                    *
//*-------------------------------------------------------------------*
//STEP020  EXEC PGM=IKJEFT01,DYNAMNBR=20,COND=(4,LT)
//STEPLIB  DD DSN=&LOADLIB,DISP=SHR
//         DD DSN=DSN.&DB2SYS..SDSNLOAD,DISP=SHR
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MPRVCRD0) PLAN(MPRVVLDR) -
      LIB('MICPS.PROD.LOADLIB')
  END
/*
//*-------------------------------------------------------------------*
//* STEP030 - EXCLUSION CHECK (OIG LEIE / SAM / STATE)              *
//*-------------------------------------------------------------------*
//STEP030  EXEC PGM=IKJEFT01,DYNAMNBR=20,COND=(4,LT)
//STEPLIB  DD DSN=&LOADLIB,DISP=SHR
//         DD DSN=DSN.&DB2SYS..SDSNLOAD,DISP=SHR
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MPRVEXC0) PLAN(MPRVVLDR) -
      LIB('MICPS.PROD.LOADLIB')
  END
/*
//*-------------------------------------------------------------------*
//* STEP040 - NETWORK VERIFICATION                                   *
//*-------------------------------------------------------------------*
//STEP040  EXEC PGM=IKJEFT01,DYNAMNBR=20,COND=(4,LT)
//STEPLIB  DD DSN=&LOADLIB,DISP=SHR
//         DD DSN=DSN.&DB2SYS..SDSNLOAD,DISP=SHR
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MPRVNET0) PLAN(MPRVVLDR) -
      LIB('MICPS.PROD.LOADLIB')
  END
/*
//*-------------------------------------------------------------------*
//* STEP050 - SANCTION LOGGING (MANDATORY - ALWAYS RUNS)            *
//* COND=EVEN so the audit trail is written even if an upstream     *
//* step abended.                                                   *
//*-------------------------------------------------------------------*
//STEP050  EXEC PGM=IKJEFT01,DYNAMNBR=20,COND=EVEN
//STEPLIB  DD DSN=&LOADLIB,DISP=SHR
//         DD DSN=DSN.&DB2SYS..SDSNLOAD,DISP=SHR
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MPRVSANL0) PLAN(MPRVVLDR) -
      LIB('MICPS.PROD.LOADLIB')
  END
/*
//
