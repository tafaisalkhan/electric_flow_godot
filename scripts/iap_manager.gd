# iap_manager.gd
# In-App Purchase & Google Play Billing Manager for Electric Flow
extends Node

signal purchase_succeeded(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal purchase_restored(product_id: String)
signal ads_removed_changed(is_removed: bool)

const PRODUCT_REMOVE_ADS := "remove_ads"

var _payment: Object = null
var is_billing_available: bool = false
var is_connected: bool = false

func _ready() -> void:
	_init_billing()
	if GameState.ads_removed:
		ads_removed_changed.emit(true)

func _init_billing() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_payment = Engine.get_singleton("GodotGooglePlayBilling")
		is_billing_available = true
		_connect_signals()
		print("[IAPManager] GodotGooglePlayBilling plugin detected. Starting connection...")
		_payment.startConnection()
	else:
		is_billing_available = false
		print("[IAPManager] GodotGooglePlayBilling plugin not available. Mock IAP mode active.")

func _connect_signals() -> void:
	if _payment == null:
		return
	
	if _payment.has_signal("connected"):
		_payment.connected.connect(_on_billing_connected)
	if _payment.has_signal("disconnected"):
		_payment.disconnected.connect(_on_billing_disconnected)
	if _payment.has_signal("connect_error"):
		_payment.connect_error.connect(_on_billing_connect_error)
	if _payment.has_signal("purchases_updated"):
		_payment.purchases_updated.connect(_on_purchases_updated)
	if _payment.has_signal("purchase_error"):
		_payment.purchase_error.connect(_on_purchase_error)
	if _payment.has_signal("sku_details_query_completed"):
		_payment.sku_details_query_completed.connect(_on_sku_details_query_completed)
	if _payment.has_signal("sku_details_query_error"):
		_payment.sku_details_query_error.connect(_on_sku_details_query_error)
	if _payment.has_signal("purchase_acknowledged"):
		_payment.purchase_acknowledged.connect(_on_purchase_acknowledged)

func _on_billing_connected() -> void:
	is_connected = true
	print("[IAPManager] Google Play Billing connected successfully!")
	if _payment.has_method("querySkuDetails"):
		_payment.querySkuDetails([PRODUCT_REMOVE_ADS], "inapp")
	restore_purchases()

func _on_billing_disconnected() -> void:
	is_connected = false
	print("[IAPManager] Google Play Billing disconnected.")

func _on_billing_connect_error(response_id: int, debug_message: String) -> void:
	is_connected = false
	print("[IAPManager] Google Play Billing connection failed: ", response_id, " - ", debug_message)

func _on_sku_details_query_completed(sku_details: Array) -> void:
	print("[IAPManager] SKU details received: ", sku_details)

func _on_sku_details_query_error(response_id: int, debug_message: String, _query_list: Array) -> void:
	print("[IAPManager] SKU query error: ", response_id, " - ", debug_message)

func _on_purchases_updated(purchases: Array) -> void:
	print("[IAPManager] Purchases updated: ", purchases)
	for purchase in purchases:
		var p_dict: Dictionary = purchase if purchase is Dictionary else {}
		var sku := ""
		if p_dict.has("skus") and p_dict["skus"] is Array and p_dict["skus"].size() > 0:
			sku = str(p_dict["skus"][0])
		elif p_dict.has("sku"):
			sku = str(p_dict["sku"])
		elif p_dict.has("product_id"):
			sku = str(p_dict["product_id"])

		if sku == PRODUCT_REMOVE_ADS or sku == "":
			var token: String = str(p_dict.get("purchase_token", p_dict.get("token", "")))
			if token != "" and _payment and _payment.has_method("acknowledgePurchase"):
				_payment.acknowledgePurchase(token)
			remove_ads()
			purchase_succeeded.emit(PRODUCT_REMOVE_ADS)

func _on_purchase_acknowledged(purchase_token: String) -> void:
	print("[IAPManager] Purchase acknowledged: ", purchase_token)

func _on_purchase_error(response_id: int, debug_message: String) -> void:
	print("[IAPManager] Purchase error: ", response_id, " - ", debug_message)
	purchase_failed.emit(PRODUCT_REMOVE_ADS, debug_message)

## Triggers the remove_ads purchase flow
func purchase_product(product_id: String = PRODUCT_REMOVE_ADS) -> void:
	if GameState.ads_removed:
		print("[IAPManager] Ads are already removed.")
		purchase_succeeded.emit(product_id)
		return

	if is_billing_available and is_connected and _payment != null:
		print("[IAPManager] Launching Google Play purchase flow for: ", product_id)
		var response = _payment.purchase(product_id)
		if response is Dictionary and response.get("status", 0) != 0:
			var msg: String = str(response.get("message", "Purchase initiation error"))
			print("[IAPManager] Purchase error: ", msg)
			purchase_failed.emit(product_id, msg)
	else:
		# Standalone / Editor / Test mode: remove ads directly
		print("[IAPManager] Standalone/editor mode: granted remove_ads.")
		remove_ads()
		purchase_succeeded.emit(product_id)

## Restores non-consumable purchases (like remove_ads)
func restore_purchases() -> void:
	if GameState.ads_removed:
		purchase_restored.emit(PRODUCT_REMOVE_ADS)
		return

	if is_billing_available and is_connected and _payment != null:
		if _payment.has_method("queryPurchases"):
			var result = _payment.queryPurchases("inapp")
			if result is Dictionary and result.get("status", 0) == 0:
				var purchases: Array = result.get("purchases", [])
				_on_purchases_updated(purchases)
				if GameState.ads_removed:
					purchase_restored.emit(PRODUCT_REMOVE_ADS)
	else:
		if GameState.ads_removed:
			purchase_restored.emit(PRODUCT_REMOVE_ADS)

## Permanently removes all ads and updates AdManager
func remove_ads() -> void:
	GameState.ads_removed = true
	GameState.save_progress()
	if AdManager and AdManager.has_method("remove_all_ads"):
		AdManager.remove_all_ads()
	elif AdManager:
		AdManager.hide_banner_top()
		AdManager.hide_banner_bottom()
	ads_removed_changed.emit(true)
	print("[IAPManager] All ads permanently removed! State saved.")
