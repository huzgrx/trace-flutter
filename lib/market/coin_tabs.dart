import 'package:flutter/material.dart';
import '../flutter_candlesticks.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../market_page.dart';
import '../portfolio/transaction_sheet.dart';
import '../main.dart';
import 'coin_aggregate_stats.dart';
import 'coin_exchanges_list.dart';
import '../portfolio/transactions_page.dart';

class CoinDetails extends StatefulWidget {
  CoinDetails({
    this.snapshot,
    this.enableTransactions = false,
  });

  final bool enableTransactions;
  final snapshot;

  @override
  CoinDetailsState createState() => new CoinDetailsState();
}

class CoinDetailsState extends State<CoinDetails> with SingleTickerProviderStateMixin {
  TabController _tabController;
  int _tabAmt;
  List<Widget> _tabBarChildren;

  String id;
  String symbol;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  _makeTabs() {
    if (widget.enableTransactions) {
      _tabAmt = 3;
      _tabBarChildren = [
        new Tab(text: "Stats"),
        new Tab(text: "Markets"),
        new Tab(text: "Transactions")
      ];
    } else {
      _tabAmt = 2;
      _tabBarChildren = [
        new Tab(text: "Aggregate Stats"),
        new Tab(text: "Markets")
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _makeTabs();
    _tabController = new TabController(length: _tabAmt, vsync: this);

    symbol = widget.snapshot["symbol"];
    id = widget.snapshot["id"];

    _makeGeneralStats();
    if (historyOHLCV == null) {
      changeHistory(historyType, historyAmt, historyTotal, historyAgg);
    }

    if (exchangeData == null) {_getExchangeData();}

  }

  @override
  Widget build(BuildContext context) {

    print("built coin tabs");

    return new Scaffold(
        key: _scaffoldKey,
        appBar: new PreferredSize(
          preferredSize: const Size.fromHeight(75.0),
          child: new AppBar(
            backgroundColor: Theme.of(context).primaryColor,
            titleSpacing: 2.0,
            elevation: appBarElevation,
            title: new Text(widget.snapshot["name"], style: Theme.of(context).textTheme.title),
            bottom: new PreferredSize(
                preferredSize: const Size.fromHeight(25.0),
                child: new Container(
                    height: 30.0,
                    child: new TabBar(
                      controller: _tabController,
                      indicatorColor: Theme.of(context).accentIconTheme.color,
                      indicatorWeight: 2.0,
                      unselectedLabelColor: Theme.of(context).disabledColor,
                      labelColor: Theme.of(context).primaryIconTheme.color,
                      tabs: _tabBarChildren,
                    )
                )
            ),
            actions: <Widget>[
              widget.enableTransactions ? new IconButton(
                  icon: new Icon(Icons.add),
                  onPressed: () {
                    _scaffoldKey.currentState.showBottomSheet((BuildContext context) {
                      return new TransactionSheet(
                        () {setState(() {});},
                        marketListData);
                    });
                }
              ) : new Container(),
            ],
          ),
        ),
        body: new TabBarView(
          controller: _tabController,
          children: widget.enableTransactions ? [
            aggregateStats(context),
            exchangeListPage(context),
            new TransactionsPage(symbol: widget.snapshot["symbol"])
          ] : [
            aggregateStats(context),
            exchangeListPage(context)
          ]
        )
    );
  }

  Map generalStats;
  List historyOHLCV;

  String _high = "0";
  String _low = "0";
  String _change = "0";

  int currentOHLCVWidthSetting;
  String historyAmt;
  String historyType;
  String historyTotal;
  String historyAgg;

  normalizeNum(num input) {
    if (input < 1) {
      return input.toStringAsFixed(4);
    } else {
      return input.toStringAsFixed(2);
    }
  }

  _getGeneralStats() async {
    await getMarketData();
    _makeGeneralStats();
  }

  _makeGeneralStats() {
    for (Map coin in marketListData) {
      if (coin["symbol"] == symbol) {
        generalStats = coin["quotes"]["USD"];
        break;
      }
    }
  }

  Future<Null> getHistoryOHLCV() async {
    var response = await http.get(
        Uri.encodeFull(
            "https://min-api.cryptocompare.com/data/histo"+ohlcvWidthOptions[historyTotal][currentOHLCVWidthSetting][3]+
                "?fsym="+symbol+
                "&tsym=USD&limit="+(ohlcvWidthOptions[historyTotal][currentOHLCVWidthSetting][1] - 1).toString()+
                "&aggregate="+ohlcvWidthOptions[historyTotal][currentOHLCVWidthSetting][2].toString()
        ),
        headers: {"Accept": "application/json"}
    );
    setState(() {
      historyOHLCV = new JsonDecoder().convert(response.body)["Data"];
      if (historyOHLCV == null) {
        historyOHLCV = [];
      }
    });
  }

  Future<Null> changeOHLCVWidth(int currentSetting) async {
    currentOHLCVWidthSetting = currentSetting;
    historyOHLCV = null;
    getHistoryOHLCV();
  }

  _getHL() {
    num highReturn = -double.infinity;
    num lowReturn = double.infinity;

    for (var i in historyOHLCV) {
      if (i["high"] > highReturn) {
        highReturn = i["high"].toDouble();
      }
      if (i["low"] < lowReturn) {
        lowReturn = i["low"].toDouble();
      }
    }

    _high = normalizeNum(highReturn);
    _low = normalizeNum(lowReturn);

    var start = historyOHLCV[0]["open"] == 0 ? 1 : historyOHLCV[0]["open"];
    var end = historyOHLCV.last["close"];
    var changePercent = (end-start)/start*100;
    _change = changePercent.toString().substring(0, changePercent > 0 ? 5 : 6);
  }

  Future<Null> changeHistory(String type, String amt, String total, String agg) async {
    setState((){
      _high = "0";
      _low = "0";
      _change = "0";

      historyAmt = amt;
      historyType = type;
      historyTotal = total;
      historyAgg = agg;

      historyOHLCV = null;

    });
    _getGeneralStats();
    await getHistoryOHLCV();
    _getHL();
  }

  Widget aggregateStats(BuildContext context) {

    print("built aggregate stats");

    return new Scaffold(
      resizeToAvoidBottomPadding: false,
      body: new RefreshIndicator(
          onRefresh: () => changeHistory(historyType, historyAmt, historyTotal, historyAgg),
          child: new ListView(
            children: <Widget>[
              new Container(
                height: MediaQuery.of(context).size.height - (appBarHeight+75.0),
                child: new Column(
                  children: <Widget>[
                    new Container(
                      padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0, bottom: 4.0),
                      child: new Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          new Text("\$"+ (generalStats != null ? generalStats["price"].toString() : "0"), style: Theme.of(context).textTheme.body2.apply(fontSizeFactor: 2.2)),
                          new Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              new Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  new Text("Market Cap", style: Theme.of(context).textTheme.caption.apply(fontSizeFactor: .8)),
                                  new Padding(padding: const EdgeInsets.symmetric(vertical: 2.5)),
                                  new Text("24h Volume", style: Theme.of(context).textTheme.caption.apply(fontSizeFactor: .8)),
                                ],
                              ),
                              new Padding(padding: const EdgeInsets.symmetric(horizontal: 2.0)),
                              new Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  new Text(generalStats != null ? numCommaParse(generalStats["market_cap"].toString()) : "0",
                                      style: Theme.of(context).textTheme.body2.apply(fontSizeFactor: 1.1, fontWeightDelta: 2)),
                                  new Text(generalStats != null ? numCommaParse(generalStats["volume_24h"].toString()) : "0",
                                      style: Theme.of(context).textTheme.body2.apply(fontSizeFactor: 1.1, fontWeightDelta: 2, color: Theme.of(context).hintColor)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    new Card(
                      elevation: 2.0,
                      child: new Row(
                        children: <Widget>[
                          new Flexible(
                            child: new Container(
//                                color: Theme.of(context).canvasColor,
                                padding: const EdgeInsets.all(6.0),
                                child: new Column(
                                  children: <Widget>[
                                    new Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        new Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            new Row(
                                              children: <Widget>[
                                                new Text("Period", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                                new Padding(padding: const EdgeInsets.only(right: 3.0)),
                                                new Text(historyTotal, style: Theme.of(context).textTheme.body2.apply(fontWeightDelta: 2)),
                                                new Padding(padding: const EdgeInsets.only(right: 4.0)),
                                                historyOHLCV != null ? new Text(num.parse(_change) > 0 ? "+" + _change+"%" : _change+"%",
                                                    style: Theme.of(context).primaryTextTheme.body2.apply(
                                                        color: num.parse(_change) >= 0 ? Colors.green : Colors.red
                                                    )
                                                ) : new Container()
                                              ],
                                            ),
                                            new Row(
                                              children: <Widget>[
                                                new Text("Candle Width", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                                new Padding(padding: const EdgeInsets.only(right: 2.0)),
                                                new Text(ohlcvWidthOptions[historyTotal][currentOHLCVWidthSetting][0], style: Theme.of(context).textTheme.body2.apply(fontWeightDelta: 2))
                                              ],
                                            ),
                                          ],
                                        ),
                                        historyOHLCV != null ? new Row(
//                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            new Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                new Text("High", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                                new Text("Low", style: Theme.of(context).textTheme.body1.apply(color: Theme.of(context).hintColor)),
                                              ],
                                            ),
                                            new Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5)),
                                            new Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: <Widget>[
                                                new Text("\$"+_high, style: Theme.of(context).textTheme.body2),
                                                new Text("\$"+_low, style: Theme.of(context).textTheme.body2)
                                              ],
                                            ),
                                          ],
                                        ) : new Container()
                                      ],
                                    ),
                                  ],
                                )
                            ),
                          ),
                          new Container(
                              child: new PopupMenuButton(
                                tooltip: "Select Width",
                                icon: new Icon(Icons.swap_horiz, color: Theme.of(context).buttonColor),
                                itemBuilder: (BuildContext context) {
                                  List<PopupMenuEntry<dynamic>> options = [];
                                  for (int i = 0; i < ohlcvWidthOptions[historyTotal].length; i++) {
                                    options.add(new PopupMenuItem(child: new Text(ohlcvWidthOptions[historyTotal][i][0]), value: i));
                                  }
                                  return options;
                                },
                                onSelected: (result) {
                                  changeOHLCVWidth(result);
                                },
                              )
                          ),
                          new Container(
                              child: new PopupMenuButton(
                                tooltip: "Select Period",
                                icon: new Icon(Icons.access_time, color: Theme.of(context).buttonColor),
                                itemBuilder: (BuildContext context) => [
                                  new PopupMenuItem(child: new Text("1h"), value: ["minute", "60", "1h", "1"]),
                                  new PopupMenuItem(child: new Text("6h"), value: ["minute", "360", "6h", "1"]),
                                  new PopupMenuItem(child: new Text("12h"), value: ["minute", "720", "12h", "1"]),
                                  new PopupMenuItem(child: new Text("24h"), value: ["minute", "720", "24h", "2"]),
                                  new PopupMenuItem(child: new Text("3D"), value: ["hour", "72", "3D", "1"]),
                                  new PopupMenuItem(child: new Text("7D"), value: ["hour", "168", "7D", "1"]),
                                  new PopupMenuItem(child: new Text("1M"), value: ["hour", "720", "1M", "1"]),
                                  new PopupMenuItem(child: new Text("3M"), value: ["day", "90", "3M", "1"]),
                                  new PopupMenuItem(child: new Text("6M"), value: ["day", "180", "6M", "1"]),
                                  new PopupMenuItem(child: new Text("1Y"), value: ["day", "365", "1Y", "1"]),
                                ],
                                onSelected: (result) {changeHistory(result[0], result[1], result[2], result[3]);},
                              )
                          ),
                        ],
                      ),
                    ),
                    new Flexible(
                      child: historyOHLCV != null ? new Container(
                        padding: const EdgeInsets.only(left: 2.0, right: 1.0, top: 10.0),
                        child: historyOHLCV.isEmpty != true ? new OHLCVGraph(
                          data: historyOHLCV,
                          enableGridLines: true,
                          gridLineColor: Theme.of(context).dividerColor,
                          gridLineLabelColor: Theme.of(context).hintColor,
                          gridLineAmount: 4,
                          volumeProp: 0.2,
                        ) : new Container(
                          padding: const EdgeInsets.all(30.0),
                          alignment: Alignment.topCenter,
                          child: new Text("No OHLCV data found :(", style: Theme.of(context).textTheme.caption),
                        ),
                      ) : new Container(
                        child: new Center(
                          child: new CircularProgressIndicator(),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          )
      ),
      bottomNavigationBar: new BottomAppBar(
        elevation: appBarElevation,
        child: generalStats != null
            ? new QuickPercentChangeBar(snapshot: generalStats)
            : new Container(
          height: 0.0,
        ),
      ),
    );
  }

  final columnProps = [.3,.3,.25];
  List exchangeData;

  Future<Null> _getExchangeData() async {
    var response = await http.get(
        Uri.encodeFull(
            "https://min-api.cryptocompare.com/data/top/exchanges/full?fsym="
                + symbol + "&tsym=USD&limit=1000"),
        headers: {"Accept": "application/json"});

    if (new JsonDecoder().convert(response.body)["Response"] != "Success") {
      setState(() {
        exchangeData = [];
      });
    } else {
      exchangeData = new JsonDecoder().convert(response.body)["Data"]["Exchanges"];
      _makeExchangeData();
    }
  }

  void _makeExchangeData() {
    List sortedExchangeData = [];
    for (var i in exchangeData) {
      if (i["VOLUME24HOURTO"] > 1000) {
        sortedExchangeData.add(i);
      }
    }
    setState(() {
      exchangeData = sortedExchangeData;
    });
  }

  Widget exchangeListPage(BuildContext context) {
    return exchangeData != null ? new RefreshIndicator(
        onRefresh: () => _getExchangeData(),
        child: exchangeData.isEmpty != true ? new CustomScrollView(
          slivers: <Widget>[
            new SliverList(delegate: new SliverChildListDelegate(<Widget>[
              new Container(
                margin: const EdgeInsets.only(left: 6.0, right: 6.0, top: 8.0),
                decoration: new BoxDecoration(
                    border: new Border(
                        bottom: new BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1.0))),
                padding: const EdgeInsets.only(bottom: 8.0, left: 2.0, right: 2.0),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    new Container(
                      width: MediaQuery.of(context).size.width * columnProps[0],
                      child: new Text("Exchange",
                          style: Theme.of(context).textTheme.body2),
                    ),
                    new Container(
                      alignment: Alignment.centerRight,
                      width: MediaQuery.of(context).size.width * columnProps[1],
                      child: new Text("24h Volume",
                          style: Theme.of(context).textTheme.body2),
                    ),
                    new Container(
                      alignment: Alignment.centerRight,
                      width: MediaQuery.of(context).size.width * columnProps[2],
                      child: new Text("Price/24h",
                          style: Theme.of(context).textTheme.body2),
                    ),
                  ],
                ),
              ),
            ]
            )
            ),
            new SliverList(
                delegate: new SliverChildBuilderDelegate(
                      (BuildContext context, int index) =>
                  new ExchangeListItem(exchangeData[index], columnProps),
                  childCount: exchangeData == null ? 0 : exchangeData.length,
                )
            )
          ],
        ) : new CustomScrollView(
          slivers: <Widget>[
            new SliverList(delegate: new SliverChildListDelegate(
                <Widget>[
                  new Container(
                    padding: const EdgeInsets.all(30.0),
                    alignment: Alignment.topCenter,
                    child: new Text("No exchanges found :(", style: Theme.of(context).textTheme.caption),
                  )
                ]
            ))
          ],
        )
    ) : new Container(
      child: new Center(child: new CircularProgressIndicator()),
    );
  }
}
