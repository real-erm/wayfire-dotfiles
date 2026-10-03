#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <glob.h>
#include <stdint.h>

static int connect_wayfire(void) {
    glob_t gl;
    char pattern[256];
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    if (!runtime) {
        static char def_rt[64];
        snprintf(def_rt, sizeof(def_rt), "/run/user/%u", getuid());
        runtime = def_rt;
    }
    snprintf(pattern, sizeof(pattern), "%s/wayfire-*.socket", runtime);
    if (glob(pattern, 0, NULL, &gl) != 0 || gl.gl_pathc == 0) {
        return -1;
    }
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        globfree(&gl);
        return -1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, gl.gl_pathv[0], sizeof(addr.sun_path) - 1);
    globfree(&gl);
    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static int get_layout_index(int fd) {
    const char *req = "{\"method\":\"wayfire/get-keyboard-state\"}";
    uint32_t len = (uint32_t)strlen(req);
    if (write(fd, &len, 4) != 4) return 0;
    if (write(fd, req, len) != (ssize_t)len) return 0;
    uint32_t resp_len = 0;
    if (read(fd, &resp_len, 4) != 4) return 0;
    char buf[1024] = {0};
    if (resp_len >= sizeof(buf)) resp_len = sizeof(buf) - 1;
    if (read(fd, buf, resp_len) <= 0) return 0;

    if (strstr(buf, "\"layout\":\"Arabic\"") != NULL ||
        strstr(buf, "\"layout-index\":1") != NULL ||
        strstr(buf, "\"layout-index\": 1") != NULL) {
        return 1;
    }
    return 0;
}

static void set_layout_index(int fd, int idx) {
    char req[128];
    snprintf(req, sizeof(req), "{\"method\":\"wayfire/set-keyboard-state\",\"data\":{\"layout-index\":%d}}", idx);
    uint32_t len = (uint32_t)strlen(req);
    write(fd, &len, 4);
    write(fd, req, len);
    uint32_t resp_len = 0;
    read(fd, &resp_len, 4);
    char buf[256];
    if (resp_len < sizeof(buf)) read(fd, buf, resp_len);
}

int main(int argc, char **argv) {
    int fd = connect_wayfire();
    if (fd < 0) {
        printf("US\n");
        return 0;
    }

    int is_toggle = (argc > 1 && strcmp(argv[1], "toggle") == 0);

    if (is_toggle) {
        int curr = get_layout_index(fd);
        int next = (curr == 0) ? 1 : 0;
        set_layout_index(fd, next);
        close(fd);

        if (next == 1) {
            system("notify-send -t 1200 -h string:x-canonical-private-synchronous:layout 'Keyboard Layout' 'Switched to: Arabic (العربية)' 2>/dev/null || true");
        } else {
            system("notify-send -t 1200 -h string:x-canonical-private-synchronous:layout 'Keyboard Layout' 'Switched to: English (US)' 2>/dev/null || true");
        }
        system("pkill -RTMIN+8 waybar 2>/dev/null || true");
        printf("%s\n", (next == 1) ? "AR" : "US");
        return 0;
    }

    int curr = get_layout_index(fd);
    close(fd);
    printf("%s\n", (curr == 1) ? "AR" : "US");
    return 0;
}
