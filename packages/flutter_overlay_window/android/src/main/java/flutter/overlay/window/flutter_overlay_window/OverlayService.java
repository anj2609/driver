package flutter.overlay.window.flutter_overlay_window;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.app.PendingIntent;
import android.graphics.Point;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Display;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import io.flutter.embedding.android.FlutterTextureView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterEngineGroup;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.JSONMessageCodec;
import io.flutter.plugin.common.MethodChannel;

public class OverlayService extends Service implements View.OnTouchListener {
    private final int DEFAULT_NAV_BAR_HEIGHT_DP = 48;
    private final int DEFAULT_STATUS_BAR_HEIGHT_DP = 25;

    private Integer mStatusBarHeight = -1;
    private Integer mNavigationBarHeight = -1;
    private Resources mResources;

    public static final String INTENT_EXTRA_IS_CLOSE_WINDOW = "IsCloseWindow";

    private static OverlayService instance;
    public static boolean isRunning = false;
    private WindowManager windowManager = null;
    private FlutterView flutterView;
    private MethodChannel flutterChannel;
    private BasicMessageChannel<Object> overlayMessageChannel;
    private int clickableFlag = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;

    private Handler mAnimationHandler = new Handler();
    private float lastX, lastY;
    private int lastYPosition;
    private boolean dragging;
    private static final float MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER = 0.8f;
    private Point szWindow = new Point();
    private Timer mTrayAnimationTimer;
    private TrayAnimationTimerTask mTrayTimerTask;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void onDestroy() {
        Log.d("OverLay", "Destroying the overlay window service");
        // NRIDE PATCH: tell the overlay's Dart side it is going away, BEFORE
        // detaching it.
        //
        // Tearing the window down does nothing to the overlay engine — it and
        // its whole widget tree carry on running, so no State is ever disposed
        // and anything they own keeps going. For the ride-request card that
        // means a looping ringtone with no card on screen, no buttons and no
        // countdown left to stop it: a phone the driver has to reboot.
        //
        // This path is reached by every native teardown, including the ones
        // Dart never initiates — MainActivity.onResume stopping the service
        // when the app comes to the front, and Android stopping it on its own.
        // Sent here rather than left to the callers, so a new one cannot be
        // added later that forgets.
        final boolean dartAskedForThis = WindowSetup.suppressDismissBroadcast;
        WindowSetup.suppressDismissBroadcast = false;
        if (overlayMessageChannel != null && !dartAskedForThis) {
            try {
                java.util.Map<String, Object> msg = new java.util.HashMap<>();
                msg.put("type", "overlay_dismiss");
                overlayMessageChannel.send(msg);
            } catch (Exception e) {
                Log.w("OverLay", "could not notify the overlay of teardown", e);
            }
        } else if (dartAskedForThis) {
            Log.d("OverLay", "close requested from Dart — not broadcasting a dismissal");
        }
        if (windowManager != null) {
            windowManager.removeView(flutterView);
            windowManager = null;
            flutterView.detachFromFlutterEngine();
            flutterView = null;
        }
        isRunning = false;
        NotificationManager notificationManager = (NotificationManager) getApplicationContext().getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancel(OverlayConstants.NOTIFICATION_ID);
        instance = null;
    }

    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        mResources = getApplicationContext().getResources();
        int startX = intent.getIntExtra("startX", OverlayConstants.DEFAULT_XY);
        int startY = intent.getIntExtra("startY", OverlayConstants.DEFAULT_XY);
        boolean isCloseWindow = intent.getBooleanExtra(INTENT_EXTRA_IS_CLOSE_WINDOW, false);
        if (isCloseWindow) {
            if (windowManager != null) {
                windowManager.removeView(flutterView);
                windowManager = null;
                flutterView.detachFromFlutterEngine();
                stopSelf();
            }
            isRunning = false;
            // NRIDE PATCH: START_NOT_STICKY, not START_STICKY.
        //
        // START_STICKY tells Android to recreate this service after it is
        // killed, with a null intent — and onStartCommand then re-attaches the
        // FlutterView to the cached engine, putting the overlay back on screen
        // by itself. For a ride-request card that is exactly wrong: the card
        // reappears with its Dart state already spent (_actionTaken latched, or
        // its countdown finished), so both buttons are dead and the driver is
        // left with a permanent overlay they cannot dismiss.
        //
        // A ride request is only meaningful for the few seconds it is offered.
        // If this service dies, the right behaviour is to stay gone and let the
        // next push raise a fresh one.
        return START_NOT_STICKY;
        }
        if (windowManager != null) {
            windowManager.removeView(flutterView);
            windowManager = null;
            flutterView.detachFromFlutterEngine();
            stopSelf();
        }
        isRunning = true;
        Log.d("onStartCommand", "Service started");
        FlutterEngine engine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);
        engine.getLifecycleChannel().appIsResumed();
        flutterView = new FlutterView(getApplicationContext(), new FlutterTextureView(getApplicationContext()));
        flutterView.attachToFlutterEngine(FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG));
        flutterView.setFitsSystemWindows(true);
        flutterView.setFocusable(true);
        flutterView.setFocusableInTouchMode(true);
        flutterView.setBackgroundColor(Color.TRANSPARENT);
        flutterChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("updateFlag")) {
                String flag = call.argument("flag").toString();
                updateOverlayFlag(result, flag);
            } else if (call.method.equals("updateOverlayPosition")) {
                int x = call.<Integer>argument("x");
                int y = call.<Integer>argument("y");
                moveOverlay(x, y, result);
            } else if (call.method.equals("resizeOverlay")) {
                int width = call.argument("width");
                int height = call.argument("height");
                boolean enableDrag = call.argument("enableDrag");
                resizeOverlay(width, height, enableDrag, result);
            }
        });
        overlayMessageChannel.setMessageHandler((message, reply) -> {
            WindowSetup.messenger.send(message);
            // NRIDE PATCH: actually answer the sender.
            //
            // Without this reply the Dart Future returned by shareData() from
            // inside the overlay never completes. Both buttons on the
            // ride-request card await shareData before calling closeOverlay,
            // so Accept, Decline and the 20s auto-decline all stopped dead on
            // that line: the card stayed on screen for good, its buttons did
            // nothing, and the only way out was force-stopping the app.
            reply.reply(null);
        });
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
            windowManager.getDefaultDisplay().getSize(szWindow);
        } else {
            DisplayMetrics displaymetrics = new DisplayMetrics();
            windowManager.getDefaultDisplay().getMetrics(displaymetrics);
            int w = displaymetrics.widthPixels;
            int h = displaymetrics.heightPixels;
            szWindow.set(w, h);
        }
        // NRIDE PATCH: a TOP-anchored overlay must start BELOW the status bar.
        //
        // The plugin's default y is -statusBarHeightPx(), which pulls the
        // window up by the status bar's height. That is harmless for the
        // centre and bottom placements it was written for, but for a
        // top-anchored card it is actively wrong: combined with
        // FLAG_LAYOUT_NO_LIMITS (which already lets the window extend into the
        // system bar areas), it puts the top of the card behind the clock and
        // the notch. Inside an overlay window Flutter's own SafeArea cannot
        // correct this — the system never reports insets to a
        // FLAG_LAYOUT_NO_LIMITS window, so MediaQuery padding reads zero — so
        // the safe area has to be honoured here, where the real status bar
        // height is actually known.
        final boolean anchoredTop =
                (WindowSetup.gravity & Gravity.VERTICAL_GRAVITY_MASK) == Gravity.TOP;
        final int defaultY = anchoredTop ? statusBarHeightPx() : -statusBarHeightPx();
        int dx = startX == OverlayConstants.DEFAULT_XY ? 0 : startX;
        int dy = startY == OverlayConstants.DEFAULT_XY ? defaultY : startY;
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowSetup.width == -1999 ? -1 : WindowSetup.width,
                WindowSetup.height != -1999 ? WindowSetup.height : screenHeight(),
                0,
                defaultY,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE,
                WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR
                        | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
        );
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
            params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
        }
        params.gravity = WindowSetup.gravity;
        android.util.Log.d("NrideWindowSetup",
                "addView gravity=0x" + Integer.toHexString(WindowSetup.gravity)
                        + " height=" + params.height);
        flutterView.setOnTouchListener(this);
        windowManager.addView(flutterView, params);
        moveOverlay(dx, dy, null);
        // NRIDE PATCH: START_NOT_STICKY, not START_STICKY.
        //
        // START_STICKY tells Android to recreate this service after it is
        // killed, with a null intent — and onStartCommand then re-attaches the
        // FlutterView to the cached engine, putting the overlay back on screen
        // by itself. For a ride-request card that is exactly wrong: the card
        // reappears with its Dart state already spent (_actionTaken latched, or
        // its countdown finished), so both buttons are dead and the driver is
        // left with a permanent overlay they cannot dismiss.
        //
        // A ride request is only meaningful for the few seconds it is offered.
        // If this service dies, the right behaviour is to stay gone and let the
        // next push raise a fresh one.
        return START_NOT_STICKY;
    }


    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    private int screenHeight() {
        Display display = windowManager.getDefaultDisplay();
        DisplayMetrics dm = new DisplayMetrics();
        display.getRealMetrics(dm);
        return inPortrait() ?
                dm.heightPixels + statusBarHeightPx() + navigationBarHeightPx()
                :
                dm.heightPixels + statusBarHeightPx();
    }

    private int statusBarHeightPx() {
        if (mStatusBarHeight == -1) {
            int statusBarHeightId = mResources.getIdentifier("status_bar_height", "dimen", "android");

            if (statusBarHeightId > 0) {
                mStatusBarHeight = mResources.getDimensionPixelSize(statusBarHeightId);
            } else {
                mStatusBarHeight = dpToPx(DEFAULT_STATUS_BAR_HEIGHT_DP);
            }
        }

        return mStatusBarHeight;
    }

    int navigationBarHeightPx() {
        if (mNavigationBarHeight == -1) {
            int navBarHeightId = mResources.getIdentifier("navigation_bar_height", "dimen", "android");

            if (navBarHeightId > 0) {
                mNavigationBarHeight = mResources.getDimensionPixelSize(navBarHeightId);
            } else {
                mNavigationBarHeight = dpToPx(DEFAULT_NAV_BAR_HEIGHT_DP);
            }
        }

        return mNavigationBarHeight;
    }


    private void updateOverlayFlag(MethodChannel.Result result, String flag) {
        if (windowManager != null) {
            WindowSetup.setFlag(flag);
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.flags = WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS |
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
                params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
            } else {
                params.alpha = 1;
            }
            windowManager.updateViewLayout(flutterView, params);
            result.success(true);
        } else {
            result.success(false);
        }
    }

    private void resizeOverlay(int width, int height, boolean enableDrag, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.width = (width == -1999 || width == -1) ? -1 : dpToPx(width);
            params.height = (height != 1999 || height != -1) ? dpToPx(height) : height;
            WindowSetup.enableDrag = enableDrag;
            windowManager.updateViewLayout(flutterView, params);
            result.success(true);
        } else {
            result.success(false);
        }
    }

    private void moveOverlay(int x, int y, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.x = (x == -1999 || x == -1) ? -1 : dpToPx(x);
            params.y = dpToPx(y);
            windowManager.updateViewLayout(flutterView, params);
            if (result != null)
                result.success(true);
        } else {
            if (result != null)
                result.success(false);
        }
    }


    public static Map<String, Double> getCurrentPosition() {
        if (instance != null && instance.flutterView != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
            Map<String, Double> position = new HashMap<>();
            position.put("x", instance.pxToDp(params.x));
            position.put("y", instance.pxToDp(params.y));
            return position;
        }
        return null;
    }

    public static boolean moveOverlay(int x, int y) {
        if (instance != null && instance.flutterView != null) {
            if (instance.windowManager != null) {
                WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
                params.x = (x == -1999 || x == -1) ? -1 : instance.dpToPx(x);
                params.y = instance.dpToPx(y);
                instance.windowManager.updateViewLayout(instance.flutterView, params);
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }


    @Override
    public void onCreate() {
        // NRIDE PATCH: go foreground FIRST, before the Flutter engine below.
        //
        // startForegroundService() gives a service roughly ten seconds to call
        // startForeground() before Android kills the whole process with
        // RemoteServiceException$ForegroundServiceDidNotStartInTimeException.
        // The engine work below used to run first, and on a cold start it does
        // not fit in that budget: with the app killed — which is exactly when a
        // ride push has to raise this overlay — there is no cached engine, so
        // createAndRunEngine() has to load the app bundle and spin up a whole
        // new Flutter isolate before startForeground() was ever reached.
        //
        // Observed on device (Vivo V2407, Android 15): FATAL EXCEPTION, the
        // process killed mid-raise, and no ride card ever shown. Building the
        // notification needs nothing from the engine, so there is no reason for
        // it to wait behind it.
        createNotificationChannel();
        Intent bootNotificationIntent = new Intent(this, FlutterOverlayWindowPlugin.class);
        int bootPendingFlags;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            bootPendingFlags = PendingIntent.FLAG_IMMUTABLE;
        } else {
            bootPendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        }
        PendingIntent bootPendingIntent = PendingIntent.getActivity(this,
                0, bootNotificationIntent, bootPendingFlags);
        final int bootNotifyIcon = getDrawableResourceId("mipmap", "launcher");
        Notification bootNotification = new NotificationCompat.Builder(this, OverlayConstants.CHANNEL_ID)
                .setContentTitle(WindowSetup.overlayTitle)
                .setContentText(WindowSetup.overlayContent)
                .setSmallIcon(bootNotifyIcon == 0 ? R.drawable.notification_icon : bootNotifyIcon)
                .setContentIntent(bootPendingIntent)
                .setVisibility(WindowSetup.notificationVisibility)
                .build();
        startForeground(OverlayConstants.NOTIFICATION_ID, bootNotification);

        // Get the cached FlutterEngine
        FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);

        // NRIDE PATCH: a cached engine is not necessarily a LIVE engine.
        //
        // Swiping the app out of recents destroys the overlay engine's Dart
        // isolate, but it stays in FlutterEngineCache — the cache holds a
        // reference, it does not keep the engine running. The null check alone
        // therefore happily reuses a corpse: the FlutterView attaches, the
        // window really is added (isOverlayActive() even reports true), and
        // every message sent into it goes to a detached FlutterJNI and is
        // dropped with no error anywhere.
        //
        // Measured on device (Vivo V2141, app swiped away, ride push arriving):
        // the raise "succeeded", the overlay's Dart entrypoint never ran a
        // second time, the router's own log-every-payload diagnostic printed
        // nothing at all, and the driver saw an empty transparent window
        // instead of the ride card. That is precisely the killed-app case this
        // overlay exists for, so the dead-engine path is the *normal* path
        // here, not an edge case.
        if (flutterEngine != null && !flutterEngine.getDartExecutor().isExecutingDart()) {
            Log.w("OverlayService", "Cached Flutter engine is no longer executing Dart — discarding it and building a fresh one");
            FlutterEngineCache.getInstance().remove(OverlayConstants.CACHED_TAG);
            flutterEngine = null;
        }

        if (flutterEngine == null) {
            // Handle the error if engine is not found
            Log.e("OverlayService", "Flutter engine not found, hence creating new flutter engine");
            FlutterEngineGroup engineGroup = new FlutterEngineGroup(this);
            DartExecutor.DartEntrypoint entryPoint = new DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "overlayMain"
            );  // "overlayMain" is custom entry point

            flutterEngine = engineGroup.createAndRunEngine(this, entryPoint);

            // NRIDE PATCH: configure this engine exactly as MainActivity
            // configures the one IT builds.
            //
            // An engine created here used to reach Dart with nothing attached
            // to it at all, and this is the app-was-killed path — the case the
            // ride-request overlay exists for. The card therefore ran in a
            // crippled engine precisely when it mattered: no
            // shared_preferences (so it could neither recover the stashed ride
            // payload nor write down an Accept), no audioplayers (so it was
            // silent), and no openApp channel (so Accept closed the card and
            // did nothing else whatsoever — "the accept button in the overlay
            // is not functional").
            configureOverlayEngine(flutterEngine);

            // Cache the created FlutterEngine for future use
            FlutterEngineCache.getInstance().put(OverlayConstants.CACHED_TAG, flutterEngine);
        }

        // Create the MethodChannel with the properly initialized FlutterEngine
        if (flutterEngine != null) {
            flutterChannel = new MethodChannel(flutterEngine.getDartExecutor(), OverlayConstants.OVERLAY_TAG);
            overlayMessageChannel = new BasicMessageChannel(flutterEngine.getDartExecutor(), OverlayConstants.MESSENGER_TAG, JSONMessageCodec.INSTANCE);
        }

        // NRIDE PATCH: the notification and startForeground() that used to sit
        // here now run at the very top of onCreate, before the engine work
        // above. See the note there.
        instance = this;
    }

    /**
     * NRIDE PATCH: hands a freshly built overlay engine to the app's own
     * configuration, so it is set up identically to one MainActivity builds.
     *
     * Reflection because the direction of the dependency has to point this
     * way. This is a plugin module; the app module already depends on it, and
     * a compile-time reference back to an app class would be a cycle. It also
     * keeps this vendored copy of a general-purpose plugin from hard-requiring
     * one specific app's class to exist.
     *
     * A missing configurator is survivable rather than fatal — the overlay
     * still renders, it just loses the tone, the SharedPreferences recovery
     * path and the ability to reopen the app — so it is logged loudly and the
     * raise continues.
     */
    private void configureOverlayEngine(FlutterEngine engine) {
        final String configurator = "online.nride.driver.OverlayEngineSupport";
        try {
            Class.forName(configurator)
                    .getMethod("configure", FlutterEngine.class, android.content.Context.class)
                    .invoke(null, engine, getApplicationContext());
        } catch (Throwable t) {
            Log.e("OverlayService",
                    "could not configure the overlay engine via " + configurator
                            + " — the card will render but Accept cannot reopen the app", t);
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                    OverlayConstants.CHANNEL_ID,
                    "Foreground Service Channel",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            assert manager != null;
            manager.createNotificationChannel(serviceChannel);
        }
    }

    private int getDrawableResourceId(String resType, String name) {
        return getApplicationContext().getResources().getIdentifier(String.format("ic_%s", name), resType, getApplicationContext().getPackageName());
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP,
                Float.parseFloat(dp + ""), mResources.getDisplayMetrics());
    }

    private double pxToDp(int px) {
        return (double) px / mResources.getDisplayMetrics().density;
    }

    private boolean inPortrait() {
        return mResources.getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
    }

    @Override
    public boolean onTouch(View view, MotionEvent event) {
        if (windowManager != null && WindowSetup.enableDrag) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    dragging = false;
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    break;
                case MotionEvent.ACTION_MOVE:
                    float dx = event.getRawX() - lastX;
                    float dy = event.getRawY() - lastY;
                    if (!dragging && dx * dx + dy * dy < 25) {
                        return false;
                    }
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    boolean invertX = WindowSetup.gravity == (Gravity.TOP | Gravity.RIGHT)
                            || WindowSetup.gravity == (Gravity.CENTER | Gravity.RIGHT)
                            || WindowSetup.gravity == (Gravity.BOTTOM | Gravity.RIGHT);
                    boolean invertY = WindowSetup.gravity == (Gravity.BOTTOM | Gravity.LEFT)
                            || WindowSetup.gravity == Gravity.BOTTOM
                            || WindowSetup.gravity == (Gravity.BOTTOM | Gravity.RIGHT);
                    int xx = params.x + ((int) dx * (invertX ? -1 : 1));
                    int yy = params.y + ((int) dy * (invertY ? -1 : 1));
                    params.x = xx;
                    params.y = yy;
                    if (windowManager != null) {
                        windowManager.updateViewLayout(flutterView, params);
                    }
                    dragging = true;
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    lastYPosition = params.y;
                    if (!WindowSetup.positionGravity.equals("none")) {
                        if (windowManager == null) return false;
                        windowManager.updateViewLayout(flutterView, params);
                        mTrayTimerTask = new TrayAnimationTimerTask();
                        mTrayAnimationTimer = new Timer();
                        mTrayAnimationTimer.schedule(mTrayTimerTask, 0, 25);
                    }
                    return false;
                default:
                    return false;
            }
            return false;
        }
        return false;
    }

    private class TrayAnimationTimerTask extends TimerTask {
        int mDestX;
        int mDestY;
        WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();

        public TrayAnimationTimerTask() {
            super();
            mDestY = lastYPosition;
            switch (WindowSetup.positionGravity) {
                case "auto":
                    mDestX = (params.x + (flutterView.getWidth() / 2)) <= szWindow.x / 2 ? 0 : szWindow.x - flutterView.getWidth();
                    return;
                case "left":
                    mDestX = 0;
                    return;
                case "right":
                    mDestX = szWindow.x - flutterView.getWidth();
                    return;
                default:
                    mDestX = params.x;
                    mDestY = params.y;
                    break;
            }
        }

        @Override
        public void run() {
            mAnimationHandler.post(() -> {
                params.x = (2 * (params.x - mDestX)) / 3 + mDestX;
                params.y = (2 * (params.y - mDestY)) / 3 + mDestY;
                if (windowManager != null) {
                    windowManager.updateViewLayout(flutterView, params);
                }
                if (Math.abs(params.x - mDestX) < 2 && Math.abs(params.y - mDestY) < 2) {
                    TrayAnimationTimerTask.this.cancel();
                    mTrayAnimationTimer.cancel();
                }
            });
        }
    }


}