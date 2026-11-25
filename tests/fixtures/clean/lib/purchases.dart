Future<void> buyPremium(ProductDetails product) =>
    InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );

Future<void> restore() => InAppPurchase.instance.restorePurchases();
