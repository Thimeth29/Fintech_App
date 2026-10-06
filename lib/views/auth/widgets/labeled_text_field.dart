import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The floating-label bordered field from the Figma "Login and Forget
/// screen" file — an uppercase label that overlaps the top border line.
class LabeledTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool isPassword;
  final Color borderColor;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.isPassword = false,
    this.borderColor = const Color(0xFFD1D1D1),
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: widget.borderColor),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primary, width: 1.5),
    );

    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword && _obscure,
      style: GoogleFonts.rubik(fontSize: 16, color: Colors.black),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.92),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: GoogleFonts.rubik(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF757575),
        ),
        border: enabledBorder,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF757575),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}
