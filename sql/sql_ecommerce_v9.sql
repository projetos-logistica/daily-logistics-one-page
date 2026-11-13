=/* =========================================================
   SQL - E-commerce | Daily Logistics (1 linha por MARCA + 1 linha TOTAL)
   Período [@INI, @D1] e filial opcionais (parâmetros do webhook). Base: query_ecommerce (PASSO 1) - DW_LOGISTICA_PRODUCAO_ECOMMERCE
   Pedidos = contagem ÚNICA de CHAVE_2 (filial + pedido), mesma regra do Power BI
   ("01 Total Pedidos" = DISTINCTCOUNT(CHAVE_2)). Peças e valor = soma das linhas.
   A linha TOTAL (eh_total = 1) traz pedidos únicos no grupo; um pedido com mais de
   uma marca conta em cada marca, então total <= soma das marcas.
   Posição de backlog = momento da execução (GETDATE): reprocessar datas passadas NÃO reproduz o backlog da época.
   Pedidos cancelados (bases ECOMM*, LOJA_PEDIDO.CANCELADO = 1) são EXCLUÍDOS,
   mesma regra do Power BI (tabela fcanceladosfinal / pedido_cancelado).
   ========================================================= */
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AGORA DATETIME = GETDATE()                           -- momento da atualização (horário do servidor SQL)
DECLARE @INI DATE = '{{ $json.dataIni }}'                    -- início do período (padrão: D-1)
DECLARE @D1 DATE = '{{ $json.dataFim }}'                     -- fim do período (padrão: D-1); nome mantido nas fórmulas
DECLARE @FILIAL NVARCHAR(200) = N'{{ $json.filialSql }}'     -- filial selecionada ('' = todas)
DECLARE @D7 DATE = DATEADD(DAY, -6, @D1)                     -- backlog: 7 dias até a data final
DECLARE @INI_MES DATE = DATEFROMPARTS(YEAR(@D1), MONTH(@D1), 1)  -- 1º dia do mês da data final (lead time mensal)
DECLARE @DATAINICIO DATE = (SELECT MIN(V) FROM (VALUES (DATEADD(DAY, -30, @INI)), (DATEADD(DAY, -7, @INI_MES)), (@D7)) T(V))  -- janela de leitura: cobre pedidos de até 30 dias antes do período expedidos nele, o mês e o backlog D-7
DECLARE @DATA_CANC_INI DATE = DATEADD(DAY, -2, @DATAINICIO)    -- cancelados: pequena margem antes da janela de leitura
DECLARE @META_LT_MIN INT = {{ $json.leadTimeMetaH }} * 60    -- meta de lead time em minutos

DROP TABLE IF EXISTS #DW
DROP TABLE IF EXISTS #CANC
DROP TABLE IF EXISTS #FIL
DROP TABLE IF EXISTS #RES

SELECT
     D.CODIGO_FILIAL_ORIGEM
    ,D.PEDIDO
    ,CASE
        WHEN D.SITE = 'NV - HUB ES' THEN 'HUB SP'
        WHEN D.CODIGO_FILIAL_ORIGEM IN ('805209','550325','560030','805210','550070','190537') THEN 'HUB RIO'
        ELSE D.SITE
     END AS SITE
    ,LTRIM(RTRIM(D.MARCA)) AS MARCA_ORIGINAL
    ,LTRIM(RTRIM(D.FILIAL)) AS FILIAL                 -- nome da filial no DW (ajuste a coluna aqui se o nome for outro)
    ,D.QTDE_TOTAL
    ,D.VALOR_TOTAL
    ,D.DATA_HORA_INTEGRACAO AS DATA_VENDA
    ,COALESCE(D.DATA_EMBARQUE, D.DATA_EXPEDIDO_WMS, D.EMISSAO_CTE) AS DATA_EXPEDIDO
    ,ROW_NUMBER() OVER (PARTITION BY D.CODIGO_FILIAL_ORIGEM, D.PEDIDO, D.MARCA
                        ORDER BY D.DATA_HORA_ATUALIZACAO DESC, D.DATA_FATURAMENTO DESC) AS RN
INTO #DW
FROM DB_VIEWS.dbo.DW_LOGISTICA_PRODUCAO_ECOMMERCE D
WHERE D.DATA_HORA_INTEGRACAO >= @DATAINICIO
  AND D.DATA_HORA_INTEGRACAO <  DATEADD(DAY, 1, @D1)
  AND D.SITE IN ('HUB RIO','HUB SP','HUB ES','NV - HUB ES','HUB CAROL BASSI','HUB CBA')
  AND D.STATUS_PEDIDO IN ('VALIDO','VÁLIDO')

DELETE #DW WHERE RN > 1

/* Cancelados: mesmas bases usadas pela tabela fcanceladosfinal do Power BI (lista sem duplicidades).
   Chave = filial (sem espaços) + pedido, comparada com CHAVE_2 = filial + pedido. */
SELECT
     CONCAT(LTRIM(RTRIM(U.CODIGO_FILIAL_ORIGEM)), CAST(U.PEDIDO AS VARCHAR(50))) COLLATE DATABASE_DEFAULT AS CHAVE
INTO #CANC
FROM (
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMANIMALEATG].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMFYIATG].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMABRANDATG].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMFARMATG].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMFABULAATG].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMFOXTONVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMmariafiloVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMOUTLETATG].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMSPANIMALEVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMSPFARMVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMspfabulaVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMcrisbarrosVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMspnvVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMspfoxtonVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[EcommCarolBassiVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMnvVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
    UNION ALL
    SELECT CODIGO_FILIAL_ORIGEM, PEDIDO FROM [192.168.9.205].[ECOMMspmariafiloVTEX].[DBO].[LOJA_PEDIDO] WHERE CANCELADO = 1 AND DATA >= @DATA_CANC_INI
) U

DELETE D
FROM #DW D
WHERE EXISTS (SELECT 1 FROM #CANC C
              WHERE C.CHAVE = CONCAT(D.CODIGO_FILIAL_ORIGEM, D.PEDIDO) COLLATE DATABASE_DEFAULT)

-- Escopo do relatório: apenas o hub definido em Parâmetros (siteFiltro), usando o mesmo mapeamento de SITE da query_ecommerce
DELETE #DW WHERE SITE <> '{{ $json.siteFiltro }}'

-- Lista de filiais do hub na janela (alimenta a lista suspensa; antes de aplicar o filtro de filial)
SELECT DISTINCT FILIAL INTO #FIL FROM #DW WHERE FILIAL IS NOT NULL AND FILIAL <> ''

-- Filtro de filial (vazio = todas)
IF @FILIAL <> N'' DELETE #DW WHERE ISNULL(FILIAL, '') COLLATE DATABASE_DEFAULT <> @FILIAL COLLATE DATABASE_DEFAULT


SELECT
     CASE WHEN GROUPING(X.MARCA) = 1 THEN 1 ELSE 0 END AS eh_total
    ,CAST(X.MARCA AS NVARCHAR(200)) AS MARCA
    -- Integrado: vendas no período
    ,COUNT(DISTINCT CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 THEN X.CHAVE_2 END)             AS ped_integrado
    ,SUM(CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 THEN ISNULL(X.QTDE_TOTAL,0)  ELSE 0 END)  AS pc_integrado
    ,SUM(CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 THEN ISNULL(X.VALOR_TOTAL,0) ELSE 0 END)  AS rs_integrado
    -- Atendido: expedidos no período
    ,COUNT(DISTINCT CASE WHEN X.DT_EXPEDIDO BETWEEN @INI AND @D1 THEN X.CHAVE_2 END)            AS ped_atendido
    ,SUM(CASE WHEN X.DT_EXPEDIDO BETWEEN @INI AND @D1 THEN ISNULL(X.QTDE_TOTAL,0)  ELSE 0 END) AS pc_atendido
    ,SUM(CASE WHEN X.DT_EXPEDIDO BETWEEN @INI AND @D1 THEN ISNULL(X.VALOR_TOTAL,0) ELSE 0 END) AS rs_atendido
    -- Backlog pendente: vendidos em D-1 que continuam sem expedição NO MOMENTO DA ATUALIZAÇÃO
    ,COUNT(DISTINCT CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 AND X.ABERTO = 1 THEN X.CHAVE_2 END)             AS ped_pendente
    ,SUM(CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 AND X.ABERTO = 1 THEN ISNULL(X.QTDE_TOTAL,0)  ELSE 0 END)  AS pc_pendente
    ,SUM(CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 AND X.ABERTO = 1 THEN ISNULL(X.VALOR_TOTAL,0) ELSE 0 END)  AS rs_pendente
    -- Backlog D-7: vendidos de D-7 a D-1 que continuam sem expedição NO MOMENTO DA ATUALIZAÇÃO
    ,COUNT(DISTINCT CASE WHEN X.DT_VENDA BETWEEN @D7 AND @D1 AND X.ABERTO = 1 THEN X.CHAVE_2 END)             AS ped_backlog_7d
    ,SUM(CASE WHEN X.DT_VENDA BETWEEN @D7 AND @D1 AND X.ABERTO = 1 THEN ISNULL(X.QTDE_TOTAL,0)  ELSE 0 END)  AS pc_backlog_7d
    ,SUM(CASE WHEN X.DT_VENDA BETWEEN @D7 AND @D1 AND X.ABERTO = 1 THEN ISNULL(X.VALOR_TOTAL,0) ELSE 0 END)  AS rs_backlog_7d
    -- SLA: pedidos vendidos em D-1. Cumprido = expedido em até a meta de lead time.
    --      Base = cumpridos + descumpridos (expedidos fora da meta + pendentes já acima da meta). Pendentes ainda dentro da meta ficam fora da base.
    ,COUNT(DISTINCT CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 AND X.ABERTO = 0 AND X.LT_MIN <= @META_LT_MIN THEN X.CHAVE_2 END)  AS sla_cumprido
    ,COUNT(DISTINCT CASE WHEN X.DT_VENDA BETWEEN @INI AND @D1 AND (X.ABERTO = 0 OR X.LT_MIN > @META_LT_MIN) THEN X.CHAVE_2 END)   AS sla_base
    -- Lead time (venda -> expedição) dos expedidos em D-1 (base: linhas pedido x marca)
    ,SUM(CASE WHEN X.DT_EXPEDIDO BETWEEN @INI AND @D1 THEN 1 ELSE 0 END)                                                                  AS qtd_expedidos
    ,SUM(CASE WHEN X.DT_EXPEDIDO BETWEEN @INI AND @D1 THEN DATEDIFF(MINUTE, X.DATA_VENDA, X.DATA_EXPEDIDO) / 60.0 ELSE 0 END)            AS soma_lead_time_h
    -- Lead time do mês vigente: expedidos de 1º do mês até D-1 (mesma base)
    ,SUM(CASE WHEN X.DT_EXPEDIDO BETWEEN @INI_MES AND @D1 THEN 1 ELSE 0 END)                                              AS qtd_expedidos_mes
    ,SUM(CASE WHEN X.DT_EXPEDIDO BETWEEN @INI_MES AND @D1 THEN DATEDIFF(MINUTE, X.DATA_VENDA, X.DATA_EXPEDIDO) / 60.0 ELSE 0 END) AS soma_lead_time_h_mes
INTO #RES
FROM (
    SELECT
         CASE
            WHEN A.MARCA_ORIGINAL LIKE '%FOXTON%'  THEN 'FOXTON'
            WHEN A.MARCA_ORIGINAL LIKE '%FABULA%'  THEN 'FABULA'
            WHEN A.MARCA_ORIGINAL LIKE '%ANIMALE%' THEN 'ANIMALE'
            ELSE A.MARCA_ORIGINAL
         END AS MARCA
        ,CONCAT(A.CODIGO_FILIAL_ORIGEM, A.PEDIDO) AS CHAVE_2
        ,A.QTDE_TOTAL
        ,A.VALOR_TOTAL
        ,A.DATA_VENDA
        ,A.DATA_EXPEDIDO
        ,CAST(A.DATA_VENDA    AS DATE) AS DT_VENDA
        ,CAST(A.DATA_EXPEDIDO AS DATE) AS DT_EXPEDIDO
        ,CASE WHEN A.DATA_EXPEDIDO IS NULL THEN 1 ELSE 0 END AS ABERTO                                  -- sem expedição agora
        ,DATEDIFF(MINUTE, A.DATA_VENDA, ISNULL(A.DATA_EXPEDIDO, @AGORA)) AS LT_MIN                       -- minutos da venda até a expedição (ou até agora, se pendente)
    FROM #DW A
) X
GROUP BY GROUPING SETS ((X.MARCA), ())

-- Linhas eh_total = 2: lista de filiais (apenas a coluna MARCA preenchida, com o nome da filial)
INSERT INTO #RES (eh_total, MARCA) SELECT 2, FILIAL FROM #FIL

SELECT * FROM #RES ORDER BY eh_total, MARCA;
