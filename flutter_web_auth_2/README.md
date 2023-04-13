# Web Auth 2 for Flutter

**This project is a continuation of [flutter_web_auth](https://github.com/LinusU/flutter_web_auth) by Linus Unnebäck with many new features and bug fixes.**

A Flutter plugin for authenticating a user with a web service, even if the web service is run by a third party. Most commonly used with OAuth2, but can be used with any web flow that can redirect to a custom scheme.

In the background, this plugin uses [`ASWebAuthenticationSession`](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession) on iOS 12+ and macOS 10.15+, [`SFAuthenticationSession`](https://developer.apple.com/documentation/safariservices/sfauthenticationsession) on iOS 11, [Chrome Custom Tabs](https://developer.chrome.com/docs/android/custom-tabs/) on Android and opens a new window on Web. You can build it with iOS 8+, but it is currently only supported by iOS 11 or higher.

<!-- TODO: Replace with a nicer GIF
| **iOS**                | **Android**                    |
| ---------------------- | ------------------------------ |
| ![iOS](https://raw.githubusercontent.com/ThexXTURBOXx/flutter_web_auth_2/master/flutter_web_auth_2/screen-ios.gif) | ![Android](https://raw.githubusercontent.com/ThexXTURBOXx/flutter_web_auth_2/master/flutter_web_auth_2/screen-android.gif) |

| **macOS**                  |
| -------------------------- |
| ![macOS](https://raw.githubusercontent.com/ThexXTURBOXx/flutter_web_auth_2/master/flutter_web_auth_2/screen-macos.gif) |
-->

## Usage

Add the following snippet to your `pubspec.yaml` and follow the [Setup guide](#setup):

```yaml
dependencies:
  flutter_web_auth_2: ^2.0.0
```

To authenticate against your own custom site:

```dart
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

// Present the dialog to the user
final result = await FlutterWebAuth2.authenticate(url: "https://my-custom-app.com/connect", callbackUrlScheme: "my-custom-app");

// Extract token from resulting url
final token = Uri.parse(result).queryParameters['token'];
```

To authenticate the user using Google's OAuth2:

```dart
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'dart:convert' show jsonDecode;
import 'package:http/http.dart' as http;

// App specific variables
final googleClientId = 'XXXXXXXXXXXX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com';
final callbackUrlScheme = 'com.googleusercontent.apps.XXXXXXXXXXXX-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

// Construct the url
final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
  'response_type': 'code',
  'client_id': googleClientId,
  'redirect_uri': '$callbackUrlScheme:/',
  'scope': 'email',
});

// Present the dialog to the user
final result = await FlutterWebAuth2.authenticate(url: url.toString(), callbackUrlScheme: callbackUrlScheme);

// Extract code from resulting url
final code = Uri.parse(result).queryParameters['code'];

// Construct an Uri to Google's oauth2 endpoint
final url = Uri.https('www.googleapis.com', 'oauth2/v4/token');

// Use this code to get an access token
final response = await http.post(url, body: {
  'client_id': googleClientId,
  'redirect_uri': '$callbackUrlScheme:/',
  'grant_type': 'authorization_code',
  'code': code,
});

// Get the access token from the response
final accessToken = jsonDecode(response.body)['access_token'] as String;
```

**Note:** To use multiple scopes with Google, you need to encode them as a single string, separated by spaces. For example, `scope: 'email https://www.googleapis.com/auth/userinfo.profile'`. Here is [a list of all supported scopes](https://developers.google.com/identity/protocols/oauth2/scopes).

## Upgrading from `flutter_web_auth`

If you used `flutter_web_auth` correctly (and without extra hackage) before, it should be sufficient to replace the following strings *everywhere* (yes, also in `AndroidManifest.xml` for example):
- `FlutterWebAuth` -> `FlutterWebAuth2`
- `flutter_web_auth` -> `flutter_web_auth_2`

If you are still unsure or something is not working as well as before, please [open a new issue](https://github.com/ThexXTURBOXx/flutter_web_auth_2/issues/new/choose).

## Setup

Setup is the same as for any Flutter plugin, with the following caveats:

### Android

In order to capture the callback url, the following `activity` needs to be added to your `AndroidManifest.xml`. Be sure to replace `YOUR_CALLBACK_URL_SCHEME_HERE` with your actual callback url scheme.

```xml
<manifest>
  <application>

    <activity
      android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
      android:exported="true">
      <intent-filter android:label="flutter_web_auth_2">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="YOUR_CALLBACK_URL_SCHEME_HERE" />
      </intent-filter>
    </activity>

  </application>
</manifest>
```

### iOS

For "normal" authentication, just use this library as usual; there is nothing special to do!

To authenticate using [Universal Links](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html)
on iOS, use `https` as the provided `callbackUrlScheme`:

```dart
final result = await FlutterWebAuth2.authenticate(url: "https://my-custom-app.com/connect", callbackUrlScheme: "https");
```

### Web

On the web platform, an endpoint must be created that captures the callback URL and sends it to the application using the JavaScript `postMessage()` method. In the `./web` folder of the project, create an HTML file named, e.g. `auth.html` with content:

```html
<!DOCTYPE html>
<title>Authentication complete</title>
<p>Authentication is complete. If this does not happen automatically, please close the window.</p>
<script>
  window.opener.postMessage({
    'flutter-web-auth-2': window.location.href
  }, window.location.origin);
  window.close();
</script>
```

The redirect URL passed to the authentication service must be the same as the URL the application is running on (schema, host, port if necessary) and the path must point to the generated HTML file, in this case `/auth.html`. The `callbackUrlScheme` parameter of the `authenticate()` method does not take this into account, so it is possible to use a schema for native platforms in the code.

For the Sign in with Apple in web_message response mode, postMessage from https://appleid.apple.com is also captured, and the authorization object is returned as a URL fragment encoded as a query string (for compatibility with other providers).

If you want to pass additional parameters to the URL open call, you can do so in the `authenticate` function using the parameter `contextArgs`.

### Windows and Linux

There is still a limitation that the callback URL scheme must start with `http://localhost:{port}`.

If you have any experience in removing this limitation, please let me know!

## Troubleshooting

When you use this package for the first time, you may experience some problems. These are some of the most common solutions:

### Troubleshooting `callbackUrlScheme`

- `callbackUrlScheme` must be a valid schema string or else this library won't work
- A valid RFC 3986 URL scheme must consist of "a letter and followed by any combination of letters, digits, plus "`+`", period "`.`", or hyphen "`-`"
- scheme = `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`
- This means you can not use underscore "`_`", space "` `" or uppercase "`ABCDEF...`". It must also not start with a number. See [RFC3986#page-17](https://www.rfc-editor.org/rfc/rfc3986#page-17)
- Examples of VALID `callbackUrlScheme`s are `callback-scheme`, `another.scheme`, `examplescheme`
- Examples of INVALID `callbackUrlScheme`s are `callback_scheme`,`1another.scheme`, `exampleScheme`

### Troubleshooting Flutter App

- You have to tell the `FlutterWebAuth2.authenticate` function what your `callbackUrlScheme` is.
- Example: If your `callbackUrlScheme` is `valid-callback-scheme`, your dart code will look like

    ```dart
    import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

    // Present the dialog to the user
    final result = await FlutterWebAuth2.authenticate(url: "https://my-custom-app.com/connect", callbackUrlScheme: "valid-callback-scheme");
    ```

### Troubleshooting Android

- You will need to update your `AndroidManifest.xml` to include the `com.linusu.flutter_web_auth_2.CallbackActivity` activity, something like

    ```xml
    <manifest>
      <application>

        <!-- add the com.linusu.flutter_web_auth_2.CallbackActivity activity -->
        <activity
          android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
          android:exported="true">
          <intent-filter android:label="flutter_web_auth_2">
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="YOUR_CALLBACK_URL_SCHEME_HERE" />
          </intent-filter>
        </activity>

      </application>
    </manifest>
    ```

- Example of a valid `AndroidManifest.xml` with VALID `callbackUrlScheme`. In the example below our `callbackUrlScheme` is `valid-callback-scheme`.

    ```xml
    <manifest>
      <application>
        <activity
          android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
          android:exported="true">
          <intent-filter android:label="flutter_web_auth_2">
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="valid-callback-scheme" />
          </intent-filter>
        </activity>

      </application>
    </manifest>
    ```

- If you are targeting S+ (SDK version 31 and above) you need to provide an explicit value for `android:exported`. If you followed earlier installation instructions, this was not included. Make sure that you add `android:exported="true"` to the `com.linusu.flutter_web_auth.CallbackActivity` activity in your `AndroidManifest.xml` file.

    ```diff
    - <activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity">
    + <activity
    +   android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    +   android:exported="true">
    ```

### Troubleshooting OAuth redirects

- Your OAuth Provider must redirect to the valid `callbackUrlScheme` + `://`. This mean if your `callbackUrlScheme` is `validscheme`, your OAuth Provider must redirect to `validscheme://`
- Example with `PHP`:
    ```php
    <?php

    header("Location: validscheme://?data1=value1&data2=value2");
    ```

### Troubleshooting HTML redirects

- If you are using HTML hyperlinks, it must be a valid `callbackUrlScheme` + `://`. This means that if your `callbackUrlScheme` is `customappname`, your HTML hyperlink should be `customappname://`
- Example with `HTML`:

    ```html
    <a href="customappname://?data1=value1&data2=value2">Go Back to App</a>
    ```

### Troubleshooting passing data to app

- You can pass data back to your app by adding GET query parameters. This is done by adding a `name=value` type of data after your `callbackUrlScheme` + `://` + `?`
- Example to pass `access-token` to your app:

    ```text
    my-callback-schema://?access-token=jdu9292s
    ```

- You can pass multiple dates by concatenating them with `&`:

    ```text
    my-callback-schema://?data1=value1&data2=value2
    ```

- Example to pass `access-token` and `user_id` to your app:

    ```text
    my-callback-schema://?access-token=jdu9292s&user_id=23
    ```

- You can get the data in your app through `Uri.parse(result).queryParameters`:

    ```dart
    // Present the dialog to the user
    final result = await FlutterWebAuth2.authenticate(url: "https://my-custom-app.com/connect", callbackUrlScheme: "valid-callback-scheme");
    // Extract token from resulting url
    String accessToken = Uri.parse(result).queryParameters['access-token'];
    String userId = Uri.parse(result).queryParameters['user_id'];
    ```

### Cannot open keyboard on iOS

This seems to be a bug in `ASWebAuthenticationSession` and no workarounds have been found yet. Please see issue [#120](https://github.com/LinusU/flutter_web_auth/issues/120) for more info.

### Error on macOS if Chrome is default browser

This seems to be a bug in `ASWebAuthenticationSession` and no workarounds have been found yet. Please see issue [#136](https://github.com/LinusU/flutter_web_auth/issues/136) for more info.
