#ifndef MACZY_FFI_H
#define MACZY_FFI_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

const char* maczy_core_version(void);
uint32_t maczy_module_count(void);
const char* maczy_module_id(uint32_t index);
const char* maczy_module_name(uint32_t index);
bool maczy_module_is_implemented(uint32_t index);
char* maczy_module_status_message(uint32_t index);
void maczy_free_string(char* s);
uint32_t maczy_classify_leftover_path(const char* path);

#ifdef __cplusplus
}
#endif

#endif /* MACZY_FFI_H */
