{{ config(enabled=var('ad_reporting__google_ads_enabled', True),
     unique_key = ['source_relation','campaign_id','updated_at'],
     partition_by={
      "field": "updated_at", 
      "data_type": "TIMESTAMP",
      "granularity": "day"
    }
    ) }}

with base as (

    select * 
    from {{ ref('stg_google_ads__campaign_history_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_google_ads__campaign_history_tmp')),
                staging_columns=get_campaign_history_columns()
            )
        }}
        
    
        {{ fivetran_utils.source_relation(
            union_schema_variable='google_ads_union_schemas', 
            union_database_variable='google_ads_union_databases') 
        }}

    from base
),

final as (

    select
        source_relation, 
        id as campaign_id, 
        CAST(FORMAT_TIMESTAMP("%F %T", updated_at, "America/Chicago") AS TIMESTAMP) as updated_at,        --Central timezone conversion
        name as campaign_name,
        customer_id as account_id,
        advertising_channel_type,
        advertising_channel_subtype,
        COALESCE(
        start_date,
        SUBSTR(start_date_time, 1, 10)
        ) AS start_date,
        COALESCE(
        end_date,
        SUBSTR(end_date_time, 1, 10)
        ) AS end_date,
        serving_status,
        status,
        tracking_url_template,
        row_number() over (partition by source_relation, id order by updated_at desc) = 1 as is_most_recent_record
    from fields
)

select * 
from final