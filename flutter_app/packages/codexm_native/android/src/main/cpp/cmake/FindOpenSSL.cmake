# Minimal OpenSSL finder for Android Prefab packages.
#
# We rely on ndk-pkg-prefab-aar-maven-repo's "openssl" package, which exposes
# CMake imported targets like:
#   openssl::headers
#   openssl::libssl.so / openssl::libssl.a
#   openssl::libcrypto.so / openssl::libcrypto.a
#
# This shim maps them to the variables/targets expected by libgit2.

find_package(openssl CONFIG QUIET)

if(openssl_FOUND)
  if(NOT TARGET OpenSSL::SSL)
    if(TARGET openssl::libssl.so)
      add_library(OpenSSL::SSL INTERFACE IMPORTED)
      target_link_libraries(OpenSSL::SSL INTERFACE openssl::libssl.so)
    elseif(TARGET openssl::libssl.a)
      add_library(OpenSSL::SSL INTERFACE IMPORTED)
      target_link_libraries(OpenSSL::SSL INTERFACE openssl::libssl.a)
    endif()
  endif()

  if(NOT TARGET OpenSSL::Crypto)
    if(TARGET openssl::libcrypto.so)
      add_library(OpenSSL::Crypto INTERFACE IMPORTED)
      target_link_libraries(OpenSSL::Crypto INTERFACE openssl::libcrypto.so)
    elseif(TARGET openssl::libcrypto.a)
      add_library(OpenSSL::Crypto INTERFACE IMPORTED)
      target_link_libraries(OpenSSL::Crypto INTERFACE openssl::libcrypto.a)
    endif()
  endif()

  set(OPENSSL_FOUND TRUE)
  if(TARGET openssl::headers)
    get_target_property(OPENSSL_INCLUDE_DIR openssl::headers INTERFACE_INCLUDE_DIRECTORIES)
  endif()
  set(OPENSSL_LIBRARIES OpenSSL::SSL OpenSSL::Crypto)
  set(OPENSSL_SSL_LIBRARY OpenSSL::SSL)
  set(OPENSSL_CRYPTO_LIBRARY OpenSSL::Crypto)
else()
  set(OPENSSL_FOUND FALSE)
  if(OpenSSL_FIND_REQUIRED)
    message(FATAL_ERROR "OpenSSL not found (expected Prefab package 'openssl')")
  endif()
endif()

