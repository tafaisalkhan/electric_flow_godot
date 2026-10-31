extends Node
## AdManager - Google AdMob integration (Poing AdMob Plugin v5)
## Banner (top & bottom toggled), Interstitial (every 3 levels)

# Google AdMob Ad Unit IDs
const ADMOB_APP_ID: String = "ca-app-pub-1852108665659812~4701123251"
const BANNER_AD_ID: String = "ca-app-pub-1852108665659812/2346422656"
const INTERSTITIAL_AD_ID: String = "ca-app-pub-1852108665659812/3455490196"
const REWARDED_AD_ID: String = "ca-app-pub-1852108665659812/4290059714"
const REWARDED_INTERSTITIAL_AD_ID: String = "ca-app-pub-3940256099942544/5354046379"

# Official Google AdMob Test Ad Unit IDs (100% Fill Rate on all test builds)
const TEST_BANNER_AD_ID: String = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_AD_ID: String = "ca-app-pub-3940256099942544/1033173712"

static var instance: Node
static var is_initialized: bool = false
var _plugin_available: bool = false

signal rewarded_video_completed
signal rewarded_video_unavailable(message: String)
signal rewarded_interstitial_completed
signal rewarded_interstitial_unavailable(message: String)

# Cached loaded ad objects
var _banner_view_top = null
var _banner_view_bottom = null
var _interstitial_ad = null

# REQUIRED: Keep callbacks alive so Godot doesn't garbage collect them!
var _init_listener = null
var _banner_top_cb = null
var _banner_bottom_cb = null
var _interstitial_cb = null

var banner_id: String = BANNER_AD_ID
var interstitial_id: String = INTERSTITIAL_AD_ID
var rewarded_id: String = REWARDED_AD_ID
var rewarded_interstitial_id: String = REWARDED_INTERSTITIAL_AD_ID

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	print("[AdManager] _ready - checking for MobileAds plugin...")
	if OS.get_name() == "Android":
		_plugin_available = true
		banner_id = BANNER_AD_ID
		interstitial_id = INTERSTITIAL_AD_ID
		rewarded_id = REWARDED_AD_ID
			
		print("[AdManager] Running on Android - initializing AdMob with banner: ", banner_id)
		_init_admob()
	else:
		print("[AdManager] Not on Android - ads disabled (desktop/editor mode)")

func _init_admob() -> void:
	if not _plugin_available:
		return
	_init_listener = OnInitializationCompleteListener.new()
	_init_listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		print("[AdManager] MobileAds native initialization complete!")
		is_initialized = true
		_load_banner_top()
		_load_banner_bottom()
		_load_interstitial()
	
	MobileAds.initialize(_init_listener)
	print("[AdManager] MobileAds.initialize() requested")

# =================== BANNER (TOP & BOTTOM) ===================

func _load_banner_top() -> void:
	if not is_initialized or GameState.ads_removed or _banner_view_top != null:
		return

	_banner_view_top = AdView.new(banner_id, AdSize.BANNER, AdPosition.TOP)
	_banner_top_cb = AdListener.new()
	_banner_top_cb.on_ad_loaded = func():
		print("[AdManager] Top Banner loaded successfully! (ID: %s)" % banner_id)
	_banner_top_cb.on_ad_failed_to_load = func(_err):
		print("[AdManager] Top Banner failed to load with ID %s: %s" % [banner_id, str(_err)])
		if not GameState.ads_removed:
			# Retry loading live banner after delay
			var tw := instance.create_tween() if is_instance_valid(instance) else null
			if tw:
				tw.tween_interval(20.0)
				tw.tween_callback(func():
					if _banner_view_top == null and not GameState.ads_removed:
						_load_banner_top()
				)
	_banner_view_top.ad_listener = _banner_top_cb
	_banner_view_top.load_ad(AdRequest.new())

func _load_banner_bottom() -> void:
	if not is_initialized or GameState.ads_removed or _banner_view_bottom != null:
		return

	_banner_view_bottom = AdView.new(banner_id, AdSize.BANNER, AdPosition.BOTTOM)
	_banner_bottom_cb = AdListener.new()
	_banner_bottom_cb.on_ad_loaded = func():
		print("[AdManager] Bottom Banner loaded successfully! (ID: %s)" % banner_id)
	_banner_bottom_cb.on_ad_failed_to_load = func(_err):
		print("[AdManager] Bottom Banner failed to load with ID %s: %s" % [banner_id, str(_err)])
		if not GameState.ads_removed:
			# Retry loading live banner after delay
			var tw := instance.create_tween() if is_instance_valid(instance) else null
			if tw:
				tw.tween_interval(20.0)
				tw.tween_callback(func():
					if _banner_view_bottom == null and not GameState.ads_removed:
						_load_banner_bottom()
				)
	_banner_view_bottom.ad_listener = _banner_bottom_cb
	_banner_view_bottom.load_ad(AdRequest.new())

func show_banner_top() -> void:
	if not _plugin_available or GameState.ads_removed:
		return
	if _banner_view_top == null:
		if is_initialized:
			_load_banner_top()
	elif _banner_view_top.has_method("show"):
		_banner_view_top.show()

func hide_banner_top() -> void:
	if _banner_view_top and _banner_view_top.has_method("hide"):
		_banner_view_top.hide()

func show_banner_bottom() -> void:
	if not _plugin_available or GameState.ads_removed:
		return
	if _banner_view_bottom == null:
		if is_initialized:
			_load_banner_bottom()
	elif _banner_view_bottom.has_method("show"):
		_banner_view_bottom.show()

func hide_banner_bottom() -> void:
	if _banner_view_bottom and _banner_view_bottom.has_method("hide"):
		_banner_view_bottom.hide()

func show_banner() -> void:
	if GameState.ads_removed:
		return
	show_banner_bottom()

func hide_banner() -> void:
	hide_banner_top()
	hide_banner_bottom()

func remove_all_ads() -> void:
	hide_banner_top()
	hide_banner_bottom()
	if _banner_view_top and _banner_view_top.has_method("destroy"):
		_banner_view_top.destroy()
		_banner_view_top = null
	if _banner_view_bottom and _banner_view_bottom.has_method("destroy"):
		_banner_view_bottom.destroy()
		_banner_view_bottom = null
	_interstitial_ad = null
	print("[AdManager] All ads removed and cached views destroyed.")

# =================== INTERSTITIAL ===================

func _load_interstitial() -> void:
	if not is_initialized or GameState.ads_removed:
		return

	var loader := InterstitialAdLoader.new()
	_interstitial_cb = InterstitialAdLoadCallback.new()

	_interstitial_cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_ad = ad
		print("[AdManager] Interstitial Ad loaded!")
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			_interstitial_ad = null
			_load_interstitial()
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
			_interstitial_ad = null
			_load_interstitial()

	_interstitial_cb.on_ad_failed_to_load = func(_err) -> void:
		_interstitial_ad = null
		print("[AdManager] Interstitial failed to load with ID %s: %s" % [interstitial_id, str(_err)])
		if not GameState.ads_removed:
			# Retry loading live interstitial after short delay
			var tw := instance.create_tween() if is_instance_valid(instance) else null
			if tw:
				tw.tween_interval(30.0)
				tw.tween_callback(func():
					if _interstitial_ad == null and not GameState.ads_removed:
						_load_interstitial()
				)

	loader.load(interstitial_id, AdRequest.new(), _interstitial_cb)

func show_interstitial() -> void:
	if not _plugin_available or GameState.ads_removed:
		return
	if _interstitial_ad:
		_interstitial_ad.show()
	else:
		if is_initialized:
			_load_interstitial()

# =================== REWARDED STUBS (UNUSED / DISABLED) ===================

func show_rewarded_video() -> bool:
	# Rewarded video removed per requirement: only interstitial & banner ads active
	rewarded_video_unavailable.emit("Rewarded video is disabled.")
	return false

func show_rewarded_interstitial() -> bool:
	rewarded_interstitial_unavailable.emit("Rewarded interstitial is disabled.")
	return false
