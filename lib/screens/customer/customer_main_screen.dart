import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/customer/customer_catalog_screen.dart';
import 'package:inventory_store_app/screens/customer/cart_screen.dart';
import 'package:inventory_store_app/screens/auth/profile_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  final int initialIndex;
  const CustomerMainScreen({super.key, this.initialIndex = 0});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack mantiene vivas las pantallas que no se están viendo
    return IndexedStack(
      index: _currentIndex,
      children: [
        CustomerCatalogScreen(onTabSelected: _onTabSelected),
        CartScreen(onTabSelected: _onTabSelected),
        ProfileScreen(onTabSelected: _onTabSelected),
      ],
    );
  }
}
