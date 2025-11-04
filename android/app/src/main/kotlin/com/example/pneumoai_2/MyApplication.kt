package com.example.pneumoai_6

import android.util.Log
import com.chaquo.python.android.PyApplication
import com.facebook.soloader.SoLoader

class MyApplication : PyApplication() {
    
    companion object {
        private const val TAG = "PneumoAI"
        private var pytorchLibrariesLoaded = false
    }
    
    override fun onCreate() {
        super.onCreate()
        
        try {
            // Initialize SoLoader
            SoLoader.init(this, false)
            Log.d(TAG, "✅ SoLoader initialized")
            
            // Load PyTorch native libraries in correct order
            loadPyTorchLibraries()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Application initialization failed: ${e.message}", e)
        }
    }
    
    private fun loadPyTorchLibraries() {
        if (pytorchLibrariesLoaded) {
            Log.d(TAG, "PyTorch libraries already loaded")
            return
        }
        
        try {
            // Load dependencies first
            try {
                SoLoader.loadLibrary("c++_shared")
                Log.d(TAG, "✅ Loaded c++_shared")
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "c++_shared already loaded or bundled: ${e.message}")
            }
            
            try {
                SoLoader.loadLibrary("fbjni")
                Log.d(TAG, "✅ Loaded fbjni")
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "fbjni load failed: ${e.message}")
            }
            
            // Load PyTorch JNI
            try {
                SoLoader.loadLibrary("pytorch_jni")
                Log.d(TAG, "✅ Loaded pytorch_jni")
                pytorchLibrariesLoaded = true
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "❌ CRITICAL: pytorch_jni not found: ${e.message}", e)
                throw e
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to load PyTorch libraries: ${e.message}", e)
            throw RuntimeException("PyTorch libraries not available", e)
        }
    }
}