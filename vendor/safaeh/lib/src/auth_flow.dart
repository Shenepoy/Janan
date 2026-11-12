import 'package:material_ui/material_ui.dart';

import 'onboarding.dart';

/// One radius for the card family: fields, OAuth, mode pill, and CTA.
const double _kAuthControlRadius = 12;

/// WorkOS-style grouping: tight inside a block, open between blocks.
const double _kAuthInnerGap = 8;
const double _kAuthGroupGap = 24;
const double _kAuthSubtitleLines = 2;
const Duration _kAuthFooterMotion = Duration(milliseconds: 240);
const Curve _kAuthFooterCurve = Curves.easeOutCubic;

/// Provider buttons a host can expose in [SafaehAuthFlow].
enum SafaehAuthProvider { google, github, apple, other }

/// Visual/authentication state supplied by the host adapter.
enum SafaehAuthMode { signIn, signUp, profile, resetPassword, pending }

class SafaehAuthSnapshot {
  const SafaehAuthSnapshot({
    this.mode = SafaehAuthMode.signIn,
    this.busy = false,
    this.errorMessage,
    this.pendingEmail,
  });

  final SafaehAuthMode mode;
  final bool busy;
  final String? errorMessage;
  final String? pendingEmail;
}

class SafaehAuthCredentials {
  const SafaehAuthCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class SafaehAuthProfile {
  const SafaehAuthProfile({required this.displayName});

  final String displayName;
}

/// Host callbacks for the generic auth presentation.
class SafaehAuthActions {
  const SafaehAuthActions({
    this.onSubmit,
    this.onProfileSubmit,
    this.onProvider,
    this.onMagicLink,
    this.onPasswordReset,
    this.onToggleMode,
    this.onBack,
    this.onResend,
  });

  final Future<void> Function(SafaehAuthCredentials credentials)? onSubmit;
  final Future<void> Function(SafaehAuthProfile profile)? onProfileSubmit;
  final Future<void> Function(SafaehAuthProvider provider)? onProvider;
  final Future<void> Function(String email)? onMagicLink;
  final Future<void> Function(String email)? onPasswordReset;
  final VoidCallback? onToggleMode;
  final VoidCallback? onBack;
  final Future<void> Function()? onResend;
}

/// Copy supplied by the host. Safaeh deliberately has no localization
/// dependency and uses these English values only as a usable fallback.
class SafaehAuthLabels {
  const SafaehAuthLabels({
    this.signInTitle = 'Welcome back',
    this.signUpTitle = 'Create your account',
    this.profileTitle = 'Tell us about you',
    this.resetTitle = 'Reset your password',
    this.pendingTitle = 'Check your email',
    this.email = 'Email',
    this.password = 'Password',
    this.displayName = 'Name',
    this.signIn = 'Sign in',
    this.signUp = 'Sign up',
    this.continueLabel = 'Continue',
    this.reset = 'Send reset link',
    this.magicLink = 'Sign in with magic link',
    this.forgotPassword = 'Forgot password?',
    this.switchToSignUp = 'Create an account',
    this.switchToSignIn = 'I already have an account',
    this.back = 'Back',
    this.resend = 'Resend email',
    this.pendingDescription = 'Use the link we sent to finish signing in.',
    this.google = 'Google',
    this.github = 'GitHub',
    this.apple = 'Apple',
    this.otherProvider = 'Continue with provider',
    this.emailDivider = 'or continue with email',
    this.requiredField = 'Required',
    this.invalidEmail = 'Enter a valid email address',
    this.signInSubtitle = 'Sign in to sync your data across devices.',
    this.signUpSubtitle = 'Create an account to enable cloud sync.',
    this.profileSubtitle = 'A few details so others know who you are.',
  });

  final String signInTitle;
  final String signUpTitle;
  final String profileTitle;
  final String resetTitle;
  final String pendingTitle;
  final String email;
  final String password;
  final String displayName;
  final String signIn;
  final String signUp;
  final String continueLabel;
  final String reset;
  final String magicLink;
  final String forgotPassword;
  final String switchToSignUp;
  final String switchToSignIn;
  final String back;
  final String resend;
  final String pendingDescription;
  final String google;
  final String github;
  final String apple;
  final String otherProvider;
  final String emailDivider;
  final String requiredField;
  final String invalidEmail;
  final String signInSubtitle;
  final String signUpSubtitle;
  final String profileSubtitle;

  String provider(SafaehAuthProvider provider) => switch (provider) {
    SafaehAuthProvider.google => google,
    SafaehAuthProvider.github => github,
    SafaehAuthProvider.apple => apple,
    SafaehAuthProvider.other => otherProvider,
  };
}

typedef SafaehAuthProviderBuilder =
    Widget Function(
      BuildContext context,
      SafaehAuthProvider provider,
      String label,
      VoidCallback? onPressed,
    );

/// Generic sign-in/signup presentation with no account or network knowledge.
class SafaehAuthFlow extends StatefulWidget {
  const SafaehAuthFlow({
    super.key,
    this.snapshot = const SafaehAuthSnapshot(),
    this.actions = const SafaehAuthActions(),
    this.labels = const SafaehAuthLabels(),
    this.design = SafaehOnboardingDesign.zen,
    this.providers = const [
      SafaehAuthProvider.google,
      SafaehAuthProvider.github,
    ],
    this.providerBuilder,
    this.brand,
    this.showTitle = true,
  });

  final SafaehAuthSnapshot snapshot;
  final SafaehAuthActions actions;
  final SafaehAuthLabels labels;
  final SafaehOnboardingDesign design;
  final List<SafaehAuthProvider> providers;
  final SafaehAuthProviderBuilder? providerBuilder;
  final Widget? brand;

  /// False when the host already paints the heading in sheet chrome.
  final bool showTitle;

  @override
  State<SafaehAuthFlow> createState() => _SafaehAuthFlowState();
}

class _SafaehAuthFlowState extends State<SafaehAuthFlow> {
  late SafaehAuthMode _mode;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _displayNameController;
  final _formKey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.snapshot.mode;
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _displayNameController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant SafaehAuthFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.mode != widget.snapshot.mode) {
      _mode = widget.snapshot.mode;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? widget.labels.requiredField
      : null;

  String? _email(String? value) {
    final required = _required(value);
    if (required != null) return required;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
        ? null
        : widget.labels.invalidEmail;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    if (_mode == SafaehAuthMode.profile) {
      await widget.actions.onProfileSubmit?.call(
        SafaehAuthProfile(displayName: _displayNameController.text.trim()),
      );
      return;
    }
    if (_mode == SafaehAuthMode.resetPassword) {
      await widget.actions.onPasswordReset?.call(email);
      return;
    }
    await widget.actions.onSubmit?.call(
      SafaehAuthCredentials(email: email, password: _passwordController.text),
    );
  }

  bool _validateEmailOnly() => _emailFieldKey.currentState?.validate() ?? false;

  Future<void> _sendMagicLink() async {
    if (!_validateEmailOnly()) return;
    await widget.actions.onMagicLink?.call(_emailController.text.trim());
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == SafaehAuthMode.signIn
          ? SafaehAuthMode.signUp
          : SafaehAuthMode.signIn;
    });
    widget.actions.onToggleMode?.call();
  }

  String get _title => switch (_mode) {
    SafaehAuthMode.signIn => widget.labels.signInTitle,
    SafaehAuthMode.signUp => widget.labels.signUpTitle,
    SafaehAuthMode.profile => widget.labels.profileTitle,
    SafaehAuthMode.resetPassword => widget.labels.resetTitle,
    SafaehAuthMode.pending => widget.labels.pendingTitle,
  };

  String? get _subtitle => switch (_mode) {
    SafaehAuthMode.signIn => widget.labels.signInSubtitle,
    SafaehAuthMode.signUp => widget.labels.signUpSubtitle,
    SafaehAuthMode.profile => widget.labels.profileSubtitle,
    SafaehAuthMode.resetPassword || SafaehAuthMode.pending => null,
  };

  double get _controlRadius => switch (widget.design) {
    SafaehOnboardingDesign.paper => 6,
    _ => _kAuthControlRadius,
  };

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final busy = snapshot.busy;
    final content = switch (_mode) {
      SafaehAuthMode.pending => _PendingAuthPanel(
        labels: widget.labels,
        email: snapshot.pendingEmail ?? _emailController.text,
        busy: busy,
        error: snapshot.errorMessage,
        onResend: widget.actions.onResend,
        onBack: widget.actions.onBack,
      ),
      SafaehAuthMode.profile => _buildForm(
        fields: [_displayNameField()],
        actionLabel: widget.labels.continueLabel,
        busy: busy,
      ),
      SafaehAuthMode.resetPassword => _buildForm(
        fields: [_emailField()],
        actionLabel: widget.labels.reset,
        busy: busy,
      ),
      _ => _buildCredentialsForm(busy),
    };

    return Semantics(
      container: true,
      label: _title,
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: _AuthSurface(
          design: widget.design,
          brand: widget.brand,
          title: widget.showTitle ? Text(_title) : null,
          subtitle: _subtitle,
          error: snapshot.errorMessage,
          child: content,
        ),
      ),
    );
  }

  Widget _buildCredentialsForm(bool busy) {
    final theme = Theme.of(context);
    final isSignUp = _mode == SafaehAuthMode.signUp;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeSwitch(
            signInLabel: widget.labels.signIn,
            signUpLabel: widget.labels.signUp,
            isSignUp: isSignUp,
            busy: busy,
            onToggle: _toggleMode,
            radius: _controlRadius,
          ),
          const SizedBox(height: _kAuthGroupGap),
          if (widget.providers.isNotEmpty) ...[
            _providerGrid(busy),
            const SizedBox(height: _kAuthGroupGap),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.labels.emailDivider,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: _kAuthInnerGap),
          ],
          _emailField(),
          const SizedBox(height: _kAuthInnerGap),
          _passwordField(),
          _AuthCollapsingSlot(
            expanded: !isSignUp,
            child: Padding(
              padding: const EdgeInsets.only(top: _kAuthInnerGap),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          if (!_validateEmailOnly()) return;
                          setState(() => _mode = SafaehAuthMode.resetPassword);
                        },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(widget.labels.forgotPassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: _kAuthGroupGap),
          FilledButton(
            onPressed: busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _authCtaFill(Theme.of(context).colorScheme),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_controlRadius),
              ),
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isSignUp
                        ? widget.labels.continueLabel
                        : widget.labels.signIn,
                  ),
          ),
          _AuthCollapsingSlot(
            expanded: !isSignUp,
            child: TextButton(
              onPressed: busy ? null : _sendMagicLink,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              child: Text(widget.labels.magicLink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({
    required List<Widget> fields,
    required String actionLabel,
    required bool busy,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: _kAuthInnerGap),
            fields[i],
          ],
          const SizedBox(height: _kAuthGroupGap),
          FilledButton(
            onPressed: busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _authCtaFill(Theme.of(context).colorScheme),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_controlRadius),
              ),
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(actionLabel),
          ),
          if (_mode == SafaehAuthMode.resetPassword)
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() => _mode = SafaehAuthMode.signIn),
              child: Text(widget.labels.back),
            ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {Widget? suffixIcon}) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(_controlRadius);
    final hairline = BorderSide(color: cs.outline.withValues(alpha: 0.06));
    return InputDecoration(
      labelText: label,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Color.lerp(cs.surface, cs.surfaceContainerHighest, 0.42),
      border: OutlineInputBorder(borderRadius: radius, borderSide: hairline),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: hairline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
      ),
    );
  }

  Widget _emailField() {
    final isSignUp = _mode == SafaehAuthMode.signUp;
    return TextFormField(
      key: _emailFieldKey,
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: isSignUp
          ? const [AutofillHints.email]
          : const [AutofillHints.username, AutofillHints.email],
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      validator: _email,
      decoration: _fieldDecoration(widget.labels.email),
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
    );
  }

  Widget _passwordField() {
    final isSignUp = _mode == SafaehAuthMode.signUp;
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: [
        isSignUp ? AutofillHints.newPassword : AutofillHints.password,
      ],
      validator: _required,
      onFieldSubmitted: (_) => _submit(),
      decoration: _fieldDecoration(
        widget.labels.password,
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  Widget _displayNameField() {
    return TextFormField(
      controller: _displayNameController,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.name],
      validator: _required,
      decoration: _fieldDecoration(widget.labels.displayName),
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _providerGrid(bool busy) {
    final providers = widget.providers;
    if (providers.length == 1) {
      return _provider(providers.first, busy);
    }
    final rows = <Widget>[];
    for (var i = 0; i < providers.length; i += 2) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 12));
      }
      final hasSecond = i + 1 < providers.length;
      rows.add(
        Row(
          children: [
            Expanded(child: _provider(providers[i], busy)),
            const SizedBox(width: 12),
            Expanded(
              child: hasSecond
                  ? _provider(providers[i + 1], busy)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _provider(SafaehAuthProvider provider, bool busy) {
    final label = widget.labels.provider(provider);
    final onPressed = busy || widget.actions.onProvider == null
        ? null
        : () => widget.actions.onProvider!(provider);
    final custom = widget.providerBuilder;
    if (custom != null) {
      return custom(context, provider, label, onPressed);
    }
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: Color.lerp(
          cs.surface,
          cs.surfaceContainerHighest,
          0.42,
        ),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.06)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Icon(switch (provider) {
              SafaehAuthProvider.google => Icons.g_mobiledata,
              SafaehAuthProvider.github => Icons.code,
              SafaehAuthProvider.apple => Icons.apple,
              SafaehAuthProvider.other => Icons.login,
            }, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

/// Fades and collapses a sign-in-only row so the password field never moves.
class _AuthCollapsingSlot extends StatefulWidget {
  const _AuthCollapsingSlot({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  State<_AuthCollapsingSlot> createState() => _AuthCollapsingSlotState();
}

class _AuthCollapsingSlotState extends State<_AuthCollapsingSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kAuthFooterMotion,
    value: widget.expanded ? 1 : 0,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: _kAuthFooterCurve,
    reverseCurve: _kAuthFooterCurve,
  );
  late bool _holdChild = widget.expanded;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _holdChild = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AuthCollapsingSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    if (widget.expanded) {
      setState(() => _holdChild = true);
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_holdChild) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !widget.expanded,
      child: FadeTransition(
        opacity: _progress,
        child: SizeTransition(
          sizeFactor: _progress,
          alignment: const AlignmentDirectional(-1, -1),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.signInLabel,
    required this.signUpLabel,
    required this.isSignUp,
    required this.busy,
    required this.onToggle,
    required this.radius,
  });

  final String signInLabel;
  final String signUpLabel;
  final bool isSignUp;
  final bool busy;
  final VoidCallback onToggle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(cs.surface, cs.surfaceContainerHighest, 0.42),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _ModeChip(
                label: signInLabel,
                selected: !isSignUp,
                radius: (radius - 4).clamp(4, radius),
                onPressed: busy
                    ? null
                    : isSignUp
                    ? onToggle
                    : () {},
              ),
            ),
            Expanded(
              child: _ModeChip(
                label: signUpLabel,
                selected: isSignUp,
                radius: (radius - 4).clamp(4, radius),
                onPressed: busy
                    ? null
                    : isSignUp
                    ? () {}
                    : onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.radius,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected ? cs.surface : Colors.transparent,
        foregroundColor: selected ? cs.onSurface : cs.onSurfaceVariant,
        minimumSize: const Size.fromHeight(40),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _PendingAuthPanel extends StatelessWidget {
  const _PendingAuthPanel({
    required this.labels,
    required this.email,
    required this.busy,
    required this.error,
    required this.onResend,
    required this.onBack,
  });

  final SafaehAuthLabels labels;
  final String email;
  final bool busy;
  final String? error;
  final Future<void> Function()? onResend;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 56, color: cs.primary),
        const SizedBox(height: 16),
        Text(labels.pendingDescription, textAlign: TextAlign.center),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy || onResend == null ? null : onResend,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(labels.resend),
        ),
        TextButton(onPressed: busy ? null : onBack, child: Text(labels.back)),
      ],
    );
  }
}

Color _authCtaFill(ColorScheme cs) {
  if (cs.brightness == Brightness.dark) {
    return Color.lerp(cs.primary, const Color(0xFFC5D4A0), 0.28)!;
  }
  return cs.primary;
}

class _AuthSurface extends StatelessWidget {
  const _AuthSurface({
    required this.design,
    required this.title,
    required this.child,
    required this.error,
    required this.brand,
    this.subtitle,
  });

  final SafaehOnboardingDesign design;
  final Widget? title;
  final String? subtitle;
  final Widget child;
  final String? error;
  final Widget? brand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = switch (design) {
      SafaehOnboardingDesign.paper => 6.0,
      SafaehOnboardingDesign.zen => 2.0,
      _ => 24.0,
    };
    final embedded = title == null && brand == null;
    final inner = ListView(
      // Unlike SingleChildScrollView, a shrink-wrapped ListView sizes the
      // wide auth panel to its content while retaining scrolling for short
      // viewports.
      shrinkWrap: true,
      padding: embedded
          ? const EdgeInsets.fromLTRB(4, 0, 4, 8)
          : const EdgeInsets.all(24),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (brand != null) ...[brand!, const SizedBox(height: 16)],
              if (title != null)
                DefaultTextStyle(
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                  child: title!,
                ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                if (title != null) const SizedBox(height: 8),
                SizedBox(
                  height:
                      (theme.textTheme.bodySmall?.fontSize ?? 12) *
                      (theme.textTheme.bodySmall?.height ?? 1.35) *
                      _kAuthSubtitleLines,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Text(
                      subtitle!,
                      maxLines: _kAuthSubtitleLines.toInt(),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(error!, style: TextStyle(color: cs.error)),
              ],
              if (brand != null ||
                  title != null ||
                  (subtitle != null && subtitle!.isNotEmpty) ||
                  error != null)
                const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ],
    );
    final decorated = switch (design) {
      SafaehOnboardingDesign.zen => inner,
      SafaehOnboardingDesign.paper => Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: inner,
      ),
      SafaehOnboardingDesign.prism => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.5),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.2)),
          ),
          child: inner,
        ),
      ),
      _ => Material(
        color: cs.surface,
        elevation: design == SafaehOnboardingDesign.orbit ? 8 : 2,
        shadowColor: cs.primary.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: inner,
      ),
    };
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: Padding(
        padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(16),
        child: decorated,
      ),
    );
  }
}
