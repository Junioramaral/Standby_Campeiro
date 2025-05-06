#!/bin/bash
 
# recover_arch_diff.sh - v1.1
# Script para copiar Archivelogs do Primary para Standby.
# O script considera todos os archives gerados após a última Sequence# catalogada para cada Thread# no Standby
 
. $HOME/ilegra/standby/$1/$1_std.env

 
###### Ajustar Valores de Acordo ao Ambiente ##############

# Credenciais e TNS Name:
export USUARIO="sys"
export SENHA="SenhaDoSYS"
export TNS_TARGET="ORCL_Primary"
export TNS_AUXILIARY="ORCL_Standby"
 
# Qtde. de Canais em paralelismo
export RMAN_CANAIS=4 
 
# Onde os archives devem ser gravados no destino
export DESTINO_ARCHIVES='+RECO'
 
##########################################################
 
# conf log
export ARQ_LOG=`pwd`/Archives_${ORACLE_SID}_`date '+%d%m%Y_%H%M%S'`.log
export NLS_DATE_FORMAT='DD/MM/YYYY HH24:MI:SS'
 
# se o formato do backup nao terminar com "/", entao considera o path ate a ultima "/" durante o catalog start with
CATALOG_PATH=${DESTINO_ARCHIVES}
FinalPath=$( echo "${CATALOG_PATH: -1}" )
if [ "$FinalPath" != "/" ] ; then
 CATALOG_PATH=$(echo "${CATALOG_PATH}" | sed 's/\(.*\)\/.*/\1/')
 CATALOG_PATH="${CATALOG_PATH}/"
fi
 
# funcao de catalogar archives na instancia auxiliar
CatalogaArchivesStandby()
{
rman target / <<EOF
 spool log to ${ARQ_LOG} append;
 catalog start with '${CATALOG_PATH}' noprompt;
EOF
}
 
echo "$(date) - INFO: Catalogando archives existentes" >> $ARQ_LOG
CatalogaArchivesStandby
 
# criando a consulta SQL que gera o script RMAN dinamicamente
echo "$(date) - INFO: Gerando consulta SQL" >> $ARQ_LOG
echo "
set trims on
set feedback off
set heading off
SET LINES 400
COL COMANDO FORMAT A200
 
spool last_sequence.cmd
 
SELECT 'run {' AS COMANDO FROM DUAL;
 
SELECT 'allocate channel ch' || lpad(Level,2,'0') || ' type disk;' AS rman_channel 
FROM Dual
CONNECT BY Level <= ${RMAN_CANAIS};
 
SELECT 'backup as copy reuse archivelog from logseq='|| MAX(SEQUENCE#) ||' thread='|| THREAD# ||' auxiliary format ''${DESTINO_ARCHIVES}'';' AS COMANDO
FROM V\$ARCHIVED_LOG
GROUP BY THREAD#;
 
SELECT '}' AS COMANDO FROM DUAL;
spool off
" > get_last_sequence.sql
 
# executa a query na instancia auxiliar pra gerar o script RMAN
echo "$(date) - INFO: Gerando script RMAN" >> $ARQ_LOG
sqlplus / as sysdba <<EOF
@get_last_sequence.sql
quit
EOF
 
# executa o script RMAN de backup as copy dos Archivelogs conectado no target e auxiliary
echo "$(date) - INFO: Iniciando copia de archives" >> $ARQ_LOG
rman <<EOF
spool log to ${ARQ_LOG} append;
connect target ${USUARIO}/${SENHA}@${TNS_TARGET}
connect auxiliary ${USUARIO}/${SENHA}@${TNS_AUXILIARY}
@last_sequence.cmd
spool log off;
EOF
 
# remove os scripts temporarios
rm -f get_last_sequence.sql
rm -f last_sequence.cmd
 
# cataloga os novos archives no controlfile do standby
echo "$(date) - INFO: Catalogando os archives copiados." >> $ARQ_LOG
CatalogaArchivesStandby
 
echo "$(date) - INFO: Cópia de archives finalizada." >> $ARQ_LOG




rsync -avc 192.168.15.101:$line /u01/archives



2131311022