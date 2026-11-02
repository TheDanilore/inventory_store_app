import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_form/user_form_state.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_components.dart';

class UserFormWarehouseSection extends StatelessWidget {
  final String? selectedWarehouseId;
  final ValueChanged<String?> onWarehouseChanged;

  const UserFormWarehouseSection({
    super.key,
    required this.selectedWarehouseId,
    required this.onWarehouseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserFormCubit, UserFormState>(
      buildWhen:
          (prev, curr) =>
              prev.warehouses != curr.warehouses ||
              prev.isLoadingWarehouses != curr.isLoadingWarehouses,
      builder: (context, state) {
        final warehouses = state.warehouses;
        final isLoading = state.isLoadingWarehouses && warehouses.isEmpty;

        return UserFormSectionCard(
          title: 'Almacén asignado',
          subtitle: 'Almacén o sucursal por defecto para este colaborador.',
          icon: Icons.storefront_outlined,
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              DropdownButtonFormField<String?>(
                initialValue:
                    warehouses.any((w) => w.id == selectedWarehouseId)
                        ? selectedWarehouseId
                        : null,
                decoration: InputDecoration(
                  labelText: 'Seleccionar almacén',
                  hintText: 'Sin almacén asignado',
                  prefixIcon: const Icon(Icons.warehouse_outlined, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Ninguno / Sin asignar'),
                  ),
                  ...warehouses.map(
                    (w) => DropdownMenuItem<String?>(
                      value: w.id,
                      child: Text(w.name),
                    ),
                  ),
                ],
                onChanged: onWarehouseChanged,
              ),
          ],
        );
      },
    );
  }
}
