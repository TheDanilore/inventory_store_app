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
  });
}
