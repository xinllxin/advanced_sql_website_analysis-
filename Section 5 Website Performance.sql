/*
Finding Top Website Pages: most-viewed website pages, ranked by session volume 
*/
USE mavenfuzzyfactory; 

SELECT pageview_url, COUNT(DISTINCT website_pageview_id) AS sessions
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY pageview_url
ORDER BY sessions DESC;

-- /home page as the top page 

/*
Finding Top Entry Pages: pull all entry pages and rank them on the entry volume 
*/
CREATE TEMPORARY TABLE landing_page
SELECT MIN(website_pageview_id) AS landing_pageview_id
FROM website_pageviews
WHERE created_at < '2012-06-12'
GROUP BY website_session_id;

SELECT 
    website_pageviews.pageview_url AS landing_page_url,
    COUNT(DISTINCT website_pageviews.website_session_id) AS sessions_hitting_page
FROM 
    landing_page
        LEFT JOIN
    website_pageviews ON landing_page.landing_pageview_id = website_pageviews.website_pageview_id
GROUP BY website_pageviews.pageview_url; 


/*
Analyzing Bounce Rates of landing page 

step 1: find the first website_pageview_id for relevant sessions 
	- website_session_id, min_pageview_id 
step 2: identify the landing page of each session 
	- website_session_id, landing_page_url 
step 3: counting pageviews for each session, to identify bounces
	- website_session_id, landing_page, count_of_pages_viewed 
step 4: summarizing total sessions and bounced sessions by landing page 
	- landing_page, total sessions, bounced sessions, bounce rate 
*/ 

CREATE TEMPORARY TABLE first_page
SELECT 
    website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS first_pv
FROM
    website_pageviews
	INNER JOIN website_sessions 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
        AND website_sessions.created_at < '2012-06-14' 
GROUP BY website_sessions.website_session_id; 

CREATE TEMPORARY TABLE session_first_page
SELECT 
    first_page.website_session_id, 
    website_pageviews.pageview_url AS landing_page
FROM
    first_page
	LEFT JOIN website_pageviews
    ON first_page.first_pv = website_pageviews.website_pageview_id;

CREATE TEMPORARY TABLE bounced_sessions
SELECT 
    session_first_page.website_session_id,
    session_first_page.landing_page,
    COUNT(DISTINCT website_pageviews.website_pageview_id) AS count_of_pages_viewed
FROM
    session_first_page
	LEFT JOIN website_pageviews 
    ON session_first_page.website_session_id = website_pageviews.website_session_id
GROUP BY session_first_page.website_session_id , landing_page
HAVING count_of_pages_viewed = 1;


SELECT 
    session_first_page.landing_page,
    COUNT(DISTINCT session_first_page.website_session_id) AS total_session,
    COUNT(DISTINCT bounced_sessions.website_session_id) AS bounced_session,
	COUNT(DISTINCT bounced_sessions.website_session_id) / COUNT(DISTINCT session_first_page.website_session_id) AS bounce_rate
FROM
    session_first_page
	LEFT JOIN bounced_sessions 
    ON session_first_page.website_session_id = bounced_sessions.website_session_id;

/*
Analyzing Test Page 
new test page /lander-1
pull bounce rate for the two groups 
just look at the time period where /lander-1 was getting traffic 
*/

-- finding the first instance of /lander-1 for setting analysis timeframe
SELECT 
    MIN(created_at) AS first_created_at,
    MIN(website_pageview_id) AS first_pageview_id
FROM
    website_pageviews
WHERE
    created_at IS NOT NULL
	AND pageview_url = '/lander-1'; 
-- output: 2012-06-19 01:35:54	23504

CREATE TEMPORARY TABLE landing_page 
SELECT 
    website_sessions.website_session_id, 
    MIN(website_pageview_id) AS min_pageview_id,
    pageview_url AS landing_page 
FROM
    website_pageviews
    INNER JOIN website_sessions
    ON website_pageviews.website_session_id = website_sessions.website_session_id 
    AND website_pageviews.created_at BETWEEN '2012-06-19 01:35:54' AND '2012-07-28'
    AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY website_sessions.website_session_id;

CREATE TEMPORARY TABLE ab_session_w_first_page
SELECT 
	website_pageviews.website_session_id,
	landing_page
FROM landing_page 
	INNER JOIN website_pageviews
    ON landing_page.min_pageview_id = website_pageviews.website_pageview_id 
WHERE website_pageviews.pageview_url IN ('/home', '/lander-1');

CREATE TEMPORARY TABLE ab_bounced_sessions
SELECT 
	ab_session_w_first_page.website_session_id, 
	COUNT(DISTINCT website_pageviews.website_pageview_id)
FROM ab_session_w_first_page 
	LEFT JOIN website_pageviews 
    ON ab_session_w_first_page.website_session_id = website_pageviews.website_session_id 
GROUP BY 
	ab_session_w_first_page.website_session_id,
	ab_session_w_first_page.landing_page
HAVING COUNT(DISTINCT website_pageviews.website_pageview_id) = 1;
;

SELECT 
    landing_page,
    COUNT(DISTINCT ab_session_w_first_page.website_session_id) AS total_sessions,
    COUNT(DISTINCT ab_bounced_sessions.website_session_id)AS bounce_sessions,
    COUNT(DISTINCT ab_bounced_sessions.website_session_id) / COUNT(DISTINCT ab_session_w_first_page.website_session_id) AS bounce_rate
FROM
    ab_session_w_first_page
	LEFT JOIN ab_bounced_sessions 
    ON ab_session_w_first_page.website_session_id = ab_bounced_sessions.website_session_id
GROUP BY landing_page;

/*
Landing Page Trend Analysis
pull the volumn of paid search nonbrand traffic landing on /home and /lander-1, trended weekly since June 1
*/

CREATE TEMPORARY TABLE first_pv
SELECT 
	website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS first_pv_id 
FROM website_pageviews 
	INNER JOIN website_sessions 
    ON website_pageviews.website_session_id = website_sessions.website_session_id 
    AND website_sessions.created_at BETWEEN '2012-06-01' AND '2012-08-31'
	AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY website_pageviews.website_session_id;

SELECT * FROM first_pv;

CREATE TEMPORARY TABLE sessions_landing
SELECT 
	first_pv.website_session_id,
    website_pageviews.pageview_url AS landing_page,
    website_pageviews.created_at
FROM first_pv 
	INNER JOIN website_pageviews
    ON first_pv.first_pv_id = website_pageviews.website_pageview_id 
WHERE website_pageviews.pageview_url IN ('/home','/lander-1');

SELECT * 
FROM sessions_landing;

SELECT website_pageviews.website_session_id , COUNT(DISTINCT website_pageviews.website_pageview_id) 
FROM sessions_landing
	LEFT JOIN website_pageviews 
	ON website_pageviews.website_session_id = website_pageviews.website_session_id 
GROUP BY website_pageviews.website_session_id, landing_page 
HAVING COUNT(DISTINCT website_pageviews.website_pageview_id) = 1;

SELECT MIN(created_at), COUNT(website_session_id)
FROM sessions_landing
GROUP BY WEEK(created_at);  

--  landing page and page view counts per session
-- CREATE temporary table sessions_landing_page_with_count
SELECT 
    website_sessions.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS landing_pv_id,
    COUNT(website_pageview_id) AS count_pv
FROM
    website_sessions
	LEFT JOIN website_pageviews 
    ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_campaign = 'nonbrand'
	AND website_sessions.utm_source = 'gsearch'
	AND website_pageviews.pageview_url IN ('/home' , '/lander-1')
	AND website_pageviews.created_at BETWEEN '2012-06-01' AND '2012-08-31'
GROUP BY 
	website_sessions.website_session_id;













