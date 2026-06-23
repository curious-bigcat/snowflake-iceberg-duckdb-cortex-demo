"""
Step 2: Read Snowflake Iceberg Tables from DuckDB
==================================================
Queries all three tables via the Horizon REST Catalog.
Demonstrates federated reads with JOINs across Iceberg tables.
"""

import duckdb
import os
import time

# -- Configuration --
ACCOUNT = "<ORG>-<ACCOUNT>"
CATALOG_URI = f"https://{ACCOUNT}.snowflakecomputing.com/polaris/api/catalog"
DATABASE = "ICEBERG_DUCKDB_DEMO"
ROLE = "ACCOUNTADMIN"
PAT = os.environ["HORIZON_PAT"]

# --- Setup connection (same as step 1) ---
conn = duckdb.connect()
conn.execute("INSTALL iceberg; LOAD iceberg;")
conn.execute("INSTALL httpfs; LOAD httpfs;")
conn.execute(f"""
    CREATE SECRET iceberg_horizon (
        TYPE iceberg, CLIENT_ID '', CLIENT_SECRET '{PAT}',
        OAUTH2_SERVER_URI '{CATALOG_URI}/v1/oauth/tokens',
        OAUTH2_GRANT_TYPE 'client_credentials',
        OAUTH2_SCOPE 'session:role:{ROLE}'
    );
""")
conn.execute(f"""
    ATTACH '{DATABASE}' AS sf (
        TYPE iceberg, ENDPOINT '{CATALOG_URI}',
        ACCESS_DELEGATION_MODE 'vended_credentials',
        DISABLE_MULTI_TABLE_COMMIT true,
        SKIP_CREATE_TABLE_METADATA_UPDATES true,
        REMOVE_FILES_ON_DELETE false
    );
""")

print("=" * 60)
print("Step 2: Read Snowflake Iceberg Tables from DuckDB")
print("=" * 60)

# --- Query CUSTOMERS ---
print("\n--- CUSTOMERS ---")
start = time.time()
rows = conn.execute("SELECT * FROM sf.PUBLIC.CUSTOMERS ORDER BY customer_id").fetchall()
elapsed = time.time() - start
print(f"  {'ID':<4} {'Name':<16} {'Email':<24} {'City':<14} {'Signup'}")
print(f"  {'-'*4} {'-'*16} {'-'*24} {'-'*14} {'-'*10}")
for r in rows:
    print(f"  {r[0]:<4} {r[1]:<16} {r[2]:<24} {r[3]:<14} {r[4]}")
print(f"  ({len(rows)} rows, {elapsed:.2f}s)")

# --- Query PRODUCTS ---
print("\n--- PRODUCTS ---")
start = time.time()
rows = conn.execute("SELECT * FROM sf.PUBLIC.PRODUCTS ORDER BY product_id").fetchall()
elapsed = time.time() - start
print(f"  {'ID':<4} {'Product':<22} {'Category':<12} {'Price'}")
print(f"  {'-'*4} {'-'*22} {'-'*12} {'-'*6}")
for r in rows:
    print(f"  {r[0]:<4} {r[1]:<22} {r[2]:<12} {r[3]}")
print(f"  ({len(rows)} rows, {elapsed:.2f}s)")

# --- Query ORDERS with 3-way JOIN ---
print("\n--- ORDERS (3-way JOIN across Iceberg tables) ---")
start = time.time()
rows = conn.execute("""
    SELECT o.order_id, c.name, p.product_name, o.quantity, o.total_amount, o.order_date
    FROM sf.PUBLIC.ORDERS o
    JOIN sf.PUBLIC.CUSTOMERS c ON o.customer_id = c.customer_id
    JOIN sf.PUBLIC.PRODUCTS p ON o.product_id = p.product_id
    ORDER BY o.order_date
""").fetchall()
elapsed = time.time() - start
print(f"  {'OrderID':<8} {'Customer':<16} {'Product':<22} {'Qty':<4} {'Total':<8} {'Date'}")
print(f"  {'-'*8} {'-'*16} {'-'*22} {'-'*4} {'-'*8} {'-'*10}")
for r in rows:
    print(f"  {r[0]:<8} {r[1]:<16} {r[2]:<22} {r[3]:<4} {r[4]:<8} {r[5]}")
print(f"  ({len(rows)} rows, {elapsed:.2f}s)")

print("\n  SUCCESS - All reads completed via Horizon REST Catalog!")
print("=" * 60)
conn.close()
