#include <ta-lib/ta_libc.h>

int main() {
    TA_Initialize();
    printf("TA-Lib initialized successfully\n");
    TA_Shutdown();
    return 0;
}
