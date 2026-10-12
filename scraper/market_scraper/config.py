"""What to scrape. Keys must match lib/core/sandbox/sandbox_config.dart."""

COLOMBO_OFFSET_HOURS = 5.5
TROY_OUNCE_GRAMS = 31.1034768

# CBSL currency code -> (app symbol, display name). XAU becomes GOLD24K.
CBSL_CURRENCIES = {
    "USD": ("USDLKR", "US Dollar"),
    "EUR": ("EURLKR", "Euro"),
    "GBP": ("GBPLKR", "Pound Sterling"),
    "AUD": ("AUDLKR", "Australian Dollar"),
    "INR": ("INRLKR", "Indian Rupee"),
    "JPY": ("JPYLKR", "Japanese Yen"),
}
# Labels CBSL's form expects in chk_cur[] ("CODE~Name").
CBSL_FORM_NAMES = {
    "USD": "US Dollar", "EUR": "Euro", "GBP": "Sterling Pound", "AUD": "Australian Dollar",
    "INR": "Indian Rupee", "JPY": "Japanese Yen", "XAU": "Gold (per Troy oz.)",
}
GOLD_SYMBOL = "GOLD24K"

# CSE symbol prefix -> app symbol (the app drops the share-class suffix).
CSE_SYMBOLS = {
    "JKH.N": "John Keells Holdings",
    "COMB.N": "Commercial Bank",
    "HNB.N": "Hatton National Bank",
    "DIAL.N": "Dialog Axiata",
    "CTC.N": "Ceylon Tobacco",
    "CARG.N": "Cargills (Ceylon)",
    "HAYL.N": "Hayleys",
    "TKYO.N": "Tokyo Cement",
    "LIOC.N": "Lanka IOC",
    "AEL.N": "Access Engineering",
}

# Banks whose names match kFdFallbackRates in the app. Each page was checked
# for the supabase/functions/_shared/institutions.ts collector; banks that
# render rates with JavaScript (e.g. NSB) can't be read and stay simulated.
BOC_RATES_URL = "https://www.boc.lk/rates-tariff"
BANKS = [
    {"name": "Bank of Ceylon", "url": BOC_RATES_URL},
    {"name": "People's Bank", "url": "https://www.peoplesbank.lk/interest-rates/"},
    {"name": "Commercial Bank", "url": "https://www.combank.lk/rates-tariff"},
    {"name": "Seylan Bank", "url": "https://www.seylan.lk/interest-rates", "table_hint": r"Interest Paid At Maturity"},
    {"name": "Central Finance", "url": "https://www.cf.lk/interest-rates/", "table_hint": r"CF Term\s*$"},
]
FD_TENURES = [1, 3, 6, 12, 24]
