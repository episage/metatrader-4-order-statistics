//+------------------------------------------------------------------+
//|                                                    TickValue.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
#property indicator_chart_window

int OnInit()
{
    runOnce();
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { Comment(""); }

int OnCalculate(const int rates_total, const int prev_calculated,
    const datetime& time[], const double& open[],
    const double& high[], const double& low[],
    const double& close[], const long& tick_volume[],
    const long& volume[], const int& spread[])
{
    runOnce();

    return (0.0);
}

void runOnce(){
    string comment = "";

    double oneLotMargin = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
    double oneLotPipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double currentSpread = MarketInfo(Symbol(), MODE_SPREAD);

    double balance = AccountBalance();
    double equity = AccountEquity();
    double freeMargin = AccountFreeMargin();
    double risk = GlobalVariableGet("MaxRiskPercent");
    if (!risk) {
        risk = 6;
    }
    double riskPln = balance * (risk / 100);
    double riskPips = riskPln / (MarketInfo(Symbol(), MODE_TICKVALUE) / 100);

    comment += "1 Lot Margin Required = " + DoubleToStr(oneLotMargin, 2) + " PLN";
    comment += "\n" + "Spread = " + DoubleToStr(currentSpread, 0);
    comment += "\n" + "1 pips @ 0.01 Lot = " + DoubleToStr(oneLotPipValue / 100, 4) + " PLN";
    comment += "\n" + "1 pips @ " + DoubleToStr(balance / oneLotMargin, 2) + " Lot = " + DoubleToStr(oneLotPipValue * balance / oneLotMargin, 2) + " PLN";

    // comment += "\n" + "Max risk = " + DoubleToStr(riskPln, 2) + " PLN";
    // comment += "\n" + "Max risk pips @ 0.01 = " + DoubleToStr(riskPips, 0);
    comment += "\n" + "Max lot (eq) = " + DoubleToStr(equity / oneLotMargin, 4);
    comment += "\n" + "Max lot (bal) = " + DoubleToStr(balance / oneLotMargin, 4);
    comment += "\n" + "Max lot (fm) = " + DoubleToStr(freeMargin / oneLotMargin, 4);

    comment += "\n" + "This pair max lot = " + DoubleToStr(balance / oneLotMargin / 3, 4);
    comment += "\n" + "This pair max risk = " + DoubleToStr(riskPln, 4) + " PLN";
    comment += "\n";
    comment += riskRewardComment();

    Comment(comment);
}

string riskRewardComment()
{
    double balance = AccountBalance();
    double equity = AccountEquity();

    int totalNumberOfOrders = OrdersTotal();
    int i;
    string text = "";
    for (i = 0; i < totalNumberOfOrders; i++) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            continue; // skip if select failed
        }

        int ticket = OrderTicket();
        double openPrice = OrderOpenPrice();
        double closePrice = OrderClosePrice();
        double sl = OrderStopLoss();
        double tp = OrderTakeProfit();
        double lots = OrderLots();

        string symbol = OrderSymbol();
        int type = OrderType();

        if (symbol != Symbol()) {
            continue; // must be the same symbol as current chart, otherwise skip
        }

        string rrString = riskRewardString(type, sl, tp, openPrice);

        double potentialProfit = calcPL(symbol, type, openPrice, tp, lots);
        string potentialProfitString = DoubleToStr(potentialProfit, 2);
        double potentialProfitToBalance = safeDiv(potentialProfit, balance) * 100;
        string potentialProfitToBalanceString = DoubleToStr(potentialProfitToBalance, 0);

        double potentialLoss = calcPL(symbol, type, openPrice, sl, lots);
        string potentialLossString = DoubleToStr(potentialLoss, 2);
        double potentialLossToBalance = safeDiv(potentialLoss, balance) * 100;
        string potentialLossToBalanceString = DoubleToStr(potentialLossToBalance, 0);

        string orderTypeString = orderTypeToString(type);
        string percentageRealizedString = percentageRealizedString(type, sl, tp, closePrice);

        text += "\n" + "RR: [" + rrString + "] " + "P: [" + potentialProfitString + " (+" + potentialProfitToBalanceString + "%)] " + "L: [" + potentialLossString + " (-" + potentialLossToBalanceString + "%)] ";
    }
    return text;
}

double safeDiv(double a, double b)
{
    if (b == 0.0) {
        return (0.0);
    }
    else {
        return (a / b);
    }
}

string riskRewardString(int type, double sl, double tp, double openPrice)
{
    double rr;

    switch (type) {
    case OP_BUY:
    case OP_BUYLIMIT:
    case OP_BUYSTOP: {
        if (sl >= openPrice) {
            rr = 0.000000;
        }
        else {
            rr = MathAbs((tp - openPrice) / (sl - openPrice));
        }
        break;
    }
    case OP_SELL:
    case OP_SELLLIMIT:
    case OP_SELLSTOP: {
        if (sl <= openPrice) {
            rr = 0.000000;
        }
        else {
            rr = MathAbs((openPrice - tp) / (openPrice - sl));
        }
        break;
    }
    default: {
        return "?";
    }
    }
    if (sl == 0.0 || tp == 0.0) {
        rr = 0.0;
    }

    string str = DoubleToStr(rr, 2);

    return str;
}

string percentageRealizedString(int type, double sl, double tp,
    double closePrice)
{
    switch (type) {
    case OP_BUY:
    case OP_SELL: {
        double range = MathAbs(sl - tp);
        double currentLevel = MathAbs(closePrice - sl);
        double percentage = currentLevel / range * 100;
        return DoubleToStr(percentage, 0) + "%";
    }
    default: {
        //      -100.00%
        return "PENDING";
    }
    }
}

string orderTypeToString(int type)
{
    switch (type) {
    case OP_BUY: {
        return "B ";
    }
    case OP_SELL: {
        return "S ";
    }
    case OP_BUYLIMIT: {
        return "BL";
    }
    case OP_BUYSTOP: {
        return "BS";
    }
    case OP_SELLLIMIT: {
        return "SL";
    }
    case OP_SELLSTOP: {
        return "SS";
    }
    default: {
        return "  ";
    }
    }
}

double PointValuePerLot()
{ // Value in account currency of a Point of Symbol.
    /* In tester I had a sale: open=1.35883 close=1.35736 (0.00147)
   * gain$=97.32/6.62 lots/147 points=$0.10/point or $1.00/pip.
   * IBFX demo/mini       EURUSD TICKVALUE=0.1 MAXLOT=50 LOTSIZE=10,000
   * IBFX demo/standard   EURUSD TICKVALUE=1.0 MAXLOT=50 LOTSIZE=100,000
   *                                  $1.00/point or $10.00/pip.
   *
   * https://forum.mql4.com/33975 CB: MODE_TICKSIZE will usually return the
   * same value as MODE_POINT (or Point for the current symbol), however, an
   * example of where to use MODE_TICKSIZE would be as part of a ratio with
   * MODE_TICKVALUE when performing money management calculations which need
   * to take account of the pair and the account currency. The reason I use
   * this ratio is that although TV and TS may constantly be returned as
   * something like 7.00 and 0.00001 respectively, I've seen this
   * (intermittently) change to 14.00 and 0.00002 respectively (just example
   * tick values to illustrate). */
    return (MarketInfo(Symbol(), MODE_TICKVALUE) / MarketInfo(Symbol(), MODE_TICKSIZE)); // Not Point.
}

double calcPL(string sym, int type, double entry, double exit, double lots)
{
    if (entry == 0.0 || exit == 0.0 || lots == 0.0) {
        return (0.0);
    }

    double result;
    if (type == OP_BUY || type == OP_BUYLIMIT || type == OP_BUYSTOP) {
        result = (exit - entry) * lots * (1 / MarketInfo(sym, MODE_POINT)) * MarketInfo(sym, MODE_TICKVALUE);
    }
    else if (type == OP_SELL || type == OP_SELLLIMIT || type == OP_SELLSTOP) {
        result = (entry - exit) * lots * (1 / MarketInfo(sym, MODE_POINT)) * MarketInfo(sym, MODE_TICKVALUE);
    }
    else {
        result = 0.0;
    }
    return (result);
}
