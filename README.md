# Snowflake Iceberg + DuckDB + Cortex AI + MCP Demo

End-to-end demo: Iceberg tables federated to DuckDB via Horizon Catalog,
Cortex AI stack (Analyst, Search, Agent), and MCP Server exposed externally.

## Architecture

```
┌─────────────────────────── Snowflake ───────────────────────────┐
│                                                                  │
│  Iceberg Tables (v2)         Cortex AI                           │
│  ┌──────────────────┐        ┌─────────────────────────────┐    │
│  │ CUSTOMERS        │───────▶│ Semantic View (Analyst)      │    │
│  │ PRODUCTS         │        │ Cortex Search (Reviews)      │    │
│  │ ORDERS           │        │ Cortex Agent                 │    │
│  └────────┬─────────┘        └──────────────┬──────────────┘    │
│           │                                  │                   │
│           │ S3 (Parquet)                     │ MCP Server        │
│           │                                  │                   │
├───────────┼──────────────────────────────────┼───────────────────┤
│  Horizon REST Catalog                        │                   │
│  (OAuth2 + vended credentials)               │ (PAT / OAuth2)    │
└───────────┼──────────────────────────────────┼───────────────────┘
            │                                  │
            ▼                                  ▼
   ┌─────────────────┐              ┌───────────────────────┐
   │  DuckDB          │              │  External Clients     │
   │  (read + write)  │              │  Claude · Cursor ·    │
   │                  │              │  Python · curl        │
   └─────────────────┘              └───────────────────────┘
```

## Demo Steps

### Part A: Iceberg + DuckDB Federation

#### Step 1: Run `setup_snowflake.sql` in Snowsight

Creates database, Iceberg tables, sample data, service user, and PAT.
Save the PAT token from the output.

#### Step 2: Set Up Python

```bash
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

#### Step 3: Export PAT

```bash
export HORIZON_PAT="<paste PAT from Step 1 output>"
```

All scripts read from this environment variable — set it once per terminal session.

#### Step 4: Run DuckDB Demo

```bash
python3 step1_connect.py   # Connect DuckDB to Horizon
python3 step2_read.py      # Read Iceberg tables
python3 step3_write.py     # Write new rows from DuckDB
python3 step4_verify.py    # Verify round-trip
```

#### Step 5: Verify from Snowflake

```sql
SELECT * FROM ICEBERG_DUCKDB_DEMO.PUBLIC.CUSTOMERS WHERE customer_id = 200;
```

---

### Part B: Cortex AI Stack

#### Step 5: Run `setup_cortex.sql` in Snowsight

Creates Semantic View, Cortex Search, Agent, and MCP Server.

#### Step 6: Test in Snowsight

Go to **AI & ML > Agents > ECOMMERCE_AGENT** and ask:
- "What is the total revenue?"
- "Which city has the most customers?"
- "What do customers say about the mechanical keyboard?"

---

### Part C: MCP Server (External Access)

#### Step 7: Run Python MCP Client

```bash
python3 mcp_client.py
```

This discovers tools, then enters interactive mode where you ask questions
and get answers via Cortex Analyst + SQL execution.

#### Step 8: Test via curl

```bash
export MCP_URL="https://SFSEAPAC-BSURESH.snowflakecomputing.com/api/v2/databases/ICEBERG_DUCKDB_DEMO/schemas/PUBLIC/mcp-servers/ECOMMERCE_MCP_SERVER"
export PAT="<YOUR_PAT>"

# Discover tools
curl -s -X POST "$MCP_URL" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | python3 -m json.tool

# Ask a question (Cortex Analyst)
curl -s -X POST "$MCP_URL" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ecommerce-analytics","arguments":{"message":"What is the total revenue?"}}}' | python3 -m json.tool

# Execute the SQL
curl -s -X POST "$MCP_URL" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"run-sql","arguments":{"sql":"SELECT * FROM SEMANTIC_VIEW(ICEBERG_DUCKDB_DEMO.PUBLIC.ECOMMERCE_ANALYTICS_SV METRICS total_revenue)"}}}' | python3 -m json.tool

# Search reviews
curl -s -X POST "$MCP_URL" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"product-reviews-search","arguments":{"query":"keyboard typing experience","limit":3}}}' | python3 -m json.tool
```

#### Step 9: Connect Claude.ai (optional)

1. Settings > Connectors > Add custom connector
2. URL: `https://SFSEAPAC-BSURESH.snowflakecomputing.com/api/v2/databases/ICEBERG_DUCKDB_DEMO/schemas/PUBLIC/mcp-servers/ECOMMERCE_MCP_SERVER`
3. Authentication: Bearer token using your PAT

## Key Notes

- DuckDB ATTACH requires: `DISABLE_MULTI_TABLE_COMMIT true`, `SKIP_CREATE_TABLE_METADATA_UPDATES true`, `REMOVE_FILES_ON_DELETE false`
- `CORTEX_AGENT_RUN` tool type does not work with external MCP clients — use Analyst + Search + SQL individually
- Service user needs `DEFAULT_WAREHOUSE` set for `SYSTEM_EXECUTE_SQL` tool
- PAT expires in 30 days — regenerate if needed

## Files

| File | Purpose |
|------|---------|
| `setup_snowflake.sql` | Database, Iceberg tables, data, service user, PAT |
| `setup_cortex.sql` | Semantic View, Search, Agent, MCP Server |
| `step1_connect.py` | DuckDB: Connect to Horizon |
| `step2_read.py` | DuckDB: Read Iceberg tables |
| `step3_write.py` | DuckDB: Write to Iceberg |
| `step4_verify.py` | DuckDB: Verify round-trip |
| `mcp_client.py` | Python MCP client (external access demo) |
| `requirements.txt` | Python dependencies |
