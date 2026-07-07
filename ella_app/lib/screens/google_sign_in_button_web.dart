import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildGoogleSignInButton() => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        text: web.GSIButtonText.continueWith,
        shape: web.GSIButtonShape.pill, // pill shape like the custom button
        minimumWidth: 320,
      ),
    );
