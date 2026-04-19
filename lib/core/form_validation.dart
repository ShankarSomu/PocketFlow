import 'package:flutter/material.dart';
import '../core/app_constants.dart';

/// Form validation result
class ValidationResult {

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;
  final bool isValid;
  final String? errorMessage;

  bool get isInvalid => !isValid;
}

/// Base validator
abstract class Validator {
  const Validator();
  
  ValidationResult validate(String? value);
  
  String get errorMessage;
}

/// Required field validator
class RequiredValidator extends Validator {

  const RequiredValidator({this.errorMessage = 'This field is required'});
  @override
  final String errorMessage;

  @override
  ValidationResult validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.invalid(errorMessage);
    }
    return const ValidationResult.valid();
  }
}

/// Email validator
class EmailValidator extends Validator {

  const EmailValidator({this.errorMessage = 'Please enter a valid email'});
  @override
  final String errorMessage;

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    if (!_emailRegex.hasMatch(value)) {
      return ValidationResult.invalid(errorMessage);
    }
    return const ValidationResult.valid();
  }
}

/// Min length validator
class MinLengthValidator extends Validator {

  MinLengthValidator(this.minLength, {String? errorMessage})
      : errorMessage = errorMessage ?? 
          'Must be at least $minLength characters';
  final int minLength;
  @override
  final String errorMessage;

  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    if (value.length < minLength) {
      return ValidationResult.invalid(errorMessage);
    }
    return const ValidationResult.valid();
  }
}

/// Max length validator
class MaxLengthValidator extends Validator {

  MaxLengthValidator(this.maxLength, {String? errorMessage})
      : errorMessage = errorMessage ?? 
          'Must be at most $maxLength characters';
  final int maxLength;
  @override
  final String errorMessage;

  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    if (value.length > maxLength) {
      return ValidationResult.invalid(errorMessage);
    }
    return const ValidationResult.valid();
  }
}

/// Min value validator
class MinValueValidator extends Validator {

  MinValueValidator(this.minValue, {String? errorMessage})
      : errorMessage = errorMessage ?? 
          'Must be at least $minValue';
  final num minValue;
  @override
  final String errorMessage;

  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    final numValue = num.tryParse(value);
    if (numValue == null || numValue < minValue) {
      return ValidationResult.invalid(errorMessage);
    }
    return const ValidationResult.valid();
  }
}

/// Max value validator
class MaxValueValidator extends Validator {

  MaxValueValidator(this.maxValue, {String? errorMessage})
      : errorMessage = errorMessage ?? 
          'Must be at most $maxValue';
  final num maxValue;
  @override
  final String errorMessage;

  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    final numValue = num.tryParse(value);
    if (numValue == null || numValue > maxValue) {
      return ValidationResult.invalid(errorMessage);
    }
    return const ValidationResult.valid();
  }
}

/// Pattern validator
class PatternValidator extends Validator {

  const PatternValidator(this.pattern, {required this.errorMessage});
  final RegExp pattern;
  @override
  final String errorMessage;

  @override
  ValidationResult validate(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.valid();
    }
    if (!pattern.hasMatch(value)) {
      return ValidationResult.invalid(errorMessage);
    }
    return const ValidationResult.valid();
  }
}

/// Composite validator - combines multiple validators
class CompositeValidator extends Validator {

  const CompositeValidator(this.validators);
  final List<Validator> validators;

  @override
  String get errorMessage => validators.first.errorMessage;

  @override
  ValidationResult validate(String? value) {
    for (final validator in validators) {
      final result = validator.validate(value);
      if (result.isInvalid) {
        return result;
      }
    }
    return const ValidationResult.valid();
  }
}

/// Validated text field with real-time feedback
class ValidatedTextField extends StatefulWidget {

  const ValidatedTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.validators = const [],
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.validateOnChange = true,
    this.showSuccessIndicator = false,
  });
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final List<Validator> validators;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool validateOnChange;
  final bool showSuccessIndicator;

  @override
  State<ValidatedTextField> createState() => _ValidatedTextFieldState();
}

class _ValidatedTextFieldState extends State<ValidatedTextField> {
  late TextEditingController _controller;
  String? _errorText;
  bool _hasInteracted = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (_hasInteracted && widget.validateOnChange) {
      _validate();
    }
    widget.onChanged?.call(_controller.text);
  }

  void _validate() {
    setState(() {
      final result = _validateValue(_controller.text);
      _errorText = result.errorMessage;
      _isValid = result.isValid;
    });
  }

  ValidationResult _validateValue(String? value) {
    for (final validator in widget.validators) {
      final result = validator.validate(value);
      if (result.isInvalid) {
        return result;
      }
    }
    return const ValidationResult.valid();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: _errorText,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: _hasInteracted && widget.showSuccessIndicator
            ? Icon(
                _isValid ? Icons.check_circle : Icons.error,
                color: _isValid ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error,
              )
            : null,
        border: const OutlineInputBorder(),
        counterText: widget.maxLength != null ? null : '',
      ),
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      onSubmitted: widget.onSubmitted,
      onTap: () {
        if (!_hasInteracted) {
          setState(() {
            _hasInteracted = true;
          });
        }
      },
      onEditingComplete: () {
        if (!_hasInteracted) {
          setState(() {
            _hasInteracted = true;
          });
        }
        _validate();
      },
    );
  }
}

/// Form builder with validation
class ValidatedForm extends StatefulWidget {

  const ValidatedForm({
    required this.child, super.key,
    this.formKey,
    this.onValidationChanged,
  });
  final Widget child;
  final GlobalKey<FormState>? formKey;
  final void Function()? onValidationChanged;

  @override
  State<ValidatedForm> createState() => _ValidatedFormState();
}

class _ValidatedFormState extends State<ValidatedForm> {
  late GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _formKey = widget.formKey ?? GlobalKey<FormState>();
  }

  bool validate() {
    final isValid = _formKey.currentState?.validate() ?? false;
    widget.onValidationChanged?.call();
    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: widget.child,
    );
  }
}

/// Common validators
class Validators {
  Validators._();

  static const required = RequiredValidator();
  static const email = EmailValidator();
  
  static MinLengthValidator minLength(int length) => MinLengthValidator(length);
  static MaxLengthValidator maxLength(int length) => MaxLengthValidator(length);
  static MinValueValidator minValue(num value) => MinValueValidator(value);
  static MaxValueValidator maxValue(num value) => MaxValueValidator(value);
  
  static final password = CompositeValidator([
    const RequiredValidator(errorMessage: 'Password is required'),
    MinLengthValidator(
      ValidationConstants.minPasswordLength,
      errorMessage: 'Password must be at least ${ValidationConstants.minPasswordLength} characters',
    ),
  ]);

  static final amount = CompositeValidator([
    const RequiredValidator(errorMessage: 'Amount is required'),
    MinValueValidator(
      ValidationConstants.minAmountCents / 100,
      errorMessage: 'Amount must be positive',
    ),
  ]);
}
