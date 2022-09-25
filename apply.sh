!/bin/bash

#Envs
. $HOME/ilegra/standby/$1/$1_std.env

function ADD_NEW()
{

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao ADD_NEW - Inicio "; fi

  DAT=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
  select name from v\$datafile WHERE file# = $DFN;
  exit;
EOF
)

  if [ "$ASMTOFS" = "Y" ];then
    DATASM=$(echo $DAT | rev | cut -f1 -d"/" | rev)
    sqlplus -s "/ as sysdba" <<EOF
    set lines 100 pages 0 trims on trim on feedback off show off verify off head off
    ALTER DATABASE CREATE DATAFILE $VER as '$STBY_DATAFILE/$DATASM';
EOF
LOG
  else
    sqlplus -s "/ as sysdba" <<EOF
    set lines 100 pages 0 trims on trim on feedback off show off verify off head off
    ALTER DATABASE create datafile $VER as new;
EOF

    LOG
  fi
}

function DELETE_ARCHIVES()
{
   if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao DELETE_ARCHIVES - Inicio"; fi

STBY_ARCH=$(echo $STBY_ARCH | tr -d ' ')
STBY_SEQ1=$(echo $STBY_SEQ1 | tr -d ' ')
PROD_SEQ1=$(echo $PROD_SEQ1 | tr -d ' ')
STBY_SEQ2=$(echo $STBY_SEQ2 | tr -d ' ')
PROD_SEQ2=$(echo $PROD_SEQ2 | tr -d ' ')

RM=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF trims ON
SELECT 'rm -f $STBY_ARCH/'|| REPLACE(NAME, regexp_substr(NAME, '.*/')) file_name FROM v\$archived_log WHERE dest_id = 2 AND thread# = 1
AND sequence# < '$STBY_SEQ1'-10 and name IS NOT NULL
UNION ALL
SELECT 'rm -f $STBY_ARCH/'|| REPLACE(NAME, regexp_substr(NAME, '.*/')) file_name FROM v\$archived_log WHERE dest_id = 2 AND thread# = 2
AND sequence# < '$STBY_SEQ2'-10 and name IS NOT NULL;
exit;
EOF
)

echo $RM >> $LOGFILE_APPLY

$RM

sed 's/^/rm -f /' $SCRIPT_HOME/archivestoget1.log > $SCRIPT_HOME/rmarchivestoget1.sh
chmod +x $SCRIPT_HOME/rmarchivestoget1.sh
scp -p $SCRIPT_HOME/rmarchivestoget1.sh $PROD_IP1:/tmp
ssh $PROD_IP1 /tmp/rmarchivestoget1.sh
ssh $PROD_IP1 rm -f /tmp/rmarchivestoget1.sh

sed 's/^/rm -f /' $SCRIPT_HOME/archivestoget2.log > $SCRIPT_HOME/rmarchivestoget2.sh
chmod +x $SCRIPT_HOME/rmarchivestoget2.sh
scp -p $SCRIPT_HOME/rmarchivestoget2.sh $PROD_IP2:/tmp
ssh $PROD_IP2 /tmp/rmarchivestoget2.sh
ssh $PROD_IP2 rm -f /tmp/rmarchivestoget2.sh

echo "0" > $SCRIPT_HOME/running.log
exit 0
}

function CHECK_01110()    ----   trabalhando aqui
{

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao CHECK_01110 - Inicio - "; fi

  VER=$(cat $LOGFILE_APPLY | grep ORA-01110 | head -n 1 | awk {'print $5'})
  DFN=$(cat $LOGFILE_APPLY | grep ORA-01110 | head -n 1 | awk '{print $4}' | cut -f1 -d':')

  if [ "$DFN" != ""  ]; then
    if [ "$DFN" = "1" ]; then
      echo "Two Process running together" >> $LOGFILE_APPLY
       echo "0" > $SCRIPT_HOME/running.log
      exit
    fi
    ADD_NEW
  else
    echo  "NENHUM NOVO DATAFILE PARA SER ADICIONADO" >>  $LOGFILE_APPLY
    DELETE_ARCHIVES
  fi
}

function APPLY()
{

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao APPLY - Inicio -"; fi

  # Testando se o Ambiente esta em Cluster ou não
  if [ "$CLUSTER" == "Y" ]
  then

    # faz a União dos arquivos gerando em sequencia para executar o rsync
    paste -d '\n' $SCRIPT_HOME/archivestoget1.log $SCRIPT_HOME/archivestoget2.log  > $SCRIPT_HOME/archives_files.log
    
    # Remove linha em branco no final do arquivo $SCRIPT_HOME/archives_files.log
    sed -i '/^$/d' $SCRIPT_HOME/archives_files.log

    while read line; do
      if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Buscando arquivo $line -"; fi
      rsync -avc $PROD_IP1:$line $STBY_ARCH >> $LOGFILE_APPLY
      rsync -avc $PROD_IP2:$line $STBY_ARCH >> $LOGFILE_APPLY
    done < $SCRIPT_HOME/archives_files.log

  else

    $SCRIPT_HOME/archivestoget1.log > $SCRIPT_HOME/archives_files.log

    # Remove linha em branco no final do arquivo $SCRIPT_HOME/archives_files.log
    sed -i '/^$/d' $SCRIPT_HOME/archives_files.log

    while read line; do
      if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Buscando arquivo $line -"; fi
      rsync -avc $PROD_IP1:$line $STBY_ARCH >> $LOGFILE_APPLY
    done < $SCRIPT_HOME/archives_files.log

  fi


  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Entrando no teste de recover - Inicio -"; fi

  until cat ${STD_HOME}/running_recover.log 2>/dev/null | grep -w '0' > /dev/null
  do      
          echo "Aguardando Processo recovery adicionado por conta do link concluir."
          cat ${STD_HOME}/running_recover.log
          sleep 10
  done

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Saindo no teste de recover - Inicio -"; fi


  echo "$(date) - INFO: Recover In Progress - Inicio -" >> $LOGFILE_APPLY
  sqlplus -s "/as sysdba" <<EOF >> $LOGFILE_APPLY
  set pagesize 0 feedback on verify off heading off echo off
  set lines 200 pages 2000
  set autorecovery on
  recover automatic database using backup controlfile;
  set feedback off
  exit;
EOF

  echo "$(date) - INFO: Recover In Progress - Fim -" >> $LOGFILE_APPLY

  CHECK_01110
}

function GETFILES()
{

# Testando se o Ambiente esta em Cluster ou não
if [ "$CLUSTER" == "Y" ]
then

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao GETFILES - Inicio - "; fi

  PROD_ARCH1=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF trims ON
  spool $SCRIPT_HOME/archivestoget1.log;
  select name from v\$archived_log where dest_id = 2 and THREAD# = 1 and SEQUENCE# between $STBY_SEQ1 and $PROD_SEQ1;
  spool off;
  EXIT;
EOF
)


  if [ $DEBUG -gt 0 ]; then cat $SCRIPT_HOME/archivestoget1.log >> $LOGFILE_APPLY; fi

  PROD_ARCH2=$(sqlplus -s $PROD_CRED@$PROD_IP2/$PROD_SN/$PROD_SID2 <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF trims ON
  spool $SCRIPT_HOME/archivestoget2.log;
  select name from v\$archived_log where dest_id = 2 and THREAD# = 2 and SEQUENCE# between $STBY_SEQ2 and $PROD_SEQ2;
  spool off;
  EXIT;
EOF
)

    # Remove linha em branco no final do arquivo $SCRIPT_HOME/archivestoget1.log
    sed -i '/^$/d' $SCRIPT_HOME/archivestoget1.log

    # Remove linha em branco no final do arquivo $SCRIPT_HOME/archivestoget2.log
    sed -i '/^$/d' $SCRIPT_HOME/archivestoget2.log

    echo $PROD_ARCH1 >> $LOGFILE_APPLY
    echo $PROD_ARCH2 >> $LOGFILE_APPLY

else

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao GETFILES - Inicio - "; fi

  PROD_ARCH1=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF trims ON
  spool $SCRIPT_HOME/archivestoget1.log;
  select name from v\$archived_log where dest_id = 2 and THREAD# = 1 and SEQUENCE# between $STBY_SEQ1 and $PROD_SEQ1;
  spool off;
  EXIT;
EOF
)

    # Remove linha em branco no final do arquivo $SCRIPT_HOME/archivestoget1.log
    sed -i '/^$/d' $SCRIPT_HOME/archivestoget1.log

    echo $PROD_ARCH1 >> $LOGFILE_APPLY

fi

}

function LOG()
{
  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao LOG - Inicio -"; fi

  find $LOG_DIR_APPLY          -name '*.log' -ctime +{$LOG_RETENTION} -exec rm -f {} \;
  find $LOG_DIR_APPLY_RECOVERY -name '*.log' -ctime +{$LOG_RETENTION} -exec rm -f {} \;
  
  find /u01/app/oracle/fra/orcl/archives -name '*.dbf' -mmin +1440 -exec rm -f {} \;

  LOGFILE_APPLY=$LOG_DIR_APPLY/apply_$ORACLE_SID_`date +%Y%m%d_%H%M%S`.log

  LOGFILE_RECOVERY=$LOG_DIR_APPLY_RECOVERY/recovery_$ORACLE_SID_`date +%Y%m%d_%H%M%S`.log

	if [ $DEBUG -gt 0 ]
	then echo "$(date) - INFO: Funcao Lista arquives nos ambientes de prod - Inicio -"

		ssh $PROD_IP1 'ls -l ${PROD_ARCH}'
		ssh $PROD_IP2 'ls -l ${PROD_ARCH}'

	fi

  GETFILES
  APPLY
}

function RUNNING()
{

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao RUNNING - Inicio -"; fi

  RUN=$(cat $SCRIPT_HOME/running.log)
  if [ "$RUN" -eq "1" ]
    then
      if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Script ainda rodando. Saindo... - "; fi
      exit 0
    else
      if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Adicionando 1 ao arquivo running... - "; fi
      echo "1" > $SCRIPT_HOME/running.log
      LOG
  fi
}

function LOCK()
{

# Testando se o Ambiente esta em Cluster ou não
if [ "$CLUSTER" == "Y" ]
then
  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao LOCK - Inicio -"; fi

  PROD_SEQ1=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
  SELECT max(sequence#) FROM v\$log_history where thread# = 1;
  EXIT;
EOF
)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: PROD_SEQ1=$PROD_SEQ1 -"; fi

  PROD_SEQ2=$(sqlplus -s $PROD_CRED@$PROD_IP2/$PROD_SN/$PROD_SID2 <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
  SELECT max(sequence#) FROM v\$log_history where thread# = 2;
  EXIT;
EOF
)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: PROD_SEQ2=$PROD_SEQ2 -"; fi

  STBY_SEQ1=$(sqlplus -s "/ as sysdba" <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
  SELECT max(sequence#) FROM v\$log_history where thread# = 1;
  EXIT;
EOF
)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: STBY_SEQ1=$STBY_SEQ1 -"; fi

  STBY_SEQ2=$(sqlplus -s "/ as sysdba" <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
  SELECT max(sequence#) FROM v\$log_history where thread# = 2;
  EXIT;
EOF
)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: STBY_SEQ2=$STBY_SEQ2 -"; fi

  DIFF_SEQ1=$(expr $PROD_SEQ1 - $STBY_SEQ1)
  DIFF_SEQ2=$(expr $PROD_SEQ2 - $STBY_SEQ2)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: DIFF_SEQ1=$DIFF_SEQ1  DIFF_SEQ2=$DIFF_SEQ2 -"; fi


  if [ "$DIFF_SEQ1" -ge "$MAX_DIFF"  ] || [ "$DIFF_SEQ2" -ge "$MAX_DIFF"  ] ;
    then
      if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Diferenca maior que MAX_DIFF $MAX_DIFF - Saindo... -"; fi
      exit 0
  fi

else

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Funcao LOCK - Inicio -"; fi

  PROD_SEQ1=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
  SELECT max(sequence#) FROM v\$log_history where thread# = 1;
  EXIT;
EOF
)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: PROD_SEQ1=$PROD_SEQ1"; fi

  STBY_SEQ1=$(sqlplus -s "/ as sysdba" <<EOF
  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
  SELECT max(sequence#) FROM v\$log_history where thread# = 1;
  EXIT;
EOF
)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: STBY_SEQ1=$STBY_SEQ1 -"; fi

  DIFF_SEQ1=$(expr $PROD_SEQ1 - $STBY_SEQ1)

  if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: DIFF_SEQ1=$DIFF_SEQ1"; fi


  if [ "$DIFF_SEQ1" -ge "$MAX_DIFF"  ] ;
  then
      if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: Diferenca maior que MAX_DIFF $MAX_DIFF - Saindo..."; fi
      exit 0
  fi

fi	

}

LOCK
RUNNING
