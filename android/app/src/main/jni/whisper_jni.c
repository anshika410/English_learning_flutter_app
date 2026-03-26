#include <jni.h>
#include <string.h>
#include <stdlib.h>
#include "whisper.h"

static struct whisper_context *ctx = NULL;

JNIEXPORT jboolean JNICALL
Java_org_navgurukul_ella_ella_1flutter_WhisperEngine_nativeInit(
    JNIEnv *env, jobject thiz, jstring model_path) {
    if (ctx != NULL) {
        whisper_free(ctx);
        ctx = NULL;
    }
    const char *path = (*env)->GetStringUTFChars(env, model_path, NULL);
    struct whisper_context_params cparams = whisper_context_default_params();
    ctx = whisper_init_from_file_with_params(path, cparams);
    (*env)->ReleaseStringUTFChars(env, model_path, path);
    return ctx != NULL ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
Java_org_navgurukul_ella_ella_1flutter_WhisperEngine_nativeTranscribe(
    JNIEnv *env, jobject thiz, jfloatArray audio_data, jint n_samples) {
    if (ctx == NULL) {
        return (*env)->NewStringUTF(env, "");
    }

    jfloat *samples = (*env)->GetFloatArrayElements(env, audio_data, NULL);

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = 0;
    params.print_progress = 0;
    params.print_timestamps = 0;
    params.print_special = 0;
    params.n_threads = 4;
    params.language = "en";
    params.translate = 0;
    params.no_context = 1;
    params.single_segment = 1;

    int ret = whisper_full(ctx, params, samples, n_samples);
    (*env)->ReleaseFloatArrayElements(env, audio_data, samples, 0);

    if (ret != 0) {
        return (*env)->NewStringUTF(env, "");
    }

    // Collect all segments into one string
    int n_segments = whisper_full_n_segments(ctx);
    char result[4096] = "";
    int offset = 0;
    for (int i = 0; i < n_segments; i++) {
        const char *text = whisper_full_get_segment_text(ctx, i);
        int len = strlen(text);
        if (offset + len < 4095) {
            memcpy(result + offset, text, len);
            offset += len;
        }
    }
    result[offset] = '\0';

    return (*env)->NewStringUTF(env, result);
}

JNIEXPORT void JNICALL
Java_org_navgurukul_ella_ella_1flutter_WhisperEngine_nativeRelease(
    JNIEnv *env, jobject thiz) {
    if (ctx != NULL) {
        whisper_free(ctx);
        ctx = NULL;
    }
}
