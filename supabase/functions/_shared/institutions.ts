// Institutions the daily collector scrapes. Each entry was checked by hand
// against its live page; `tableHint` picks the standard retail FD table on
// pages that also list promo / senior-citizen / product-specific tables.
//
// Institutions whose sites render rates with JavaScript (Sampath, HNB, DFCC,
// NSB, ...) can't be scraped with a plain fetch and aren't listed here — the
// app still shows them with a link to their official page.

export interface Institution {
  name: string; // must match the app's directory (investing_data_service.dart)
  type: 'LCB' | 'LSB' | 'LFC';
  url: string;
  tableHint?: RegExp;
}

export const INSTITUTIONS: Institution[] = [
  { name: 'Bank of Ceylon', type: 'LCB', url: 'https://www.boc.lk/rates-tariff' },
  { name: "People's Bank", type: 'LCB', url: 'https://www.peoplesbank.lk/interest-rates/' },
  { name: 'Commercial Bank', type: 'LCB', url: 'https://www.combank.lk/rates-tariff' },
  { name: 'Seylan Bank', type: 'LCB', url: 'https://www.seylan.lk/interest-rates', tableHint: /Interest Paid At Maturity/i },
  { name: 'Nations Trust Bank', type: 'LCB', url: 'https://www.nationstrust.com/deposit-rates' },
  { name: 'Regional Development Bank', type: 'LSB', url: 'https://www.rdb.lk/interest-rates/' },
  { name: 'Central Finance', type: 'LFC', url: 'https://www.cf.lk/interest-rates/', tableHint: /CF Term\s*$/ },
  { name: 'Vallibel Finance', type: 'LFC', url: 'https://www.vallibelfinance.com/fixed-deposits/', tableHint: /Normal Citizen\s*$/i },
  { name: 'HNB Finance', type: 'LFC', url: 'https://www.hnbfinance.lk/fixed-deposits/' },
];
