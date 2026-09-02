# Demo 0 · What's an Agent? What's MCP?

**Cold open: the one big idea before we touch a container.**

---

## An agent isn't a chatbot with a clever prompt

- A **model in a loop with tools**
- It decides **which** tool to call, and in what order, from your question alone
- **MCP** is the standard port: any tool server plugs into any agent client
- Nothing here is a plugin. It's all **HTTP**

---

## The agent loop

```
        ┌─────────────────────────────────────────────────────────┐
        │                                                         │
        │   You: "Are there any blocking sessions right now?"     │
        │                                                         │
        └────────────────────────────┬────────────────────────────┘
                                     ▼
                         ┌───────────────────────┐
                         │   Language Model      │
                         │   (decides WHAT to    │
                         │    call, not HOW)     │
                         └───────────┬───────────┘
                                     │ tool call
                                     ▼
                         ┌───────────────────────┐
                         │   MCP Client          │
                         │   (Copilot Chat)      │◄──── mcp.json names
                         └───────────┬───────────┘        the servers
                                     │ HTTP
                                     ▼
                         ┌───────────────────────┐
                         │   MCP Server          │
                         │   (sql-mcp-server)    │
                         │   runs the real T-SQL │
                         └───────────┬───────────┘
                                     │ TDS
                                     ▼
                         ┌───────────────────────┐
                         │   SQL Server          │
                         │   (the DMVs)          │
                         └───────────────────────┘

     The model never touches the database. It calls the tool.
     The tool server runs the query. You stay in control of what
     queries exist to be called.
```

---

## Two MCP servers, two trust boundaries

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Docker Compose network                        │
│                                                                     │
│  ┌────────────────┐        CRUD         ┌───────────────────────┐   │
│  │                │◄────────────────────│  products-db (DAB)    │   │
│  │  sqlserver1    │                     │  :5001: zero-code    │   │
│  │  ProductsDB    │                     │  REST/GraphQL/MCP     │   │
│  │  :1433         │                     │  scoped to 4 tables   │   │
│  │                │                     └───────────────────────┘   │
│  │                │    SELECT only      ┌───────────────────────┐   │
│  │                │◄────────────────────│  sql-dba (custom)     │   │
│  │                │                     │  :3001: 34 DMV tools │   │
│  └────────────────┘                     │  safety.ts allowlist  │   │
│          ▲                              └───────────────────────┘   │
│          │ SELECT only                              ▲               │
│  ┌────────────────┐                                 │               │
│  │  sqlserver2    │─────────────────────────────────┘               │
│  │  (secondary)   │    multi-instance fan-out                       │
│  └────────────────┘                                                 │
└─────────────────────────────────────────────────────────────────────┘

  products-db: scoped CRUD, application data, DAB enforces the rules.
  sql-dba:     read-only DMVs, the whole estate, safety.ts enforces the rules.
  Neither server knows the other exists. The agent is the only thing
  that spans both, and it still can't do anything either server disallows.
```

---

## Tools → Skills → Guardrails

```
  TOOLS       →  give the agent eyes.       (Demo 2: blocking + DAB, no skill attached)
  SKILLS      →  give the agent judgment.   (Demos 3-6: availability, backup, security, observability)
  GUARDRAILS  →  keep a human in the loop.  (Demo 7: synthesis, what stopped the agent, every time)
```

---

## Watch for three things this hour

1. What **tools** exist (Demo 2)
2. What **judgment** a skill file adds on top of the same tools (Demos 3-6)
3. What the agent **refused** to do without a human (every demo, synthesized in Demo 7)

---

**Next:** [Demo 1 · Install & Configure the MCP Server →](01-install-and-configure.md)
