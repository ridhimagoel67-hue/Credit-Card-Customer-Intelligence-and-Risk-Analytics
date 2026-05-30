CREATE VIEW revenue_segment_analysis AS

SELECT
    spending_tier,

    ROUND(
        SUM(total_spend)::numeric,
        2
    ) AS total_revenue,

    COUNT(client_id) AS customer_count,

    ROUND(
        AVG(total_spend)::numeric,
        2
    ) AS avg_customer_revenue,

    ROUND(
        (
            SUM(total_spend) * 100.0
            /
            SUM(SUM(total_spend)) OVER ()
        )::numeric,
        2
    ) AS revenue_contribution_pct

FROM customer_analytics

GROUP BY spending_tier;


SELECT * FROM revenue_segment_analysis;



CREATE VIEW churn_analysis AS

SELECT
    client_id,
    churn_risk,
    days_since_last_transaction,
    total_spend,
    engagement_score,

    CASE
        WHEN days_since_last_transaction > 60
        THEN 'Critical Risk'

        WHEN days_since_last_transaction > 30
        THEN 'High Risk'

        ELSE 'Active'
    END AS churn_category

FROM customer_analytics;

SELECT *
FROM churn_analysis
LIMIT 10;

CREATE VIEW customer_loyalty_analysis AS

WITH loyalty_scores AS (

    SELECT
        client_id,
        total_spend,
        transaction_count,
        engagement_score,

        (
            total_spend * 0.4
            +
            transaction_count * 0.3
            +
            engagement_score * 0.3
        ) AS loyalty_score

    FROM customer_analytics
)

SELECT
    *,

    RANK() OVER (
        ORDER BY loyalty_score DESC
    ) AS loyalty_rank

FROM loyalty_scores;


SELECT *
FROM customer_loyalty_analysis
LIMIT 10;


CREATE VIEW transaction_behavior_analysis AS

SELECT
    hour,

    CASE
        WHEN is_weekend = TRUE
        THEN 'Weekend'

        ELSE 'Weekday'
    END AS day_type,

    COUNT(*) AS transaction_count,

    ROUND(
        SUM(amount)::numeric,
        2
    ) AS total_revenue,

    ROUND(
        AVG(amount)::numeric,
        2
    ) AS avg_transaction_amount

FROM transactions_cleaned

GROUP BY
    hour,
    day_type;

SELECT *
FROM transaction_behavior_analysis
LIMIT 10;

CREATE VIEW customer_risk_analysis AS

WITH declined_transactions AS (

    SELECT
        client_id,
        COUNT(*) AS decline_count

    FROM transactions_cleaned

    WHERE errors != 'No Error'

    GROUP BY client_id
)

SELECT
    ca.client_id,
    ca.spending_volatility,
    ca.volatility_level,
    ca.total_spend,

    COALESCE(
        dt.decline_count,
        0
    ) AS decline_count,

    RANK() OVER (

        ORDER BY
            ca.spending_volatility DESC,
            COALESCE(dt.decline_count,0) DESC
    ) AS risk_rank

FROM customer_analytics ca

LEFT JOIN declined_transactions dt
ON ca.client_id = dt.client_id;

SELECT *
FROM customer_risk_analysis
LIMIT 10;

CREATE VIEW strategic_recommendations AS

SELECT
    client_id,
    total_spend,
    engagement_score,
    churn_risk,
    wellness_score,

    CASE

        WHEN
            total_spend > 15000
            AND engagement_score > 100

        THEN 'Premium Offer'

        WHEN
            churn_risk = 'High Risk'
            AND total_spend > 7000

        THEN 'Retention Campaign'

        WHEN
            wellness_score < 50

        THEN 'Financial Wellness Program'

        ELSE 'Standard Engagement'

    END AS recommendation

FROM customer_analytics;

SELECT *
FROM strategic_recommendations
LIMIT 20;