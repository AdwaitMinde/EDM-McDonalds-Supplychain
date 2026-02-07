'Query 1 : This query provides a ranked analysis of menu item feedback for each franchise, based on
customer ratings. It calculates the average feedback rating and total feedback count for each menu
item at a franchise, ranks the items within each franchise by their ratings, and filters out items with no
feedback. The results help franchises identify their top-rated menu items, assess customer
satisfaction, and make informed decisions about menu optimization, promotions, or potential
adjustments to poorly rated items.'
WITH MenuFeedback AS (
SELECT
F.franchise_id,
MI.mItemName,
AVG(CF.rating) AS avg_feedback_rating,
COUNT(CF.feedbackID) AS total_feedbacks
FROM
MENU_ITEMS MI
LEFT JOIN
LISTS L ON MI.mItemID = L.mitemID
LEFT JOIN
CUSTOMER_ORDERS CO ON L.order_id = CO.order_id
LEFT JOIN
FEEDBACK_INFO FI ON CO.order_id = FI.order_id
LEFT JOIN
CUSTOMER_FEEDBACKS CF ON FI.feedbackID = CF.feedbackID
LEFT JOIN
FRANCHISE F ON CO.franchise_id = F.franchise_id
GROUP BY
F.franchise_id, MI.mItemName
HAVING
F.franchise_id IS NOT NULL AND MI.mItemName IS NOT NULL
)
SELECT
franchise_id,
mItemName,
avg_feedback_rating,
total_feedbacks,
ROW_NUMBER() OVER (PARTITION BY franchise_id ORDER BY
avg_feedback_rating DESC) AS feedback_rank
FROM
MenuFeedback
WHERE
total_feedbacks > 0
ORDER BY
franchise_id,feedback_rank;

'Query 2: This query evaluates yearly revenue growth for each franchise by comparing current and previous
year revenues. It calculates the revenue difference and growth percentage year-over-year. The results enable
franchises to track financial performance trends, identify periods of significant growth or decline, and make
data-driven decisions for strategic planning, such as investing in high-performing franchises or addressing
issues in underperforming ones.'
WITH yearly_revenue AS (
SELECT
franchise_id,
EXTRACT(YEAR FROM orderdate) AS year,
SUM(totalamount) AS total_revenue
FROM
CUSTOMER_ORDERS
GROUP BY
franchise_id, EXTRACT(YEAR FROM orderdate)
),
growth_calculation AS (
SELECT
franchise_id,
year,
total_revenue,
LAG(total_revenue) OVER (PARTITION BY franchise_id ORDER BY
year) AS previous_year_revenue
FROM
yearly_revenue
)
SELECT
franchise_id,
year,
total_revenue,
COALESCE(previous_year_revenue, 0) AS previous_year_revenue,
(total_revenue - COALESCE(previous_year_revenue, 0)) AS growth,
CASE
WHEN previous_year_revenue IS NULL OR previous_year_revenue
= 0 THEN '0.00%'
ELSE TO_CHAR(((total_revenue - previous_year_revenue) /
previous_year_revenue) * 100, 'FM999990.00') || '%'
END AS growth_percentage
FROM
growth_calculation;

'Query 3: This query analyzes and ranks franchise performance based on two key metrics: the duration of
franchise agreements and the total inventory managed. It provides insights into franchise stability (measured
by agreement duration) and operational scale (measured by inventory). By ranking franchises on these metrics,
businesses can identify long-term stable franchises, assess inventory management capabilities, and prioritize
support or investments in franchises with high operational demands or significant tenure. This aids in strategic
decision-making for resource allocation and franchise relationship management.'
WITH AgreementDurations AS (
SELECT
F.franchise_id,
FO.lname AS owner_last_name,
FO.fname AS owner_first_name,
F.franchise_since,
FA.term_start_date,
FA.term_end_date,
ROUND((FA.term_end_date - FA.term_start_date) / 365, 2) AS
agreement_years
FROM
FRANCHISE_AGREEMENT FA
JOIN
FRANCHISE F ON FA.franchise_id = F.franchise_id
JOIN
FRANCHISEOWNERS FO ON F.owner_id = FO.owner_id
),
InventoryCounts AS (
SELECT
FI.franchise_id,
COUNT(FI.inv_Id) AS total_inventory
FROM
FRANCHISE_INVENTORY FI
GROUP BY
FI.franchise_id
),
RankedFranchises AS (
SELECT
AD.franchise_id,
AD.owner_last_name,
AD.owner_first_name,
AD.agreement_years,
IC.total_inventory,
RANK() OVER (ORDER BY AD.agreement_years DESC,
AD.franchise_ID ASC ) AS agreement_rank,
RANK() OVER (ORDER BY IC.total_inventory DESC,
AD.franchise_ID ASC) AS inventory_rank
FROM
AgreementDurations AD
LEFT JOIN
InventoryCounts IC ON AD.franchise_id = IC.franchise_id
)
SELECT
franchise_id,
owner_last_name || ', ' || owner_first_name AS franchise_owner,
agreement_years,
total_inventory,
agreement_rank,
inventory_rank
FROM
RankedFranchises
ORDER BY
inventory_rank, agreement_rank;

'Query 4: This query analyzes employee shift patterns across franchises by categorizing shifts as "Short,"
"Regular," or "Long" based on their durations. It calculates the total shifts, average shift duration, and total
hours worked for each franchise and shift type, with results also including aggregated data across all franchises
due to the CUBE operation. The business application is to monitor workforce utilization, identify labor trends,
optimize staffing schedules, and ensure compliance with labor regulations while maintaining operational
efficiency.'
SELECT
F.franchise_id,
CASE
WHEN ES.shiftDuration < 4 THEN 'Short Shift'
WHEN ES.shiftDuration BETWEEN 4 AND 8 THEN 'Regular Shift'
ELSE 'Long Shift'
END AS shift_type,
COUNT(*) AS total_shifts,
AVG(ES.shiftDuration) AS avg_shift_duration,
SUM(ES.shiftDuration) AS total_shift_hours
FROM FRANCHISE F
JOIN EMPLOYEES E ON F.franchise_id = E.franchise_ID
JOIN ESHIFTS_DETAILS ES ON E.employee_ID = ES.Employee_ID
GROUP BY CUBE (F.franchise_id,
CASE
WHEN ES.shiftDuration < 4 THEN 'Short Shift'
WHEN ES.shiftDuration BETWEEN 4 AND 8 THEN 'Regular Shift'
ELSE 'Long Shift'
END);

'Query 5: This query calculates the profitability score for each franchise by comparing its seating capacity to
the average employee cost (base salary plus bonus). The profitability score helps assess how efficiently each
franchise utilizes its workforce relative to its size, providing insights into labor cost management and
operational efficiency. This analysis can guide decision-making for resource allocation, staffing strategies, and
identifying franchises that are performing well or need improvement in cost management.'
WITH FranchiseProfit AS (
SELECT f.franchise_id, f.city, f.seating_capacity,
AVG(s.base_salary + COALESCE(s.bonus, 0)) AS
avg_employee_cost
FROM FRANCHISE f
JOIN SALARY_DETAILS s ON f.franchise_id = s.franchise_id
GROUP BY f.franchise_id, f.city, f.seating_capacity
)
SELECT franchise_id, city, seating_capacity, avg_employee_cost,
(round((seating_capacity / avg_employee_cost),5)) AS
profitability_score
FROM FranchiseProfit
ORDER BY profitability_score DESC;

'Query 6: This query evaluates the performance of franchise owners by calculating the total revenue generated
by their franchises. It ranks owners based on their total revenue, providing a clear picture of which owners are
performing best. The business application is to identify top-performing franchise owners, reward successful
ones, and assess potential areas for improvement or support for lower-performing owners. This information
helps in making decisions related to incentives, resource allocation, and franchise growth strategies.'
WITH FranchisePerformance AS (
SELECT
F.franchise_id,
F.owner_id,
SUM(O.totalamount) AS total_revenue
FROM
FRANCHISE F
JOIN
CUSTOMER_ORDERS O ON F.franchise_id = O.franchise_id
GROUP BY
F.franchise_id, F.owner_id
),
OwnerPerformance AS (
SELECT
FP.owner_id,
FO.fname || ' ' || FO.lname AS owner_name, -- Concatenation
fixed for Oracle SQL
SUM(FP.total_revenue) AS total_owner_revenue,
RANK() OVER (ORDER BY SUM(FP.total_revenue) DESC) AS
owner_rank
FROM
FranchisePerformance FP
JOIN
FRANCHISEOWNERS FO ON FP.owner_id = FO.owner_id
GROUP BY
FP.owner_id, FO.fname, FO.lname
)
SELECT
owner_id,
owner_name,
total_owner_revenue,
owner_rank
FROM
OwnerPerformance
;

'Query 7: This query calculates each franchises revenue share as a percentage of the total company revenue.
By summing up the revenue generated by each franchise and comparing it to the overall total revenue, it helps
assess the contribution of individual franchises to the business. The business application is to identify highperforming
franchises, track revenue distribution across locations, and inform strategic decisions regarding
resource allocation, support for underperforming franchises, and potential expansion opportunities.'
WITH TotalRevenue AS (
SELECT
SUM(CO.totalamount) AS total_revenue
FROM
CUSTOMER_ORDERS CO
)
SELECT
F.franchise_id,
F.city,
SUM(CO.totalamount) AS franchise_revenue,
ROUND((SUM(CO.totalamount) * 100.0 / (SELECT total_revenue FROM
TotalRevenue)), 2) AS revenue_share_percentage
FROM
CUSTOMER_ORDERS CO
INNER JOIN
FRANCHISE F ON CO.franchise_id = F.franchise_id
GROUP BY
F.franchise_id, F.city
ORDER BY
franchise_revenue DESC;
'Query 8: This query calculates the staff-to-seating ratio for each franchise, which compares the number of
employees to the seating capacity of the franchise. The business application is to assess whether a franchise is
overstaffed or understaffed relative to its size, helping optimize labor costs and staffing efficiency. It can guide
decisions on workforce adjustments, improve operational management, and ensure better customer service by
aligning staff levels with franchise needs.'
WITH FranchiseStaffing AS (
SELECT f.franchise_id, f.city, f.seating_capacity,
COUNT(e.employee_id) AS staff_count
FROM FRANCHISE f
JOIN EMPLOYEES e ON f.franchise_id = e.franchise_id
GROUP BY f.franchise_id, f.city, f.seating_capacity
)
SELECT franchise_id, city, seating_capacity, staff_count,
(staff_count / seating_capacity) AS staff_to_seating_ratio
FROM FranchiseStaffing
ORDER BY staff_to_seating_ratio DESC;

'Query 9: This query calculates the revenue per employee for each franchise by dividing total revenue by the
number of employees. The business application is to measure labor productivity and efficiency across
franchises. By identifying franchises with higher revenue per employee, the business can recognize topperforming
locations, optimize staffing levels, and assess where improvements in employee performance or
resource allocation might be necessary. This metric helps in making decisions regarding staffing, operational
improvements, and resource distribution.'
WITH FranchiseRevenue AS (
SELECT
CO.franchise_id,
SUM(CO.totalamount) AS total_revenue
FROM
CUSTOMER_ORDERS CO
GROUP BY
CO.franchise_id
),
FranchiseStaff AS (
SELECT
F.franchise_id,
COUNT(E.employee_id) AS num_employees
FROM
FRANCHISE F
INNER JOIN
EMPLOYEES E ON F.franchise_id = E.franchise_id
GROUP BY
F.franchise_id
)
SELECT
R.franchise_id,
F.city,
R.total_revenue,
S.num_employees,
ROUND(R.total_revenue / S.num_employees, 2) AS
revenue_per_employee
FROM
FranchiseRevenue R
INNER JOIN
FranchiseStaff S ON R.franchise_id = S.franchise_id
INNER JOIN
FRANCHISE F ON R.franchise_id = F.franchise_id
WHERE
S.num_employees > 0
ORDER BY
revenue_per_employee DESC;
Query 10: This query evaluates franchise performance by analyzing material purchases relative to seating
capacity over the last six months. It calculates the ratio of purchases to seating capacity (purchases_per_seat)

'for each franchise and compares it to the average across all franchises. Based on this comparison, it categorizes
franchises as either "Needs expansion" (if their ratio significantly exceeds the average) or "Adequate." This
analysis helps identify high-performing locations that may require capacity upgrades to meet demand and
optimize resource allocation.'
WITH franchise_purchases AS (
SELECT dd.Franchise_ID, SUM(po.PurcQty) AS total_purchases
FROM DELIVERY_DETAILS dd
JOIN SHIPMENT_DETAILS sd ON dd.trackingID = sd.trackingID
JOIN PURCHASE_ORDER po ON sd.Material_Id = po.Material_Id
WHERE dd.DeliveryDate >= ADD_MONTHS(SYSDATE, -6)
GROUP BY dd.Franchise_ID
)
SELECT f.franchise_id, f.city, f.seating_capacity,
fp.total_purchases,
ROUND((fp.total_purchases / f.seating_capacity),2) AS
purchases_per_seat,
ROUND(AVG(fp.total_purchases / f.seating_capacity) OVER (),
2) AS avg_purchases_per_seat,
CASE
WHEN (fp.total_purchases / f.seating_capacity) >
(AVG(fp.total_purchases / f.seating_capacity) OVER
() * 1.5)
THEN 'Needs expansion'
ELSE 'Adequate'
END AS capacity_status
FROM FRANCHISE f
JOIN franchise_purchases fp ON f.franchise_id = fp.Franchise_ID
ORDER BY purchases_per_seat DESC;