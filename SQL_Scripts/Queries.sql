/*
===============================================================================
Project: Indian Personal Finance & Spending Habits Analysis
Description: End-to-end data analysis of consumer spending, income distribution, 
             and savings potential across Indian demographics.
Database: PostgreSQL
Author: Somnath Maity
===============================================================================
*/

-------------------------------------------------------------------------------
-- 1. DATA DEFINITION & SCHEMA SETUP
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS p_finance;

CREATE TABLE p_finance (
    income DECIMAL(12, 2),
    age INT,
    dependents INT2,
    occupation VARCHAR(20),
    city_tier VARCHAR(10),
    rent DECIMAL(12, 2),
    loan_repayment DECIMAL(12, 2),
    insurance DECIMAL(12, 2),
    groceries DECIMAL(12, 2),
    transport DECIMAL(12, 2),
    eating_out DECIMAL(12, 2),
    entertainment DECIMAL(12, 2),
    utilities DECIMAL(12, 2),
    healthcare DECIMAL(12, 2),
    education DECIMAL(12, 2),
    miscellaneous DECIMAL(12, 2),
    desired_savings_percentage DECIMAL(5, 2),
    desired_savings DECIMAL(12, 2),
    disposable_income DECIMAL(12, 2),
    potential_savings_groceries DECIMAL(12, 2),
    potential_savings_transport DECIMAL(12, 2),
    potential_savings_eating_out DECIMAL(12, 2),
    potential_savings_entertainment DECIMAL(12, 2),
    potential_savings_utilities DECIMAL(12, 2),
    potential_savings_healthcare DECIMAL(12, 2),
    potential_savings_education DECIMAL(12, 2),
    potential_savings_miscellaneous DECIMAL(12, 2)
);

-- Basic Data Audit
SELECT * FROM rounded_p_finance LIMIT 10;

-------------------------------------------------------------------------------
-- 2. INCOME DISTRIBUTION ANALYSIS
-------------------------------------------------------------------------------

-- Occupation-wise income breakdown by City Tier
SELECT 
    occupation,
    SUM(CASE WHEN city_tier = 'Tier_1' THEN income ELSE 0 END) AS tier_1_income,
    SUM(CASE WHEN city_tier = 'Tier_2' THEN income ELSE 0 END) AS tier_2_income,
    SUM(CASE WHEN city_tier = 'Tier_3' THEN income ELSE 0 END) AS tier_3_income,
    SUM(income) AS total_income
FROM rounded_p_finance
GROUP BY occupation
ORDER BY total_income DESC;

-- Average income metrics identifying highest earning segments
WITH income_ranks AS (
    SELECT 
        city_tier,
        ROUND(AVG(CASE WHEN occupation = 'Professional' THEN income ELSE 0 END), 0) AS professional_avg,
        ROUND(AVG(CASE WHEN occupation = 'Student' THEN income ELSE 0 END), 0) AS student_avg,
        ROUND(AVG(CASE WHEN occupation = 'Self_Employed' THEN income ELSE 0 END), 0) AS self_employed_avg,
        ROUND(AVG(CASE WHEN occupation = 'Retired' THEN income ELSE 0 END), 0) AS retired_avg,
        ROUND(AVG(income), 0) AS overall_avg
    FROM rounded_p_finance
    GROUP BY city_tier
)
SELECT *,
    CASE 
        WHEN professional_avg >= GREATEST(student_avg, self_employed_avg, retired_avg) THEN 'Professional'
        WHEN student_avg >= GREATEST(professional_avg, self_employed_avg, retired_avg) THEN 'Student'
        WHEN self_employed_avg >= GREATEST(professional_avg, student_avg, retired_avg) THEN 'Self-Employed'
        ELSE 'Retired'
    END AS top_earning_segment
FROM income_ranks;

-------------------------------------------------------------------------------
-- 3. SPENDING PATTERNS & DEMOGRAPHICS
-------------------------------------------------------------------------------

-- Expense analysis by 5-year Age Groups
WITH age_spending AS (
    SELECT 
        FLOOR(age/5)*5 || '-' || (FLOOR(age/5)*5+5) AS age_group,
        ROUND(AVG(rent), 0) AS avg_rent,
        ROUND(AVG(groceries), 0) AS avg_groceries,
        ROUND(AVG(transport), 0) AS avg_transport,
        ROUND(AVG(total_expenses), 0) AS avg_total_expenses
    FROM rounded_p_finance
    GROUP BY age_group
)
SELECT *,
    DENSE_RANK() OVER (ORDER BY avg_total_expenses DESC) AS expense_rank
FROM age_spending;

-- Impact of Dependents on Household Expenses
SELECT 
    dependents,
    ROUND(AVG(groceries), 0) AS avg_groceries,
    ROUND(AVG(total_expenses), 0) AS avg_total_exp,
    ROUND(
        (AVG(total_expenses) - LAG(AVG(total_expenses)) OVER (ORDER BY dependents)) * 100.0 /
        NULLIF(LAG(AVG(total_expenses)) OVER (ORDER BY dependents), 0), 2
    ) AS percentage_increase
FROM rounded_p_finance
GROUP BY dependents
ORDER BY dependents;

-------------------------------------------------------------------------------
-- 4. SAVINGS AUDIT & POTENTIAL OPTIMIZATION
-------------------------------------------------------------------------------

-- Actual vs Desired Savings Performance
SELECT 
    city_tier,
    occupation,
    ROUND(AVG(disposable_income), 0) AS actual_savings,
    ROUND(AVG(desired_savings), 0) AS targeted_savings,
    ROUND(AVG(((income - total_expenses) * 100.0) / NULLIF(income, 0)), 2) AS saving_percentage,
    CASE 
        WHEN AVG(disposable_income) >= AVG(desired_savings) THEN 'Goal Met' 
        ELSE 'Deficit' 
    END AS goal_status
FROM rounded_p_finance
GROUP BY city_tier, occupation
ORDER BY saving_percentage DESC;

-- Identifying Potential Savings Leakages
SELECT
    city_tier,
    AVG((potential_savings_eating_out / NULLIF(total_expenses, 0)) * 100) AS potential_dining_savings,
    AVG((potential_savings_entertainment / NULLIF(total_expenses, 0)) * 100) AS potential_ent_savings,
    ROUND(AVG(
        100.0 * (potential_savings_groceries + potential_savings_transport + 
        potential_savings_eating_out + potential_savings_entertainment + 
        potential_savings_utilities + potential_savings_healthcare + 
        potential_savings_education + potential_savings_miscellaneous) / 
        NULLIF(total_expenses, 0)
    ), 2) AS overall_potential_savings_pct
FROM rounded_p_finance
GROUP BY city_tier
ORDER BY overall_potential_savings_pct DESC;
