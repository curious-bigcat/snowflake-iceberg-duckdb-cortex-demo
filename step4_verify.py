"""
Step 4: Verify Round-Trip - Read DuckDB-Written Data
=====================================================
Confirms that data written by DuckDB in Step 3 is immediately visible
when read back through the same Horizon catalog connection.
Also verifiable from Snowflake (run the verification queries in Snowsight).
"""

import duckdb
import os

# -- Configuration --
ACCOUNT = "<ORG>-<ACCOUNT>"
CATALOG_URI = f"https://{ACCOUNT}.snowflakecomputing.com/polaris/api/catalog"
DATABASE = "ICEBERG_DUCKDB_DEMO"
ROLE = "ACCOUNTADMIN"
PAT = os.environ["HORIZON_PAT"]

# --- Setup connection ---
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
print("Step 4: Verify Round-Trip (DuckDB writes -> DuckDB reads)")
print("=" * 60)

# --- Verify CUSTOMER ---
print("\n--- Verifying new customer (id=200) ---")
rows = conn.execute("SELECT * FROM sf.PUBLIC.CUSTOMERS WHERE customer_id = 200").fetchall()
if rows:
    print(f"  FOUND: {rows[0]}")
else:
    print("  NOT FOUND (run step3_write.py first)")

# --- Verify PRODUCT ---
print("\n--- Verifying new product (id=300) ---")
rows = conn.execute("SELECT * FROM sf.PUBLIC.PRODUCTS WHERE product_id = 300").fetchall()
if rows:
    print(f"  FOUND: {rows[0]}")
else:
    print("  NOT FOUND (run step3_write.py first)")

# --- Verify ORDER (with join) ---
print("\n--- Verifying new order (id=3001, joined) ---")
rows = conn.execute("""
    SELECT o.order_id, c.name, p.product_name, o.quantity, o.total_amount, o.order_date
    FROM sf.PUBLIC.ORDERS o
    JOIN sf.PUBLIC.CUSTOMERS c ON o.customer_id = c.customer_id
    JOIN sf.PUBLIC.PRODUCTS p ON o.product_id = p.product_id
    WHERE o.order_id = 3001
""").fetchall()
if rows:
    r = rows[0]
    print(f"  FOUND: Order #{r[0]} | {r[1]} bought {r[2]} | Qty: {r[3]} | Total: ${r[4]} | Date: {r[5]}")
else:
    print("  NOT FOUND (run step3_write.py first)")

# --- Total row counts ---
print("\n--- Total row counts ---")
for table in ['CUSTOMERS', 'PRODUCTS', 'ORDERS']:
    count = conn.execute(f"SELECT COUNT(*) FROM sf.PUBLIC.{table}").fetchone()[0]
    print(f"  {table}: {count} rows")

print("\n  SUCCESS - Full round-trip verified!")
print("  These rows are also visible in Snowflake:")
print("    SELECT * FROM ICEBERG_DUCKDB_DEMO.PUBLIC.CUSTOMERS WHERE customer_id = 200;")
print("    SELECT * FROM ICEBERG_DUCKDB_DEMO.PUBLIC.PRODUCTS WHERE product_id = 300;")
print("    SELECT * FROM ICEBERG_DUCKDB_DEMO.PUBLIC.ORDERS WHERE order_id = 3001;")
print("=" * 60)
conn.close()
