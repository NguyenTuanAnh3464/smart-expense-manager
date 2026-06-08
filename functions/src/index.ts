import {initializeApp} from "firebase-admin/app";
import {defineSecret} from "firebase-functions/params";
import {onCall, HttpsError} from "firebase-functions/v2/https";

initializeApp();

const openAiApiKey = defineSecret("OPENAI_API_KEY");

type AnalyzeRequest = {
  userId?: string;
  imageBase64?: string;
  mimeType?: string;
  fileType?: string;
};

const prompt = `Bạn là hệ thống đọc ảnh giao dịch ngân hàng Việt Nam.
Hãy trích xuất các giao dịch trong ảnh.
Chỉ trả về JSON hợp lệ, không giải thích thêm.
Chỉ lấy các field: date, amount, type, content, currency, confidence.

JSON:
{
  "success": true,
  "transactions": [
    {
      "date": "YYYY-MM-DD",
      "amount": 0,
      "content": "",
      "currency": "VND",
      "type": "income|expense|unknown",
      "confidence": 0.0
    }
  ],
  "warnings": []
}
Rules:
- Extract only the transaction date, amount, income/expense type, content, currency, and confidence.
- Do not extract time, account number, fee, or balance after transaction.
- Positive, plus sign, green amount means income.
- Negative, minus sign, orange/red amount means expense.
- If uncertain, use type unknown and add a warning.
- amount is an integer VND value without commas, dots, "đ", or "VND".
- date is yyyy-MM-dd when recognized.
- If date or amount is uncertain, keep the best value and use low confidence.
- If the image has multiple transactions, return multiple items.
- Do not include passwords, tokens, or unrelated personal data.`;

export const analyzeBankTransactionImage = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "512MiB",
    maxInstances: 10,
    secrets: [openAiApiKey],
  },
  async (request) => {
    const uid = request.auth?.uid;
    const data = request.data as AnalyzeRequest;
    if (!uid || uid !== data.userId) {
      throw new HttpsError("permission-denied", "Invalid authenticated user.");
    }
    if (!data.imageBase64 || (!data.mimeType && !data.fileType)) {
      throw new HttpsError("invalid-argument", "Missing image data.");
    }
    const imageBase64 = data.imageBase64;

    const apiKey = openAiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "OPENAI_API_KEY chưa được cấu hình.",
      );
    }

    const mimeType = data.mimeType ??
      `image/${data.fileType === "jpg" ? "jpeg" : data.fileType}`;
    if (!mimeType.startsWith("image/")) {
      throw new HttpsError("invalid-argument", "mimeType must be an image.");
    }

    console.info("analyzeBankTransactionImage request", {
      uid,
      mimeType,
      base64Length: imageBase64.length,
    });

    const imageUrl = `data:${mimeType};base64,${imageBase64}`;

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
            role: "user",
            content: [
              {type: "input_text", text: prompt},
              {type: "input_image", image_url: imageUrl},
            ],
          },
        ],
        text: {
          format: {type: "json_object"},
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("OpenAI image analysis failed", {
        status: response.status,
        statusText: response.statusText,
        bodyPreview: errorText.slice(0, 500),
      });
      throw new HttpsError(
        "internal",
        `OpenAI image analysis failed: ${response.status}`,
      );
    }

    const json = await response.json();
    const outputText = extractOutputText(json);
    try {
      const parsed = JSON.parse(outputText);
      console.info("analyzeBankTransactionImage parsed", {
        success: parsed?.success,
        transactionsCount: Array.isArray(parsed?.transactions) ?
          parsed.transactions.length :
          0,
      });
      return parsed;
    } catch {
      console.error("AI returned invalid JSON", {
        outputPreview: outputText.slice(0, 500),
      });
      throw new HttpsError("internal", "AI returned invalid JSON.");
    }
  },
);

function extractOutputText(response: any): string {
  const output = response?.output;
  if (Array.isArray(output)) {
    for (const item of output) {
      const content = item?.content;
      if (!Array.isArray(content)) continue;
      for (const part of content) {
        if (typeof part?.text === "string") return part.text;
      }
    }
  }
  if (typeof response?.output_text === "string") return response.output_text;
  return "{}";
}
