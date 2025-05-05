package com.fluttercandies.flutter_ali_auth;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** FlutterAliAuthPlugin */
public class FlutterAliAuthPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_ali_auth");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("initSdk")) {
      // 模拟SDK初始化
      result.success(null);
    } else if (call.method.equals("login")) {
      // 模拟登录
      // 在实际场景中，这里会调用阿里云SDK然后通过channel.invokeMethod回调结果
      // 由于没有实际SDK，这里只是返回成功
      result.success(null);
      
      // 模拟延迟后发送登录成功事件
      android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());
      handler.postDelayed(new Runnable() {
        @Override
        public void run() {
          // 创建模拟的登录成功事件
          java.util.HashMap<String, Object> successEvent = new java.util.HashMap<>();
          successEvent.put("resultCode", "600000");  // 成功码
          successEvent.put("token", "mock_login_token_" + System.currentTimeMillis());  // 模拟token
          successEvent.put("msg", "登录成功");
          
          // 通过通道发送事件
          System.out.println("Java端发送onEvent事件: " + successEvent);
          // 方法一：直接调用onEvent方法
          channel.invokeMethod("onEvent", successEvent);
          
          // 方法二：添加备用调用方式
          handler.postDelayed(new Runnable() {
            @Override
            public void run() {
              System.out.println("Java端发送备用事件");
              channel.invokeMethod("loginResult", successEvent);
            }
          }, 500);
        }
      }, 1500); // 1.5秒后触发，模拟网络请求延迟
    } else if (call.method.equals("hideLoginLoading")) {
      // 模拟隐藏加载
      result.success(null);
    } else if (call.method.equals("quitLoginPage")) {
      // 模拟退出登录页面
      result.success(null);
    } else if (call.method.equals("getPhoneInfo")) {
      // 调用阿里云SDK预取号
      // 在实际场景中，这里会调用阿里云SDK然后通过channel.invokeMethod回调结果
      // 在这里实现原生SDK的预取号方法
      // 示例返回：成功时返回掩码手机号，失败时返回错误信息
      java.util.HashMap<String, Object> mockResult = new java.util.HashMap<>();
      mockResult.put("resultCode", "600000");
      mockResult.put("token", "mock_token_" + System.currentTimeMillis());
      // 添加手机号掩码，使用模拟数据
      mockResult.put("phone", "138****1234");
      mockResult.put("msg", "success");
      result.success(mockResult);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
} 