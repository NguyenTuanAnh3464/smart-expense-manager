import "dotenv/config";

import cors from "cors";
import express from "express";

const app = express();
const port = Number(process.env.PORT || 3000);
const allowedOrigin = process.env.ALLOWED_ORIGIN || "*";

app.use(cors({origin: allowedOrigin}));
app.use(express.json({limit: "1mb"}));

app.get("/health", (_req, res) => {
  res.json({success: true, service: "smart-expense-manager-ai-backend"});
});

app.post("/api/ai/chat", async (req, res) => {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({
      success: false,
      message: "AI chưa được cấu hình backend hoặc API key.",
    });
  }

  const payload = sanitizePayload(req.body);
  if (!payload.question) {
    return res.status(400).json({
      success: false,
      message: "Vui lòng nhập câu hỏi cho AI.",
    });
  }

  try {
    console.info("AI chat request", {
      hasQuestion: true,
      budgetsCount: payload.budgets.length,
      goalsCount: payload.savingGoals.length,
      transactionsCount: payload.recentTransactions.length,
    });

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        input: [
          {
            role: "system",
            content: [
              {
                type: "input_text",
                text: [
                  "Bạn là trợ lý AI phân tích tài chính cá nhân.",
                  "Luôn trả lời bằng tiếng Việt, rõ ràng, ngắn gọn và thực tế.",
                  "Không đưa lời khuyên đầu tư rủi ro, không cam kết lợi nhuận.",
                  "Chỉ dùng dữ liệu đã được tổng hợp trong payload.",
                  "Không yêu cầu người dùng cung cấp mật khẩu, token hoặc thông tin nhạy cảm.",
                ].join(" "),
              },
            ],
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: JSON.stringify(payload),
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("OpenAI chat request failed", {
        status: response.status,
        statusText: response.statusText,
        bodyPreview: errorText.slice(0, 300),
      });
      return res.status(502).json({
        success: false,
        message: "AI tạm thời không phản hồi. Vui lòng thử lại sau.",
      });
    }

    const data = await response.json();
    const answer = extractOutputText(data).trim();
    if (!answer) {
      return res.status(502).json({
        success: false,
        message: "AI chưa trả về nội dung phù hợp.",
      });
    }

    return res.json({success: true, answer});
  } catch (error) {
    console.error("AI chat unexpected error", {
      message: error instanceof Error ? error.message : String(error),
    });
    return res.status(500).json({
      success: false,
      message: "Không thể kết nối AI. Vui lòng thử lại sau.",
    });
  }
});

app.listen(port, () => {
  console.info(`AI backend listening on port ${port}`);
});

function sanitizePayload(body) {
  const question = truncateText(body?.question, 500);
  const totalIncome = toNumber(body?.totalIncome);
  const totalExpense = toNumber(body?.totalExpense);

  return {
    question,
    totalIncome,
    totalExpense,
    budgets: sanitizeBudgets(body?.budgets),
    savingGoals: sanitizeSavingGoals(body?.savingGoals),
    recentTransactions: sanitizeTransactions(body?.recentTransactions),
  };
}

function sanitizeBudgets(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 30).map((item) => ({
    category: truncateText(item?.category, 60),
    amount: toNumber(item?.amount),
    month: toInteger(item?.month),
    year: toInteger(item?.year),
    type: truncateText(item?.type, 30),
  }));
}

function sanitizeSavingGoals(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 30).map((item) => ({
    title: truncateText(item?.title, 80),
    targetAmount: toNumber(item?.targetAmount),
    currentAmount: toNumber(item?.currentAmount),
    deadline: truncateText(item?.deadline, 20),
  }));
}

function sanitizeTransactions(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 40).map((item) => ({
    amount: toNumber(item?.amount),
    type: truncateText(item?.type, 30),
    category: truncateText(item?.category, 60),
    note: truncateText(item?.note, 100),
    date: truncateText(item?.date, 20),
  }));
}

function extractOutputText(response) {
  if (typeof response?.output_text === "string") return response.output_text;

  const output = response?.output;
  if (!Array.isArray(output)) return "";
  for (const item of output) {
    const content = item?.content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (typeof part?.text === "string") return part.text;
    }
  }
  return "";
}

function truncateText(value, maxLength) {
  const text = String(value ?? "").trim().replace(/\s+/g, " ");
  return text.length <= maxLength ? text : `${text.slice(0, maxLength)}...`;
}

function toNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function toInteger(value) {
  const number = Number.parseInt(value, 10);
  return Number.isFinite(number) ? number : null;
}
