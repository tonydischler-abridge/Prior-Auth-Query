-- Provider list CTE: edit provider IDs here only once
-- Provider list CTE: edit provider IDs here once (use the VALUES-style constructor)
WITH provider_list AS (
    -- Edit providers in one place. Example: (100),(101),(102)
    SELECT v.provider_id
    FROM (VALUES (100),(101),(102)) AS v(provider_id)
),
-- CTE: encounter_date_range
-- Restrict encounters to a contact date window. Edit the start/end values below.
-- Adjust date literal format if your SQL dialect requires it (this uses YYYY-MM-DD strings).
encounter_date_range AS (
    SELECT p.PAT_ENC_CSN_ID AS pat_enc_csn_id
    FROM PAT_ENC p
    WHERE p.CONTACT_DATE >= '2024-01-01' AND p.CONTACT_DATE < '2025-01-01' -- <-- edit start/end dates
),
-- CTE: provider_encounters
-- Returns distinct PAT_ENC_CSN_ID (unique visit IDs) for providers in provider_list.
provider_encounters AS (
    SELECT DISTINCT p.PAT_ENC_CSN_ID AS pat_enc_csn_id
    FROM PAT_ENC p
    JOIN provider_list pl ON p.VISIT_PROV_ID = pl.provider_id
    JOIN encounter_date_range ed ON p.PAT_ENC_CSN_ID = ed.pat_enc_csn_id
)

SELECT
    pe.pat_enc_csn_id encounter_id -- encounter (visit) unique id from provider_encounters
    , ROW_NUMBER() OVER (
        PARTITION BY pe.pat_enc_csn_id
        ORDER BY COALESCE(pedx.DX_ID, 0), ordp.ORDER_PROC_ID, auth.AUTH_ID
    ) as row_in_encounter -- order within each encounter (diagnosis -> order -> auth)
    , auth.AUTH_ID authorization_id -- I AUT .1
    , auth.AUTH_NUM authorization_number -- I AUT 18062
    , auth.ORDER_ENTRY_ORDER_ID order_id -- I AUT 120 when the auth is created from an order 
    , auth.REFERRAL_ID referral_id -- I AUT 105 - Referral associated with the authorization
    , epm.PAYOR_NAME payor_name -- payor name from CLARITY_EPM
    , epp.BENEFIT_PLAN_NAME benefit_plan_name -- plan name from CLARITY_EPP
    , ordp.PROC_ID procedure_id -- I ORD 40 populated when the auth related order is a procedure order
    , ordp.PROC_CODE procedure_code -- I EAP 100 holds CPT 
    , opc.PROC_CODES_CODE_PROC_ID multi_procedure_codes -- I ORD 61310 holds multiple CPT codes when there are multiple
    , ordp.AUTHRZING_PROV_ID procedure_authorizing_provider_id -- I ORD 100
    , ser2p.NPI procedure_authorizing_provider_npi -- I SER 12100
    , scidp.CID procedure_authorizing_provider_cid -- I SER 11 remove if not licensed for intraconnect
    , edg.DX_NAME visit_diagnosis_name -- EDG diagnosis name
    , pedx.DX_ID visit_diagnosis_id -- PAT_ENC_DX id (may be null)
FROM 
    provider_encounters pe
    JOIN ORDER_PROC ordp on pe.pat_enc_csn_id = ordp.PAT_ENC_CSN_ID
    -- include diagnosis rows for the encounter (may be multiple per encounter)
    LEFT JOIN PAT_ENC_DX pedx on pe.pat_enc_csn_id = pedx.PAT_ENC_CSN_ID
    -- enrich diagnoses with EDG metadata (join by DX_ID)
    LEFT JOIN CLARITY_EDG edg on pedx.DX_ID = edg.DX_ID
    -- include all orders from encounters, but only attach authorizations when they exist and are active
    LEFT JOIN AUTHORIZATIONS auth on ordp.ORDER_PROC_ID = auth.ORDER_ENTRY_ORDER_ID
        AND auth.RECORD_STATUS_C NOT IN (2, 4, 6) -- only non-deleted/visible auths
        AND auth.DELETED_YN != 1 -- only non-deleted auths
    LEFT JOIN REFERRAL ref on auth.REFERRAL_ID = ref.REFERRAL_ID
    LEFT JOIN COVERAGE cov on ref.COVERAGE_ID = cov.COVERAGE_ID
    LEFT JOIN CLARITY_EPM epm on ref.PAYOR_ID = epm.PAYOR_ID
    LEFT JOIN CLARITY_EPP epp on ref.PLAN_ID = epp.BENEFIT_PLAN_ID
    LEFT JOIN ORDER_PROC_CODES opc on ordp.ORDER_PROC_ID = opc.ORDER_ID
    LEFT JOIN CLARITY_SER_2 ser2p on ordp.AUTHRZING_PROV_ID = ser2p.PROV_ID
    LEFT JOIN SER_MAP scidp on ser2p.PROV_ID = scidp.INTERNAL_ID -- remove if not licensed for intraconnect
-- Note: provider narrowing is handled by `provider_encounters` -> `ORDER_PROC`.
-- Authorization record-status and deleted filtering is applied by joining
-- directly to `AUTHORIZATIONS` from `ORDER_PROC`.

-- Order results grouped by encounter (PE.PAT_ENC_CSN_ID) so all rows for an encounter
-- appear together. Adjust secondary ordering as needed.
ORDER BY
    pe.pat_enc_csn_id
    , COALESCE(pedx.DX_ID, 0)
    , ordp.ORDER_PROC_ID
    , auth.AUTH_ID;
