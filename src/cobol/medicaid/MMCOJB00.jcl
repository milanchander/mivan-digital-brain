//MMCOJB00 JOB (MIVAN),'MEDICAID CLAIM PROC',
//             CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M
//*
//* MEDICAID CLAIM PROCESSING JOB STREAM
//* SCHEDULE:   NIGHTLY AFTER MADJMN00
//* UPSTREAM:   MADJMN00 (adjudication complete)
//* DOWNSTREAM: State MMIS submission
//* CONTACT:    MIVAN HEALTH PLAN - MEDICAID OPERATIONS
//*
//JOBLIB  DD  DSN=MIVAN.CPS.LOADLIB,DISP=SHR
//*
//********************************************************************
//* STEP010: MEDICAID ELIGIBILITY VERIFY
//********************************************************************
//STEP010  EXEC PGM=IKJEFT01
//STEPLIB  DD  DSN=MIVAN.CPS.LOADLIB,DISP=SHR
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MMCOELV0) PLAN(MMCOELV0) -
      LIB('MIVAN.CPS.DBRMLIB')
  END
/*
//*
//********************************************************************
//* STEP020: TPL IDENTIFICATION
//********************************************************************
//STEP020  EXEC PGM=IKJEFT01,
//             COND=(8,LT,STEP010)
//STEPLIB  DD  DSN=MIVAN.CPS.LOADLIB,DISP=SHR
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MMCOTPL0) PLAN(MMCOTPL0) -
      LIB('MIVAN.CPS.DBRMLIB')
  END
/*
//*
//********************************************************************
//* STEP030: PAYER OF LAST RESORT CALCULATION (42 CFR 433.139)
//********************************************************************
//STEP030  EXEC PGM=IKJEFT01,
//             COND=(8,LT,STEP020)
//STEPLIB  DD  DSN=MIVAN.CPS.LOADLIB,DISP=SHR
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MMCOLRP0) PLAN(MMCOLRP0) -
      LIB('MIVAN.CPS.DBRMLIB')
  END
/*
//*
//********************************************************************
//* STEP040: ENCOUNTER BUILD - WRITE TO STAGING ESDS
//********************************************************************
//STEP040  EXEC PGM=IKJEFT01,
//             COND=(8,LT,STEP030)
//STEPLIB  DD  DSN=MIVAN.CPS.LOADLIB,DISP=SHR
//MMCOENCR DD  DSN=MIVAN.MC.ENCOUNTER.STAGE,
//             DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(10,5)),
//             DCB=(RECFM=FB,LRECL=256,BLKSIZE=0)
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MMCOENC0) PLAN(MMCOENC0) -
      LIB('MIVAN.CPS.DBRMLIB')
  END
/*
//*
//********************************************************************
//* STEP050: STATE MMIS SUBMISSION
//********************************************************************
//STEP050  EXEC PGM=IKJEFT01,
//             COND=(8,LT,STEP040)
//STEPLIB  DD  DSN=MIVAN.CPS.LOADLIB,DISP=SHR
//MMCOENCR DD  DSN=MIVAN.MC.ENCOUNTER.STAGE,DISP=SHR
//MMCOSTOUT DD DSN=MIVAN.MC.STATE.OUTPUT.D&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             SPACE=(CYL,(20,10)),
//             DCB=(RECFM=FB,LRECL=512,BLKSIZE=0)
//MMCOSRPT DD  SYSOUT=*
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(DB2P)
  RUN PROGRAM(MMCOSSUB0) PLAN(MMCOSSUB0) -
      LIB('MIVAN.CPS.DBRMLIB')
  END
/*
//
