// features/cashier/presentation/widgets/product_grid.dart
// WHY: Product display grid with category filtering. Touch-optimized
// with large tap targets for fast repetitive selling.
// Now uses DB-backed FutureProviders instead of hardcoded products.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/design_system/colors.dart';
import 'package:holol_POS/core/design_system/spacing.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/l10n/app_localizations.dart';
import 'package:holol_POS/core/services/formatters/pos_formatters.dart';

import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/features/cashier/domain/models/product.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:holol_POS/shared/presentation/widgets/app_dropdown.dart';
import 'package:holol_POS/shared/presentation/widgets/app_loading.dart';
import 'package:holol_POS/shared/presentation/widgets/app_empty_state.dart';
import 'package:holol_POS/shared/presentation/utils/app_snackbar.dart';
import 'package:holol_POS/shared/presentation/dialogs/app_dialog.dart';

class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final productsAsync = ref.watch(cashierProductCardsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // -- Category tabs --
        Container(
          width: double.infinity,
          color: AppColors.surface,
          child: categoriesAsync.when(
            data: (categories) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _CategoryChip(
                    label: l10n.allCategories,
                    isSelected: selectedCategory == null,
                    onTap: () {
                      ref.read(selectedCategoryProvider.notifier).state = null;
                    },
                  ),
                  ...categories.map((cat) {
                    final isSelected = cat.id == selectedCategory;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.sm,
                      ),
                      child: _CategoryChip(
                        label: cat.name,
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(selectedCategoryProvider.notifier).state =
                              cat.id;
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            loading: () => const AppLoading(),
            error: (e, _) => Center(
              child: Text(
                ErrorMapper.userMessage(e),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
        const Divider(height: 1),

        // -- Product grid --
        Expanded(
          child: productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                final search = ref.read(searchQueryProvider);
                final cat = ref.read(selectedCategoryProvider);
                if (search.isEmpty && cat == null) {
                  final session = ref
                      .read(activePosSessionProvider)
                      .valueOrNull;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 64,
                          color: AppColors.warning,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noPricedProductsForDeviceStore,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          l10n.storeAndPriceLevelDetails(
                            session?.activeStoreId ?? '',
                            session?.activePriceLevelId ?? '',
                          ),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return AppEmptyState(
                  icon: Icons.search_off,
                  title: l10n.noProductsFound,
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = switch (constraints.maxWidth) {
                    > 1500 => 7,
                    > 1200 => 6,
                    > 900 => 5,
                    > 620 => 4,
                    > 420 => 3,
                    _ => 2,
                  };
                  final aspectRatio = switch (constraints.maxWidth) {
                    > 900 => 0.98,
                    > 420 => 0.92,
                    _ => 0.86,
                  };
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final card = products[index];
                      return _ProductCard(
                        key: ValueKey(card.item.id),
                        card: card,
                      );
                    },
                  );
                },
              );
            },
            loading: () => const AppLoading(),
            error: (e, _) => Center(
              child: Text(
                ErrorMapper.userMessage(e),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
      borderRadius: AppSpacing.borderRadiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerStatefulWidget {
  final ProductCardViewModel card;

  const _ProductCard({super.key, required this.card});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  String? _selectedUnitId;

  Future<void> _addToCart(ProductUnitOption selectedUnit) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);

      await ref
          .read(cartProvider.notifier)
          .addSellableItem(selectedUnit.sellableItem);
    } catch (_) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        AppSnackbar.showError(context, l10n.unableToAddItemToCart);
      }
    }
  }

  void _showNoPriceError() {
    HapticFeedback.vibrate();
    final session = ref.read(activePosSessionProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final details =
        'ItemId: ${widget.card.item.id}\n'
        '${l10n.storeAndPriceLevelDetails(session?.activeStoreId ?? '', session?.activePriceLevelId ?? '')}';

    AppDialog.show(
      context: context,
      dialog: AppDialog.error(
        title: l10n.error,
        content: SelectableText(
          '${l10n.noPriceForCurrentStorePriceLevel}\n\n$details',
        ),
        cancelLabel: l10n.close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.card.units;
    if (units.isEmpty) {
      return _buildCard(null, null, isEmpty: true);
    }

    final selected = units.firstWhere(
      (u) => u.sellableItem.unitId == _selectedUnitId,
      orElse: () => widget.card.defaultUnit ?? units.first,
    );
    return _buildCard(selected, units, isEmpty: false);
  }

  Widget _buildCard(
    ProductUnitOption? selectedUnit,
    List<ProductUnitOption>? allUnits, {
    bool isEmpty = false,
    bool isLoading = false,
    bool isError = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.card.item;
    final unitPrice = selectedUnit?.sellableItem.unitPrice ?? 0;
    final unitName = selectedUnit?.sellableItem.unitName ?? '';

    final isInteractive = !isEmpty && !isLoading && !isError;

    return Material(
      color: isEmpty ? AppColors.surfaceVariant : AppColors.cardSurface,
      borderRadius: AppSpacing.borderRadiusMd,
      elevation: isInteractive ? 1 : 0,
      child: InkWell(
        onTap: isInteractive
            ? () => _addToCart(selectedUnit!)
            : (isEmpty ? _showNoPriceError : null),
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: AppSpacing.borderRadiusMd,
                    child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                        ? Image.network(
                            item.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            color: isEmpty
                                ? Colors.white.withValues(alpha: 0.5)
                                : null,
                            colorBlendMode: isEmpty ? BlendMode.modulate : null,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(isEmpty),
                          )
                        : _buildPlaceholder(isEmpty),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Product name
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),

              if (isLoading)
                const LinearProgressIndicator(minHeight: 2)
              else if (isEmpty)
                Text(
                  l10n.noPrice,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (isError)
                Text(
                  l10n.errorLoading,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                )
              else ...[
                // Unit Dropdown or Text
                if (allUnits != null && allUnits.length > 1)
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AppInlineDropdown<String>(
                      value: selectedUnit!.sellableItem.unitId,
                      items: allUnits
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.sellableItem.unitId,
                              child: Text(u.sellableItem.unitName),
                            ),
                          )
                          .toList(),
                      onChanged: (newId) {
                        setState(() => _selectedUnitId = newId);
                      },
                    ),
                  )
                else
                  Text(
                    unitName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                const SizedBox(height: 2),
                // Price
                Text(
                  PosFormatters.amount(unitPrice),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isEmpty) {
    return Opacity(
      opacity: isEmpty ? 0.5 : 1.0,
      child: Image.asset(
        'assets/images/placeholder.jpg',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
