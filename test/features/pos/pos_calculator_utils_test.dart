import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';

void main() {
  group('PosCalculatorUtils Tests', () {
    test('validateDiscountInput correctly validates percentages and amounts', () {
      // Percentage checks
      expect(
        PosCalculatorUtils.validateDiscountInput(
          text: '50',
          isPercentage: true,
          cartTotal: 100,
        ),
        isNull,
      );
      expect(
        PosCalculatorUtils.validateDiscountInput(
          text: '120',
          isPercentage: true,
          cartTotal: 100,
        ),
        equals('Máximo 100%'),
      );
      expect(
        PosCalculatorUtils.validateDiscountInput(
          text: '-5',
          isPercentage: true,
          cartTotal: 100,
        ),
        equals('No negativo'),
      );

      // Amount checks
      expect(
        PosCalculatorUtils.validateDiscountInput(
          text: '45.50',
          isPercentage: false,
          cartTotal: 100,
        ),
        isNull,
      );
      expect(
        PosCalculatorUtils.validateDiscountInput(
          text: '150.00',
          isPercentage: false,
          cartTotal: 100,
          maxDiscountAmount: 100,
        ),
        equals('Excede máximo (S/ 100.00)'),
      );
    });

    test('validateSalePreFlight catches discount exceeding cart total or 100%', () {
      final cartItem = CartItemEntity(
        productId: 'prod-1',
        productName: 'Producto Test',
        cartKey: 'var-1',
        variantId: 'var-1',
        quantity: 2,
        unitPrice: 50.0,
        unitCost: 30.0,
        availableStock: 10,
        usesBatches: false,
        isSelected: true,
      );
      final cartState = CartState(items: {'var-1': cartItem});

      // Percentage > 100%
      final posStateInvalidPerc = const PosState(
        selectedWarehouseId: 'wh-1',
        selectedAccountId: 'acc-1',
        paymentMethod: 'EFECTIVO',
        discountText: '110',
        isDiscountPercentage: true,
      );

      final errorPerc = PosCalculatorUtils.validateSalePreFlight(
        posState: posStateInvalidPerc,
        cartState: cartState,
        totalFinal: 0,
      );
      expect(errorPerc, equals('El porcentaje de descuento no puede superar el 100%.'));

      // Amount > cart total (100 soles)
      final posStateInvalidAmount = const PosState(
        selectedWarehouseId: 'wh-1',
        selectedAccountId: 'acc-1',
        paymentMethod: 'EFECTIVO',
        discountText: '150',
        isDiscountPercentage: false,
      );

      final errorAmount = PosCalculatorUtils.validateSalePreFlight(
        posState: posStateInvalidAmount,
        cartState: cartState,
        totalFinal: 0,
      );
      expect(errorAmount, equals('El descuento en soles no puede exceder el total de la venta.'));
    });

    test('calcularTotalFinal correctly subtracts loyalty points and discounts', () {
      final cartItem = CartItemEntity(
        productId: 'prod-1',
        productName: 'Producto Test',
        cartKey: 'var-1',
        variantId: 'var-1',
        quantity: 2,
        unitPrice: 50.0,
        unitCost: 30.0,
        availableStock: 10,
        usesBatches: false,
        isSelected: true,
      );
      final cartState = CartState(items: {'var-1': cartItem}); // Total: 100.0

      // Case 1: 500 points with ratio 0.01 = S/ 5.00 discount. Final = 95.00
      final posWithPoints = const PosState(
        selectedClientId: 'cli-1',
        saldoActualCliente: 1000,
        puntosAUsar: 500,
        discountText: '',
      );
      final totalWithPoints = PosCalculatorUtils.calcularTotalFinal(
        discountText: posWithPoints.discountText,
        isDiscountPercentage: posWithPoints.isDiscountPercentage,
        pos: posWithPoints,
        cart: cartState,
        ratio: 0.01,
      );
      expect(totalWithPoints, equals(95.0));

      // Case 2: 10% manual discount on 100.0 = S/ 10.00 discount. Final = 90.00
      final posWithPerc = const PosState(
        puntosAUsar: 0,
        discountText: '10',
        isDiscountPercentage: true,
      );
      final totalWithPerc = PosCalculatorUtils.calcularTotalFinal(
        discountText: posWithPerc.discountText,
        isDiscountPercentage: posWithPerc.isDiscountPercentage,
        pos: posWithPerc,
        cart: cartState,
        ratio: 0.01,
      );
      expect(totalWithPerc, equals(90.0));

      // Case 3: Points (S/ 5.00) + Fixed Soles discount (S/ 10.00) = S/ 15.00 discount. Final = 85.00
      final posCombined = const PosState(
        selectedClientId: 'cli-1',
        saldoActualCliente: 1000,
        puntosAUsar: 500,
        discountText: '10',
        isDiscountPercentage: false,
      );
      final totalCombined = PosCalculatorUtils.calcularTotalFinal(
        discountText: posCombined.discountText,
        isDiscountPercentage: posCombined.isDiscountPercentage,
        pos: posCombined,
        cart: cartState,
        ratio: 0.01,
      );
      expect(totalCombined, equals(85.0));
    });

    test('accountRequiresShift identifies cash accounts requiring active shift', () {
      expect(
        PosCalculatorUtils.accountRequiresShift({'is_cash_register': true}),
        isTrue,
      );
      expect(
        PosCalculatorUtils.accountRequiresShift({'requires_shift': true}),
        isTrue,
      );
      expect(
        PosCalculatorUtils.accountRequiresShift({'type': 'CAJA'}),
        isTrue,
      );
      expect(
        PosCalculatorUtils.accountRequiresShift({'type': 'CASH_REGISTER'}),
        isTrue,
      );
      expect(
        PosCalculatorUtils.accountRequiresShift({'name': 'BCP Transferencia', 'type': 'BANK'}),
        isFalse,
      );
      expect(
        PosCalculatorUtils.accountRequiresShift({'name': 'Yape', 'type': 'WALLET'}),
        isFalse,
      );
    });

    test('clampPointsValue clamps points within available client balance and cart total', () {
      final cartItem = CartItemEntity(
        productId: 'prod-1',
        productName: 'Producto Test',
        cartKey: 'var-1',
        variantId: 'var-1',
        quantity: 1,
        unitPrice: 10.0,
        unitCost: 5.0,
        availableStock: 10,
        usesBatches: false,
        isSelected: true,
      );
      final cartState = CartState(items: {'var-1': cartItem}); // Total: 10.0 (max 1000 points @ 0.01)

      final posState = const PosState(
        selectedClientId: 'cli-1',
        saldoActualCliente: 500, // Client only has 500 points
      );

      // Attempting to use 800 points should clamp to 500
      final clampedToBalance = PosCalculatorUtils.clampPointsValue(
        800,
        posState,
        cartState,
        0.01,
      );
      expect(clampedToBalance, equals(500));

      // Attempting negative points should clamp to 0
      final clampedNegative = PosCalculatorUtils.clampPointsValue(
        -50,
        posState,
        cartState,
        0.01,
      );
      expect(clampedNegative, equals(0));
    });
  });
}
