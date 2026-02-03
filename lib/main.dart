import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

void main() {
  runApp(const MyApp());
}

// 🔴 CHANGE ONLY THIS
const String BACKEND_URL = "https://api.chandus7.in";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PaymentPage(),
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late Razorpay _razorpay;

  String? _orderId;
  bool _loading = false;
  String _status = "Ready";

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // =====================================================
  // STEP 1: CREATE ORDER
  // =====================================================
  Future<void> startPayment() async {
    setState(() {
      _loading = true;
      _status = "Creating order…";
    });

    try {
      final res = await http.post(
        Uri.parse("$BACKEND_URL/create-order/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"amount": 500}), // ₹5 (recommended)
      );

      if (res.statusCode != 200) {
        throw "Order creation failed";
      }

      final data = jsonDecode(res.body);
      _orderId = data["order_id"];

      _openRazorpay(data["key"]);
    } catch (e) {
      setState(() {
        _loading = false;
        _status = "Failed to start payment";
      });
    }
  }

  // =====================================================
  // STEP 2: OPEN RAZORPAY
  // =====================================================
  void _openRazorpay(String key) {
    _status = "Opening payment gateway…";

    _razorpay.open({
      'key': key,
      'order_id': _orderId,
      'amount': 200,
      'currency': 'INR',
      'name': 'Chandus7 Payment',
      'description': 'UPI / Card Payment',
      'timeout': 180,
      'retry': {'enabled': false},
      'prefill': {
        'contact': '9949597079',
        'email': 'kingchandus143@gmail.com'
      }
    });
  }

  // =====================================================
  // STEP 3: SDK SUCCESS CALLBACK (NOT FINAL TRUTH)
  // =====================================================
  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _status = "Verifying payment…";
    });

    // ⚠️ ONLY NOW we talk to backend
    final res = await http.post(
      Uri.parse("$BACKEND_URL/verify-payment/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "order_id": _orderId,
        "payment_id": response.paymentId,
        "signature": response.signature,
      }),
    );

    if (res.statusCode == 200) {
      setState(() {
        _status = "✅ Payment Successful";
        _loading = false;
      });
    } else {
      // Signature failed or backend rejected
      setState(() {
        _status = "⚠️ Payment processing. Please refresh.";
        _loading = false;
      });
    }
  }

  // =====================================================
  // STEP 4: SDK ERROR / BANKING BUG / UPI ISSUE
  // =====================================================
  void _onError(PaymentFailureResponse response) {
    // ❌ DO NOT mark failed immediately
    setState(() {
      _status = "⚠️ Payment not completed / cancelled";
      _loading = false;
    });
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Razorpay Payment")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : startPayment,
                child: const Text("Pay ₹5"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
