package flutter.overlay.window.flutter_overlay_window;

import android.app.Activity;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import java.util.Map;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterEngineGroup;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.JSONMessageCodec;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

public class FlutterOverlayWindowPlugin implements
        FlutterPlugin, ActivityAware, BasicMessageChannel.MessageHandler, MethodCallHandler,
        PluginRegistry.ActivityResultListener {

    private MethodChannel channel;
    private Context context;
    private Activity mActivity;
    private BasicMessageChannel<Object> messenger;
    private Result pendingResult;
    final int REQUEST_CODE_FOR_OVERLAY_PERMISSION = 1248;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), OverlayConstants.CHANNEL_TAG);
        channel.setMethodCallHandler(this);

        messenger = new BasicMessageChannel(flutterPluginBinding.getBinaryMessenger(), OverlayConstants.MESSENGER_TAG,
                JSONMessageCodec.INSTANCE);
        messenger.setMessageHandler(this);

        WindowSetup.messenger = messenger;
        WindowSetup.messenger.setMessageHandler(this);
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        pendingResult = result;
        if (call.method.equals("checkPermission")) {
            result.success(checkOverlayPermission());
        } else if (call.method.equals("requestPermission")) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
                intent.setData(Uri.parse("package:" + mActivity.getPackageName()));
                mActivity.startActivityForResult(intent, REQUEST_CODE_FOR_OVERLAY_PERMISSION);
            } else {
                result.success(true);
            }
        } else if (call.method.equals("showOverlay")) {
            if (!checkOverlayPermission()) {
                result.error("PERMISSION", "overlay permission is not enabled", null);
                return;
            }
            Integer height = call.argument("height");
            Integer width = call.argument("width");
            String alignment = call.argument("alignment");
            String flag = call.argument("flag");
            String overlayTitle = call.argument("overlayTitle");
            String overlayContent = call.argument("overlayContent");
            String notificationVisibility = call.argument("notificationVisibility");
            boolean enableDrag = call.argument("enableDrag");
            String positionGravity = call.argument("positionGravity");
            Map<String, Integer> startPosition = call.argument("startPosition");
            int startX = startPosition != null ? startPosition.getOrDefault("x", OverlayConstants.DEFAULT_XY) : OverlayConstants.DEFAULT_XY;
            int startY = startPosition != null ? startPosition.getOrDefault("y", OverlayConstants.DEFAULT_XY) : OverlayConstants.DEFAULT_XY;


            WindowSetup.width = width != null ? width : -1;
            WindowSetup.height = height != null ? height : -1;
            WindowSetup.enableDrag = enableDrag;
            WindowSetup.setGravityFromAlignment(alignment != null ? alignment : "center");
            WindowSetup.setFlag(flag != null ? flag : "flagNotFocusable");
            WindowSetup.overlayTitle = overlayTitle;
            WindowSetup.overlayContent = overlayContent == null ? "" : overlayContent;
            WindowSetup.positionGravity = positionGravity;
            WindowSetup.setNotificationVisibility(notificationVisibility);

            final Intent intent = new Intent(context, OverlayService.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
            intent.putExtra("startX", startX);
            intent.putExtra("startY", startY);
            // NRIDE PATCH: startForegroundService, not startService.
            //
            // OverlayService calls startForeground() in its own onCreate, so it
            // is a foreground service and always was — but starting it with
            // startService() is only legal while the app is already in the
            // foreground. When a ride-request push arrives with the driver's
            // app closed, this runs from a background process and Android 8+
            // throws BackgroundServiceStartNotAllowedException, so no overlay
            // is ever shown in the one case the feature exists for.
            //
            // startForegroundService() is the sanctioned call for exactly this,
            // and an app holding SYSTEM_ALERT_WINDOW (which any caller of
            // showOverlay must, or the permission check above would have
            // failed) is exempt from Android 12's further restrictions on
            // starting foreground services from the background.
            ContextCompat.startForegroundService(context, intent);
            result.success(null);
        } else if (call.method.equals("isOverlayActive")) {
            result.success(OverlayService.isRunning);
            return;
        } else if (call.method.equals("isOverlayActive")) {
            result.success(OverlayService.isRunning);
            return;
        } else if (call.method.equals("moveOverlay")) {
            int x = call.argument("x");
            int y = call.argument("y");
            result.success(OverlayService.moveOverlay(x, y));
        } else if (call.method.equals("getOverlayPosition")) {
            result.success(OverlayService.getCurrentPosition());
        } else if (call.method.equals("closeOverlay")) {
            // NRIDE PATCH: reply on BOTH paths.
            //
            // This used to return without completing the result when no
            // overlay was running. A MethodChannel result that is never
            // completed leaves the Dart Future pending forever — it does not
            // throw, resolve to null, or time out, so awaiting closeOverlay()
            // simply never came back, and any code that closed a stale overlay
            // before showing a new one deadlocked on its second line.
            if (OverlayService.isRunning) {
                // NRIDE PATCH: Dart asked for this close, so onDestroy must not
                // broadcast a dismissal for it — see WindowSetup's own note.
                WindowSetup.suppressDismissBroadcast = true;
                final Intent i = new Intent(context, OverlayService.class);
                context.stopService(i);
                result.success(true);
            } else {
                result.success(false);
            }
            return;
        } else {
            result.notImplemented();
        }

    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        WindowSetup.messenger.setMessageHandler(null);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        mActivity = binding.getActivity();
        // NRIDE PATCH: the overlay engine is NOT built here any more.
        //
        // This ran while the Activity was being created, on the main thread,
        // and createAndRunEngine() is not cheap: it loads the app bundle and
        // spins up a second Dart isolate. Every single app launch paid for it,
        // including the overwhelming majority that never show an overlay at
        // all — and it was paid at the worst possible moment, before Flutter
        // had rendered its first frame. What the driver saw was a white screen
        // for several seconds after tapping Accept, long enough to read as the
        // app having hung or crashed.
        //
        // Nothing needs the engine to exist this early. OverlayService.onCreate
        // builds one when it finds no live engine in the cache, so a raise that
        // arrives before anything else has warmed one still works; and
        // MainActivity now warms it just after the first frame, off the startup
        // critical path, so in practice one is ready long before any push.
        //
        // Left as the plain assignment above deliberately — mActivity is what
        // this callback is actually for.
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        this.mActivity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
    }

    @Override
    public void onMessage(@Nullable Object message, @NonNull BasicMessageChannel.Reply reply) {
        // NRIDE PATCH: forward to the OverlayService's live engine when there
        // is one, and never NPE when there isn't.
        //
        // This used to dereference FlutterEngineCache.get(CACHED_TAG) blind. A
        // null there — or an engine that is cached but no longer running Dart —
        // throws inside this handler, which BasicMessageChannel swallows: the
        // Dart shareData() future completes normally with a null reply, so the
        // caller logs a successful send for a message that reached nobody.
        // That is exactly how eight "hint sent" lines accompanied a router that
        // received nothing, and an overlay window that attached empty.
        io.flutter.embedding.engine.FlutterEngine engine =
                FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);
        if (engine == null || !engine.getDartExecutor().isExecutingDart()) {
            Log.w("NrideOverlayMsg", "no live overlay engine in the cache"
                    + " (engine=" + (engine == null ? "null" : "dead") + ")");
            reply.reply(null);
            return;
        }
        Log.d("NrideOverlayMsg", "forwarding to overlay engine");
        BasicMessageChannel overlayMessageChannel = new BasicMessageChannel(
                engine.getDartExecutor(),
                OverlayConstants.MESSENGER_TAG, JSONMessageCodec.INSTANCE);
        overlayMessageChannel.send(message, reply);
    }

    private boolean checkOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return Settings.canDrawOverlays(context);
        }
        return true;
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CODE_FOR_OVERLAY_PERMISSION) {
            pendingResult.success(checkOverlayPermission());
            return true;
        }
        return false;
    }

}
