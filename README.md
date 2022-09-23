# Standby_Campeiro
Projeto Standby Campeiro para Oracle by ilegra




-----  Step de Criação ------

- Arquivo de configuração

1) Instance_name
2) Cluster ( S/N )
  2.1) Single
    ###################################################################
    # DEBUG - Habilita debug no log do apply
    # SCRIPT_HOME - Diretorio onde ficam todos os arquivos do standby
    # SCRIPT_LOGS - Diretorio dos logs do apply
    # MAX_DIFF - Diferenca maxima aceita entre producao e standby
    # ASMTOFS - Flag para conversao de ASM para Filesystem
    # STBY_ARCH - Caminho absoluto dos archives do standby
    # STBY_DATAFILE - Caminho absoluto dos datafiles do standby
    # PROD_CRED - usuario e senha de system da producao
    # PROD_SN - Service Name da Producao
    # PROD_IP1 - IP do No 1 - Producao
    # PROD_SID1 - SID do No 1 - Producao
    ###################################################################

  2.2) Cluster
    ###################################################################
    # DEBUG - Habilita debug no log do apply
    # SCRIPT_HOME - Diretorio onde ficam todos os arquivos do standby
    # SCRIPT_LOGS - Diretorio dos logs do apply
    # MAX_DIFF - Diferenca maxima aceita entre producao e standby
    # ASMTOFS - Flag para conversao de ASM para Filesystem
    # STBY_ARCH - Caminho absoluto dos archives do standby
    # STBY_DATAFILE - Caminho absoluto dos datafiles do standby
    # PROD_CRED - usuario e senha de system da producao
    # PROD_SN - Service Name da Producao
    # PROD_IP1 - IP do No 1 - Producao
    # PROD_IP2 - IP do No 2 - Producao
    # PROD_SID1 - SID do No 1 - Producao
    # PROD_SID2 - SID do No 2 - Producao
    ###################################################################
    
    
