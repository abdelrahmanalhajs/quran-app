package com.abdelrahmanalhajs.quranapp

import android.hardware.GeomagneticField
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Subclasses [AudioServiceActivity] (required by just_audio_background) and adds
 * one extra platform method: the magnetic declination at a location.
 *
 * The Qiblah bearing is computed from TRUE north, but Android's compass
 * (TYPE_ROTATION_VECTOR, via flutter_compass) reports heading relative to
 * MAGNETIC north. Without correcting for the declination between them, the
 * Qiblah arrow points off by several degrees — the bug where it "doesn't face
 * the right way". [GeomagneticField] gives the exact declination for the user's
 * coordinates so the Dart side can turn the magnetic heading into a true one.
 * (iOS already returns CoreLocation's trueHeading, so it needs no correction.)
 */
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qibla/declination")
            .setMethodCallHandler { call, result ->
                if (call.method == "declination") {
                    val lat = (call.argument<Double>("lat") ?: 0.0).toFloat()
                    val lng = (call.argument<Double>("lng") ?: 0.0).toFloat()
                    val field = GeomagneticField(
                        lat, lng, 0f, System.currentTimeMillis()
                    )
                    result.success(field.declination.toDouble())
                } else {
                    result.notImplemented()
                }
            }
    }
}
