#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <signal.h>
#include <IOKit/IOKitLib.h>

#define PRIMARY_SOCKET "/var/run/lefan.sock"
#define FALLBACK_SOCKET "/tmp/lefan.sock"

typedef struct {
    unsigned char major;
    unsigned char minor;
    unsigned char build;
    unsigned char reserved;
    unsigned short release;
} SMCVersion;

typedef struct {
    unsigned short version;
    unsigned short length;
    unsigned int cpuPLimit;
    unsigned int gpuPLimit;
    unsigned int memPLimit;
} SMCPLimitData;

typedef struct {
    unsigned int dataSize;
    unsigned int dataType;
    unsigned char dataAttributes;
} SMCKeyInfoData;

typedef struct {
    unsigned int key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfoData keyInfo;
    unsigned char result;
    unsigned char status;
    unsigned char data8;
    unsigned int data32;
    unsigned char bytes[32];
} SMCKeyData;

#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_WRITE_BYTES 6
#define SMC_CMD_READ_KEYINFO 9

static io_connect_t g_conn = 0;

static uint32_t str_to_key(const char *str) {
    return ((uint8_t)str[0] << 24) |
           ((uint8_t)str[1] << 16) |
           ((uint8_t)str[2] << 8) |
           ((uint8_t)str[3]);
}

int smc_open(void) {
    if (g_conn) return 0;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return -1;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_conn);
    IOObjectRelease(service);
    return (kr == KERN_SUCCESS) ? 0 : -1;
}

void smc_close(void) {
    if (g_conn) {
        IOServiceClose(g_conn);
        g_conn = 0;
    }
}

static kern_return_t smc_call(SMCKeyData *in, SMCKeyData *out) {
    size_t inSize = sizeof(SMCKeyData);
    size_t outSize = sizeof(SMCKeyData);
    return IOConnectCallStructMethod(g_conn, 2, in, inSize, out, &outSize);
}

static int smc_read_key_info(uint32_t key, SMCKeyInfoData *info) {
    SMCKeyData in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = key;
    in.data8 = SMC_CMD_READ_KEYINFO;
    kern_return_t kr = smc_call(&in, &out);
    if (kr == KERN_SUCCESS && out.result == 0) {
        *info = out.keyInfo;
        return 0;
    }
    return -1;
}

static int smc_write_key(uint32_t key, const unsigned char *bytes, unsigned int size) {
    SMCKeyInfoData info;
    if (smc_read_key_info(key, &info) != 0) {
        return -1;
    }
    SMCKeyData in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = key;
    in.data8 = SMC_CMD_WRITE_BYTES;
    in.keyInfo = info;
    memcpy(in.bytes, bytes, size);
    kern_return_t kr = smc_call(&in, &out);
    if (kr == KERN_SUCCESS && out.result == 0) {
        return 0;
    }
    return (kr != KERN_SUCCESS) ? (int)kr : -((int)out.result);
}

int set_fan(int fanIndex, int mode, float rpm) {
    if (smc_open() != 0) return -1;

    char modeKeyStr[5];
    snprintf(modeKeyStr, sizeof(modeKeyStr), "F%dMd", fanIndex);
    uint32_t modeKey = str_to_key(modeKeyStr);

    unsigned char modeByte = (mode == 0) ? 0 : 1;
    int err = smc_write_key(modeKey, &modeByte, 1);
    if (err != 0) {
        return err;
    }

    if (mode == 1 && rpm > 0) {
        char tgKeyStr[5];
        snprintf(tgKeyStr, sizeof(tgKeyStr), "F%dTg", fanIndex);
        uint32_t tgKey = str_to_key(tgKeyStr);

        SMCKeyInfoData info;
        if (smc_read_key_info(tgKey, &info) == 0) {
            if (info.dataSize == 4) {
                float f = rpm;
                err = smc_write_key(tgKey, (unsigned char*)&f, 4);
            } else if (info.dataSize == 2) {
                uint16_t val = (uint16_t)(rpm * 4.0f);
                unsigned char buf[2] = { (unsigned char)(val >> 8), (unsigned char)(val & 0xff) };
                err = smc_write_key(tgKey, buf, 2);
            }
        }
    }
    return err;
}

int set_all_fans(int mode, float rpm) {
    if (smc_open() != 0) return -1;
    int count = 2; // Default to dual fans
    SMCKeyInfoData info;
    uint32_t key = str_to_key("FNum");
    if (smc_read_key_info(key, &info) == 0) {
        SMCKeyData in, out;
        memset(&in, 0, sizeof(in));
        memset(&out, 0, sizeof(out));
        in.key = key;
        in.data8 = SMC_CMD_READ_BYTES;
        in.keyInfo.dataSize = info.dataSize;
        if (smc_call(&in, &out) == KERN_SUCCESS) {
            count = out.bytes[0];
        }
    }
    int lastErr = 0;
    for (int i = 0; i < count; i++) {
        int e = set_fan(i, mode, rpm);
        if (e != 0) lastErr = e;
    }
    return lastErr;
}

int handle_command(const char *cmd_buf, char *resp_buf, size_t resp_size) {
    int fan = -1;
    int rpm = 0;
    char mode[16] = {0};

    if (strncmp(cmd_buf, "ping", 4) == 0 || strncmp(cmd_buf, "status", 6) == 0) {
        snprintf(resp_buf, resp_size, "{\"status\":\"ok\",\"pong\":true,\"uid\":%d}\n", getuid());
        return 0;
    }

    if (strncmp(cmd_buf, "set-all", 7) == 0) {
        if (sscanf(cmd_buf, "set-all %15s %d", mode, &rpm) >= 1) {
            int m = (strcmp(mode, "manual") == 0) ? 1 : 0;
            int err = set_all_fans(m, (float)rpm);
            if (err == 0) {
                snprintf(resp_buf, resp_size, "{\"status\":\"ok\",\"action\":\"set-all\",\"mode\":\"%s\",\"rpm\":%d}\n", mode, rpm);
            } else {
                snprintf(resp_buf, resp_size, "{\"status\":\"error\",\"code\":%d,\"message\":\"smc write error\"}\n", err);
            }
            return 0;
        }
    }

    if (strncmp(cmd_buf, "set", 3) == 0) {
        if (sscanf(cmd_buf, "set %d %15s %d", &fan, mode, &rpm) >= 2) {
            int m = (strcmp(mode, "manual") == 0) ? 1 : 0;
            int err = set_fan(fan, m, (float)rpm);
            if (err == 0) {
                snprintf(resp_buf, resp_size, "{\"status\":\"ok\",\"fan\":%d,\"mode\":\"%s\",\"rpm\":%d}\n", fan, mode, rpm);
            } else {
                snprintf(resp_buf, resp_size, "{\"status\":\"error\",\"code\":%d,\"message\":\"smc write error\"}\n", err);
            }
            return 0;
        }
    }

    snprintf(resp_buf, resp_size, "{\"status\":\"error\",\"message\":\"unknown command\"}\n");
    return -1;
}

static int g_sfd = -1;
static const char *g_active_socket_path = NULL;

void sig_handler(int sig) {
    if (g_sfd >= 0) close(g_sfd);
    if (g_active_socket_path) unlink(g_active_socket_path);
    exit(0);
}

int run_daemon(void) {
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    const char *sock_path = PRIMARY_SOCKET;
    unlink(sock_path);

    int sfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sfd < 0) {
        sock_path = FALLBACK_SOCKET;
        unlink(sock_path);
        sfd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sfd < 0) {
            perror("socket failed");
            return 1;
        }
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sock_path, sizeof(addr.sun_path) - 1);

    if (bind(sfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        if (strcmp(sock_path, FALLBACK_SOCKET) != 0) {
            sock_path = FALLBACK_SOCKET;
            unlink(sock_path);
            memset(&addr, 0, sizeof(addr));
            addr.sun_family = AF_UNIX;
            strncpy(addr.sun_path, sock_path, sizeof(addr.sun_path) - 1);
            if (bind(sfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
                perror("bind fallback failed");
                return 1;
            }
        } else {
            perror("bind failed");
            return 1;
        }
    }

    chmod(sock_path, 0666);
    listen(sfd, 10);
    g_sfd = sfd;
    g_active_socket_path = sock_path;

    printf("lefan-helper daemon running on %s (uid=%d)\n", sock_path, getuid());
    fflush(stdout);

    while (1) {
        int cfd = accept(sfd, NULL, NULL);
        if (cfd < 0) continue;
        char inBuf[256] = {0};
        char outBuf[256] = {0};
        ssize_t n = read(cfd, inBuf, sizeof(inBuf) - 1);
        if (n > 0) {
            inBuf[n] = '\0';
            handle_command(inBuf, outBuf, sizeof(outBuf));
            write(cfd, outBuf, strlen(outBuf));
        }
        close(cfd);
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1) {
        if (strcmp(argv[1], "daemon") == 0) {
            return run_daemon();
        } else if (strcmp(argv[1], "status") == 0 || strcmp(argv[1], "ping") == 0) {
            char out[128];
            handle_command("ping", out, sizeof(out));
            printf("%s", out);
            return 0;
        } else if (strcmp(argv[1], "set") == 0 && argc >= 4) {
            char cmd[128];
            snprintf(cmd, sizeof(cmd), "set %s %s %s", argv[2], argv[3], (argc >= 5) ? argv[4] : "0");
            char out[256];
            handle_command(cmd, out, sizeof(out));
            printf("%s", out);
            return 0;
        } else if (strcmp(argv[1], "set-all") == 0 && argc >= 3) {
            char cmd[128];
            snprintf(cmd, sizeof(cmd), "set-all %s %s", argv[2], (argc >= 4) ? argv[3] : "0");
            char out[256];
            handle_command(cmd, out, sizeof(out));
            printf("%s", out);
            return 0;
        }
    }
    printf("Usage: lefan-helper [daemon | status | set <fan> <auto|manual> [rpm] | set-all <auto|manual> [rpm]]\n");
    return 0;
}
