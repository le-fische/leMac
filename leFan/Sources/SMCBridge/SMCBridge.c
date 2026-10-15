#include "SMCBridge.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

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
#define SMC_CMD_READ_INDEX 8
#define SMC_CMD_READ_KEYINFO 9

static io_connect_t g_conn = 0;

static uint32_t str_to_key(const char *str) {
    return ((uint8_t)str[0] << 24) |
           ((uint8_t)str[1] << 16) |
           ((uint8_t)str[2] << 8) |
           ((uint8_t)str[3]);
}

static void key_to_str(uint32_t key, char *str) {
    str[0] = (key >> 24) & 0xff;
    str[1] = (key >> 16) & 0xff;
    str[2] = (key >> 8) & 0xff;
    str[3] = key & 0xff;
    str[4] = '\0';
}

int smc_init(void) {
    if (g_conn) return 0;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return -1;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &g_conn);
    IOObjectRelease(service);
    return (kr == KERN_SUCCESS) ? 0 : -1;
}

void smc_cleanup(void); // forward declaration

// Implemented at bottom with HID cleanup

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

static int smc_read_bytes(uint32_t key, SMCKeyInfoData *info, unsigned char *out_bytes) {
    SMCKeyData in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = key;
    in.data8 = SMC_CMD_READ_BYTES;
    in.keyInfo.dataSize = info->dataSize;
    kern_return_t kr = smc_call(&in, &out);
    if (kr == KERN_SUCCESS && out.result == 0) {
        memcpy(out_bytes, out.bytes, info->dataSize);
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

static float decode_value(const char *dataType, uint32_t dataSize, unsigned char *bytes) {
    if (strncmp(dataType, "flt ", 4) == 0 && dataSize == 4) {
        float f;
        memcpy(&f, bytes, 4);
        return f;
    } else if (strncmp(dataType, "fpe2", 4) == 0 && dataSize == 2) {
        int val = (bytes[0] << 8) | bytes[1];
        return (float)val / 4.0f;
    } else if (strncmp(dataType, "sp78", 4) == 0 && dataSize == 2) {
        short val = (bytes[0] << 8) | bytes[1];
        return (float)val / 256.0f;
    } else if (strncmp(dataType, "ui8 ", 4) == 0 && dataSize == 1) {
        return (float)bytes[0];
    } else if (strncmp(dataType, "ui16", 4) == 0 && dataSize == 2) {
        return (float)((bytes[0] << 8) | bytes[1]);
    } else if (strncmp(dataType, "ui32", 4) == 0 && dataSize == 4) {
        return (float)((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]);
    }
    return 0.0f;
}

static float read_key_float(const char *kstr) {
    SMCKeyInfoData info;
    unsigned char bytes[32];
    uint32_t key = str_to_key(kstr);
    if (smc_read_key_info(key, &info) == 0 && smc_read_bytes(key, &info, bytes) == 0) {
        char typeStr[5];
        key_to_str(info.dataType, typeStr);
        return decode_value(typeStr, info.dataSize, bytes);
    }
    return 0.0f;
}

bool smc_is_apple_silicon(void) {
#if defined(__arm64__) || defined(__aarch64__)
    return true;
#else
    return false;
#endif
}

int smc_get_fan_count(void) {
    if (smc_init() != 0) return 0;
    SMCKeyInfoData info;
    unsigned char bytes[32];
    uint32_t key = str_to_key("FNum");
    if (smc_read_key_info(key, &info) == 0 && smc_read_bytes(key, &info, bytes) == 0) {
        return (int)bytes[0];
    }
    return 0;
}

bool smc_get_fan_info(int fanIndex, FanInfo_t *outInfo) {
    if (smc_init() != 0 || !outInfo) return false;
    memset(outInfo, 0, sizeof(FanInfo_t));
    outInfo->index = fanIndex;

    char keyActual[5], keyMin[5], keyMax[5], keyTarget[5], keyMode[5], keyDesc[5];
    snprintf(keyActual, sizeof(keyActual), "F%dAc", fanIndex);
    snprintf(keyMin, sizeof(keyMin), "F%dMn", fanIndex);
    snprintf(keyMax, sizeof(keyMax), "F%dMx", fanIndex);
    snprintf(keyTarget, sizeof(keyTarget), "F%dTg", fanIndex);
    snprintf(keyMode, sizeof(keyMode), "F%dMd", fanIndex);
    snprintf(keyDesc, sizeof(keyDesc), "F%dID", fanIndex);

    outInfo->actualRPM = read_key_float(keyActual);
    outInfo->minRPM = read_key_float(keyMin);
    outInfo->maxRPM = read_key_float(keyMax);
    outInfo->targetRPM = read_key_float(keyTarget);
    outInfo->mode = (int)read_key_float(keyMode);

    // Read fan description / name
    SMCKeyInfoData info;
    unsigned char bytes[32];
    if (smc_read_key_info(str_to_key(keyDesc), &info) == 0 && smc_read_bytes(str_to_key(keyDesc), &info, bytes) == 0) {
        int len = (info.dataSize < 31) ? info.dataSize : 31;
        memcpy(outInfo->name, bytes, len);
        outInfo->name[len] = '\0';
    } else {
        if (fanIndex == 0) {
            strncpy(outInfo->name, "Left Fan", sizeof(outInfo->name));
        } else if (fanIndex == 1) {
            strncpy(outInfo->name, "Right Fan", sizeof(outInfo->name));
        } else {
            snprintf(outInfo->name, sizeof(outInfo->name), "Fan %d", fanIndex + 1);
        }
    }

    return true;
}

bool smc_set_fan_mode(int fanIndex, int mode) {
    if (smc_init() != 0) return false;
    char keyMode[5];
    snprintf(keyMode, sizeof(keyMode), "F%dMd", fanIndex);
    uint32_t key = str_to_key(keyMode);

    unsigned char byte = (mode == 0) ? 0 : 1;
    return (smc_write_key(key, &byte, 1) == 0);
}

bool smc_set_fan_target_rpm(int fanIndex, float rpm) {
    if (smc_init() != 0) return false;
    char keyTg[5];
    snprintf(keyTg, sizeof(keyTg), "F%dTg", fanIndex);
    uint32_t key = str_to_key(keyTg);

    SMCKeyInfoData info;
    if (smc_read_key_info(key, &info) != 0) return false;

    if (info.dataSize == 4) {
        float f = rpm;
        return (smc_write_key(key, (unsigned char*)&f, 4) == 0);
    } else if (info.dataSize == 2) {
        uint16_t val = (uint16_t)(rpm * 4.0f);
        unsigned char buf[2] = { (unsigned char)(val >> 8), (unsigned char)(val & 0xff) };
        return (smc_write_key(key, buf, 2) == 0);
    }
    return false;
}

// IOHIDEvent declarations
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

#define IOHIDEventFieldBase(type) ((type) << 16)
#define kIOHIDEventTypeTemperature 15

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timeout);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

typedef struct {
    IOHIDServiceClientRef service;
    char key[16];
    char name[64];
    char category[32];
    bool isCPU;
} CachedSensor_t;

static IOHIDEventSystemClientRef g_hid_client = NULL;
static CachedSensor_t g_cached_sensors[128];
static int g_cached_sensor_count = 0;
static bool g_sensors_discovered = false;

static void format_friendly_name(const char *rawName, char *outName, size_t outSize, char *outCat, size_t catSize, bool *outIsCPU) {
    *outIsCPU = false;
    if (strncmp(rawName, "PMU tdie", 8) == 0) {
        int coreNum = atoi(rawName + 8);
        snprintf(outName, outSize, "CPU Core %d", coreNum);
        strncpy(outCat, "CPU", catSize);
        *outIsCPU = true;
    } else if (strcmp(rawName, "gas gauge battery") == 0) {
        strncpy(outName, "Battery", outSize);
        strncpy(outCat, "Battery", catSize);
    } else if (strncmp(rawName, "NAND", 4) == 0) {
        strncpy(outName, "Apple SSD (NAND)", outSize);
        strncpy(outCat, "Storage", catSize);
    } else if (strcmp(rawName, "PMU tcal") == 0) {
        strncpy(outName, "Power Management (PMU)", outSize);
        strncpy(outCat, "System", catSize);
    } else if (strstr(rawName, "GPU") || strstr(rawName, "gpu")) {
        snprintf(outName, outSize, "%s", rawName);
        strncpy(outCat, "GPU", catSize);
    } else {
        snprintf(outName, outSize, "%s", rawName);
        strncpy(outCat, "System", catSize);
        if (strstr(rawName, "CPU") || strstr(rawName, "Core")) {
            *outIsCPU = true;
        }
    }
}

static void ensure_hid_sensors_initialized(void) {
    if (g_sensors_discovered) return;
    g_sensors_discovered = true;

    if (!g_hid_client) {
        g_hid_client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (!g_hid_client) return;
    }

    int page = 0xff00;
    int usage = 5;
    CFNumberRef pageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
    CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *vals[] = { pageNum, usageNum };
    CFDictionaryRef matching = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 2,
                                                  &kCFTypeDictionaryKeyCallBacks,
                                                  &kCFTypeDictionaryValueCallBacks);
    IOHIDEventSystemClientSetMatching(g_hid_client, matching);
    CFRelease(matching);
    CFRelease(pageNum);
    CFRelease(usageNum);

    CFArrayRef services = IOHIDEventSystemClientCopyServices(g_hid_client);
    if (!services) return;

    CFIndex total = CFArrayGetCount(services);
    for (CFIndex i = 0; i < total && g_cached_sensor_count < 128; i++) {
        IOHIDServiceClientRef s = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        CFStringRef pName = (CFStringRef)IOHIDServiceClientCopyProperty(s, CFSTR("Product"));
        if (!pName) continue;

        char rawBuf[64];
        CFStringGetCString(pName, rawBuf, sizeof(rawBuf), kCFStringEncodingUTF8);
        CFRelease(pName);

        // Test one event read to verify validity
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(s, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;
        double val = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);
        if (val < 0.0 || val > 125.0) continue;

        // De-duplicate sensors by raw name
        bool isDup = false;
        for (int d = 0; d < g_cached_sensor_count; d++) {
            if (strcmp(g_cached_sensors[d].key, rawBuf) == 0) {
                isDup = true;
                break;
            }
        }
        if (isDup) continue;

        CachedSensor_t *cs = &g_cached_sensors[g_cached_sensor_count];
        cs->service = (IOHIDServiceClientRef)CFRetain(s);
        strncpy(cs->key, rawBuf, sizeof(cs->key) - 1);
        format_friendly_name(rawBuf, cs->name, sizeof(cs->name) - 1, cs->category, sizeof(cs->category) - 1, &cs->isCPU);
        g_cached_sensor_count++;
    }
    CFRelease(services);
}

bool smc_get_quick_cpu_temp(float *outCpuAvg, float *outCpuMax, float *outHighest) {
    ensure_hid_sensors_initialized();
    if (g_cached_sensor_count == 0) return false;

    float sum = 0.0f;
    int cpuCount = 0;
    float maxCpu = 0.0f;

    for (int i = 0; i < g_cached_sensor_count; i++) {
        CachedSensor_t *cs = &g_cached_sensors[i];
        if (!cs->isCPU) continue;
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(cs->service, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;
        double val = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);

        if (val < 0.0 || val > 125.0) continue;
        float fVal = (float)val;
        sum += fVal;
        cpuCount++;
        if (fVal > maxCpu) maxCpu = fVal;
    }

    if (cpuCount == 0) {
        // Fallback: if no sensors were tagged isCPU, query up to 4 sensors
        for (int i = 0; i < g_cached_sensor_count && cpuCount < 4; i++) {
            CachedSensor_t *cs = &g_cached_sensors[i];
            IOHIDEventRef event = IOHIDServiceClientCopyEvent(cs->service, kIOHIDEventTypeTemperature, 0, 0);
            if (!event) continue;
            double val = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
            CFRelease(event);
            if (val > 0.0 && val < 125.0) {
                float fVal = (float)val;
                sum += fVal;
                cpuCount++;
                if (fVal > maxCpu) maxCpu = fVal;
            }
        }
    }

    float avg = (cpuCount > 0) ? (sum / (float)cpuCount) : 40.0f;
    float mx = (cpuCount > 0) ? maxCpu : 40.0f;
    if (outCpuAvg) *outCpuAvg = avg;
    if (outCpuMax) *outCpuMax = mx;
    if (outHighest) *outHighest = mx;
    return true;
}

int smc_get_all_sensors(SensorInfo_t *outSensors, int maxSensors) {
    if (!outSensors || maxSensors <= 0) return 0;
    ensure_hid_sensors_initialized();

    int count = 0;
    for (int i = 0; i < g_cached_sensor_count && count < maxSensors; i++) {
        CachedSensor_t *cs = &g_cached_sensors[i];
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(cs->service, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;
        double val = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);

        if (val < 0.0 || val > 125.0) continue;

        SensorInfo_t *sensor = &outSensors[count];
        strncpy(sensor->key, cs->key, sizeof(sensor->key) - 1);
        strncpy(sensor->name, cs->name, sizeof(sensor->name) - 1);
        strncpy(sensor->category, cs->category, sizeof(sensor->category) - 1);
        sensor->temperatureC = (float)val;
        count++;
    }
    return count;
}

void smc_cleanup(void) {
    if (g_conn) {
        IOServiceClose(g_conn);
        g_conn = 0;
    }
    for (int i = 0; i < g_cached_sensor_count; i++) {
        if (g_cached_sensors[i].service) {
            CFRelease(g_cached_sensors[i].service);
            g_cached_sensors[i].service = NULL;
        }
    }
    g_cached_sensor_count = 0;
    g_sensors_discovered = false;

    if (g_hid_client) {
        CFRelease(g_hid_client);
        g_hid_client = NULL;
    }
}
