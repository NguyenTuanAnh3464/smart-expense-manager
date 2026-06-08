# Smart Expense Manager AI Backend

Backend Node.js/Express an toàn để Flutter gọi AI mà không đưa `OPENAI_API_KEY`
vào app mobile.

## Chạy local

```powershell
cd backend
npm install
Copy-Item .env.example .env
npm run dev
```

Điền API key trong `backend/.env`:

```env
OPENAI_API_KEY=sk-...
PORT=3000
ALLOWED_ORIGIN=*
```

Khi chạy Android emulator, build Flutter với backend local:

```powershell
flutter run --dart-define=AI_BACKEND_URL=http://10.0.2.2:3000
```

Thiết bị thật cần dùng IP LAN của máy chạy backend, ví dụ:

```powershell
flutter run --dart-define=AI_BACKEND_URL=http://192.168.1.10:3000
```

## Endpoint

`POST /api/ai/chat`

Request body:

```json
{
  "question": "Tóm tắt chi tiêu tháng này",
  "totalIncome": 10000000,
  "totalExpense": 3500000,
  "budgets": [],
  "savingGoals": [],
  "recentTransactions": []
}
```

Response:

```json
{
  "success": true,
  "answer": "..."
}
```

Không commit file `.env` lên GitHub.
