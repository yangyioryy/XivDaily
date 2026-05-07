package com.xivdaily.app.data.remote

import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import java.util.concurrent.TimeUnit

object NetworkModule {
    fun createApiService(baseUrl: String): ApiService {
        val moshi = Moshi.Builder()
            .add(KotlinJsonAdapterFactory())
            .build()
        val okHttpClient = OkHttpClient.Builder()
            .connectTimeout(DEFAULT_CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            // 论文对话可能等待后端下载 PDF 和调用 LLM，客户端超时需要长于后端 LLM 超时。
            .readTimeout(PAPER_CHAT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .callTimeout(PAPER_CHAT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .build()

        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(ApiService::class.java)
    }

    private const val DEFAULT_CONNECT_TIMEOUT_SECONDS = 20L
    private const val PAPER_CHAT_TIMEOUT_SECONDS = 75L
}
