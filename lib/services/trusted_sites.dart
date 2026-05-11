import 'package:flutter/material.dart';

class TrustedSite {
  final String name;
  final IconData icon;
  final String url;
  const TrustedSite(this.name, this.icon, this.url);
}

class TrustedSitesData {
  static Map<String, Map<String, List<TrustedSite>>> getAllCountriesTrustedSites() {
    return {
      'India': {
        'KYC Directory': [
          TrustedSite('Aadhaar', Icons.fingerprint_rounded, 'https://myaadhaar.uidai.gov.in'),
          TrustedSite('DigiLocker', Icons.badge_rounded, 'https://digilocker.gov.in'),
          TrustedSite('PAN Services', Icons.credit_score_rounded, 'https://www.tin.nsdl.com'),
        ],
        'Tax & Finance': [
          TrustedSite('Income Tax', Icons.receipt_long_rounded, 'https://www.incometax.gov.in'),
          TrustedSite('EPFO / PF', Icons.savings_rounded, 'https://passbook.epfindia.gov.in'),
          TrustedSite('GST Portal', Icons.home_work_rounded, 'https://www.gst.gov.in'),
          TrustedSite('NSE / BSE', Icons.trending_up_rounded, 'https://www.nseindia.com'),
        ],
        'Banking': [
          TrustedSite('HDFC Bank', Icons.account_balance_rounded, 'https://netbanking.hdfcbank.com'),
          TrustedSite('SBI', Icons.account_balance_rounded, 'https://www.onlinesbi.sbi.in'),
          TrustedSite('ICICI Bank', Icons.account_balance_rounded, 'https://www.icicibank.com/online/accounts'),
          TrustedSite('Axis Bank', Icons.account_balance_rounded, 'https://www.axisbank.com/online-banking'),
          TrustedSite('Kotak Bank', Icons.account_balance_rounded, 'https://netbanking.kotak.com'),
        ],
        'Government': [
          TrustedSite('Parivahan', Icons.directions_car_rounded, 'https://parivahan.gov.in'),
          TrustedSite('LIC', Icons.health_and_safety_rounded, 'https://licindia.in'),
          TrustedSite('CIBIL Score', Icons.credit_score_rounded, 'https://www.cibil.com'),
        ],
      },
      'United States': {
        'Government': [
          TrustedSite('IRS', Icons.receipt_long_rounded, 'https://www.irs.gov'),
          TrustedSite('Social Security', Icons.badge_rounded, 'https://www.ssa.gov'),
          TrustedSite('DMV', Icons.directions_car_rounded, 'https://www.dmv.org'),
        ],
        'Banking': [
          TrustedSite('Chase Bank', Icons.account_balance_rounded, 'https://www.chase.com'),
          TrustedSite('Bank of America', Icons.account_balance_rounded, 'https://www.bankofamerica.com'),
          TrustedSite('Wells Fargo', Icons.account_balance_rounded, 'https://www.wellsfargo.com'),
        ],
        'Finance': [
          TrustedSite('NYSE', Icons.trending_up_rounded, 'https://www.nyse.com'),
          TrustedSite('NASDAQ', Icons.trending_up_rounded, 'https://www.nasdaq.com'),
          TrustedSite('SEC', Icons.verified_user_rounded, 'https://www.sec.gov'),
        ],
      },
      'United Kingdom': {
        'Government': [
          TrustedSite('HMRC', Icons.receipt_long_rounded, 'https://www.gov.uk/government/organisations/hm-revenue-customs'),
          TrustedSite('DVLA', Icons.directions_car_rounded, 'https://www.dvla.gov.uk'),
          TrustedSite('DWP', Icons.badge_rounded, 'https://www.gov.uk/government/organisations/department-for-work-pensions'),
        ],
        'Banking': [
          TrustedSite('Barclays', Icons.account_balance_rounded, 'https://www.barclays.co.uk'),
          TrustedSite('HSBC', Icons.account_balance_rounded, 'https://www.hsbc.co.uk'),
          TrustedSite('Lloyds', Icons.account_balance_rounded, 'https://www.lloydsbankinggroup.com'),
        ],
        'Finance': [
          TrustedSite('LSE', Icons.trending_up_rounded, 'https://www.londonstockexchange.com'),
          TrustedSite('FCA', Icons.verified_user_rounded, 'https://www.fca.org.uk'),
        ],
      },
      'Canada': {
        'Government': [
          TrustedSite('CRA', Icons.receipt_long_rounded, 'https://www.canada.ca/taxes'),
          TrustedSite('Service Canada', Icons.badge_rounded, 'https://www.canada.ca/service'),
          TrustedSite('Provincial ID', Icons.directions_car_rounded, 'https://www.ontario.ca/page/drive-clean-program'),
        ],
        'Banking': [
          TrustedSite('RBC', Icons.account_balance_rounded, 'https://www.rbc.com'),
          TrustedSite('TD Bank', Icons.account_balance_rounded, 'https://www.td.com'),
          TrustedSite('BMO', Icons.account_balance_rounded, 'https://www.bmo.com'),
        ],
        'Finance': [
          TrustedSite('TSX', Icons.trending_up_rounded, 'https://www.tmx.com'),
        ],
      },
      'Australia': {
        'Government': [
          TrustedSite('ATO', Icons.receipt_long_rounded, 'https://www.ato.gov.au'),
          TrustedSite('Centrelink', Icons.badge_rounded, 'https://www.servicesaustralia.gov.au'),
          TrustedSite('RMS', Icons.directions_car_rounded, 'https://www.rms.nsw.gov.au'),
        ],
        'Banking': [
          TrustedSite('Commonwealth Bank', Icons.account_balance_rounded, 'https://www.commbank.com.au'),
          TrustedSite('Westpac', Icons.account_balance_rounded, 'https://www.westpac.com.au'),
          TrustedSite('ANZ', Icons.account_balance_rounded, 'https://www.anz.com.au'),
        ],
        'Finance': [
          TrustedSite('ASX', Icons.trending_up_rounded, 'https://www.asx.com.au'),
          TrustedSite('ASIC', Icons.verified_user_rounded, 'https://asic.gov.au'),
        ],
      },
      'Singapore': {
        'Government': [
          TrustedSite('IRAS', Icons.receipt_long_rounded, 'https://www.iras.gov.sg'),
          TrustedSite('CPF', Icons.savings_rounded, 'https://www.cpf.gov.sg'),
          TrustedSite('LTA', Icons.directions_car_rounded, 'https://www.lta.gov.sg'),
        ],
        'Banking': [
          TrustedSite('DBS Bank', Icons.account_balance_rounded, 'https://www.dbs.com.sg'),
          TrustedSite('OCBC', Icons.account_balance_rounded, 'https://www.ocbc.com'),
          TrustedSite('UOB', Icons.account_balance_rounded, 'https://www.uob.com.sg'),
        ],
        'Finance': [
          TrustedSite('SGX', Icons.trending_up_rounded, 'https://www.sgx.com'),
          TrustedSite('MAS', Icons.verified_user_rounded, 'https://www.mas.gov.sg'),
        ],
      },
      'Germany': {
        'Government': [
          TrustedSite('Bundeszentralamt für Steuern', Icons.receipt_long_rounded, 'https://www.bzst.bund.de'),
          TrustedSite('ELSTER', Icons.badge_rounded, 'https://www.elster.de'),
          TrustedSite('KBA', Icons.directions_car_rounded, 'https://www.kba.de'),
        ],
        'Banking': [
          TrustedSite('Deutsche Bank', Icons.account_balance_rounded, 'https://www.deutsche-bank.de'),
          TrustedSite('Commerzbank', Icons.account_balance_rounded, 'https://www.commerzbank.de'),
        ],
        'Finance': [
          TrustedSite('Frankfurt Stock Exchange', Icons.trending_up_rounded, 'https://www.boerse-frankfurt.de'),
          TrustedSite('BaFin', Icons.verified_user_rounded, 'https://www.bafin.de'),
        ],
      },
      'France': {
        'Government': [
          TrustedSite('Impôts Gouv', Icons.receipt_long_rounded, 'https://www.impots.gouv.fr'),
          TrustedSite('French ID', Icons.badge_rounded, 'https://www.ants.gouv.fr'),
          TrustedSite('IMMATRICULATION', Icons.directions_car_rounded, 'https://www.immatriculation.gouv.fr'),
        ],
        'Banking': [
          TrustedSite('BNP Paribas', Icons.account_balance_rounded, 'https://www.bnpparibas.fr'),
          TrustedSite('Crédit Agricole', Icons.account_balance_rounded, 'https://www.credit-agricole.fr'),
          TrustedSite('Société Générale', Icons.account_balance_rounded, 'https://www.societegenerale.fr'),
        ],
        'Finance': [
          TrustedSite('Euronext Paris', Icons.trending_up_rounded, 'https://www.euronext.com'),
          TrustedSite('AMF', Icons.verified_user_rounded, 'https://www.amf-france.org'),
        ],
      },
      'Japan': {
        'Government': [
          TrustedSite('National Tax Agency', Icons.receipt_long_rounded, 'https://www.nta.go.jp'),
          TrustedSite('My Number', Icons.badge_rounded, 'https://www.my-number.go.jp'),
          TrustedSite('MLIT', Icons.directions_car_rounded, 'https://www.mlit.go.jp'),
        ],
        'Banking': [
          TrustedSite('Mitsubishi UFJ Bank', Icons.account_balance_rounded, 'https://www.bk.mufg.jp'),
          TrustedSite('Sumitomo Mitsui Banking', Icons.account_balance_rounded, 'https://www.smbc.co.jp'),
          TrustedSite('Mizuho Bank', Icons.account_balance_rounded, 'https://www.mizuhobank.co.jp'),
        ],
        'Finance': [
          TrustedSite('Tokyo Stock Exchange', Icons.trending_up_rounded, 'https://www.jpx.co.jp'),
          TrustedSite('FSA', Icons.verified_user_rounded, 'https://www.fsa.go.jp'),
        ],
      },
      'China': {
        'Government': [
          TrustedSite('State Taxation Administration', Icons.receipt_long_rounded, 'https://www.chinatax.gov.cn'),
          TrustedSite('CIDCA', Icons.badge_rounded, 'https://www.cidca.gov.cn'),
          TrustedSite('China Vehicle Administration', Icons.directions_car_rounded, 'https://www.122.gov.cn'),
        ],
        'Banking': [
          TrustedSite('Industrial and Commercial Bank of China', Icons.account_balance_rounded, 'https://www.icbc.com.cn'),
          TrustedSite('China Construction Bank', Icons.account_balance_rounded, 'https://www.ccb.com'),
          TrustedSite('Bank of China', Icons.account_balance_rounded, 'https://www.boc.cn'),
        ],
        'Finance': [
          TrustedSite('Shanghai Stock Exchange', Icons.trending_up_rounded, 'https://www.sse.com.cn'),
          TrustedSite('CSRC', Icons.verified_user_rounded, 'https://www.csrc.gov.cn'),
        ],
      },
      'Brazil': {
        'Government': [
          TrustedSite('Receita Federal', Icons.receipt_long_rounded, 'https://www.gov.br/rfb'),
          TrustedSite('Denatran', Icons.directions_car_rounded, 'https://www.gov.br/denatran'),
          TrustedSite('INSS', Icons.badge_rounded, 'https://www.gov.br/inss'),
        ],
        'Banking': [
          TrustedSite('Banco do Brasil', Icons.account_balance_rounded, 'https://www.bb.com.br'),
          TrustedSite('Bradesco', Icons.account_balance_rounded, 'https://www.bradesco.com.br'),
          TrustedSite('Itaú Unibanco', Icons.account_balance_rounded, 'https://www.itau.com.br'),
        ],
        'Finance': [
          TrustedSite('B3', Icons.trending_up_rounded, 'https://www.b3.com.br'),
          TrustedSite('CVM', Icons.verified_user_rounded, 'https://www.gov.br/cvm'),
        ],
      },
      'Mexico': {
        'Government': [
          TrustedSite('SAT', Icons.receipt_long_rounded, 'https://www.sat.gob.mx'),
          TrustedSite('INE', Icons.badge_rounded, 'https://www.ine.mx'),
          TrustedSite('Semovi', Icons.directions_car_rounded, 'https://www.semovi.cdmx.gob.mx'),
        ],
        'Banking': [
          TrustedSite('Banamex', Icons.account_balance_rounded, 'https://www.banamex.com'),
          TrustedSite('BBVA México', Icons.account_balance_rounded, 'https://www.bbva.mx'),
          TrustedSite('Scotiabank', Icons.account_balance_rounded, 'https://www.scotiabank.com.mx'),
        ],
        'Finance': [
          TrustedSite('BMV', Icons.trending_up_rounded, 'https://www.bmv.com.mx'),
          TrustedSite('CNBV', Icons.verified_user_rounded, 'https://www.cnbv.gob.mx'),
        ],
      },
      'South Korea': {
        'Government': [
          TrustedSite('National Tax Service', Icons.receipt_long_rounded, 'https://www.nts.go.kr'),
          TrustedSite('Road Traffic Authority', Icons.directions_car_rounded, 'https://www.koroad.or.kr'),
          TrustedSite('National Health Insurance', Icons.badge_rounded, 'https://www.nhis.or.kr'),
        ],
        'Banking': [
          TrustedSite('KB Kookmin Bank', Icons.account_balance_rounded, 'https://www.kbstar.com'),
          TrustedSite('Shinhan Bank', Icons.account_balance_rounded, 'https://www.shinhanbank.com'),
          TrustedSite('Hana Bank', Icons.account_balance_rounded, 'https://www.hanabank.com'),
        ],
        'Finance': [
          TrustedSite('Korea Exchange', Icons.trending_up_rounded, 'https://www.krx.co.kr'),
          TrustedSite('FSC', Icons.verified_user_rounded, 'https://www.fsc.go.kr'),
        ],
      },
      'Saudi Arabia': {
        'Government': [
          TrustedSite('General Authority of Zakat and Tax', Icons.receipt_long_rounded, 'https://www.gazt.gov.sa'),
          TrustedSite('ABSHER', Icons.badge_rounded, 'https://www.absher.sa'),
          TrustedSite('Traffic Authority', Icons.directions_car_rounded, 'https://www.moi.gov.sa'),
        ],
        'Banking': [
          TrustedSite('Saudi National Bank', Icons.account_balance_rounded, 'https://www.snb.com.sa'),
          TrustedSite('Al Rajhi Bank', Icons.account_balance_rounded, 'https://www.alrajhibank.com.sa'),
          TrustedSite('Saudi British Bank', Icons.account_balance_rounded, 'https://www.sabb.com.sa'),
        ],
        'Finance': [
          TrustedSite('Saudi Stock Exchange', Icons.trending_up_rounded, 'https://www.tadawul.com.sa'),
          TrustedSite('CMA', Icons.verified_user_rounded, 'https://www.cma.org.sa'),
        ],
      },
      'United Arab Emirates': {
        'Government': [
          TrustedSite('FTA', Icons.receipt_long_rounded, 'https://www.fta.gov.ae'),
          TrustedSite('GDRFA', Icons.badge_rounded, 'https://www.gdrfa.ae'),
          TrustedSite('RTA', Icons.directions_car_rounded, 'https://www.rta.ae'),
        ],
        'Banking': [
          TrustedSite('Emirates NBD', Icons.account_balance_rounded, 'https://www.emiratesnbd.com'),
          TrustedSite('First Abu Dhabi Bank', Icons.account_balance_rounded, 'https://www.fab.ae'),
          TrustedSite('Mashreq', Icons.account_balance_rounded, 'https://www.mashreqbank.com'),
        ],
        'Finance': [
          TrustedSite('ADX', Icons.trending_up_rounded, 'https://www.adx.ac'),
          TrustedSite('DFM', Icons.trending_up_rounded, 'https://www.dfm.ae'),
        ],
      },
    };
  }

  static List<String> getAllCountries() {
    return getAllCountriesTrustedSites().keys.toList()..sort();
  }
}