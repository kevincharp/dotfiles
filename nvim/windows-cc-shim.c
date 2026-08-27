/* Shim de compilador C para nvim-treesitter en Windows (rama 'main').
 *
 * nvim-treesitter compila los parsers invocando literalmente un programa
 * llamado "cc" (ver do_compile en su install.lua). Sin MSVC instalado, la
 * unica opcion liviana es que ese "cc" sea zig ("zig cc"), pero eso no se
 * puede lograr solo con la variable CC: tree-sitter-cli usa la PRIMERA
 * palabra de CC como programa y descarta el resto, asi que CC="zig cc"
 * termina invocando "zig" con "-O2" (u otro flag) como si fuera un
 * subcomando, y zig lo rechaza ("unknown command"). Hace falta un unico
 * ejecutable llamado cc.exe que internamente reenvie todo a "zig cc".
 *
 * Ademas, tree-sitter-cli le pasa a "cc" el target triple con el que se
 * compilo la propia herramienta, en formato Rust/LLVM
 * ("x86_64-pc-windows-msvc"). El parser de targets de zig no tiene campo de
 * vendor y no entiende ese string tal cual ("UnknownOperatingSystem"). Sin
 * MSVC instalado tampoco sirve pedirle la ABI msvc real, asi que se reescribe
 * a la ABI gnu ("x86_64-windows-gnu"), que zig resuelve con sus propios
 * headers de mingw-w64 embebidos, sin depender de Visual Studio.
 *
 * Lo compila bootstrap.ps1 con `zig build-exe` a ~/.local/bin/cc.exe (ver el
 * paso "shim de compilador" en la seccion de nvim). CC=cc queda seteada a
 * nivel de usuario para que nvim (y cualquier otra herramienta) la use.
 */
#include <windows.h>
#include <string.h>
#include <stdio.h>

int main(void) {
    char *full = GetCommandLineA();
    /* Saltar el primer token (el nombre del propio ejecutable) para quedarnos
     * solo con los argumentos que nos pasaron. */
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
