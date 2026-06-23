"""
Step 3: Write to Snowflake Iceberg Tables from DuckDB
======================================================
Inserts new rows natively from DuckDB into Snowflake-managed Iceberg tables
using the Horizon REST Catalog with vended credentials.
"""

import duckdb
import os

# -- Configuration --
ACCOUNT = "SFSEAPAC-BSURESH"
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
print("Step 3: Write to Snowflake Iceberg Tables from DuckDB")
print("=" * 60)
print("\n  All writes go through DuckDB's native Iceberg extension.")
print("  Data is written to S3 via Horizon-vended credentials,")
print("  then committed to the Iceberg catalog.\n")

# --- INSERT into CUSTOMERS ---
print("[1/3] Inserting new customer...")
conn.execute("""
    INSERT INTO sf.PUBLIC.CUSTOMERS
    VALUES (200, 'DuckDB Native Writer', 'duckdb-native@lakehouse.io', 'Amsterdam', '2026-06-23')
""")
print("  Inserted: (200, 'DuckDB Native Writer', 'Amsterdam')")

# --- INSERT into PRODUCTS ---
print("\n[2/3] Inserting new product...")
conn.execute("""
    INSERT INTO sf.PUBLIC.PRODUCTS
    VALUES (300, 'Standing Desk', 'Furniture', 599.99)
""")
print("  Inserted: (300, 'Standing Desk', 599.99)")

# --- INSERT into ORDERS ---
print("\n[3/3] Inserting new order...")
conn.execute("""
    INSERT INTO sf.PUBLIC.ORDERS
    VALUES (3001, 200, 300, 1, '2026-06-23', 599.99)
""")
print("  Inserted: (3001, customer=200, product=300, total=599.99)")

print("\n  SUCCESS - All 3 inserts committed to Iceberg via Horizon!")
print("=" * 60)
conn.close()
