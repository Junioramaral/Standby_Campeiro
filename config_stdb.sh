#!/bin/bash

. $HOME/ilegra/variable_conf.env

function HEADLINE(){
	clear
	echo -e "\n\n"
	echo "		----------------------------------------------------------------"
	echo "		-- Configurar dados do standby - $(date) --"
	echo "		----------------------------------------------------------------"
	echo -e "\n"
}

function END()
{

HEADLINE

	echo -e "\n\n 		O Cadastro e configurações aplicado com sucesso"
	echo -e "\n 		Remover o diretório de configuração atual que foi usado somente para a configuração"
	echo -e "\n\n  			Executar:  rm -rf ${PWD}"
	echo -e "\n\n\n"

	cd ${DIRAPPLY}

}

#########################################################
# Informações a serem adicionados na crontab do Standby #
#########################################################
function CRONTAB()
{

HEADLINE

	echo "		Adicionar o codigo abaixo na crontab do user oracle"
	echo "		Depois de Configurado e testado descomentar as linhas dos scripts"
	echo -e "\n\n\n"

	echo "##################################"
	echo "# Scripts do Apply standby       #"
	echo "##################################"
	echo "# Standby ${oraclesid}"
	echo "#*/5 * * * * /home/oracle/ilegra/standby/${oraclesid}/apply.sh ${oraclesid}"
	echo "#"
	echo "# Confere a diferenca de archives entre prod e standby"
	echo "#*/2 * * * * /home/oracle/ilegra/standby/${oraclesid}/diff.sh ${oraclesid}"

	echo -e "\n\n"

	read -p 'As Informações Foram adicionadas corretamente na crontab (y/n) ? ' asnyn
	case ${asnyn} in
	    [Yy]* )
	        END
	    ;;
	    [Nn]* )
	        CRONTAB
	    ;;
	esac

}

############################################################
# Informações a serem Verificado e adicionados em produção #
############################################################
function ADD_INFOS()
{

HEADLINE

	LOG_MODE=$(sqlplus -s $PROD_CRED@$PROD_IP1/$PROD_SN/$PROD_SID1 <<EOF
	  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	  col force_logging FOR a13
	  SELECT force_logging FROM   v\$database;
	  EXIT;
EOF
)

	LOCATION_ARCH=$(sqlplus -s / as sysdba <<EOF
	  SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF echo OFF
	  select substr(value,10,20) from v\$parameter where name = 'log_archive_dest_1';
	  EXIT;
EOF
)

	if [ "$LOG_MODE" == "YES" ]
	then
		if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: FORCE LOGGING MODE=$LOG_MODE"; fi
		
		echo -e "\nALTER SYSTEM SET log_archive_dest_1='LOCATION=${LOCATION_ARCH}' SCOPE=both;"
		echo "ALTER SYSTEM SET log_archive_dest_2='LOCATION=${PROD_ARCH} OPTIONAL' scope=bboth;"

	else
		if [ $DEBUG -gt 0 ]; then echo "$(date) - INFO: FORCE LOGGING MODE=$LOG_MODE"; fi

		echo -e "\nALTER DATABASE FORCE LOGGING;"	
		echo -e "\nALTER SYSTEM SET log_archive_dest_1='LOCATION=${LOCATION_ARCH}' SCOPE=both;"
		echo "ALTER SYSTEM SET log_archive_dest_2='LOCATION=${PROD_ARCH} OPTIONAL' scope=bboth;"

	fi

	echo -e "\n\n\n"

	read -p 'As Informações Foram adicionadas corretas (y/n) ? ' asnyn
	case ${asnyn} in
	    [Yy]* )
	        CRONTAB
	    ;;
	    [Nn]* )
	        ADD_INFOS
	    ;;
	esac

}

#####################################################
# Criação dos diretórios de logs se ele não existir #
#####################################################
function CRIA_DIR()
{

	DIRAPPLY="/home/oracle/ilegra/standby/${oraclesid}"
	DIRLOGSAPPLY="${DIRAPPLY}/logs"
	DIRLOGSDIFF="${DIRAPPLY}/logs_diff"
	DIRLOGSRECOVER="${DIRAPPLY}/logs_recovery"
	
	[ ! -d "$DIRLOGS" ] && mkdir -p "$DIRLOGSAPPLY"
	[ ! -d "$DIRLOGS" ] && mkdir -p "$DIRLOGSDIFF"
	[ ! -d "$DIRLOGS" ] && mkdir -p "$DIRLOGSRECOVER"

	cp ./*  $DIRAPPLY

ADD_INFOS

}

########################################################################
# Geração do arquivo de configuração baseado nas perguntas respondidas #
########################################################################
function GERAR_ENV()
{

	echo "## Oracle Settings ##"  >> ${oraclesid}_std.env
	echo -e "\n" >> ${oraclesid}_std.env
	echo ". /home/oracle/${oraclesid}_std.env"  >> ${oraclesid}_std.env
	
	echo -e "\n\n\n" >> ${oraclesid}_std.env
	
	echo "## Standby Parameters ##"  >> ${oraclesid}_std.env
	echo -e "\n" >> ${oraclesid}_std.env
	
	echo "# DEBUG - Habilita debug no log do apply" >> ${oraclesid}_std.env
	echo "DEBUG=1" >> ${oraclesid}_std.env
	
	echo -e "\n# CLUSTER - Informa se o Standby será configurado para Cluster ou Single" >> ${oraclesid}_std.env
	echo "CLUSTER=${cluster^^}" >> ${oraclesid}_std.env
	
	echo -e "\n# ORACLE_SID - SID da Instancia do Stanby" >> ${oraclesid}_std.env
	echo "ORACLE_SID=${oraclesid}" >> ${oraclesid}_std.env
	
	echo -e "\n# STD_HOME - Diretório onde ficam todos os arquivos do standby" >> ${oraclesid}_std.env
	echo "STD_HOME=/home/oracle/ilegra/standby/${oraclesid}" >> ${oraclesid}_std.env
	
	echo -e "\n# LOG_DIR_APPLY - Diretório dos logs do apply" >> ${oraclesid}_std.env
	echo "LOG_DIR_APPLY=/home/oracle/ilegra/standby/${oraclesid}/logs" >> ${oraclesid}_std.env
	
	echo -e "\n# LOG_DIR_APPLY_RECOVERY - Diretório dos logs do apply" >> ${oraclesid}_std.env
	echo "LOG_DIR_APPLY_RECOVERY=/home/oracle/ilegra/standby${oraclesid}/logs_recovery" >> ${oraclesid}_std.env
	
	echo -e "\n# MAX_DIFF - Diferença maxima aceita entre produção e standby" >> ${oraclesid}_std.env
	echo "MAX_DIFF=500" >> ${oraclesid}_std.env
	
	echo -e "\n# ASMTOFS - Flag para conversão de ASM para Filesystem, preencher com Y caso tenha que converter de ASM para FileSystem" >> ${oraclesid}_std.env
	echo "ASMTOFS=$ASMTOFS" >> ${oraclesid}_std.env
	
	echo -e "\n# STBY_ARCH - Caminho absoluto dos archives do standby" >> ${oraclesid}_std.env
	echo "STBY_ARCH=$stby_arch" >> ${oraclesid}_std.env
	
	echo -e "\n# LOG_RETENTION - Numero em dias para retenção dos logs" >> ${oraclesid}_std.env
	echo "STBY_ARCH=$logretenntion" >> ${oraclesid}_std.env
	
	if [[ -v stbydatafile ]];
	then
		echo -e "\n# STBY_DATAFILE - Caminho absoluto dos datafiles do standby" >> ${oraclesid}_std.env
	    echo "STBY_DATAFILE=$stbydatafile"  >> ${oraclesid}_std.env
	fi
	
	echo -e "\n\n\n" >> ${oraclesid}_std.env
	
	echo "## Production Parameters ##"  >> ${oraclesid}_std.env
	echo -e "\n" >> ${oraclesid}_std.env
	
	
	echo -e "\n# PROD_CRED - Senha de system da producão" >> ${oraclesid}_std.env
	echo "PWD=system/$ppwd" >> ${oraclesid}_std.env
	
	echo -e "\n# PROD_SN - Service Name da Produção" >> ${oraclesid}_std.env
	echo "PROD_SN=$prodsn" >> ${oraclesid}_std.env
	
	echo -e "\n# PROD_IP[1,2] e PROD_SID[1,2] - IP(s) e SID(s) do Servidor de Produção" >> ${oraclesid}_std.env
	for var in PROD_IP1 PROD_IP2 PROD_SID1 PROD_SID2
	do
	  declare -p $var > /dev/null 2>&1 \
	  && printf '%s=%s\n' "$var" "${!var}" >> ${oraclesid}_std.env
	done

CRIA_DIR

}

########################################################################
# Geração do arquivo de configuração baseado nas perguntas respondidas #
########################################################################
function VERIFY_INFOS()
{

HEADLINE

	echo "## Oracle Settings ##"
	echo -e "\n"
	echo ". /home/oracle/${oraclesid}_std.env"
	
	echo -e "\n"
	
	echo "## Standby Parameters ##"
	echo "##"
	
	echo "# DEBUG - Habilita debug no log do apply"
	echo "DEBUG=1"
	
	echo -e "\n# CLUSTER - Informa se o Standby será configurado para Cluster ou Single"
	echo "CLUSTER=${cluster^^}"
	
	echo -e "\n# ORACLE_SID - SID da Instancia do Stanby"
	echo "ORACLE_SID=${oraclesid}"
	
	echo -e "\n# STD_HOME - Diretório onde ficam todos os arquivos do standby"
	echo "STD_HOME=/home/oracle/ilegra/standby/${oraclesid}"
	
	echo -e "\n# LOG_DIR_APPLY - Diretório dos logs do apply"
	echo "LOG_DIR_APPLY=/home/oracle/ilegra/standby/${oraclesid}/logs"
	
	echo -e "\n# LOG_DIR_APPLY_RECOVERY - Diretório dos logs do apply"
	echo "LOG_DIR_APPLY_RECOVERY=/home/oracle/ilegra/standby${oraclesid}/logs_recovery"
	
	echo -e "\n# MAX_DIFF - Diferença maxima aceita entre produção e standby"
	echo "MAX_DIFF=500"
	
	echo -e "\n# ASMTOFS - Flag para conversão de ASM para Filesystem, preencher com Y caso tenha que converter de ASM para FileSystem"
	echo "ASMTOFS=$ASMTOFS"
	
	echo -e "\n# STBY_ARCH - Caminho absoluto dos archives do standby"
	echo "STBY_ARCH=$stby_arch"
	
	echo -e "\n# LOG_RETENTION - Numero em dias para retenção dos logs"
	echo "STBY_ARCH=$logretenntion"
	
	if [[ -v stbydatafile ]];
	then
		echo -e "\n# STBY_DATAFILE - Caminho absoluto dos datafiles do standby"
	    echo "STBY_DATAFILE=$stbydatafile"
	fi
	
	echo -e "\n"
	
	echo "## Production Parameters ##"
	echo "##"
	
	
	echo -e "\n# PROD_CRED - Senha de system da producão"
	echo "PWD=system/$ppwd"
	
	echo -e "\n# PROD_SN - Service Name da Produção"
	echo "PROD_SN=$prodsn"
	
	echo -e "\n# PROD_IP[1,2] e PROD_SID[1,2] - IP(s) e SID(s) do Servidor de Produção"
	for var in PROD_IP1 PROD_IP2 PROD_SID1 PROD_SID2
	do
	  declare -p $var > /dev/null 2>&1 \
	  && printf '%s=%s\n' "$var" "${!var}"
	done

	echo -e "\n"

	read -p 'As Informações Estão corretas (y/n) ? ' asnyn
	case ${asnyn} in
	    [Yy]* )
	        GERAR_ENV
	    ;;
	    [Nn]* )
	        CADASTRO
	    ;;
	esac

}

##############################################
# Cadastro das informações para gerar o .ENV #
##############################################
function CADASTRO()
{

HEADLINE

# Standby
echo -e "\n# Standby\n"
read -p 'ORACLE_SID - Oracle Sid do Standby : ' oraclesid
read -p 'STBY_ARCH - Caminho absoluto dos archives do Standby : ' stby_arch

read -p 'ASMTOFS - Irá converter ASM to FS (y/n) ? ' asmtofs
case ${asmtofs} in
    [Yy]* )
        ASMTOFS=Y
        read -p '	STBY_DATAFILE - Caminho Absoluto dos datafiles : ' stbydatafile
    ;;
    [Nn]* )
        ASMTOFS=N
    ;;
esac

# Produção
echo -e "\n\n# Produção\n"
read -p 'PWD - Password do System : ' ppwd
read -p 'PROD_SN - Service Name da Produção : ' prodsn
read -p 'PROD_ARCH - Caminho absoluto dos archives em Produção : ' prod_arch
read -p 'CLUSTER - Ambiente de Produção está em Cluster (Y/N)? ' cluster
case ${cluster} in
    y|Y )
		echo -e "\n"
		echo -e "Configure Cluster Instance\n"
		read -p '	PROD_IP1  - IP do No 1  - Produção : ' PROD_IP1
		read -p '	PROD_IP2  - IP do No 2  - Produção : ' PROD_IP2
		read -p '	PROD_SID1 - SID do No 1 - Produção : ' PROD_SID1
		read -p '	PROD_SID2 - SID do No 2 - Produção : ' PROD_SID2
    ;;
    [Nn]* )
		echo -e "\n"
		echo -e "Configure Single Instance\n"
		read -p '	PROD_IP1  - IP  do No 1 - Produção : ' PROD_IP1
		read -p '	PROD_SID1 - SID do No 1 - Produção : ' PROD_SID1
    ;;
esac

echo -e "\n"
read -p 'LOG_RETENTION - Numero em dias para retenção dos logs "Enter to Default [30] : ' logretenntion
logretenntion=${logretenntion:-30}

VERIFY_INFOS

}

# Begin
CADASTRO

