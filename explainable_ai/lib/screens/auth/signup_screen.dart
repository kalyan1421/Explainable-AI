import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _doctorCodeCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  
  bool _isDoctor = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureDoctorCode = true;
  String _gender = "Male";

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red)
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // If registering as doctor, verify the code first
    if (_isDoctor) {
      bool isValidCode = await _auth.verifyDoctorCode(_doctorCodeCtrl.text.trim());
      if (!isValidCode) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid doctor registration code. Please contact admin."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          )
        );
        return;
      }
    }
    
    String role = _isDoctor ? 'doctor' : 'patient';
    String? error = await _auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      role: role,
      age: int.tryParse(_ageCtrl.text) ?? 0,
      gender: _gender,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account created successfully!"), backgroundColor: Colors.green)
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Account"),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Personal Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? "Name is required" : null,
                ),
                SizedBox(height: 16),
                
                // Age & Gender Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Age",
                          prefixIcon: Icon(Icons.cake_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(
                          labelText: "Gender",
                          prefixIcon: Icon(Icons.wc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ["Male", "Female", "Other"].map((g) => 
                          DropdownMenuItem(value: g, child: Text(g))
                        ).toList(),
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                
                Text("Account Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return "Email is required";
                    if (!v.contains('@')) return "Invalid email format";
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return "Password is required";
                    if (v.length < 6) return "Password must be at least 6 characters";
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Confirm Password
                TextFormField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? "Please confirm password" : null,
                ),
                SizedBox(height: 24),
                
                // Role Selection
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isDoctor ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isDoctor ? Colors.blue.shade200 : Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Register as Doctor", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_isDoctor 
                          ? "You'll need an admin-provided registration code"
                          : "You'll have access to AI health screening features"),
                        value: _isDoctor,
                        onChanged: (val) => setState(() => _isDoctor = val),
                        activeColor: Colors.blue,
                      ),
                      
                      // Doctor Code Field - Only show when registering as doctor
                      if (_isDoctor) ...[
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _doctorCodeCtrl,
                          obscureText: _obscureDoctorCode,
                          decoration: InputDecoration(
                            labelText: "Doctor Registration Code",
                            hintText: "Enter code provided by admin",
                            prefixIcon: Icon(Icons.key, color: Colors.blue),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureDoctorCode ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureDoctorCode = !_obscureDoctorCode),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) {
                            if (_isDoctor && (v == null || v.isEmpty)) {
                              return "Doctor code is required";
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Contact the hospital administrator to get your registration code.",
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDoctor ? Colors.blue.shade700 : Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Create ${_isDoctor ? 'Doctor' : 'Patient'} Account", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
