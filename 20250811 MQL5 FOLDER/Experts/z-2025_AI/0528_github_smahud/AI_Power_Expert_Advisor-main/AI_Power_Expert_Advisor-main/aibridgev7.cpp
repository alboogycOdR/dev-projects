/*
 * AI Bridge DLL v7.x (WinINet, Manual API Key Patch, Full Feature)
 * PATCH: Pisahkan AnalyzeWithAI_Secure2 dan AnalyzeLicense (cek lisensi)
 * PATCH: Logging ke folder C:\Users\Public\Documents\AIBridge_Log
 *        Otomatis buat folder jika belum ada
 *        Nama file log sesuai format instruksi
 */

#include <windows.h>
#include <wininet.h>
#include <cstdio>
#include <cstring>
#include <string>
#include <ctime>
#include <direct.h>
#include "json.hpp" // nlohmann::json

using json = nlohmann::json;

const char* DLL_VERSION = "v7.00";
const double DEMO_EQUITY_LIMIT = 1000000.0;

// =============== LOGGING ===============
void EnsureLogDirectoryExists() {
    const char* log_dir = "C:\\Users\\Public\\Documents\\AIBridge_Log";
    DWORD attrib = GetFileAttributesA(log_dir);
    if (attrib == INVALID_FILE_ATTRIBUTES || !(attrib & FILE_ATTRIBUTE_DIRECTORY)) {
        _mkdir(log_dir); // Buat dir jika belum ada
    }
}

const char* PhaseToSuffix(const char* stage) {
    if (strcmp(stage, "EA->DLL") == 0)      return "phase1-EAtoDLL";
    if (strcmp(stage, "DLL->API") == 0)     return "phase2-DLLtoAPI";
    if (strcmp(stage, "API->DLL") == 0)     return "phase3-APItoDLL";
    if (strcmp(stage, "DLL->EA") == 0)      return "phase4-DLLtoEA";
    return "other";
}

void LogBridgeFile(const char *stage, const char *data) {
    EnsureLogDirectoryExists();
    char datebuf[16];
    SYSTEMTIME t;
    GetLocalTime(&t);
    sprintf(datebuf, "%04d-%02d-%02d", t.wYear, t.wMonth, t.wDay);
    char filename[512];
    sprintf(filename, "C:\\Users\\Public\\Documents\\AIBridge_Log\\%s-%s.log", datebuf, PhaseToSuffix(stage));
    FILE *f = fopen(filename, "a");
    if (!f) return;
    fprintf(f, "[%04d-%02d-%02d %02d:%02d:%02d.%03d] [%s]: %s\n",
        t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, t.wMilliseconds, stage, data ? data : "(null)");
    fclose(f);
}

// =============== UTILITY ===============
bool aes128cbc_decrypt(const std::string& ciphertext_b64, const std::string& key, const std::string& iv, std::string& plaintext) {
    // ... implementasi or placeholder ...
    return false;
}

bool decode_license(const std::string& key_b64, std::string& jenis, std::string& expired, std::string& maxeq, std::string& nama, std::string& random) {
    // ... implementasi or placeholder ...
    return false;
}

bool is_expired(const std::string& expired) {
    // ... implementasi or placeholder ...
    return false;
}

double parse_double(const std::string& str) {
    try { return std::stod(str); } catch(...) { return 0; }
}

void WriteStringToCharArr(const char* src, unsigned char* dst, int maxlen) {
    if(!src || !dst || maxlen<=0) return;
    int len = (int)strlen(src);
    if(len > maxlen-1) len = maxlen-1;
    memcpy(dst, src, len);
    dst[len] = 0;
}

std::string trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\n\r");
    size_t end = s.find_last_not_of(" \t\n\r");
    if (start == std::string::npos || end == std::string::npos) return "";
    return s.substr(start, end - start + 1);
}

bool ExtractContentField(const std::string& json_str, std::string& out) {
    try {
        auto j = json::parse(json_str);
        if(j.contains("choices") && j["choices"].is_array() && !j["choices"].empty()) {
            if(j["choices"][0].contains("message") && j["choices"][0]["message"].contains("content")) {
                out = j["choices"][0]["message"]["content"].get<std::string>();
                return true;
            }
            if(j["choices"][0].contains("text")) { // DeepSeek
                out = j["choices"][0]["text"].get<std::string>();
                return true;
            }
        }
    } catch(...) {}
    return false;
}

// ------------ FILTER LOG: abaikan payload test
bool isPayloadTest(const char* payload) {
    if (!payload) return false;
    if (strstr(payload, "\"test\":\"licenceinfo\"")) return true;
    if (strstr(payload, "\"test\"")) return true;
    return false;
}

// --- HTTP POST to AI (WinINet) ---
bool HttpPostToAI(const char* url, const char* apikey, const char* payload, char* out_response, int out_size) {
    HINTERNET hSession = InternetOpenA("AITradingDLL", INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
    if (!hSession) return false;

    char host[128] = {0}, path[256] = {0};
    int port = 443;
    if (strncmp(url, "https://", 8) == 0) {
        sscanf(url + 8, "%127[^/]/%255[^\n]", host, path);
        char* slash = strchr(host, '/');
        if (slash) {
            strcpy(path, slash + 1);
            *slash = '\0';
        }
    } else { InternetCloseHandle(hSession); return false; }
    char path_slash[260] = "/";
    if(strlen(path) > 0) strcat(path_slash, path);

    HINTERNET hConnect = InternetConnectA(hSession, host, port, NULL, NULL, INTERNET_SERVICE_HTTP, 0, 0);
    if (!hConnect) { InternetCloseHandle(hSession); return false; }

    const char* accept[] = { "application/json", NULL };
    HINTERNET hRequest = HttpOpenRequestA(
        hConnect, "POST", path_slash,
        NULL, NULL, accept, INTERNET_FLAG_SECURE|INTERNET_FLAG_RELOAD, 0
    );
    if (!hRequest) { InternetCloseHandle(hConnect); InternetCloseHandle(hSession); return false; }

    char headers[512] = "Content-Type: application/json\r\n";
    if (apikey && strlen(apikey) > 0) {
        strcat(headers, "Authorization: Bearer ");
        strcat(headers, apikey);
        strcat(headers, "\r\n");
    }

    // LOG PAYLOAD HANYA JIKA BUKAN TEST
    if (!isPayloadTest(payload)) {
        LogBridgeFile("DLL->API", payload);
        FILE *f = fopen("C:\\aibridge_PAYLOADtoAI.json", "a");
        if (f) {
            SYSTEMTIME t;
            GetLocalTime(&t);
            fprintf(f, "\n// [%04d-%02d-%02d %02d:%02d:%02d.%03d]\n",
                t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
            fprintf(f, "%s\n", payload ? payload : "(null)");
            fclose(f);
        }
    }

    int payload_len = (int)strlen(payload);
    BOOL sent = HttpSendRequestA(
        hRequest, headers, (DWORD)strlen(headers), (LPVOID)payload, (DWORD)payload_len
    );
    if (!sent) {
        DWORD err = GetLastError();
        char msg[128]; sprintf(msg, "HttpSendRequestA failed, error %lu", err);
        LogBridgeFile("DLL->API", msg);
        InternetCloseHandle(hRequest); InternetCloseHandle(hConnect); InternetCloseHandle(hSession); return false;
    }
    DWORD bytesRead = 0, totalRead = 0;
    char buffer[4096]; out_response[0] = 0;
    while (InternetReadFile(hRequest, buffer, sizeof(buffer) - 1, &bytesRead) && bytesRead > 0) {
        if (totalRead + bytesRead < (DWORD)out_size - 1) {
            memcpy(out_response + totalRead, buffer, bytesRead);
            totalRead += bytesRead;
        } else break;
    }
    out_response[totalRead] = 0;
    InternetCloseHandle(hRequest); InternetCloseHandle(hConnect); InternetCloseHandle(hSession);
    return totalRead > 0;
}

void getProviderModelUrl(const char *provider, std::string &model, std::string &url) {
    model = "gpt-4o";
    url = "https://api.openai.com/v1/chat/completions";
    if (provider && (strcmp(provider, "deepseek") == 0 || strcmp(provider, "deepseek-ai") == 0)) {
        url = "https://api.deepseek.com/v1/chat/completions";
        model = "deepseek-chat";
    }
}

// ============= FUNGSI UTAMA: Analisa AI =============
std::string RealAIProcess(
    const char* payload_in, const char* apikey, const char* provider, const char* licence,
    std::string& licinfo, std::string& dllver, std::string& error_log,
    double account_equity
) {
    // --- License & expiry logic ---
    std::string licenceKey(licence ? licence : "");
    std::string jenis, expired, maxeq, nama, random;
    double equity_limit = 0;
    bool is_demo = false, is_pro = false, expired_flag = false, eq_limit_exceeded = false;
    std::string licinfo_detail;

    if (licenceKey == "DEMO") {
        jenis = "DEMO";
        expired = "2025/05/31";
        maxeq = "1000000";
        nama = "DEMO";
        random = "";
        is_demo = true;
        is_pro = false;
        expired_flag = is_expired(expired);
        equity_limit = DEMO_EQUITY_LIMIT;
    } else {
        bool ok = decode_license(licenceKey, jenis, expired, maxeq, nama, random);
        if (!ok || (jenis != "PRO")) {
            licinfo = "INVALID";
            dllver = DLL_VERSION;
            return "HOLD";
        }
        is_pro = true;
        is_demo = false;
        expired_flag = is_expired(expired);
        equity_limit = parse_double(maxeq);
    }
    if(equity_limit > 0 && account_equity > equity_limit) {
        eq_limit_exceeded = true;
    }
    licinfo_detail = (is_demo ? "DEMO" : "PRO");
    licinfo_detail += " | Exp: " + expired;
    licinfo_detail += " | MaxEq: " + maxeq;
    licinfo_detail += " | User: " + nama;
    licinfo_detail += " | EqNow: " + std::to_string(account_equity);
    if (expired_flag)
        licinfo_detail += " | EXPIRED";
    if (eq_limit_exceeded)
        licinfo_detail += " | LIMIT";
    if(licinfo_detail.length() > 250)
        licinfo_detail = licinfo_detail.substr(0, 250);
    licinfo = licinfo_detail;
    dllver = DLL_VERSION;
    if (expired_flag || eq_limit_exceeded)
        return "HOLD";

    std::string strPayload(payload_in ? payload_in : "");
    std::string model, url;
    getProviderModelUrl(provider, model, url);

    // LOGGING: EA -> DLL
    LogBridgeFile("EA->DLL", strPayload.c_str());
    LogBridgeFile("EA->DLL", provider ? (const char*)provider : "(null)");

    std::string s_apikey;
    if(apikey) s_apikey = trim(std::string((const char*)apikey));
    if(s_apikey.empty()) {
        LogBridgeFile("DLL->EA", "API_KEY_MISSING");
        return "API_KEY_MISSING";
    }
    if(s_apikey.length() < 5) {
        LogBridgeFile("DLL->EA", "API_KEY_INVALID");
        return "API_KEY_INVALID";
    }

    char ai_response[8192] = {0};
    bool ok = HttpPostToAI(url.c_str(), s_apikey.c_str(), strPayload.c_str(), ai_response, sizeof(ai_response));
    LogBridgeFile("API->DLL", ai_response);

    std::string result;
    if (ok && strlen(ai_response) > 0) {
        std::string content;
        if (ExtractContentField(ai_response, content)) {
            result = content;
        } else {
            result = ai_response;
        }
    } else {
        result = "{\"error\":\"AI request failed or not implemented\"}";
    }
    LogBridgeFile("DLL->EA", result.c_str());
    return result;
}

// ============= EXPORT UNTUK MQL5 =============

extern "C" __declspec(dllexport)
int __stdcall AnalyzeWithAI_Secure2(
    const unsigned char* payload, int payload_len,
    const unsigned char* apikey,
    const unsigned char* provider,
    const unsigned char* licence,
    const char* account_number,
    double account_equity,
    unsigned char* response, int resp_size,
    unsigned char* dllver, int dllver_size,
    unsigned char* licinfo, int licinfo_size
)
{
    char _apikey[2048] = {0};
    char _provider[32] = {0};
    char _licence[128] = {0};

    // PATCH: Copy API key manual, null-terminated
    if (apikey) {
        int n = 0;
        while (n < 2047 && apikey[n]) {
            _apikey[n] = (char)apikey[n];
            n++;
        }
        _apikey[n] = 0;
    }

    if (provider) {
        int n = 0;
        while (n < 31 && provider[n]) {
            _provider[n] = (char)provider[n];
            n++;
        }
        _provider[n] = 0;
    }
    if (licence) {
        int n = 0;
        while (n < 127 && licence[n]) {
            _licence[n] = (char)licence[n];
            n++;
        }
        _licence[n] = 0;
    }

    std::string licinfo_str, dllver_str, error_log;
    std::string result = RealAIProcess(
        (const char*)payload,
        _apikey,
        _provider,
        _licence,
        licinfo_str,
        dllver_str,
        error_log,
        account_equity
    );

    WriteStringToCharArr(result.c_str(), response, resp_size);
    WriteStringToCharArr(dllver_str.c_str(), dllver, dllver_size);
    WriteStringToCharArr(licinfo_str.c_str(), licinfo, licinfo_size);
    return 1;
}

// ============= EXPORT: CEK LISENSI SAJA =============
extern "C" __declspec(dllexport)
int __stdcall AnalyzeLicense(
    const unsigned char* licence,
    double account_equity,
    unsigned char* licinfo, int licinfo_size,
    unsigned char* dllver, int dllver_size
)
{
    char _licence[128] = {0};
    if (licence) {
        int n = 0;
        while (n < 127 && licence[n]) {
            _licence[n] = (char)licence[n];
            n++;
        }
        _licence[n] = 0;
    }

    std::string licinfo_str, dllver_str;
    std::string licenceKey(_licence);
    std::string jenis, expired, maxeq, nama, random;
    double equity_limit = 0;
    bool is_demo = false, is_pro = false, expired_flag = false, eq_limit_exceeded = false;
    if (licenceKey == "DEMO") {
        jenis = "DEMO";
        expired = "2025/05/31";
        maxeq = "1000000";
        nama = "DEMO";
        random = "";
        is_demo = true;
        is_pro = false;
        expired_flag = false;
        equity_limit = DEMO_EQUITY_LIMIT;
    } else {
        bool ok = decode_license(licenceKey, jenis, expired, maxeq, nama, random);
        if (!ok || (jenis != "PRO")) {
            licinfo_str = "INVALID";
            dllver_str = DLL_VERSION;
            WriteStringToCharArr(licinfo_str.c_str(), licinfo, licinfo_size);
            WriteStringToCharArr(dllver_str.c_str(), dllver, dllver_size);
            return 0;
        }
        is_pro = true;
        is_demo = false;
        expired_flag = is_expired(expired);
        equity_limit = parse_double(maxeq);
    }
    if(equity_limit > 0 && account_equity > equity_limit) {
        eq_limit_exceeded = true;
    }
    licinfo_str = (is_demo ? "DEMO" : "PRO");
    licinfo_str += " | Exp: " + expired;
    licinfo_str += " | MaxEq: " + maxeq;
    licinfo_str += " | User: " + nama;
    licinfo_str += " | EqNow: " + std::to_string(account_equity);
    if (expired_flag)
        licinfo_str += " | EXPIRED";
    if (eq_limit_exceeded)
        licinfo_str += " | LIMIT";
    if(licinfo_str.length() > 250)
        licinfo_str = licinfo_str.substr(0, 250);

    dllver_str = DLL_VERSION;
    WriteStringToCharArr(licinfo_str.c_str(), licinfo, licinfo_size);
    WriteStringToCharArr(dllver_str.c_str(), dllver, dllver_size);
    return 1;
}

extern "C" __declspec(dllexport)
const char* __stdcall DllGetVersion() {
    return DLL_VERSION;
}