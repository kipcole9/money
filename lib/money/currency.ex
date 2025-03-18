defmodule Money.Currency do
  @moduledoc """
  Functions to return lists of known, historic and
  legal tender currencies.
  """
  @data_dir [:code.priv_dir(:ex_cldr), "/cldr/locales"] |> :erlang.iolist_to_binary()
  @config %{data_dir: @data_dir, locales: ["en"], default_locale: "en"}

  @currencies Cldr.Locale.Loader.get_locale(:en, @config)
              |> Map.get(:currencies)

  @current_currencies @currencies
                      |> Enum.filter(fn {_code, currency} -> !is_nil(currency.iso_digits) end)
                      |> Enum.map(fn {code, _currency} -> code end)
                      |> Enum.sort()

  @historic_currencies @currencies
                       |> Enum.filter(fn {_code, currency} -> is_nil(currency.iso_digits) end)
                       |> Enum.map(fn {code, _currency} -> code end)
                       |> Enum.sort()

  @tender_currencies @currencies
                     |> Enum.filter(fn {_code, currency} -> currency.tender end)
                     |> Enum.map(fn {code, _currency} -> code end)
                     |> Enum.sort()

  @doc """
  Returns the list of currently active ISO 4217 currency codes.

  ## Example:

      iex> Money.Currency.known_current_currencies()
      [:AED, :AFN, :ALL, :AMD, :ANG, :AOA, :ARS, :AUD, :AWG, :AZN, :BAM, :BBD, :BDT,
       :BGN, :BHD, :BIF, :BMD, :BND, :BOB, :BOV, :BRL, :BSD, :BTN, :BWP, :BYN, :BZD,
       :CAD, :CDF, :CHE, :CHF, :CHW, :CLF, :CLP, :CNY, :COP, :COU, :CRC, :CUC, :CUP,
       :CVE, :CZK, :DJF, :DKK, :DOP, :DZD, :EGP, :ERN, :ETB, :EUR, :FJD, :FKP, :GBP,
       :GEL, :GHS, :GIP, :GMD, :GNF, :GTQ, :GYD, :HKD, :HNL, :HRK, :HTG, :HUF, :IDR,
       :ILS, :INR, :IQD, :IRR, :ISK, :JMD, :JOD, :JPY, :KES, :KGS, :KHR, :KMF, :KPW,
       :KRW, :KWD, :KYD, :KZT, :LAK, :LBP, :LKR, :LRD, :LSL, :LYD, :MAD, :MDL, :MGA,
       :MKD, :MMK, :MNT, :MOP, :MRU, :MUR, :MVR, :MWK, :MXN, :MXV, :MYR, :MZN, :NAD,
       :NGN, :NIO, :NOK, :NPR, :NZD, :OMR, :PAB, :PEN, :PGK, :PHP, :PKR, :PLN, :PYG,
       :QAR, :RON, :RSD, :RUB, :RWF, :SAR, :SBD, :SCR, :SDG, :SEK, :SGD, :SHP, :SLL,
       :SOS, :SRD, :SSP, :STN, :SVC, :SYP, :SZL, :THB, :TJS, :TMT, :TND, :TOP, :TRY,
       :TTD, :TWD, :TZS, :UAH, :UGX, :USD, :USN, :UYI, :UYU, :UYW, :UZS, :VES, :VND,
       :VUV, :WST, :XAF, :XAG, :XAU, :XBA, :XBB, :XBC, :XBD, :XCD, :XDR, :XOF, :XPD,
       :XPF, :XPT, :XSU, :XTS, :XUA, :XXX, :YER, :ZAR, :ZMW, :ZWL]

  """
  def known_current_currencies do
    @current_currencies
  end

  @doc """
  Returns the list of historic ISO 4217 currency codes.

  ## Example:

      iex> Money.Currency.known_historic_currencies()
      [:ADP, :AFA, :ALK, :AOK, :AON, :AOR, :ARA, :ARL, :ARM, :ARP, :ATS, :AZM, :BAD,
       :BAN, :BEC, :BEF, :BEL, :BGL, :BGM, :BGO, :BOL, :BOP, :BRB, :BRC, :BRE, :BRN,
       :BRR, :BRZ, :BUK, :BYB, :BYR, :CLE, :CNH, :CNX, :CSD, :CSK, :CYP, :DDM, :DEM,
       :ECS, :ECV, :EEK, :ESA, :ESB, :ESP, :FIM, :FRF, :GEK, :GHC, :GNS, :GQE, :GRD,
       :GWE, :GWP, :HRD, :IEP, :ILP, :ILR, :ISJ, :ITL, :KRH, :KRO, :LTL, :LTT, :LUC,
       :LUF, :LUL, :LVL, :LVR, :MAF, :MCF, :MDC, :MGF, :MKN, :MLF, :MRO, :MTL, :MTP,
       :MVP, :MXP, :MZE, :MZM, :NIC, :NLG, :PEI, :PES, :PLZ, :PTE, :RHD, :ROL, :RUR,
       :SDD, :SDP, :SIT, :SKK, :SLE, :SRG, :STD, :SUR, :TJR, :TMM, :TPE, :TRL, :UAK,
       :UGS, :USS, :UYP, :VEB, :VED, :VEF, :VNN, :XCG, :XEU, :XFO, :XFU, :XRE, :YDD,
       :YUD, :YUM, :YUN, :YUR, :ZAL, :ZMK, :ZRN, :ZRZ, :ZWD, :ZWG, :ZWR]

  """
  def known_historic_currencies do
    @historic_currencies
  end

  @doc """
  Returns the list of legal tender ISO 4217 currency codes.

  ## Example:

      iex> Money.Currency.known_tender_currencies()
      [:ADP, :AED, :AFA, :AFN, :ALK, :ALL, :AMD, :ANG, :AOA, :AOK, :AON, :AOR, :ARA,
       :ARL, :ARM, :ARP, :ARS, :ATS, :AUD, :AWG, :AZM, :AZN, :BAD, :BAM, :BAN, :BBD,
       :BDT, :BEC, :BEF, :BEL, :BGL, :BGM, :BGN, :BGO, :BHD, :BIF, :BMD, :BND, :BOB,
       :BOL, :BOP, :BOV, :BRB, :BRC, :BRE, :BRL, :BRN, :BRR, :BRZ, :BSD, :BTN, :BUK,
       :BWP, :BYB, :BYN, :BYR, :BZD, :CAD, :CDF, :CHE, :CHF, :CHW, :CLE, :CLF, :CLP,
       :CNH, :CNX, :CNY, :COP, :COU, :CRC, :CSD, :CSK, :CUC, :CUP, :CVE, :CYP, :CZK,
       :DDM, :DEM, :DJF, :DKK, :DOP, :DZD, :ECS, :ECV, :EEK, :EGP, :ERN, :ESA, :ESB,
       :ESP, :ETB, :EUR, :FIM, :FJD, :FKP, :FRF, :GBP, :GEK, :GEL, :GHC, :GHS, :GIP,
       :GMD, :GNF, :GNS, :GQE, :GRD, :GTQ, :GWE, :GWP, :GYD, :HKD, :HNL, :HRD, :HRK,
       :HTG, :HUF, :IDR, :IEP, :ILP, :ILR, :ILS, :INR, :IQD, :IRR, :ISJ, :ISK, :ITL,
       :JMD, :JOD, :JPY, :KES, :KGS, :KHR, :KMF, :KPW, :KRH, :KRO, :KRW, :KWD, :KYD,
       :KZT, :LAK, :LBP, :LKR, :LRD, :LSL, :LTL, :LTT, :LUC, :LUF, :LUL, :LVL, :LVR,
       :LYD, :MAD, :MAF, :MCF, :MDC, :MDL, :MGA, :MGF, :MKD, :MKN, :MLF, :MMK, :MNT,
       :MOP, :MRO, :MRU, :MTL, :MTP, :MUR, :MVP, :MVR, :MWK, :MXN, :MXP, :MXV, :MYR,
       :MZE, :MZM, :MZN, :NAD, :NGN, :NIC, :NIO, :NLG, :NOK, :NPR, :NZD, :OMR, :PAB,
       :PEI, :PEN, :PES, :PGK, :PHP, :PKR, :PLN, :PLZ, :PTE, :PYG, :QAR, :RHD, :ROL,
       :RON, :RSD, :RUB, :RUR, :RWF, :SAR, :SBD, :SCR, :SDD, :SDG, :SDP, :SEK, :SGD,
       :SHP, :SIT, :SKK, :SLE, :SLL, :SOS, :SRD, :SRG, :SSP, :STD, :STN, :SUR, :SVC,
       :SYP, :SZL, :THB, :TJR, :TJS, :TMM, :TMT, :TND, :TOP, :TPE, :TRL, :TRY, :TTD,
       :TWD, :TZS, :UAH, :UAK, :UGS, :UGX, :USD, :USN, :USS, :UYI, :UYP, :UYU, :UYW,
       :UZS, :VEB, :VED, :VEF, :VES, :VND, :VNN, :VUV, :WST, :XAF, :XAG, :XAU, :XBA,
       :XBB, :XBC, :XBD, :XCD, :XCG, :XDR, :XEU, :XFO, :XFU, :XOF, :XPD, :XPF, :XPT,
       :XRE, :XSU, :XTS, :XUA, :XXX, :YDD, :YER, :YUD, :YUM, :YUN, :YUR, :ZAL, :ZAR,
       :ZMK, :ZMW, :ZRN, :ZRZ, :ZWD, :ZWG, :ZWL, :ZWR]

  """
  def known_tender_currencies do
    @tender_currencies
  end

  def currency_for_code(code) do
    Cldr.Currency.currency_for_code(code, Money.default_backend!())
  end
end
