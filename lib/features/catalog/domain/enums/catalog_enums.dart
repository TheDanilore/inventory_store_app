enum CatalogSortOption {
  recent('Recientes'),
  nameAsc('Nombre (A-Z)'),
  priceAsc('Precio: Menor a Mayor'),
  priceDesc('Precio: Mayor a Menor'),
  highStock('Mayor Stock');

  final String label;
  const CatalogSortOption(this.label);
}

enum CatalogStockFilter {
  all('Todos', 0),
  inStock('En Stock', 1),
  outOfStock('Agotados', 2);

  final String label;
  final int value;
  const CatalogStockFilter(this.label, this.value);
}
