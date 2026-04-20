WITH users_parsed AS (
    /* КРОК 1. Підготовка користувачів */
    SELECT 
        u.user_id,
        u.signup_datetime, 
        u.promo_signup_flag,
        CASE 
            WHEN LENGTH(SPLIT_PART(REPLACE(REPLACE(SPLIT_PART(TRIM(u.signup_datetime), ' ', 1), '/', '-'), '.', '-'), '-', 3)) = 4
                THEN TO_DATE(REPLACE(REPLACE(SPLIT_PART(TRIM(u.signup_datetime), ' ', 1), '/', '-'), '.', '-'), 'DD-MM-YYYY')
            ELSE TO_DATE(REPLACE(REPLACE(SPLIT_PART(TRIM(u.signup_datetime), ' ', 1), '/', '-'), '.', '-'), 'DD-MM-YY')
        END AS signup_ts
    FROM cohort_users_raw u
),

events_parsed AS (
    /* КРОК 2. Підготовка подій */
    SELECT 
        e.user_id,
        e.event_type,
        e.event_datetime,
        CASE 
            WHEN LENGTH(SPLIT_PART(REPLACE(REPLACE(SPLIT_PART(TRIM(e.event_datetime), ' ', 1), '/', '-'), '.', '-'), '-', 3)) = 4
                THEN TO_DATE(REPLACE(REPLACE(SPLIT_PART(TRIM(e.event_datetime), ' ', 1), '/', '-'), '.', '-'), 'DD-MM-YYYY')
            ELSE TO_DATE(REPLACE(REPLACE(SPLIT_PART(TRIM(e.event_datetime), ' ', 1), '/', '-'), '.', '-'), 'DD-MM-YY')
        END AS event_ts
    FROM cohort_events_raw e
),

user_activity AS (
    /* КРОК 3. Об'єднання та розрахунок зсуву */
    SELECT 
        u.user_id,
        u.promo_signup_flag,
        -- Використовуємо ::DATE для відсікання часу 00:00:00
        DATE_TRUNC('month', u.signup_ts)::DATE AS cohort_month,
        DATE_TRUNC('month', e.event_ts)::DATE AS activity_month,
        /* Розрахунок стажу: (Роки * 12) + Місяці */
        (EXTRACT(YEAR FROM AGE(DATE_TRUNC('month', e.event_ts), DATE_TRUNC('month', u.signup_ts))) * 12 +
         EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', e.event_ts), DATE_TRUNC('month', u.signup_ts)))) AS month_offset
    FROM users_parsed u
    JOIN events_parsed e ON u.user_id = e.user_id
    WHERE 
        u.signup_ts IS NOT NULL 
        AND e.event_ts IS NOT NULL
        AND e.event_type <> 'test_event'
)

/* КРОК 4. Фінальна агрегація */
SELECT 
    promo_signup_flag,
    cohort_month,
    month_offset,
    COUNT(DISTINCT user_id) AS users_total
FROM user_activity
WHERE 
    /* аналізуємо 6 когорт в межах першого півріччя */
    cohort_month BETWEEN '2025-01-01' AND '2025-06-01'
    AND activity_month BETWEEN '2025-01-01' AND '2025-06-01'
GROUP BY 
    promo_signup_flag,
    cohort_month,
    month_offset
ORDER BY 
    promo_signup_flag,
    cohort_month,
    month_offset;