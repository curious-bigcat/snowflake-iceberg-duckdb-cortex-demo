"""
Step 1: Connect DuckDB to Snowflake Horizon REST Catalog
=========================================================
Installs extensions, creates OAuth2 secret, and attaches the catalog.
"""

import duckdb
import os

# -- Configuration --
ACCOUNT = "<ORG>-<ACCOUNT>"
CATALOG_URI = f"https://{ACCOUNT}.snowflakecomputing.com/polaris/api/catalog"
DATABASE = "ICEBERG_DUCKDB_DEMO"
ROLE = "ACCOUNTADMIN"
PAT = os.environ["HORIZON_PAT"]

print("=" * 60)
print("Step 1: Connect DuckDB to Snowflake Horizon Catalog")
print("=" * 60)

conn = duckdb.connect()

print("\n[1/3] Installing and loading extensions...")
conn.execute("INSTALL iceberg; LOAD iceberg;")
conn.execute("INSTALL httpfs; LOAD httpfs;")
print("  Done: iceberg + httpfs loaded.")

print("\n[2/3] Creating OAuth2 secret for Horizon authentication...")
conn.execute(f"""
    CREATE SECRET iceberg_horizon (
        TYPE iceberg,
        CLIENT_ID '',
        CLIENT_SECRET '{PAT}',
        OAUTH2_SERVER_URI '{CATALOG_URI}/v1/oauth/tokens',
        OAUTH2_GRANT_TYPE 'client_credentials',
        OAUTH2_SCOPE 'session:role:{ROLE}'
    );
""")
print("  Done: Secret created with PAT credentials.")

print("\n[3/3] Attaching Snowflake Horizon catalog...")
conn.execute(f"""
    ATTACH '{DATABASE}' AS sf (
        TYPE iceberg,
        ENDPOINT '{CATALOG_URI}',
        ACCESS_DELEGATION_MODE 'vended_credentials',
        DISABLE_MULTI_TABLE_COMMIT true,
        SKIP_CREATE_TABLE_METADATA_UPDATES true,
        REMOVE_FILES_ON_DELETE false
    );
""")
print(f"  Done: Catalog attached as 'sf'")
print(f"  Endpoint: {CATALOG_URI}")
print(f"  Database: {DATABASE}")

# Show available tables
print("\n[Catalog Contents]")
tables = conn.execute("SHOW ALL TABLES").fetchall()
for t in tables:
    print(f"  {t[0]}.{t[1]}.{t[2]}")

print("\n  SUCCESS - DuckDB is connected to Snowflake Iceberg via Horizon!")
print("=" * 60)
conn.close()
