# Standby_Campeiro
Projeto Standby Campeiro para Oracle by ilegra




-----  Step de Criação ------

- Arquivo de configuração

1) Instance_name
2) Cluster ( S/N )

Single

    - DEBUG - Habilita debug no log do apply
    - SCRIPT_HOME - Diretorio onde ficam todos os arquivos do standby
    - SCRIPT_LOGS - Diretorio dos logs do apply
    - MAX_DIFF - Diferenca maxima aceita entre producao e standby
    - ASMTOFS - Flag para conversao de ASM para Filesystem
    - STBY_ARCH - Caminho absoluto dos archives do standby
    - STBY_DATAFILE - Caminho absoluto dos datafiles do standby
    - PROD_CRED - usuario e senha de system da producao
    - PROD_SN - Service Name da Producao
    - PROD_IP1 - IP do No 1 - Producao
    - PROD_SID1 - SID do No 1 - Producao    

Cluster

    - DEBUG - Habilita debug no log do apply
    - SCRIPT_HOME - Diretorio onde ficam todos os arquivos do standby
    - SCRIPT_LOGS - Diretorio dos logs do apply
    - MAX_DIFF - Diferenca maxima aceita entre producao e standby
    - ASMTOFS - Flag para conversao de ASM para Filesystem
    - STBY_ARCH - Caminho absoluto dos archives do standby
    - STBY_DATAFILE - Caminho absoluto dos datafiles do standby
    - PROD_CRED - usuario e senha de system da producao
    - PROD_SN - Service Name da Producao
    - PROD_IP1 - IP do No 1 - Producao
    - PROD_IP2 - IP do No 2 - Producao
    - PROD_SID1 - SID do No 1 - Producao 
    - PROD_SID2 - SID do No 2 - Producao     





----- Akterações e melhorias -------

1) Ajustado para verificar se é Cluster ou não para usar o mesmo apply.sh

2) Ajustes para a remoção dos archives que somente foram aplicados.

SELECT 'rm -f /u01/archives/' || REPLACE(NAME, regexp_substr(NAME, '.*/')) from v$archived_log WHERE dest_id = 1 AND thread# = 1
and sequence# between 143 and 146;

3) Melhoria na leitura do archives a serem aplicados com ajuste na query para pegar o Incarnation atual

SELECT max(sequence#) FROM v\$log_history WHERE (RESETLOGS_CHANGE#) in (select max(RESETLOGS_CHANGE#) from v\$log_history) and thread# = 1;



STBY_ARCH=/u01/archives


RM=$(sqlplus -s "/ as sysdba" <<EOF
SET show OFF pagesize 0 feedback OFF termout ON TIME OFF timing OFF verify OFF trims ON
SELECT 'rm -f $STBY_ARCH/'|| REPLACE(NAME, regexp_substr(NAME, '.*/')) file_name FROM v\$archived_log WHERE dest_id = 1 AND thread# = 1
AND sequence# between $STBY_SEQ1 and $PROD_SEQ1
UNION ALL
SELECT 'rm -f $STBY_ARCH/'|| REPLACE(NAME, regexp_substr(NAME, '.*/')) file_name FROM v\$archived_log WHERE dest_id = 1 AND thread# = 2
AND sequence# between $STBY_SEQ2 and $PROD_SEQ2;
  EXIT;
EOF
)


echo $RM


SELECT 'rm -f $STBY_ARCH/'|| REPLACE(NAME, regexp_substr(NAME, '.*/')) file_name FROM v$archived_log WHERE dest_id = 1 AND thread# = 1
AND sequence# between 140 and 156 order by sequence#





Prioridades no atendimento:


