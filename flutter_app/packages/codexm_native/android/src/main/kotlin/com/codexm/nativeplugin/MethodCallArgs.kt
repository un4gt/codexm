package com.codexm.nativeplugin

import io.flutter.plugin.common.MethodCall

internal fun MethodCall.argsMap(): Map<*, *> {
    return arguments as? Map<*, *> ?: emptyMap<String, Any?>()
}

internal fun MethodCall.requiredString(key: String): String {
    return optionalString(key) ?: throw IllegalArgumentException("$key is required")
}

internal fun MethodCall.optionalString(key: String): String? {
    return argsMap()[key]?.toString()
}

internal fun MethodCall.optionalBoolean(key: String, fallback: Boolean = false): Boolean {
    return argsMap()[key] as? Boolean ?: fallback
}

internal fun MethodCall.optionalInt(key: String, fallback: Int): Int {
    val value = argsMap()[key]
    return when (value) {
        is Int -> value
        is Long -> value.toInt()
        else -> fallback
    }
}

internal fun MethodCall.optionalStringList(key: String): List<String>? {
    val value = argsMap()[key] as? List<*> ?: return null
    return value.mapNotNull { item -> item?.toString() }
}

internal fun MethodCall.optionalStringMap(key: String): Map<String, String>? {
    val value = argsMap()[key] as? Map<*, *> ?: return null
    val result = LinkedHashMap<String, String>()
    value.forEach { (rawKey, rawValue) ->
        if (rawKey != null && rawValue != null) {
            result[rawKey.toString()] = rawValue.toString()
        }
    }
    return result
}
