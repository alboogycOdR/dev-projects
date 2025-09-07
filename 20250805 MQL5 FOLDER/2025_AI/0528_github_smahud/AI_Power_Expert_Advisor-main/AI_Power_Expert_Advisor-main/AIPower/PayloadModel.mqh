//+------------------------------------------------------------------+
//| PayloadModel.mqh                                                 |
//| Huda Choirul Anam - Copyright 2025, MetaQuotes Ltd.              |
//| https://www.ulfasanda.com                                        |
//+------------------------------------------------------------------+
// --- Escape string agar aman di JSON ---
string EscapeJson(const string &source) {
   string result = "";
   for (int i = 0; i < StringLen(source); i++) {
      string c = StringSubstr(source, i, 1);
      if (c == "\\") result += "\\\\";
      else if (c == "\"") result += "\\\"";
      else if (c == CharToString(8)) result += "\\b";
      else if (c == CharToString(12)) result += "\\f";
      else if (c == "\n" || c == "\r") result += " "; // newline jadi spasi
      else if (c == "\t") result += "\\t";
      else result += c;
   }
   return result;
}

// --- Payload Gemini API (bisa tambah param jika perlu) ---
string BuildGeminiPayload(const string prompt, double temperature = 0.2) {
   // Jika ingin tanpa generationConfig, cukup hapus bagian bawah
   return StringFormat(
      "{\"contents\":[{\"parts\":[{\"text\":\"%s\"}]}],\"generationConfig\":{\"temperature\":%.2f}}",
      EscapeJson(prompt), temperature
   );
}

// --- Payload Universal (OpenAI, DeepSeek, TogetherAI, dll) ---
string BuildUniversalPayload(const string model, const string prompt, double temperature = 0.1) {
   return StringFormat(
      "{\"model\":\"%s\",\"messages\":[{\"role\":\"user\",\"content\":\"%s\"}],\"temperature\":%.2f}",
      model, EscapeJson(prompt), temperature
   );
}