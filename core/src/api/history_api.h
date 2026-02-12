// Pasty - Copyright (c) 2026. MIT License.

#ifndef PASTY_API_HISTORY_API_H
#define PASTY_API_HISTORY_API_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

bool pasty_history_ingest_text(const char* text, const char* source_app_id);

bool pasty_history_ingest_image(
    const unsigned char* bytes,
    unsigned long byte_count,
    int width,
    int height,
    const char* format_hint,
    const char* source_app_id
);

const char* pasty_history_list_json(int limit);

bool pasty_history_search(const char* query, int limit, int preview_length, const char* content_type, bool include_ocr, char** out_json);

bool pasty_history_get_pending_ocr_images(int limit, char** out_json);

bool pasty_history_get_next_ocr_task(char** out_json);

bool pasty_history_ocr_mark_processing(const char* id);

bool pasty_history_ocr_success(const char* id, const char* ocr_text);

bool pasty_history_ocr_failed(const char* id);

bool pasty_history_get_ocr_status(const char* id, char** out_json);

char* pasty_history_get_json(const char* id);

void pasty_free_string(char* str);

bool pasty_history_delete(const char* id);

void pasty_history_set_storage_directory(const char* path);

void pasty_history_set_migration_directory(const char* path);

bool pasty_history_enforce_retention(int maxCount);

#ifdef __cplusplus
}
#endif

#endif
