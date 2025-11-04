package com.example.pneumoai_6

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import com.chaquo.python.Python
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import org.pytorch.IValue
import org.pytorch.Module
import org.pytorch.Tensor
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ai_inference"
    private val TAG = "PneumoAI"

    private var trainX_mean: FloatArray? = null
    private var trainInput_std: FloatArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "App started successfully")

        try {
            loadNormalizationParams()
            Log.d(TAG, "✅ Normalization params loaded: mean size=${trainX_mean?.size}, std size=${trainInput_std?.size}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to load normalization params: ${e.message}", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                
                when (call.method) {
                    "getXrayModelPath" -> {
                        try {
                            Log.d(TAG, "Getting X-ray model path")
                            ensureModelAsset("models/chest_xray_model.tflite")
                            val base = File(filesDir, "chaquopy/AssetFinder/app/python")
                            val path = File(File(base, "models"), "chest_xray_model.tflite").absolutePath
                            Log.d(TAG, "X-ray model path: $path")
                            result.success(path)
                        } catch (e: Exception) {
                            Log.e(TAG, "Model path error: ${e.message}", e)
                            result.error("MODEL_PATH_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                    
                    "predictStethoscope" -> {
                        val fileName = call.argument<String>("audio") ?: ""
                        Log.d(TAG, "🎙️ Stethoscope prediction requested for: $fileName")

                        try {
                            val audioFile = File(fileName)
                            if (!audioFile.exists()) {
                                Log.e(TAG, "Audio file not found: $fileName")
                                result.error("FILE_NOT_FOUND", "Audio file not found: $fileName", null)
                                return@setMethodCallHandler
                            }
                            Log.d(TAG, "Audio file exists: ${audioFile.length()} bytes")

                            if (trainX_mean == null || trainInput_std == null) {
                                Log.e(TAG, "Normalization parameters not loaded!")
                                result.error("NORMALIZATION_ERROR", 
                                    "Normalization parameters not loaded.", null)
                                return@setMethodCallHandler
                            }

                            Log.d(TAG, "Loading PyTorch model...")
                            ensureModelAsset("models/stethoscope_model.ptl")
                            
                            val base = File(filesDir, "chaquopy/AssetFinder/app/python")
                            val modelFile = File(File(base, "models"), "stethoscope_model.ptl")
                            
                            if (!modelFile.exists()) {
                                Log.e(TAG, "Model file not found: ${modelFile.absolutePath}")
                                result.error("MODEL_NOT_FOUND", "Model file not found", null)
                                return@setMethodCallHandler
                            }

                            val ptModel = Module.load(modelFile.absolutePath)
                            Log.d(TAG, "✅ PyTorch model loaded")

                            Log.d(TAG, "Preprocessing audio...")
                            val inputFeatures = preprocessAudioToFloatArray(fileName)
                            
                            if (inputFeatures.size != 40) {
                                result.error("INVALID_FEATURES", 
                                    "Expected 40 features, got ${inputFeatures.size}", null)
                                return@setMethodCallHandler
                            }

                            Log.d(TAG, "Running inference...")
                            val inputTensor = Tensor.fromBlob(inputFeatures, longArrayOf(1, 40))
                            val outputTensor = ptModel.forward(IValue.from(inputTensor)).toTensor()
                            val outputArray = outputTensor.dataAsFloatArray
                            Log.d(TAG, "Raw output: ${outputArray.contentToString()}")

                            val labels = listOf("Both", "Crackle", "Normal", "Wheeze")
                            val validOutputs = outputArray.take(labels.size).toFloatArray()

                            val maxVal = validOutputs.maxOrNull() ?: 0f
                            val exps = validOutputs.map { exp((it - maxVal).toDouble()) }
                            val sumExps = exps.sum()
                            val probs = exps.map { it / sumExps }

                            val conf = HashMap<String, Double>()
                            for (i in labels.indices) {
                                conf[labels[i]] = if (i < probs.size) probs[i] else 0.0
                            }

                            val maxProb = probs.maxOrNull() ?: 0.0
                            val maxIndex = probs.indexOf(maxProb)
                            val predLabel = labels.getOrElse(maxIndex) { labels[0] }

                            val resultMap = HashMap<String, Any?>()
                            resultMap["prediction"] = predLabel
                            resultMap["confidence"] = conf

                            Log.d(TAG, "✅ Prediction: $predLabel (${(maxProb * 100).toInt()}%)")
                            result.success(resultMap)

                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Stethoscope error: ${e.message}", e)
                            result.error("PTL_ERROR", e.message, e.stackTraceToString())
                        }
                    }

                    "predictXray" -> {
                        val fileName = call.argument<String>("image") ?: ""
                        Log.d(TAG, "🩻 X-ray prediction requested for: $fileName")
                        try {
                            val predMap = predictXrayNative(fileName)
                            Log.d(TAG, "✅ X-ray prediction successful")
                            result.success(predMap)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ X-ray error: ${e.message}", e)
                            result.error("TFLITE_ERROR", e.message, e.stackTraceToString())
                        }
                    }
                    
                    else -> result.notImplemented()
                }
            }
    }

    private fun loadNormalizationParams() {
        try {
            val jsonString = assets.open("models/normalization_params.json")
                .bufferedReader()
                .use { it.readText() }
            
            val jsonObject = JSONObject(jsonString)
            
            val meanArray = jsonObject.getJSONArray("X_mean")
            trainX_mean = FloatArray(meanArray.length()) { i ->
                meanArray.getDouble(i).toFloat()
            }
            
            val stdArray = jsonObject.getJSONArray("input_std")
            trainInput_std = FloatArray(stdArray.length()) { i ->
                stdArray.getDouble(i).toFloat()
            }
            
            Log.d(TAG, "Loaded X_mean[0..5]: ${trainX_mean?.take(5)?.joinToString()}")
            Log.d(TAG, "Loaded input_std[0..5]: ${trainInput_std?.take(5)?.joinToString()}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load normalization params: ${e.message}", e)
            throw e
        }
    }

    private fun preprocessAudioToFloatArray(filePath: String): FloatArray {
        val file = File(filePath)
        if (!file.exists()) throw IllegalArgumentException("Audio file not found: $filePath")

        val sampleRate = 22050
        val frameSize = 512
        val hopSize = 256
        val nCoefficients = 40
        val nFilters = 20
        val lowFreq = 300f
        val highFreq = 8000f

        val audioSamples = readWavFile(filePath, sampleRate)
        
        if (audioSamples.isEmpty()) {
            throw IllegalArgumentException("No audio samples read from file")
        }

        val mfccCalculator = MFCCCalculator(
            sampleRate, frameSize, nCoefficients, nFilters, lowFreq, highFreq
        )

        val mfccFeatures = FloatArray(nCoefficients)
        var frameCount = 0

        var i = 0
        while (i + frameSize <= audioSamples.size) {
            val frame = audioSamples.sliceArray(i until i + frameSize)
            val frameMfcc = mfccCalculator.process(frame)
            
            for (j in frameMfcc.indices) {
                mfccFeatures[j] += frameMfcc[j]
            }
            frameCount++
            i += hopSize
        }

        if (frameCount == 0) {
            throw IllegalArgumentException("Audio file too short, no frames processed")
        }

        for (j in mfccFeatures.indices) {
            mfccFeatures[j] /= frameCount
        }

        if (trainX_mean == null || trainInput_std == null) {
            throw IllegalStateException("Normalization parameters not loaded!")
        }

        for (j in mfccFeatures.indices) {
            mfccFeatures[j] = (mfccFeatures[j] - trainX_mean!![j]) / trainInput_std!![j]
        }

        Log.d(TAG, "MFCC normalized [0..5]: ${mfccFeatures.take(5).joinToString { "%.3f".format(it) }}")
        return mfccFeatures
    }

    private fun readWavFile(filePath: String, targetSampleRate: Int): FloatArray {
        return try {
            val extractor = MediaExtractor()
            extractor.setDataSource(filePath)
            
            var audioTrackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    break
                }
            }
            
            if (audioTrackIndex == -1) throw IllegalArgumentException("No audio track")
            
            extractor.selectTrack(audioTrackIndex)
            val buffer = ByteBuffer.allocate(1024 * 1024)
            val samples = mutableListOf<Float>()
            
            while (true) {
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                
                buffer.rewind()
                for (i in 0 until sampleSize step 2) {
                    val sample = buffer.short.toFloat() / 32768f
                    samples.add(sample)
                }
                
                extractor.advance()
            }
            
            extractor.release()
            samples.toFloatArray()
            
        } catch (e: Exception) {
            Log.w(TAG, "MediaExtractor failed: ${e.message}")
            readRawWavFile(filePath)
        }
    }

    private fun readRawWavFile(filePath: String): FloatArray {
        val raf = RandomAccessFile(filePath, "r")
        raf.seek(44)
        
        val samples = mutableListOf<Float>()
        val buffer = ByteArray(2)
        
        while (raf.read(buffer) == 2) {
            val sample = (buffer[1].toInt() shl 8 or (buffer[0].toInt() and 0xFF)).toShort()
            samples.add(sample.toFloat() / 32768f)
        }
        
        raf.close()
        return samples.toFloatArray()
    }

    inner class MFCCCalculator(
        private val sampleRate: Int,
        private val frameSize: Int,
        private val nCoefficients: Int,
        private val nFilters: Int,
        private val lowFreq: Float,
        private val highFreq: Float
    ) {
        private val fftBins = frameSize / 2
        private val melFilterbank = createMelFilterbank()
        
        fun process(frame: FloatArray): FloatArray {
            val windowed = applyHammingWindow(frame)
            val powerSpectrum = computePowerSpectrum(windowed)
            val melEnergies = applyMelFilterbank(powerSpectrum)
            val logMel = melEnergies.map { ln(it + 1e-10f) }.toFloatArray()
            val mfcc = dct(logMel)
            return mfcc.sliceArray(0 until minOf(nCoefficients, mfcc.size))
        }
        
        private fun applyHammingWindow(signal: FloatArray): FloatArray {
            return FloatArray(signal.size) { i ->
                signal[i] * (0.54f - 0.46f * cos(2 * PI * i / (signal.size - 1))).toFloat()
            }
        }
        
        private fun computePowerSpectrum(signal: FloatArray): FloatArray {
            val fft = fft(signal)
            return FloatArray(fftBins) { i ->
                val real = fft[i * 2]
                val imag = fft[i * 2 + 1]
                real * real + imag * imag
            }
        }
        
        private fun fft(input: FloatArray): FloatArray {
            val n = input.size
            val output = FloatArray(n * 2)
            
            for (i in input.indices) {
                output[i * 2] = input[i]
                output[i * 2 + 1] = 0f
            }
            
            fftRadix2(output, n)
            return output
        }
        
        private fun fftRadix2(data: FloatArray, n: Int) {
            var j = 0
            for (i in 0 until n - 1) {
                if (i < j) {
                    var temp = data[i * 2]
                    data[i * 2] = data[j * 2]
                    data[j * 2] = temp
                    temp = data[i * 2 + 1]
                    data[i * 2 + 1] = data[j * 2 + 1]
                    data[j * 2 + 1] = temp
                }
                var k = n / 2
                while (k <= j) {
                    j -= k
                    k /= 2
                }
                j += k
            }
            
            var length = 2
            while (length <= n) {
                val angle = -2.0 * PI / length
                for (i in 0 until n step length) {
                    var k = 0
                    while (k < length / 2) {
                        val wReal = cos(angle * k).toFloat()
                        val wImag = sin(angle * k).toFloat()
                        val evenIdx = (i + k) * 2
                        val oddIdx = (i + k + length / 2) * 2
                        
                        val tempReal = wReal * data[oddIdx] - wImag * data[oddIdx + 1]
                        val tempImag = wReal * data[oddIdx + 1] + wImag * data[oddIdx]
                        
                        data[oddIdx] = data[evenIdx] - tempReal
                        data[oddIdx + 1] = data[evenIdx + 1] - tempImag
                        data[evenIdx] += tempReal
                        data[evenIdx + 1] += tempImag
                        k++
                    }
                }
                length *= 2
            }
        }
        
        private fun createMelFilterbank(): Array<FloatArray> {
            val melLow = hzToMel(lowFreq)
            val melHigh = hzToMel(highFreq)
            val melPoints = FloatArray(nFilters + 2) { i ->
                melLow + (melHigh - melLow) * i / (nFilters + 1)
            }
            val hzPoints = melPoints.map { melToHz(it) }
            
            val bins = hzPoints.map { hz ->
                val bin = ((hz * frameSize) / sampleRate).toInt()
                bin.coerceIn(0, fftBins - 1)
            }
            
            return Array(nFilters) { i ->
                FloatArray(fftBins) { j ->
                    when {
                        j < bins[i] || j > bins[i + 2] -> 0f
                        j < bins[i + 1] -> {
                            val denominator = bins[i + 1] - bins[i]
                            if (denominator > 0) (j - bins[i]).toFloat() / denominator else 0f
                        }
                        else -> {
                            val denominator = bins[i + 2] - bins[i + 1]
                            if (denominator > 0) (bins[i + 2] - j).toFloat() / denominator else 0f
                        }
                    }
                }
            }
        }
        
        private fun applyMelFilterbank(powerSpectrum: FloatArray): FloatArray {
            return FloatArray(nFilters) { i ->
                var sum = 0f
                val maxIdx = minOf(powerSpectrum.size, melFilterbank[i].size)
                for (j in 0 until maxIdx) {
                    sum += powerSpectrum[j] * melFilterbank[i][j]
                }
                sum
            }
        }
        
        private fun dct(input: FloatArray): FloatArray {
            val n = input.size
            return FloatArray(n) { k ->
                var sum = 0.0
                for (i in 0 until n) {
                    sum += input[i] * cos(PI * k * (i + 0.5) / n)
                }
                sum.toFloat()
            }
        }
        
        private fun hzToMel(hz: Float) = 2595 * log10(1 + hz / 700f)
        private fun melToHz(mel: Float) = 700 * (10.0.pow(mel / 2595.0) - 1).toFloat()
    }

    // ✅ FIXED: TFLite X-ray prediction with NHWC layout
    private fun predictXrayNative(imagePath: String): HashMap<String, Any?> {
        ensureModelAsset("models/chest_xray_model.tflite")
        val base = File(filesDir, "chaquopy/AssetFinder/app/python")
        val modelFile = File(File(base, "models"), "chest_xray_model.tflite")
        val interpreter = Interpreter(modelFile)

        val inputTensor = interpreter.getInputTensor(0)
        val shape: IntArray = inputTensor.shape()
        Log.d(TAG, "TFLite input shape: ${shape.contentToString()}")

        val bitmap: Bitmap = BitmapFactory.decodeFile(imagePath)
            ?: throw IllegalArgumentException("Image not found: $imagePath")
        
        Log.d(TAG, "Original image: ${bitmap.width}x${bitmap.height}, config=${bitmap.config}")
        
        val input: ByteBuffer = bitmapToTensor(bitmap, shape)

        val outputTensor = interpreter.getOutputTensor(0)
        val outShape: IntArray = outputTensor.shape()
        Log.d(TAG, "TFLite output shape: ${outShape.contentToString()}")

        val output: Any = when (outShape.size) {
            1 -> FloatArray(outShape[0])
            2 -> Array(outShape[0]) { FloatArray(outShape[1]) }
            else -> FloatArray(2)
        }

        interpreter.run(input, output)

        val probs: FloatArray = when (output) {
            is FloatArray -> output
            is Array<*> -> (output as Array<FloatArray>)[0]
            else -> FloatArray(0)
        }

        Log.d(TAG, "TFLite raw output: ${probs.contentToString()}")

        val result = HashMap<String, Any?>()
        val conf = HashMap<String, Double>()
        
        if (probs.size == 1) {
            // Single output (binary classification with sigmoid)
            val rawOutput = probs[0].toDouble()
            
            // ✅ Check if already sigmoid-ed (0-1 range) or needs sigmoid
            val p1 = if (rawOutput in -10.0..10.0 && rawOutput !in 0.0..1.0) {
                // Looks like logit, apply sigmoid
                Log.d(TAG, "Applying sigmoid to logit: $rawOutput")
                sigmoid(rawOutput)
            } else {
                // Already probability
                Log.d(TAG, "Using raw output as probability: $rawOutput")
                rawOutput.coerceIn(0.0, 1.0)
            }
            
            conf["Pneumonia"] = p1
            conf["Healthy"] = 1.0 - p1
            result["prediction"] = if (p1 > 0.5) "Pneumonia" else "Healthy"
            
        } else if (probs.size >= 2) {
            // Two outputs (softmax)
            val p0 = probs[0].toDouble()
            val p1 = probs[1].toDouble()
            val m = maxOf(p0, p1)
            val e0 = kotlin.math.exp(p0 - m)
            val e1 = kotlin.math.exp(p1 - m)
            val s = e0 + e1
            conf["Healthy"] = e0 / s
            conf["Pneumonia"] = e1 / s
            result["prediction"] = if (conf["Pneumonia"]!! > conf["Healthy"]!!) "Pneumonia" else "Healthy"
        }

        Log.d(TAG, "Final confidences: $conf")
        result["confidence"] = conf
        return result
    }

    // ✅ FIXED: NHWC layout for TFLite
    private fun bitmapToTensor(bmp: Bitmap, shape: IntArray): ByteBuffer {
        // Determine layout from shape
        val isNHWC = shape.size == 4 && shape[3] in 1..4
        
        val inputHeight = if (isNHWC) shape[1] else (shape.getOrNull(2) ?: 224)
        val inputWidth = if (isNHWC) shape[2] else (shape.getOrNull(3) ?: 224)
        val inputChannels = if (isNHWC) shape[3] else (shape.getOrNull(1) ?: 3)

        Log.d(TAG, "Tensor layout: ${if (isNHWC) "NHWC" else "NCHW"}, size: ${inputWidth}x${inputHeight}x${inputChannels}")

        val mean = floatArrayOf(0.485f, 0.456f, 0.406f)
        val std = floatArrayOf(0.229f, 0.224f, 0.225f)

        val resizedBmp = Bitmap.createScaledBitmap(bmp, inputWidth, inputHeight, true)

        val buf: ByteBuffer = ByteBuffer.allocateDirect(1 * inputChannels * inputHeight * inputWidth * 4)
            .apply { order(ByteOrder.nativeOrder()) }

        val pixels = IntArray(inputWidth * inputHeight)
        resizedBmp.getPixels(pixels, 0, inputWidth, 0, 0, inputWidth, inputHeight)

        if (isNHWC) {
            // ✅ NHWC: [Height, Width, Channels]
            for (y in 0 until inputHeight) {
                for (x in 0 until inputWidth) {
                    val idx = y * inputWidth + x
                    val pixel = pixels[idx]
                    
                    val r = ((pixel shr 16) and 0xFF).toFloat() / 255.0f
                    val g = ((pixel shr 8) and 0xFF).toFloat() / 255.0f
                    val b = (pixel and 0xFF).toFloat() / 255.0f
                    
                    buf.putFloat((r - mean[0]) / std[0])
                    buf.putFloat((g - mean[1]) / std[1])
                    buf.putFloat((b - mean[2]) / std[2])
                }
            }
        } else {
            // NCHW: [Channels, Height, Width]
            for (c in 0 until inputChannels) {
                for (y in 0 until inputHeight) {
                    for (x in 0 until inputWidth) {
                        val idx = y * inputWidth + x
                        val pixel = pixels[idx]
                        val value = when(c) {
                            0 -> ((pixel shr 16) and 0xFF).toFloat() / 255.0f
                            1 -> ((pixel shr 8) and 0xFF).toFloat() / 255.0f
                            else -> (pixel and 0xFF).toFloat() / 255.0f
                        }
                        buf.putFloat((value - mean[c]) / std[c])
                    }
                }
            }
        }
        
        buf.rewind()
        
        // Log first few values for debugging
        val preview = FloatArray(10)
        for (i in 0 until 10) {
            preview[i] = buf.getFloat(i * 4)
        }
        Log.d(TAG, "Tensor first 10 values: ${preview.joinToString { "%.3f".format(it) }}")
        buf.rewind()
        
        return buf
    }

    private fun sigmoid(x: Double): Double = 1.0 / (1.0 + kotlin.math.exp(-x))

    private fun ensureModelAsset(assetPath: String) {
        val base = File(filesDir, "chaquopy/AssetFinder/app/python")
        val modelsDir = File(base, "models")
        if (!modelsDir.exists()) modelsDir.mkdirs()

        val fileName = assetPath.substringAfterLast('/')
        val dest = File(modelsDir, fileName)
        if (dest.exists() && dest.length() > 0) return

        assets.open(assetPath).use { input ->
            FileOutputStream(dest).use { out ->
                val buf = ByteArray(8 * 1024)
                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    out.write(buf, 0, n)
                }
                out.flush()
            }
        }
    }
}