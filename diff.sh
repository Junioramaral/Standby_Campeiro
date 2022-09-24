#!/bin/bash

. $HOME/ilegra/standby/$1/$1_std.env

# Testando se o Ambiente esta em Cluster ou não
if [ "$CLUSTER" == "Y" ]
then

	PROD_SEQ1=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
	SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	SELECT max(sequence#) FROM v\$log_history where thread# = 1;
	EXIT;
EOF
	)
	
	PROD_SEQ2=$(sqlplus -s $PROD_CRED@$PROD_IP2/$PROD_SN/$PROD_SID2 <<EOF
	SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	SELECT max(sequence#) FROM v\$log_history where thread# = 2;
	EXIT;
EOF
	)
	
	STBY_SEQ1=$(sqlplus -s "/ as sysdba" <<EOF
	SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	SELECT max(sequence#) FROM v\$log_history where thread# = 1;
	EXIT;
EOF
	)
	
	STBY_SEQ2=$(sqlplus -s "/ as sysdba" <<EOF
	SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	SELECT max(sequence#) FROM v\$log_history where thread# = 2;
	EXIT;
EOF
	)

	DIFF_SEQ1=$(expr $PROD_SEQ1 - $STBY_SEQ1)
	DIFF_SEQ2=$(expr $PROD_SEQ2 - $STBY_SEQ2)
	
	STBY_INST=$(ps -ef | grep pmon | grep $ORACLE_SID | awk {'print $8'})
	
	STBY_STATUS=$(sqlplus -s "/ as sysdba" <<EOF
	set head off
	set time off
	set timing off
	SELECT status from V\$INSTANCE;
	EXIT;
EOF
	)

else

	PROD_SEQ1=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
	SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	SELECT max(sequence#) FROM v\$log_history where thread# = 1;
	EXIT;
EOF
	)

	STBY_SEQ1=$(sqlplus -s "/ as sysdba" <<EOF
	SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	SELECT max(sequence#) FROM v\$log_history where thread# = 1;
	EXIT;
EOF
	)

	DIFF_SEQ1=$(expr $PROD_SEQ1 - $STBY_SEQ1)
	
	STBY_INST=$(ps -ef | grep pmon | grep $ORACLE_SID | awk {'print $8'})
	
	STBY_STATUS=$(sqlplus -s "/ as sysdba" <<EOF
	set head off
	set time off
	set timing off
	SELECT status from V\$INSTANCE;
	EXIT;
EOF
	)

fi

# Testando se o Ambiente esta em Cluster ou não
if [ "$CLUSTER" == "Y" ]
then
	if [ -z $DIFF_SEQ1 ] || [ -z $DIFF_SEQ2 ] ;then
	
	   echo "$(date) - INFO: Variavel nula" > $SCRIPT_HOME/error.log
	
	else
	
		if [ $STBY_INST != "ora_pmon_$ORACLE_SID" -o $STBY_STATUS != "MOUNTED" ];then
		        echo "99 | Standby" > $SCRIPT_HOME/diff.log
		else
		        echo "$DIFF_SEQ1 | Standby" >  $SCRIPT_HOME/diff.log
		        echo "$DIFF_SEQ2 | Standby" >> $SCRIPT_HOME/diff.log
		fi
	
	fi

else

	if [ -z $DIFF_SEQ1 ]
	then
	
	   echo "$(date) - INFO: Variavel nula" > $SCRIPT_HOME/error.log
	
	else
	
		if [ $STBY_INST != "ora_pmon_$ORACLE_SID" -o $STBY_STATUS != "MOUNTED" ]
		then
		        echo "99 | Standby" > $SCRIPT_HOME/diff.log
		else
		        echo "$DIFF_SEQ1 | Standby" >  $SCRIPT_HOME/diff.log
		fi
	
	fi

fi	


# Testando se o Ambiente esta em Cluster ou não
if [ "$CLUSTER" == "Y" ]
then

	echo "-----------------------------"
	echo "-- Analise das informações --"
	echo -e "-----------------------------\n"
	
	echo "Prod_SEQ1 : $PROD_SEQ1"
	echo "STBY_SEQ1 : $STBY_SEQ1"
	echo "Diference : $DIFF_SEQ1" 
	echo -e "\n"
	echo "Prod_SEQ2 : $PROD_SEQ2"
	echo "STBY_SEQ2 : $STBY_SEQ2"
	echo "Diference : $DIFF_SEQ2"

else

	echo "-----------------------------"
	echo "-- Analise das informações --"
	echo -e "-----------------------------\n"
	
	echo "Prod_SEQ1 : $PROD_SEQ1"
	echo "STBY_SEQ1 : $STBY_SEQ1"
	echo "Diference : $DIFF_SEQ1" 

fi
