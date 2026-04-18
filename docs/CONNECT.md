# PocketFlow — AI Connector Guide

PocketFlow runs a local REST API server on your phone so AI assistants can read and write your finance data directly.

---

## How It Works

1. Open PocketFlow → tap the **Connect** tab
2. Tap **Start Server**
3. Your phone shows a URL like `http://192.168.1.42:8080`
4. Your phone and laptop/browser must be on the **same WiFi**
5. Paste the URL into your AI app's connector setup

---

## Connecting to ChatGPT (Custom GPT)

1. Go to [chat.openai.com](https://chat.openai.com) → **Explore GPTs** → **Create**
2. Go to the **Configure** tab → **Actions** → **Create new action**
3. Paste the OpenAPI schema below into the schema field
4. Replace `YOUR_PHONE_IP` with your actual IP shown in the app
5. Save and test with: *"What did I spend this month?"*

### OpenAPI Schema

```yaml
openapi: 3.0.0
info:
  title: PocketFlow API
  version: 1.0.0
servers:
  - url: http://YOUR_PHONE_IP:8080
paths:
  /summary:
    get:
      summary: Get monthly financial summary
      operationId: getSummary
      responses:
        '200':
          description: Monthly income, expenses, net, savings goals
  /transactions:
    get:
      summary: List transactions
      operationId: getTransactions
      parameters:
        - name: type
          in: query
          schema:
            type: string
            enum: [income, expense]
        - name: from
          in: query
          schema:
            type: string
            format: date
        - name: to
          in: query
          schema:
            type: string
            format: date
        - name: keyword
          in: query
          schema:
            type: string
      responses:
        '200':
          description: List of transactions
    post:
      summary: Add a transaction
      operationId: addTransaction
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [type, amount, category]
              properties:
                type:
                  type: string
                  enum: [income, expense]
                amount:
                  type: number
                category:
                  type: string
                note:
                  type: string
                date:
                  type: string
                  format: date-time
      responses:
        '200':
          description: Created transaction id
  /budgets:
    get:
      summary: Get budgets with spent and remaining
      operationId: getBudgets
      responses:
        '200':
          description: List of budgets
    post:
      summary: Set a budget
      operationId: setBudget
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [category, limit]
              properties:
                category:
                  type: string
                limit:
                  type: number
      responses:
        '200':
          description: OK
  /savings:
    get:
      summary: Get savings goals with progress
      operationId: getSavings
      responses:
        '200':
          description: List of savings goals
    post:
      summary: Create a savings goal
      operationId: createSavingsGoal
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [name, target]
              properties:
                name:
                  type: string
                target:
                  type: number
      responses:
        '200':
          description: Created goal id
  /savings/{name}/contribute:
    post:
      summary: Add money to a savings goal
      operationId: contributeToGoal
      parameters:
        - name: name
          in: path
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [amount]
              properties:
                amount:
                  type: number
      responses:
        '200':
          description: OK
```

---

## Connecting to Perplexity

Perplexity does not yet support custom HTTP connectors for personal data.  
**Workaround:** Use the ChatGPT Custom GPT above, or use the prompt below directly in Perplexity after copying your summary:

1. In PocketFlow → **Connect** tab → tap **Copy URL**
2. Open your browser and go to `http://YOUR_PHONE_IP:8080/summary`
3. Copy the JSON response
4. Paste into Perplexity with: *"Here is my finance data: [paste]. Analyze my spending."*

---

## Connecting to Claude (claude.ai)

Claude does not support custom HTTP connectors yet.  
**Workaround:** Same as Perplexity — copy the JSON from `/summary` and paste it into the chat.

---

## Connecting to Cursor / VS Code (MCP)

If you use Cursor or any MCP-compatible IDE assistant:

1. Add this to your MCP config (`~/.cursor/mcp.json` or similar):

```json
{
  "mcpServers": {
    "pocketflow": {
      "url": "http://YOUR_PHONE_IP:8080",
      "type": "http"
    }
  }
}
```

2. Ask: *"Check my PocketFlow budget status"*

---

## API Quick Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server status |
| GET | `/summary` | Monthly totals + savings |
| GET | `/transactions` | List with filters |
| POST | `/transactions` | Add income/expense |
| GET | `/budgets` | Budgets + spent/remaining |
| POST | `/budgets` | Set budget limit |
| GET | `/savings` | Goals + progress % |
| POST | `/savings` | Create goal |
| POST | `/savings/:name/contribute` | Add to goal |

---

## Troubleshooting

- **Can't connect?** Make sure phone and laptop are on the same WiFi network
- **Server stops?** The server runs only while the app is open — keep the Connect tab active
- **iOS not working?** iOS may stop background network activity — keep the screen on
- **Need HTTPS?** ChatGPT Custom GPT Actions require HTTPS for production — for personal use HTTP on LAN works fine
