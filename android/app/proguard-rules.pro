# Keep necessary annotations
-keep @interface com.google.errorprone.annotations.**
-keep @interface javax.annotation.**

# Keep Tink crypto library classes
-keep class com.google.crypto.tink.** { *; }

-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
-dontwarn com.google.api.client.http.GenericUrl
-dontwarn com.google.api.client.http.HttpHeaders
-dontwarn com.google.api.client.http.HttpRequest
-dontwarn com.google.api.client.http.HttpRequestFactory
-dontwarn com.google.api.client.http.HttpResponse
-dontwarn com.google.api.client.http.HttpTransport
-dontwarn com.google.api.client.http.javanet.NetHttpTransport$Builder
-dontwarn com.google.api.client.http.javanet.NetHttpTransport
-dontwarn javax.annotation.concurrent.ThreadSafe
-dontwarn org.joda.time.Instant