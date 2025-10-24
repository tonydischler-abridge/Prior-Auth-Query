WITH allowed_auths AS (
    SELECT auth.*
    FROM AUTHORIZATIONS auth
    JOIN ORDER_PROC ordp ON auth.ORDER_ENTRY_ORDER_ID = ordp.ORDER_PROC_ID
    WHERE ordp.AUTHRZING_PROV_ID IN (100,101,102) -- <-- Edit provider IDs here
      AND auth.RECORD_STATUS_C NOT IN (2, 4, 6) -- exclude soft deleted, hidden, hidden and soft deleted
      AND auth.DELETED_YN != 1 -- exclude deleted records
)

SELECT
    auth.AUTH_ID authorization_id -- I AUT .1
    , auth.AUTH_NUM authorization_number -- I AUT 18062
    , auth.ORDER_ENTRY_ORDER_ID order_id -- I AUT 120 when the auth is created from an order 
    , auth.LINKED_REFERRAL_ID referral_id -- I AUT 20000 links to the referral record for the auth
    , auth.FIRST_PAT_ENC_CSN_ID first_encounter_id -- I AUT 2315
    , auth.LAST_PAT_ENC_CSN_ID last_encounter_id -- I AUT 2316
    , ordp.PROC_ID procedure_id -- I ORD 40 populated when the auth related order is a procedure order
    , ordp.PROC_CODE procedure_code -- I EAP 100 holds CPT 
    , opc.PROC_CODES_CODE_PROC_ID multi_procedure_codes -- I ORD 61310 holds multiple CPT codes when there are multiple
    , ordp.AUTHRZING_PROV_ID procedure_authorizing_provider_id -- I ORD 100
    , ser2p.NPI procedure_authorizing_provider_npi -- I SER 12100
    , scidp.CID procedure_authorizing_provider_cid -- I SER 11 remove if not licensed for intraconnect
FROM 
    allowed_auths auth
    LEFT JOIN REFERRAL ref on auth.LINKED_REFERRAL_ID = ref.REFERRAL_ID
    LEFT JOIN COVERAGE cov on ref.COVERAGE_ID = cov.COVERAGE_ID
    LEFT JOIN CLARITY_EPM epm on ref.PAYOR_ID = epm.PAYOR_ID -- Check this one
    LEFT JOIN CLARITY_EPP epp on ref.PLAN_ID = epp.PLAN_ID -- Check this one 
    LEFT JOIN ORDER_PROC ordp on auth.ORDER_ENTRY_ORDER_ID = ordp.ORDER_PROC_ID
    LEFT JOIN ORDER_PROC_CODES opc on ordp.ORDER_PROC_ID = opc.ORDER_ID
    LEFT JOIN CLARITY_SER_2 ser2p on ordp.AUTHRZING_PROV_ID = ser2p.PROV_ID
    LEFT JOIN SER_MAP scidp on ser2p.PROV_ID =scidp.INTERNAL_ID -- remove if not licensed for intraconnect
-- Note: filtering by provider happens in the allowed_auths CTE above. If you prefer
-- to keep the original WHERE clause instead of filtering in the CTE, replace
-- `allowed_auths auth` with `AUTHORIZATIONS auth` and add
-- `AND ordp.AUTHRZING_PROV_ID IN (100,101,102)` to the WHERE clause.
