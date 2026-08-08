//MAENCJB0 JOB (MIVAN,MA,001),'MA-ENC-PROCESSING',
//             CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M
//*
//* MA ENCOUNTER DATA PROCESSING JOB STREAM
//* RUNS:    DAILY AFTER CMS ENROLLMENT FILE RECEIPT
//* CONTACT: MIVAN HEALTH PLAN - MA OPERATIONS
//*
//JOBLIB  DD  DSN=MIVAN.MA.LOADLIB,DISP=SHR
//*
//********************************************************************
//* STEP 1: SORT ENROLLMENT INPUT BY MBI
//********************************************************************
//SORT001 EXEC PGM=SORT
//SORTIN   DD  DSN=MIVAN.MA.ENROLL.DAILY,DISP=SHR
//SORTOUT  DD  DSN=&&ENRSORT,
//             UNIT=SYSDA,SPACE=(CYL,(50,10)),DISP=(,PASS),
//             DCB=(RECFM=FB,LRECL=150,BLKSIZE=0)
//SYSIN    DD  *
  SORT FIELDS=(1,11,CH,A)
  OUTREC FIELDS=(1,150)
/*
//SYSOUT   DD  SYSOUT=*
//*
//********************************************************************
//* STEP 2: ELIGIBILITY PRE-CHECK (DB2 TABLE VALIDATION)
//********************************************************************
//ELGPRE  EXEC PGM=IKJEFT01,DYNAMNBR=20
//STEPLIB  DD  DSN=MIVAN.MA.LOADLIB,DISP=SHR
//SYSTSPRT DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(MIVN)
  RUN PROGRAM(MAELGCK0) PLAN(MAELGPL0) -
      LIB('MIVAN.MA.LOADLIB')
/*
//SYSPRINT DD  SYSOUT=*
//*
//********************************************************************
//* STEP 3: MAIN ENCOUNTER DRIVER
//********************************************************************
//ENCDRV  EXEC PGM=MAENCDR0,COND=(4,LT)
//STEPLIB  DD  DSN=MIVAN.MA.LOADLIB,DISP=SHR
//MAENROLL DD  DSN=&&ENRSORT,DISP=(OLD,DELETE)
//MAENCSTG DD  DSN=MIVAN.MA.ENCOUNTER.STAGE.D&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(100,20)),
//             DCB=(RECFM=FB,LRECL=400,BLKSIZE=0)
//MAENCDRR DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//********************************************************************
//* STEP 4: EDPS SUBMISSION BATCH
//********************************************************************
//EDPSUB  EXEC PGM=MAEDPSUB0,COND=(4,LT)
//STEPLIB  DD  DSN=MIVAN.MA.LOADLIB,DISP=SHR
//         DD  DSN=MIVAN.MA.DBRMLIB,DISP=SHR
//SYSPRINT DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//********************************************************************
//* STEP 5: REPORTING
//********************************************************************
//REPORT  EXEC PGM=MAENCDRR,COND=(4,LT)
//STEPLIB  DD  DSN=MIVAN.MA.LOADLIB,DISP=SHR
//REPTIN   DD  DSN=MIVAN.MA.ENCOUNTER.STAGE.D&DATE,DISP=SHR
//REPTOUT  DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//
