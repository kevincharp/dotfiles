/* Shim "cc" para nvim-treesitter en Windows: reenvia todo a "zig cc".
 *
 * tree-sitter-cli invoca la primera palabra de CC y descarta el resto, asi que
 * CC="zig cc" no sirve: hace falta un ejecutable llamado cc.exe. Ademas pasa el
 * target "x86_64-pc-windows-msvc", que zig no entiende; se reescribe a
 * "x86_64-windows-gnu" (mingw-w64 embebido, sin Visual Studio).
 *
 * Lo compila bootstrap.ps1 con `zig build-exe` a ~/.local/bin/cc.exe.
 */
#include <windows.h>
#include <string.h>
#include <stdio.h>

int main(void) {
    char *full = GetCommandLineA();
    /* Saltar el nombre del propio ejecutable. */
    char *rest = full;
    if (*rest == '"') {
        rest++;
        while (*rest && *rest != '"') rest++;
        if (*rest == '"') rest++;
    } else {
        while (*rest && *rest != ' ') rest++;
    }
    while (*rest == ' ') rest++;

    char fixed[32768];
    {
        const char *needle = "x86_64-pc-windows-msvc";
        const char *replacement = "x86_64-windows-gnu";
        const char *p = rest;
        char *out = fixed;
        size_t needle_len = strlen(needle);
        while (*p && (size_t)(out - fixed) < sizeof(fixed) - needle_len - 1) {
            if (strncmp(p, needle, needle_len) == 0) {
                strcpy(out, replacement);
                out += strlen(replacement);
                p += needle_len;
            } else {
                *out++ = *p++;
            }
        }
        *out = '\0';
    }

    char cmdline[32768];
    snprintf(cmdline, sizeof(cmdline) - 1, "zig.exe cc %s", fixed);
    cmdline[sizeof(cmdline) - 1] = '\0';

    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);

    if (!CreateProcessA(NULL, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        return 1;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (int)code;
}
