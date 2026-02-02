import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

void main() => runApp(const MyApp());

// CHANGE THIS ONLY
const String BACKEND_URL = "http://13.203.219.206:8000/";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PaymentScreen(),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;

  String? orderId;
  String statusText = "Ready to pay";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // STEP 1: CALL YOUR EXISTING BACKEND
  Future<void> startPayment() async {
    setState(() {
      isLoading = true;
      statusText = "Creating order...";
    });

    try {
      final response = await http.post(
        Uri.parse("$BACKEND_URL/create-order/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "amount": 100, // ₹1 = 100 paise (REAL TIME)
        }),
      );

      if (response.statusCode != 200) {
        throw "Order creation failed";
      }

      final data = jsonDecode(response.body);
      orderId = data['order_id'];

      openRazorpay(data['key']);

    } catch (e) {
      setState(() {
        isLoading = false;
        statusText = "Error: $e";
      });
    }
  }

  // STEP 2: OPEN RAZORPAY CHECKOUT
  void openRazorpay(String key) {
    var options = {
      'key': key,
      'order_id': orderId,
      'amount': 500,
      'currency': 'INR',
      'name': 'Secure Payment',
      'description': '₹1 Test Payment',
      'prefill': {
        'contact': '+91 9949597079',
        'email': 'chandrasekharsuragani532@gmail.com',
      },
      'theme': {'color': '#0A6EBD'}
    };

    _razorpay.open(options);
  }

  // STEP 3: SDK SUCCESS (NOT FINAL)
  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    setState(() {
      statusText = "Verifying payment...";
    });

    final verify = await http.post(
      Uri.parse("$BACKEND_URL/verify-payment/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "order_id": orderId,
        "payment_id": response.paymentId,
        "signature": response.signature,
      }),
    );

    if (verify.statusCode == 200) {
      setState(() {
        statusText = "✅ ₹1 Payment Successful";
        isLoading = false;
      });
    } else {
      setState(() {
        statusText = "⚠️ Payment pending (money safe)";
        isLoading = false;
      });
    }
  }

  // PAYMENT FAILED OR CANCELLED
  void _handleError(PaymentFailureResponse response) {
    setState(() {
      statusText = "❌ Payment cancelled / failed";
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Razorpay Real-Time Payment")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : startPayment,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Pay ₹1"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
