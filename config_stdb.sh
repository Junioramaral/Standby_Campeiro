#!/bin/bash

echo -e "\nConfigurar dados do standby\n"

read -p 'ORACLE_SID - Oracle Sid do Standby : ' oraclesid
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

read -p 'STBY_ARCH - Caminho absoluto dos archives do standby : ' stby_arch
read -p 'PWD - Password do System : ' ppwd
read -p 'PROD_SN - Service Name da Produção : ' prodsn

read -p 'CLUSTER - Ambiente de Produção está em Cluster (Y/N)? ' cluster
case ${cluster} in
    y|Y )
		echo -e "Configure Cluster Instance\n"
		read -p '	PROD_IP1  - IP do No 1  - Produção : ' PROD_IP1
		read -p '	PROD_IP2  - IP do No 2  - Produção : ' PROD_IP2
		read -p '	PROD_SID1 - SID do No 1 - Produção : ' PROD_SID1
		read -p '	PROD_SID2 - SID do No 2 - Produção : ' PROD_SID2
    ;;
    [Nn]* )
		echo -e "Configure Single Instance\n"
		read -p '	PROD_IP1  - IP do No 1  - Produção : ' PROD_IP1
		read -p '	PROD_SID1 - SID do No 1 - Produção : ' PROD_SID1
    ;;
esac



##################################
# Criação dos diretórios de logs #
##################################

mkdir -p /home/oracle/ilegra/${oraclesid}/logs
mkdir -p /home/oracle/ilegra/${oraclesid}/logs_recovery

########################################################################
# Geração do arquivo de configuração baseado nas perguntas respondidas #
########################################################################

echo "# DEBUG - Habilita debug no log do apply" >> ${oraclesid}_std.env
echo "DEBUG=1" >> ${oraclesid}_std.env

echo -e "\n# CLUSTER - Informa se o Standby será configurado para Cluster ou Single" >> ${oraclesid}_std.env
echo "CLUSTER=${cluster^^}" >> ${oraclesid}_std.env

echo -e "\n# ORACLE_SID - SID da Instancia do Stanby" >> ${oraclesid}_std.env
echo "ORACLE_SID=${oraclesid}" >> ${oraclesid}_std.env

echo -e "\n# STD_HOME - Diretório onde ficam todos os arquivos do standby" >> ${oraclesid}_std.env
echo "STD_HOME=/home/oracle/ilegra/${oraclesid}" >> ${oraclesid}_std.env

echo -e "\n# LOG_DIR_APPLY - Diretório dos logs do apply" >> ${oraclesid}_std.env
echo "LOG_DIR_APPLY=/home/oracle/ilegra/${oraclesid}/logs" >> ${oraclesid}_std.env

echo -e "\n# LOG_DIR_APPLY_RECOVERY - Diretório dos logs do apply" >> ${oraclesid}_std.env
echo "LOG_DIR_APPLY_RECOVERY=/home/oracle/ilegra/${oraclesid}/logs_recovery" >> ${oraclesid}_std.env

echo -e "\n# MAX_DIFF - Diferença maxima aceita entre produção e standby" >> ${oraclesid}_std.env
echo "MAX_DIFF=500" >> ${oraclesid}_std.env

echo -e "\n# ASMTOFS - Flag para conversão de ASM para Filesystem, preencher com Y caso tenha que converter de ASM para FileSystem" >> ${oraclesid}_std.env
echo "ASMTOFS=$ASMTOFS" >> ${oraclesid}_std.env

echo -e "\n# STBY_ARCH - Caminho absoluto dos archives do standby" >> ${oraclesid}_std.env
echo "STBY_ARCH=$stby_arch" >> ${oraclesid}_std.env

if [[ -v stbydatafile ]];
then
	echo -e "\n# STBY_DATAFILE - Caminho absoluto dos datafiles do standby" >> ${oraclesid}_std.env
    echo "STBY_DATAFILE=$stbydatafile"  >> ${oraclesid}_std.env
fi

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



