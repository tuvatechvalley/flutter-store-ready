// planted: a non-consumable is sold, earlier purchases can never be recovered
Future<void> buyPremium(ProductDetails product) =>
    InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
