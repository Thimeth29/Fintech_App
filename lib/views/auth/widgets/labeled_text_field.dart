import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_fonts.dart';

class LabeledTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool isPassword;
  final IconData? prefixIcon;
  final String? hintText;
  final Color? borderColor;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.isPassword = false,
    this.prefixIcon,
    this.hintText,
    this.borderColor,
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppFonts.text(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onGlass,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword && _obscure,
          style: AppFonts.text(fontSize: 15, color: AppColors.onGlass),
          cursorColor: AppColors.accentCyan,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.glassFillStrong,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: widget.hintText ?? 'Enter your ${widget.label.toLowerCase()}...',
            hintStyle: AppFonts.text(fontSize: 14, color: AppColors.onGlassMuted),
            prefixIcon: Icon(
              widget.prefixIcon ??
                  (widget.isPassword
                      ? Icons.lock_outline_rounded
                      : (widget.keyboardType == TextInputType.emailAddress ||
                              widget.label.toLowerCase().contains('email')
                          ? Icons.email_outlined
                          : Icons.edit_note_rounded)),
              color: AppColors.onGlassMuted,
              size: 20,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.onGlassMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.borderColor ?? AppColors.glassBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.borderColor ?? AppColors.glassBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

