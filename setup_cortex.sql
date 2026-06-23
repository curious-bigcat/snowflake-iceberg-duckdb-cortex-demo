-- ============================================================
-- CORTEX AI + MCP SERVER SETUP
-- ============================================================
-- Run AFTER setup_snowflake.sql
-- Creates: Semantic View, Search Service, Agent, MCP Server, OAuth
-- ============================================================

USE DATABASE ICEBERG_DUCKDB_DEMO;
USE SCHEMA PUBLIC;

-- ============================================================
-- STEP 1: Create PRODUCT_REVIEWS table (for Cortex Search)
-- ============================================================
CREATE OR REPLACE TABLE PRODUCT_REVIEWS (
    review_id INT,
    product_id INT,
    customer_id INT,
    rating INT,
    review_text STRING,
    review_date DATE
);

INSERT INTO PRODUCT_REVIEWS VALUES
(1, 101, 1, 5, 'This wireless mouse is incredibly smooth and responsive. The ergonomic design fits my hand perfectly. Battery life is amazing - lasted 3 months on a single charge.', '2024-06-10'),
(2, 101, 3, 4, 'Good mouse overall. Comfortable grip and accurate tracking. Only downside is the scroll wheel feels a bit cheap. Still recommend it for everyday use.', '2024-06-15'),
(3, 101, 5, 3, 'Decent wireless mouse but the Bluetooth connection drops occasionally when I move too far from my laptop. Works fine within 3 feet though.', '2024-06-20'),
(4, 102, 2, 5, 'Best mechanical keyboard I have ever owned! The tactile switches are so satisfying to type on. Build quality is premium - solid aluminum frame with no flex.', '2024-06-12'),
(5, 102, 4, 5, 'Absolutely love this keyboard. The RGB lighting is beautiful and the key switches are perfectly weighted. Makes coding a pleasure.', '2024-06-18'),
(6, 102, 1, 4, 'Great mechanical keyboard with excellent build quality. The only issue is it is a bit loud for office use. Perfect for home office though.', '2024-06-25'),
(7, 103, 3, 5, 'This USB-C hub is a lifesaver! Connects my monitor, keyboard, mouse, and charges my laptop all through one cable. Rock solid connection.', '2024-06-08'),
(8, 103, 2, 4, 'Solid hub that works well with my MacBook. All ports detected immediately. Gets slightly warm during heavy use but nothing concerning.', '2024-06-14'),
(9, 103, 5, 2, 'Hub stopped working after 2 weeks. The HDMI port became intermittent. Had to get a replacement. Second unit works fine so far.', '2024-06-22'),
(10, 104, 4, 5, 'This monitor stand completely transformed my desk setup. Adjustable height is perfect and the cable management underneath keeps everything tidy.', '2024-06-09'),
(11, 104, 1, 4, 'Sturdy monitor stand that holds my 27-inch display without any wobble. Assembly was straightforward. The drawer underneath is handy for small items.', '2024-06-16'),
(12, 104, 3, 4, 'Good quality stand. Elevated my monitor to the right height which really helped with neck pain. Looks sleek on my desk too.', '2024-06-23'),
(13, 105, 2, 5, 'Perfect desk lamp for late night work. The adjustable color temperature from warm to cool white is great. Touch controls are intuitive.', '2024-06-11'),
(14, 105, 5, 4, 'Nice lamp with good brightness range. The USB charging port on the base is a thoughtful addition. Slim design does not take much desk space.', '2024-06-17'),
(15, 105, 4, 3, 'Lamp works fine but the touch sensor is too sensitive. Sometimes turns on/off when I accidentally brush against it. Light quality is good though.', '2024-06-24'),
(16, 101, 4, 5, 'Switched from a wired mouse to this and never looking back. Zero lag, precision tracking, and the silent clicks are perfect for meetings.', '2024-07-01'),
(17, 102, 3, 4, 'Fantastic keyboard for programming. The dedicated macro keys save me so much time. Hot-swappable switches are a nice bonus for customization.', '2024-07-05'),
(18, 103, 1, 5, 'Essential accessory for anyone with a USB-C laptop. 4K display output is crisp and the 100W passthrough charging means my laptop stays powered all day.', '2024-07-08'),
(19, 104, 2, 3, 'The stand is functional but the assembly instructions were confusing. Took me 30 minutes to figure out. Once built its solid and stable.', '2024-07-12'),
(20, 105, 1, 5, 'Love this lamp! The auto-dimming feature that adjusts to ambient light is brilliant. My eyes feel so much less strained during evening work sessions.', '2024-07-15');

-- ============================================================
-- STEP 2: Create Semantic View (Cortex Analyst)
-- ============================================================
CREATE OR REPLACE SEMANTIC VIEW ECOMMERCE_ANALYTICS_SV

  TABLES (
    customers AS ICEBERG_DUCKDB_DEMO.PUBLIC.CUSTOMERS
      PRIMARY KEY (customer_id)
      COMMENT = 'Customer master data',
    products AS ICEBERG_DUCKDB_DEMO.PUBLIC.PRODUCTS
      PRIMARY KEY (product_id)
      COMMENT = 'Product catalog',
    orders AS ICEBERG_DUCKDB_DEMO.PUBLIC.ORDERS
      PRIMARY KEY (order_id)
      COMMENT = 'Sales orders'
  )

  RELATIONSHIPS (
    orders_to_customers AS orders (customer_id) REFERENCES customers,
    orders_to_products AS orders (product_id) REFERENCES products
  )

  FACTS (
    orders.quantity_sold AS quantity,
    orders.order_revenue AS total_amount,
    products.unit_price AS price
  )

  DIMENSIONS (
    customers.customer_name AS name WITH SYNONYMS = ('name', 'buyer') COMMENT = 'Full name of the customer',
    customers.customer_city AS city WITH SYNONYMS = ('location', 'customer city') COMMENT = 'City where customer is located',
    customers.customer_email AS email COMMENT = 'Customer email address',
    customers.signup_date AS signup_date COMMENT = 'Date customer registered',
    products.product_name AS product_name WITH SYNONYMS = ('product', 'item') COMMENT = 'Name of the product',
    products.product_category AS category WITH SYNONYMS = ('product type', 'category') COMMENT = 'Product category',
    orders.order_date AS order_date WITH SYNONYMS = ('purchase date', 'date') COMMENT = 'Date the order was placed'
  )

  METRICS (
    orders.total_revenue AS SUM(orders.order_revenue) WITH SYNONYMS = ('total sales', 'gross revenue') COMMENT = 'Total revenue in USD',
    orders.order_count AS COUNT(orders.order_revenue) WITH SYNONYMS = ('number of orders') COMMENT = 'Total number of orders',
    orders.avg_order_value AS AVG(orders.order_revenue) WITH SYNONYMS = ('AOV') COMMENT = 'Average order value in USD',
    orders.total_quantity AS SUM(orders.quantity_sold) COMMENT = 'Total items sold',
    customers.customer_count AS COUNT(customer_id) COMMENT = 'Number of customers'
  )

  COMMENT = 'E-commerce analytics for Iceberg DuckDB demo';

-- ============================================================
-- STEP 3: Create Cortex Search Service
-- ============================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE PRODUCT_REVIEWS_SEARCH
  ON review_text
  ATTRIBUTES rating, product_id
  WAREHOUSE = 'DEMO_WH'
  TARGET_LAG = '1 day'
  AS (
    SELECT r.review_text, r.rating, r.product_id, r.customer_id, r.review_date,
           p.product_name, p.category
    FROM PRODUCT_REVIEWS r
    JOIN PRODUCTS p ON r.product_id = p.product_id
  );

-- ============================================================
-- STEP 4: Create Cortex Agent
-- ============================================================
CREATE OR REPLACE AGENT ECOMMERCE_AGENT
  COMMENT = 'E-commerce AI assistant: analytics + review search over Iceberg tables'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-3-5-sonnet

  instructions:
    response: "You are an e-commerce analytics assistant. Provide concise, data-driven answers. Always include the actual numbers in your response."
    orchestration: "Use EcommerceAnalytics for revenue, orders, customer, and product questions. Use ReviewSearch for product feedback and review questions."
    sample_questions:
      - question: "What is the total revenue?"
      - question: "Which city has the most customers?"
      - question: "What do customers say about the wireless mouse?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "EcommerceAnalytics"
        description: "Query e-commerce structured data: revenue, orders, customers, products, quantities, and order values"
    - tool_spec:
        type: "cortex_search"
        name: "ReviewSearch"
        description: "Search product reviews by topic, sentiment, product name, or rating"

  tool_resources:
    EcommerceAnalytics:
      semantic_view: "ICEBERG_DUCKDB_DEMO.PUBLIC.ECOMMERCE_ANALYTICS_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "DEMO_WH"
    ReviewSearch:
      name: "ICEBERG_DUCKDB_DEMO.PUBLIC.PRODUCT_REVIEWS_SEARCH"
      max_results: "5"
  $$;

-- ============================================================
-- STEP 5: Create MCP Server
-- ============================================================
-- NOTE: CORTEX_AGENT_RUN tool type is not included because it has compatibility
-- issues with external MCP clients (returns "No tool result received").
-- Instead, we expose Analyst + Search + SQL execution individually.
-- External platforms (Foundry AI, Claude) orchestrate across them directly.

CREATE OR REPLACE MCP SERVER ECOMMERCE_MCP_SERVER
  FROM SPECIFICATION $$
  tools:
    - name: "ecommerce-analytics"
      type: "CORTEX_ANALYST_MESSAGE"
      identifier: "ICEBERG_DUCKDB_DEMO.PUBLIC.ECOMMERCE_ANALYTICS_SV"
      description: "Generate SQL from natural language questions about e-commerce data: revenue, orders, customers, products"
      title: "E-Commerce Analytics"
    - name: "product-reviews-search"
      type: "CORTEX_SEARCH_SERVICE_QUERY"
      identifier: "ICEBERG_DUCKDB_DEMO.PUBLIC.PRODUCT_REVIEWS_SEARCH"
      description: "Search product reviews by topic, sentiment, rating, or product name"
      title: "Product Review Search"
    - name: "run-sql"
      type: "SYSTEM_EXECUTE_SQL"
      description: "Execute SQL queries against Snowflake to get actual data results. Use after ecommerce-analytics generates a SQL query."
      title: "Execute SQL"
  $$;

