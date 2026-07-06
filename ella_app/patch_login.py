import re

with open("lib/screens/login_screen.dart", "r") as f:
    content = f.read()

# Replace the microtask with one that has prints
old_microtask = """    Future.microtask(() async {
      try {
        final lightweightAuth = gsi.GoogleSignIn.instance.attemptLightweightAuthentication();
        if (lightweightAuth != null) {
          final googleUser = await lightweightAuth;
          if (googleUser != null) {
            final gsi.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
            final String? idToken = googleAuth.idToken;
            if (idToken != null) {
              final success = await _api.loginWithGoogle(idToken);
              if (success && mounted) {
                Navigator.pushReplacementNamed(context, '/');
              } else {
                _showError('One Tap Login failed on backend.');
              }
            } else {
              _showError('One Tap failed: no idToken.');
            }
          } else {
            _showError('One Tap failed: googleUser is null.');
          }
        }
      } catch (e) {
        _showError('One Tap Error: $e');
      }
    });"""

new_microtask = """    Future.microtask(() async {
      print("---- ONE TAP: Starting attemptLightweightAuthentication");
      try {
        final lightweightAuth = gsi.GoogleSignIn.instance.attemptLightweightAuthentication();
        if (lightweightAuth != null) {
          final googleUser = await lightweightAuth;
          print("---- ONE TAP: googleUser is ${googleUser?.email}");
          if (googleUser != null) {
            final gsi.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
            final String? idToken = googleAuth.idToken;
            print("---- ONE TAP: idToken is ${idToken != null ? 'present' : 'null'}");
            if (idToken != null) {
              final success = await _api.loginWithGoogle(idToken);
              print("---- ONE TAP: backend success is $success");
              if (success && mounted) {
                print("---- ONE TAP: Navigating to /");
                Navigator.pushReplacementNamed(context, '/');
              } else {
                _showError('One Tap Login failed on backend.');
              }
            } else {
              _showError('One Tap failed: no idToken.');
            }
          } else {
            _showError('One Tap failed: googleUser is null.');
          }
        }
      } catch (e, st) {
        print("---- ONE TAP ERROR: $e");
        print(st);
        _showError('One Tap Error: $e');
      }
    });"""

content = content.replace(old_microtask, new_microtask)

with open("lib/screens/login_screen.dart", "w") as f:
    f.write(content)
