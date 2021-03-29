WITH OORDDTA AS
  (SELECT T0.ISO_COUNTRY_CODE,
    T0.SALES_ORDER_ID,
    CAST(T0.AFFILIATE_CODE AS     NUMBER(38,0)) AS oper_aff_id,
    CAST(T0.AMWAY_SALES_ENTITY AS NUMBER(38,0)) AS oper_cntry_id,
    CASE
      WHEN CONS_T.DELIVERY_ISO_COUNTRY_CODE='MY'
      THEN 100
      WHEN CONS_T.DELIVERY_ISO_COUNTRY_CODE='PH'
      THEN 350
      WHEN CONS_T.DELIVERY_ISO_COUNTRY_CODE='SG'
      THEN 530
      WHEN CONS_T.DELIVERY_ISO_COUNTRY_CODE='BN'
      THEN 780
      WHEN CONS_T.DELIVERY_ISO_COUNTRY_CODE='VN'
      THEN 500
      WHEN CONS_T.DELIVERY_ISO_COUNTRY_CODE='AU'
      THEN 30
      WHEN CONS_T.DELIVERY_ISO_COUNTRY_CODE='NZ'
      THEN 240
      ELSE CAST(T0.AMWAY_SALES_ENTITY AS NUMBER(38,0))
    END                                                                                                                         AS shp_cntry_id,
    T0.ORDER_DATE_TIME                                                                                                          AS ord_dt,
    EXTRACT(YEAR FROM T0.ORDER_DATE_TIME)*10000+EXTRACT(MONTH FROM T0.ORDER_DATE_TIME)*100+EXTRACT(DAY FROM T0.ORDER_DATE_TIME) AS ord_dt_key_no,
    EXTRACT(YEAR FROM T0.ORDER_DATE_TIME)*100+EXTRACT(MONTH FROM T0.ORDER_DATE_TIME)                                            AS ord_mo_yr_id,
    CASE
      WHEN COUNT(T0.SALES_ORDER_ID) OVER(PARTITION BY T0.AMWAY_SALES_ENTITY, COALESCE(T0.GROUP_ORDER_ID, CAST(T0.SALES_ORDER_ID AS INTEGER)))>1
      THEN 'true'
      ELSE 'false'
    END                                                             AS comb_ord_flag,
    COALESCE(T0.GROUP_ORDER_ID, CAST(T0.SALES_ORDER_ID AS INTEGER)) AS comb_ord_id,
    CAST(T0.SALES_ORDER_ID AS INTEGER)                              AS ord_id,
    T0.ISO_CURRENCY_CODE                                            AS curcy_cd,
    T0.SALES_CHANNEL_CODE                                           AS ord_channel,
    CAST(CONS_T.WAREHOUSE_CODE AS       VARCHAR2(240))                    AS whse_cd,
    CAST(CONS_T.DELIVERY_POSTAL_CODE AS VARCHAR2(240))                    AS shp_postal_cd,
    CAST(T0.VOLUME_SALES_ACCOUNT_ID AS  INTEGER)                          AS account_id,
    /*map to orderfromsalesaccount once it will appear in orderheader*/
    CAST(NULLIF('0', '0') AS VARCHAR2(8 BYTE)) AS account_type_ord,
    /*map  to "entity.lynxusertype" one it will appear in Atomic header*/
    CAST(T0.VOLUME_SALES_ACCOUNT_ID AS   INTEGER) AS vol_account_id,
    CAST(T0.ORDERING_SALES_ACCOUNT_ID AS INTEGER) AS ord_account_id,
    CAST(T0.SHIP_TO_SALES_ACCOUNT_ID AS  INTEGER) AS shp_account_id,
    CASE
      WHEN T0.ORDER_STATUS='CANCELLED'
      THEN 'true'
      ELSE 'false'
    END AS ord_canc_flag,
    CASE
      WHEN T0.ORDER_STATUS='SHIPPED'
      THEN 'true'
      ELSE 'false'
    END AS ord_shp_flag,
    CASE
      WHEN T0.PAYMENT_REQUIRED='true'
      THEN 'true'
      ELSE 'false'
    END AS pay_req_flag,
    CASE
      WHEN T0.PAYMENT_STATUS='PAID'
      THEN 'true'
      ELSE 'false'
    END                                                                                 AS ord_paid_flag,
    CAST(REGEXP_REPLACE(T0.ORIGINAL_ORDER_ID, '[,.]', '') AS INTEGER)                                               AS org_ord_id,
    CAST(NULLIF('0', '0') AS     VARCHAR2(240 CHAR))                                    AS ord_type_cd,
    CAST(NULLIF('0', '0') AS     VARCHAR2(240 CHAR))                                    AS drop_cd,
    CONS_T.AMWAY_SALES_ENTITY AS CONS_AMWAY_SALES_ENTITY,
    NULLIF(CAST(T0.TOTAL_ORDER_VALUE AS NUMBER)-CAST(T0.TOTAL_TAX_AMOUNT AS NUMBER), 0) AS NET_REVENUE_TTL
  FROM DWSATM01.DWT42231_ORD_HDR_EAP T0
  LEFT JOIN
    (SELECT DISTINCT SALES_ORDER_ID,
      DELIVERY_POSTAL_CODE,
      DELIVERY_ISO_COUNTRY_CODE,
      AMWAY_SALES_ENTITY,
      WAREHOUSE_CODE
    FROM DWSATM01.DWT42343_ORD_CONSIGN_EAP
    WHERE EXTRACT(YEAR FROM ORDER_DATE_TIME)*100+EXTRACT(MONTH FROM ORDER_DATE_TIME) BETWEEN 202102 AND 202102
    ) CONS_T
  ON T0.SALES_ORDER_ID     =CONS_T.SALES_ORDER_ID
  AND T0.AMWAY_SALES_ENTITY=CONS_T.AMWAY_SALES_ENTITY
  WHERE EXTRACT(YEAR FROM T0.ORDER_DATE_TIME)*100+EXTRACT(MONTH FROM T0.ORDER_DATE_TIME) BETWEEN 202102 AND 202102
  ),
  -----OORDLIN
  OORDLIN AS
  (SELECT SALE_COUNTRY_CODE,
    SALES_ORDER_ID,
    CAST('01-01-00' AS TIMESTAMP(6)) AS shp_dt,
    /*Map to valid ship date once it will appear in order lines*/
    20000101 AS shp_dt_key_no,
    /*Map to valid ship date once it will appear in order lines*/
    200001 AS shp_mo_yr_id,
    /*Map to valid ship date once it will appear in order lines*/
    CAST(SALES_ORDER_ID AS   INTEGER)                                                    AS ord_id,
    CAST(T0.ORDER_LINE_ID AS INTEGER)                                                    AS ord_ln_id,
    CAST(NULLIF(0,0) AS      NUMBER(38))                                                 AS ref_ln_id,
    CAST('*' AS              VARCHAR2(240 BYTE))                                         AS ord_ln_disp_cd,
    trim(COALESCE(BUNDLE_ITEM_ID, BASE_ITEM_ID))                                         AS ord_item_cd,
    trim(BASE_ITEM_ID)                                                                   AS shp_item_cd,
    SUM(CAST(CAST(T0.LINE_PRICE AS NUMBER) AS NUMBER)) OVER(partition BY SALES_ORDER_ID) AS NET_REV_BEFORE_ADJ_TTL,
    CAST(T0.LINE_PRICE AS NUMBER)                                                        AS NET_REV_BEFORE_ADJ,
    T0.LINE_PV_AMOUNT                                                                    AS adj_ln_pv,
    T0.LINE_BV_AMOUNT                                                                    AS adj_ln_bv,
    COALESCE(T0.SHIPPED_QUANTITY, 0)+COALESCE(T0.PENDING_QUANTITY, 0)                    AS ord_qty,
    COALESCE(T0.ORDERED_QUANTITY, 0)-COALESCE(T0.CANCELLED_QUANTITY,0)                   AS shp_qty,
    DEMAND_LOCATION                                                                      AS ord_whse_cd,
    FULFILLMENT_TYPE                                                                     AS delivery_mode_cd
  FROM DWSATM01.DWT42332_ORD_LINE_EAP T0
  ),
  FEES_T AS
  (SELECT SALES_ORDER_ID,
    SALE_COUNTRY_CODE,
    SUM(COALESCE(CAST(FEE_AMOUNT AS NUMBER), 0))-SUM(COALESCE(CAST(FEE_TAX_TOTAL_AMOUNT AS NUMBER), 0)) AS FEE_TTL,
    SUM(
    CASE
      WHEN FEE_CODE IN ('netRoundOff_increase', 'netRoundOff_decrease')
      THEN 0
      ELSE COALESCE(CAST(FEE_AMOUNT AS NUMBER), 0)
    END)-SUM(
    CASE
      WHEN FEE_CODE IN ('netRoundOff_increase', 'netRoundOff_decrease')
      THEN 0
      ELSE COALESCE(CAST(FEE_TAX_TOTAL_AMOUNT AS NUMBER), 0)
    END) AS delivery_fee_net
  FROM DWSATM01.DWT42339_ORD_FEES_EAP T0
  GROUP BY SALES_ORDER_ID,
    SALE_COUNTRY_CODE
  )
/*Main script*/
SELECT OORDDTA.oper_aff_id                         AS oper_aff_id,
  OORDDTA.oper_cntry_id                            AS oper_cntry_id,
  OORDDTA.shp_cntry_id                             AS shp_cntry_id,
  OORDDTA.ord_dt                                   AS ord_dt,
  CAST(OORDDTA.ord_dt_key_no AS NUMBER(8, 0))      AS ord_dt_key_no,
  CAST(OORDDTA.ord_mo_yr_id AS  NUMBER(6, 0))      AS ord_mo_yr_id,
  OORDLIN.shp_dt                                   AS shp_dt,
  CAST(OORDLIN.shp_dt_key_no AS NUMBER(8, 0))      AS shp_dt_key_no,
  CAST(OORDLIN.shp_mo_yr_id AS  NUMBER(6, 0))      AS shp_mo_yr_id,
  OORDDTA.comb_ord_flag                            AS comb_ord_flag,
  OORDDTA.comb_ord_id                              AS comb_ord_id,
  OORDDTA.ord_id                                   AS ord_id,
  CAST(INV_T.INVOICE_NUMBER AS VARCHAR2(240 CHAR)) AS inv_cd,
  OORDDTA.curcy_cd                                 AS curcy_cd,
  OORDDTA.ord_channel                              AS ord_channel,
  OORDDTA.whse_cd                                  AS whse_cd,
  OORDLIN.ord_whse_cd                              AS ord_whse_cd,
  OORDDTA.shp_postal_cd                            AS shp_postal_cd,
  OORDDTA.account_id                               AS account_id,
  OORDDTA.account_type_ord                         AS account_type_ord,
  OORDDTA.vol_account_id                           AS vol_account_id,
  OORDDTA.ord_account_id                           AS ord_account_id,
  OORDDTA.shp_account_id                           AS shp_account_id,
  OORDDTA.ord_canc_flag                            AS ord_canc_flag,
  OORDDTA.ord_shp_flag                             AS ord_shp_flag,
  OORDDTA.pay_req_flag                             AS pay_req_flag,
  OORDDTA.ord_paid_flag                            AS ord_paid_flag,
  OORDDTA.org_ord_id          AS org_ord_id,
  OORDDTA.ord_type_cd                              AS ord_type_cd,
  OORDDTA.drop_cd                                  AS drop_cd,
  CASE WHEN OORDDTA.CONS_AMWAY_SALES_ENTITY IS NULL THEN 0 ELSE FEES_T.delivery_fee_net         END                  AS delivery_fee_net,
  OORDLIN.ord_ln_id                                AS ord_ln_id,
  OORDLIN.ref_ln_id                                AS ref_ln_id,
  OORDLIN.ord_ln_disp_cd,
  OORDLIN.ord_item_cd AS ord_item_cd,
  OORDLIN.shp_item_cd AS shp_item_cd,
  CASE
    WHEN INSTR(REGEXP_REPLACE(SUBSTR(TRIM(CAST(OORDLIN.ord_item_cd AS VARCHAR2(15 CHAR))), 4, LENGTH(TRIM(CAST(OORDLIN.ord_item_cd AS VARCHAR2(15 CHAR))))                                                                -3), '[B-Z]', 'A'), 'A')>0
    THEN SUBSTR(TRIM(CAST(OORDLIN.ord_item_cd AS VARCHAR2(15 CHAR))), 1, INSTR(REGEXP_REPLACE(SUBSTR(TRIM(CAST(OORDLIN.ord_item_cd AS VARCHAR2(15 CHAR))), 4, LENGTH(TRIM(CAST(OORDLIN.ord_item_cd AS VARCHAR2(15 CHAR))))-3), '[B-Z]', 'A'), 'A')+ 2)
    ELSE TRIM(CAST(OORDLIN.ord_item_cd AS VARCHAR2(15 CHAR)))
  END AS ord_item_base_cd,
  CASE
    WHEN INSTR(REGEXP_REPLACE(SUBSTR(TRIM(CAST(OORDLIN.shp_item_cd AS VARCHAR2(15 CHAR))), 4, LENGTH(TRIM(CAST(OORDLIN.shp_item_cd AS VARCHAR2(15 CHAR))))                                                                -3), '[B-Z]', 'A'), 'A')>0
    THEN SUBSTR(TRIM(CAST(OORDLIN.shp_item_cd AS VARCHAR2(15 CHAR))), 1, INSTR(REGEXP_REPLACE(SUBSTR(TRIM(CAST(OORDLIN.shp_item_cd AS VARCHAR2(15 CHAR))), 4, LENGTH(TRIM(CAST(OORDLIN.shp_item_cd AS VARCHAR2(15 CHAR))))-3), '[B-Z]', 'A'), 'A')+ 2)
    ELSE TRIM(CAST(OORDLIN.shp_item_cd AS VARCHAR2(15 CHAR)))
  END                                                                                                                       AS shp_item_base_cd,
  ROUND(OORDLIN.NET_REV_BEFORE_ADJ*((OORDDTA.NET_REVENUE_TTL-FEES_T.FEE_TTL)/NULLIF(OORDLIN.NET_REV_BEFORE_ADJ_TTL, 0)), 2) AS adj_ln_lc_net,
  OORDLIN.adj_ln_pv                                                                                                         AS adj_ln_pv,
  OORDLIN.adj_ln_bv                                                                                                         AS adj_ln_bv,
  OORDLIN.ord_qty                                                                                                           AS ord_qty,
  OORDLIN.shp_qty                                                                                                           AS shp_qty,
  OORDLIN.delivery_mode_cd                                                                                                  AS delivery_mode_cd,
  CAST(NULLIF('0', '0') AS VARCHAR2(50 CHAR))                                                                         AS consultant_cd      
FROM OORDLIN OORDLIN
LEFT JOIN OORDDTA OORDDTA
ON OORDLIN.ord_id            =OORDDTA.ord_id
AND OORDLIN.SALE_COUNTRY_CODE=OORDDTA.ISO_COUNTRY_CODE
LEFT JOIN DWSATM01.DWT42341_ORD_LN_INVOICE_EAP INV_T
ON OORDLIN.SALE_COUNTRY_CODE=INV_T.SALE_COUNTRY_CODE
AND OORDLIN.SALES_ORDER_ID  =INV_T.SALES_ORDER_ID
AND OORDLIN.ord_ln_id       =CAST(INV_T.ORDER_LINE_ID AS INTEGER)
LEFT JOIN FEES_T FEES_T
ON OORDLIN.SALE_COUNTRY_CODE=FEES_T.SALE_COUNTRY_CODE
AND OORDLIN.SALES_ORDER_ID  =FEES_T.SALES_ORDER_ID
WHERE OORDDTA.ORD_ID       IS NOT NULL
