#ifndef SMC_BRIDGE_H
#define SMC_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int index;
    char name[32];
    float actualRPM;
    float minRPM;
    float maxRPM;
    float targetRPM;
    int mode; // 0 = Auto, 1 = Manual
} FanInfo_t;

typedef struct {
    char key[16];
    char name[64];
    char category[32]; // CPU, GPU, Battery, Storage, System, Other
    float temperatureC;
} SensorInfo_t;

int smc_init(void);
void smc_cleanup(void);

int smc_get_fan_count(void);
bool smc_get_fan_info(int fanIndex, FanInfo_t *outInfo);

int smc_get_all_sensors(SensorInfo_t *outSensors, int maxSensors);

bool smc_is_apple_silicon(void);

// Direct SMC writes (requires root/setuid privileges)
bool smc_set_fan_mode(int fanIndex, int mode);
bool smc_set_fan_target_rpm(int fanIndex, float rpm);

#ifdef __cplusplus
}
#endif

#endif /* SMC_BRIDGE_H */
