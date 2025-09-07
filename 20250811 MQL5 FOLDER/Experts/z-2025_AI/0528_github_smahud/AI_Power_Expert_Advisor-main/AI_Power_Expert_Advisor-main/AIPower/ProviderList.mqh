// Inisialisasi konfigurasi provider
void InitProviderConfigurations() {
   ArrayResize(Providers, 8); // Up to 8 provider (expandable)
   // Provider built-in
   Providers[0].name  = "None";        Providers[0].url  = "";                                     Providers[0].model = "";
   Providers[1].name  = "OpenAI";      Providers[1].url  = "https://api.openai.com/v1/chat/completions";   Providers[1].model = "gpt-4.1-nano-2025-04-14";
   Providers[2].name  = "DeepSeek";    Providers[2].url  = "https://api.deepseek.com/v1/chat/completions"; Providers[2].model = "deepseek-chat";
   Providers[3].name  = "Gemini";      Providers[3].url  = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";   Providers[3].model = "gemini-2.0-flash";
   Providers[4].name  = "Sonnet";      Providers[4].url  = "https://api.sonnet.com/v1/chat/completions";   Providers[4].model = "sonnet-chat";
   Providers[5].name  = "TogetherAILlama";  Providers[5].url  = "https://api.together.xyz/v1/chat/completions";  Providers[5].model = "meta-llama/Llama-3.3-70B-Instruct-Turbo-Free";
   Providers[6].name  = "TogetherAIDeepSeekV3";   Providers[6].url  = "https://api.together.xyz/v1/chat/completions"; Providers[6].model = "deepseek-ai/DeepSeek-V3";
   Providers[7].name  = "MetaLlamaInstructTurbo";   Providers[7].url  = "https://api.together.xyz/v1/chat/completions"; Providers[7].model = "meta-llama/Llama-3.3-70B-Instruct-Turbo";
}