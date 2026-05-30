CREATE TABLE users_cleaned (
    id INT PRIMARY KEY,
    current_age INT,
    retirement_age INT,
    birth_year INT,
    birth_month INT,
    gender VARCHAR(20),
    address TEXT,
    latitude FLOAT,
    longitude FLOAT,
    per_capita_income FLOAT,
    yearly_income FLOAT,
    total_debt FLOAT,
    credit_score INT,
    num_credit_cards INT
);

CREATE TABLE cards_cleaned (
    id INT PRIMARY KEY,
    client_id INT,
    card_brand VARCHAR(50),
    card_type VARCHAR(50),
    card_number BIGINT,
    expires VARCHAR(20),
    cvv INT,
    has_chip VARCHAR(10),
    num_cards_issued INT,
    credit_limit FLOAT,
    acct_open_date DATE,
    year_pin_last_changed INT,
    card_on_dark_web VARCHAR(10)
);

CREATE TABLE transactions_cleaned (
    id BIGINT PRIMARY KEY,
    date TIMESTAMP,
    client_id INT,
    card_id INT,
    amount FLOAT,
    use_chip VARCHAR(50),
    merchant_id INT,
    merchant_city VARCHAR(100),
    merchant_state VARCHAR(50),
    zip FLOAT,
    mcc INT,
    errors TEXT,
    year INT,
    month VARCHAR(20),
    month_num INT,
    weekday VARCHAR(20),
    hour INT,
    is_weekend BOOLEAN
);

CREATE TABLE customer_analytics (
    client_id INT,
    total_spend FLOAT,
    avg_spend FLOAT,
    transaction_count INT,
    spending_volatility FLOAT,
    engagement_score FLOAT,
    persona VARCHAR(50),
    spending_tier VARCHAR(50),
    volatility_level VARCHAR(50),
    wellness_score FLOAT,
    wellness_category VARCHAR(50),
    high_value_customer INT,
    digital_transaction_ratio FLOAT,
    digital_persona VARCHAR(50),
    last_transaction_date TIMESTAMP,
    days_since_last_transaction INT,
    churn_risk VARCHAR(50)
);
DROP TABLE customer_analytics
CREATE TABLE customer_analytics (
    client_id INT,
    total_spend FLOAT,
    avg_spend FLOAT,
    transaction_count INT,
    spending_volatility FLOAT,
    engagement_score FLOAT,
    spending_tier VARCHAR(50),
    volatility_level VARCHAR(50),
    wellness_score FLOAT,
    wellness_category VARCHAR(50),
    high_value_customer INT,
    digital_transaction_ratio FLOAT,
    digital_persona VARCHAR(50),
    last_transaction_date TIMESTAMP,
    days_since_last_transaction INT,
    churn_risk VARCHAR(50),
    current_age INT,
    gender VARCHAR(20),
    yearly_income FLOAT,
    total_debt FLOAT,
    credit_score INT,
    num_credit_cards INT
);

SELECT COUNT(*) FROM users_cleaned;
SELECT COUNT(*) FROM cards_cleaned;
SELECT COUNT(*) FROM transactions_cleaned;
SELECT COUNT(*) FROM customer_analytics;

--Which customer segment drives maximum revenue?
SELECT
spending_tier,
ROUND(SUM(total_spend)::numeric,2) AS total_revenue,
COUNT(client_id) AS customer_count,
ROUND(AVG(total_spend)::numeric,2) AS avg_customer_revenue,
ROUND((SUM(total_spend) * 100.0 /SUM(SUM(total_spend)) OVER ())::numeric,2) AS revenue_contribution_pct
FROM customer_analytics
GROUP BY spending_tier
ORDER BY total_revenue DESC;

--Which category contribute most revenue?
SELECT
mcc,
ROUND(SUM(amount)::numeric,2) AS total_revenue,
COUNT(*) AS transaction_count,
RANK() OVER (ORDER BY SUM(amount) DESC) AS revenue_rank
FROM transactions_cleaned
GROUP BY mcc;

--Which cities have highest transaction volume?
SELECT
merchant_city,
COUNT(*) AS total_transactions,
ROUND(SUM(amount)::numeric,2) AS revenue,
DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS city_rank
FROM transactions_cleaned
GROUP BY merchant_city;

--Who are elite customers?
WITH elite_customers AS (SELECT
client_id,
total_spend,
engagement_score,
wellness_score,
NTILE(10) OVER (ORDER BY total_spend DESC) AS spend_decile
FROM customer_analytics
)

SELECT *
FROM elite_customers
WHERE spend_decile = 1;

--Which customers are inactive?
SELECT
client_id,
days_since_last_transaction,
RANK() OVER (ORDER BY days_since_last_transaction DESC) AS inactivity_rank
FROM customer_analytics;

--Which customers are likely to churn?
SELECT
    client_id,
    churn_risk,
    days_since_last_transaction,
    total_spend
FROM customer_analytics
WHERE churn_risk = 'High Risk'
ORDER BY days_since_last_transaction DESC;

--Which customer segments are most profitable?
SELECT
    spending_tier,
    ROUND(AVG(total_spend)::numeric,2) AS avg_revenue,
    ROUND(AVG(wellness_score)::numeric,2) AS avg_wellness
FROM customer_analytics
GROUP BY spending_tier
ORDER BY avg_revenue DESC;

--Peak transaction hours?
SELECT
hour,COUNT(*) AS transactions,
ROUND(AVG(amount)::numeric,2) AS avg_transaction,
RANK() OVER (ORDER BY COUNT(*) DESC) AS peak_rank
FROM transactions_cleaned
GROUP BY hour;

--Weekend vs weekday spending?
SELECT CASE
WHEN is_weekend = TRUE
THEN 'Weekend'

ELSE 'Weekday'
END AS day_type,
ROUND( SUM(amount)::numeric, 2) AS revenue,
ROUND(AVG(amount)::numeric,2) AS avg_spend
FROM transactions_cleaned
GROUP BY day_type;

--Seasonal behavior?
SELECT month,
ROUND(SUM(amount)::numeric,2) AS monthly_revenue,
LAG(SUM(amount)) OVER (ORDER BY MIN(month_num)) AS previous_month_revenue
FROM transactions_cleaned
GROUP BY month, month_num
ORDER BY month_num;

--Which categories are most popular?
SELECT
    mcc,
    COUNT(*) AS total_transactions
FROM transactions_cleaned
GROUP BY mcc
ORDER BY total_transactions DESC
LIMIT 10;

--Which customers show unstable spending?
SELECT
client_id,
spending_volatility,
PERCENT_RANK() OVER (ORDER BY spending_volatility) AS volatility_percentile
FROM customer_analytics;

--Which transactions show abnormal patterns?
WITH transaction_stats AS ( SELECT AVG(amount) AS avg_amount,
STDDEV(amount) AS std_amount
FROM transactions_cleaned
)

SELECT
    t.client_id,
    t.amount,
    t.merchant_city,
    t.errors
FROM transactions_cleaned t
CROSS JOIN transaction_stats s
WHERE t.amount >
(s.avg_amount + 3 * s.std_amount)
ORDER BY t.amount DESC;

--Which customers have high volatility and high decline frequency?
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
    dt.decline_count,
	RANK() OVER (ORDER BY dt.decline_count DESC, ca.spending_volatility DESC) AS risk_rank
FROM customer_analytics ca
JOIN declined_transactions dt
ON ca.client_id = dt.client_id;
--Which customers deserve premium offers?
SELECT
    client_id,
    total_spend,
    engagement_score,
    wellness_score,

    NTILE(5) OVER (
        ORDER BY engagement_score DESC
    ) AS engagement_quintile

FROM customer_analytics;

--Which categories should receive cashback campaigns?
SELECT
    mcc,
    COUNT(*) AS transactions,
    ROUND(AVG(amount)::numeric,2) AS avg_spend
FROM transactions_cleaned
GROUP BY mcc
ORDER BY transactions DESC
LIMIT 10;

--Which users should receive retention offers?
WITH retention_targets AS (
SELECT
        client_id,
        churn_risk,
        total_spend,
        engagement_score,
ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS value_rank
FROM customer_analytics
WHERE churn_risk = 'High Risk')
SELECT *
FROM retention_targets
WHERE value_rank <= 50;

--Which customers are losing engagement?
SELECT
    client_id,
    days_since_last_transaction,
    engagement_score
FROM customer_analytics
ORDER BY days_since_last_transaction DESC;

--Which users transact most frequently?
SELECT
    client_id,
    transaction_count,

    DENSE_RANK() OVER (
        ORDER BY transaction_count DESC
    ) AS frequency_rank

FROM customer_analytics;

--Which customers are highly loyal?
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

SELECT *
FROM loyalty_scores
ORDER BY loyalty_score DESC;

--Which customers overutilize credit?
SELECT
    client_id,
    total_debt,
    yearly_income,

    ROUND(
        (total_debt / yearly_income)::numeric,
        2
    ) AS debt_to_income_ratio,

    NTILE(5) OVER (
        ORDER BY
        (total_debt / yearly_income) DESC
    ) AS financial_risk_quintile

FROM customer_analytics;
--Which users maintain healthy repayment behavior?
SELECT
    client_id,
    wellness_score,
    spending_volatility,
    total_debt
FROM customer_analytics
WHERE
    wellness_score > 100
    AND spending_volatility < 50
ORDER BY wellness_score DESC;

--Which segments appear financially stressed?
SELECT
    spending_tier,
    ROUND(AVG(total_debt)::numeric,2) AS avg_debt,
    ROUND(AVG(wellness_score)::numeric,2) AS avg_wellness
FROM customer_analytics
GROUP BY spending_tier
ORDER BY avg_debt DESC;

--Which card network drives the highest revenue?
SELECT
    c.card_brand,

    ROUND(
        SUM(t.amount)::numeric,
        2
    ) AS total_revenue,

    COUNT(*) AS total_transactions,

    ROUND(
        AVG(t.amount)::numeric,
        2
    ) AS avg_transaction_value

FROM transactions_cleaned t

JOIN cards_cleaned c
ON t.card_id = c.id

GROUP BY c.card_brand

ORDER BY total_revenue DESC;

--network which has the most loyal customers
SELECT
    c.card_brand,

    ROUND(
        AVG(ca.engagement_score)::numeric,
        2
    ) AS avg_engagement,

    ROUND(
        AVG(ca.transaction_count)::numeric,
        2
    ) AS avg_transactions,

    ROUND(
        AVG(ca.total_spend)::numeric,
        2
    ) AS avg_customer_spend

FROM customer_analytics ca

JOIN cards_cleaned c
ON ca.client_id = c.client_id

GROUP BY c.card_brand

ORDER BY avg_engagement DESC;

--Which card networks show higher risk behavior?
SELECT
    c.card_brand,

    ROUND(
        AVG(ca.spending_volatility)::numeric,
        2
    ) AS avg_volatility,

    COUNT(tc.errors) AS decline_count

FROM customer_analytics ca

JOIN cards_cleaned c
ON ca.client_id = c.client_id

JOIN transactions_cleaned tc
ON ca.client_id = tc.client_id

WHERE tc.errors != 'No Error'

GROUP BY c.card_brand

ORDER BY avg_volatility DESC;



