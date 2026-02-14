#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* pasty_runtime_ref;

pasty_runtime_ref pasty_runtime_create(void);
void pasty_runtime_destroy(pasty_runtime_ref runtime);

bool pasty_runtime_start(
    pasty_runtime_ref runtime,
    const char* storage_directory,
    const char* migration_directory,
    int default_max_history_count
);
void pasty_runtime_stop(pasty_runtime_ref runtime);
bool pasty_runtime_is_started(pasty_runtime_ref runtime);

bool pasty_runtime_set_max_history_count(pasty_runtime_ref runtime, int max_count);
int pasty_runtime_get_max_history_count(pasty_runtime_ref runtime);

void pasty_settings_initialize(pasty_runtime_ref runtime, int max_history_count);
void pasty_settings_update(pasty_runtime_ref runtime, const char* key, const char* value);
int pasty_settings_get_max_history_count(pasty_runtime_ref runtime);

bool pasty_cloud_sync_import_now(pasty_runtime_ref runtime);
bool pasty_cloud_sync_get_status_json(pasty_runtime_ref runtime, char** out_json);
bool pasty_cloud_sync_e2ee_initialize(pasty_runtime_ref runtime, const char* passphrase);
void pasty_cloud_sync_e2ee_clear(pasty_runtime_ref runtime);

bool pasty_history_ingest_text(pasty_runtime_ref runtime, const char* text, const char* source_app_id);
bool pasty_history_ingest_text_with_result(pasty_runtime_ref runtime, const char* text, const char* source_app_id, bool* out_inserted);

bool pasty_history_ingest_image(
    pasty_runtime_ref runtime,
    const unsigned char* bytes,
    unsigned long byte_count,
    int width,
    int height,
    const char* format_hint,
    const char* source_app_id
);
bool pasty_history_ingest_image_with_result(
    pasty_runtime_ref runtime,
    const unsigned char* bytes,
    unsigned long byte_count,
    int width,
    int height,
    const char* format_hint,
    const char* source_app_id,
    bool* out_inserted
);

bool pasty_history_list_json(pasty_runtime_ref runtime, int limit, char** out_json);

bool pasty_history_search(
    pasty_runtime_ref runtime,
    const char* query,
    int limit,
    int preview_length,
    const char* content_type,
    bool include_ocr,
    char** out_json
);

bool pasty_history_get_pending_ocr_images(pasty_runtime_ref runtime, int limit, char** out_json);

bool pasty_history_get_next_ocr_task(pasty_runtime_ref runtime, char** out_json);

bool pasty_history_ocr_mark_processing(pasty_runtime_ref runtime, const char* id);

bool pasty_history_ocr_success(pasty_runtime_ref runtime, const char* id, const char* ocr_text);

bool pasty_history_ocr_failed(pasty_runtime_ref runtime, const char* id);

bool pasty_history_get_ocr_status(pasty_runtime_ref runtime, const char* id, char** out_json);

bool pasty_history_get_json(pasty_runtime_ref runtime, const char* id, char** out_json);

bool pasty_history_get_tags(pasty_runtime_ref runtime, const char* id, char** out_json);

bool pasty_history_set_tags(pasty_runtime_ref runtime, const char* id, const char* tags_json);

void pasty_free_string(char* str);

bool pasty_history_delete(pasty_runtime_ref runtime, const char* id);

bool pasty_history_enforce_retention(pasty_runtime_ref runtime, int maxCount);

#ifdef __cplusplus
}
#endif
