# Recording — Demo 2: Tools Without Skills (Blocking + DAB)

Captured live on 2026-08-28 against the freshly rebuilt core stack (from
[01-install-and-configure.md](01-install-and-configure.md)).

## 1. Seed the blocker
```bash
$ cd demos/sql
$ ./seed-blocking.sh
```
```
Blocking scenario seeded. WAITFOR expires in 8 minutes.
```

## 2. Tool call: get_blocking_chains
```
get_blocking_chains(instance_name: "SqlServer1")
```
This run captured a **two-level chain** — even better than a single blocker.
The seed script's background DAB REST scan (session 66, `dab_app`) got caught
behind the head blocker and then blocked the plain SELECT victim itself:
```json
{
  "blocking_chains": [
    {
      "blocked_session_id": 66,
      "blocking_session_id": 106,
      "wait_type": "LCK_M_S",
      "wait_seconds": 8.638,
      "blocked_status": "suspended",
      "blocked_command": "SELECT",
      "database_name": "ProductsDB",
      "blocked_login": "dab_app",
      "blocked_host": "dab-mcp",
      "blocked_program": "dab_oss_2.0.1",
      "blocked_statement": "SELECT TOP 101 [dbo_Products].[ProductID] ... FROM [dbo].[Products] AS [dbo_Products] WHERE 1 = 1 ORDER BY [dbo_Products].[ProductID] ASC FOR JSON PATH, INCLUDE_NULL_VALUES",
      "blocker_login": "sa",
      "blocker_host": "sqlserver1",
      "blocker_program": "SQLCMD",
      "blocker_sql_text": "\nBEGIN TRANSACTION;\nUPDATE dbo.Products SET UnitPrice = UnitPrice * 1.01 WHERE Category = 'Electronics';\nWAITFOR DELAY '00:08:00';\nROLLBACK;",
      "blocker_last_request_start": "2026-08-29T00:07:17.133Z"
    },
    {
      "blocked_session_id": 107,
      "blocking_session_id": 66,
      "wait_type": "LCK_M_S",
      "wait_seconds": 7.6,
      "blocked_status": "suspended",
      "blocked_command": "SELECT",
      "database_name": "ProductsDB",
      "blocked_login": "sa",
      "blocked_host": "sqlserver1",
      "blocked_program": "SQLCMD",
      "blocked_statement": "SELECT [ProductID],[ProductName],[UnitPrice] FROM [dbo].[Products] WHERE [Category]=@1",
      "blocker_login": "dab_app",
      "blocker_host": "dab-mcp",
      "blocker_program": "dab_oss_2.0.1",
      "blocker_sql_text": "SELECT TOP 101 [dbo_Products].[ProductID] ... FOR JSON PATH, INCLUDE_NULL_VALUES"
    }
  ]
}
```
The head blocker (open transaction + `WAITFOR` on Electronics), the LCK_M_S
waiters, wait times, and both SQL texts — all present. Note the chain crosses
both MCP servers' data paths: the DAB scan is a link in the same chain the
sql-dba tool is diagnosing.

## 3. DAB aside — read_records while the blocker is still active
```
read_records(entity: "Products", filter: "UnitsInStock lt 50", first: 10, orderby: ["UnitsInStock asc"])
```
**Real observed result — this timed out, and that's the point:**
```json
{
  "toolName": "read_records",
  "status": "error",
  "error": {
    "type": "InternalServerError",
    "message": "Execution Timeout Expired.  The timeout period elapsed prior to completion of the operation or the server is not responding."
  }
}
```
DAB's SELECT scans `Products` too and queued behind the same exclusive lock the
blocker holds. **If this happens live, say the line:** "That's not a bug,
that's the point. DAB's read is blocked by the exact lock sql-dba just
diagnosed. Two different MCP servers, one real contention."

## 4. Reset the blocker
```bash
$ ./reset-blocking.sh
```
```
Blocker killed (if present).
```

## 5. DAB aside — read_records after the blocker clears
```
read_records(entity: "Products", filter: "UnitsInStock lt 50", first: 10, orderby: ["UnitsInStock asc"])
```
```json
{
  "entity": "Products",
  "result": {
    "value": [
      { "ProductID": 4,  "ProductName": "Standing Desk", "Category": "Furniture",       "UnitPrice": 599.99,  "UnitsInStock": 15, "Discontinued": false },
      { "ProductID": 17, "ProductName": "Bookshelf",      "Category": "Furniture",       "UnitPrice": 129.99,  "UnitsInStock": 20, "Discontinued": false },
      { "ProductID": 14, "ProductName": "Air Purifier",   "Category": "Appliances",      "UnitPrice": 179.99,  "UnitsInStock": 25, "Discontinued": false },
      { "ProductID": 3,  "ProductName": "Office Chair",   "Category": "Furniture",       "UnitPrice": 249.99,  "UnitsInStock": 30, "Discontinued": false },
      { "ProductID": 19, "ProductName": "Whiteboard",     "Category": "Office Supplies", "UnitPrice": 59.99,   "UnitsInStock": 40, "Discontinued": false },
      { "ProductID": 1,  "ProductName": "Laptop Pro 15",  "Category": "Electronics",     "UnitPrice": 1299.99, "UnitsInStock": 45, "Discontinued": false }
    ]
  },
  "message": "Successfully read records for entity 'Products'",
  "status": "success"
}
```
Furniture is the most at-risk category (3 of 6 low-stock rows) — matches the
demo script's expected narrative exactly.

## Result
Both halves of Demo 2 reproduce as written. Bonus this run: the blocking chain
came back **two levels deep** with the DAB REST scan as the middle link — an
even cleaner illustration of cross-MCP-server contention than a single blocker.
Consider seeding the DAB read (or the background `curl` in the seed script)
intentionally on stage to reproduce it.
