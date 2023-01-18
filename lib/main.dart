import 'dart:async';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SampleApp());
}

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: const MainPage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});
  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  String _version = "Version";
  bool useRememberMe = false;
  bool actionBarEnabled = false;
  bool autoConsentEnabled = false;
  bool statementRetrievalEnabled = false;
  bool loggingEnabled = true;
  bool balanceRetrievalEnabled = false;
  bool showLogging = true;

  static const MethodChannel statementChannel = MethodChannel('com.brankas.tap/statement');

  var apiKeyController = TextEditingController();
  var orgNameController = TextEditingController();
  var successURLController = TextEditingController();
  var failURLController = TextEditingController();
  var actionBarController = TextEditingController();
  var externalIDController = TextEditingController();

  List<String> countries = ["Philippines", "Indonesia", "Thailand"];
  List<String> bankNames = [];
  List<int> bankCodes = [];
  List<String> bankLogos = [];
  List<bool> isBankChecked = [];
  String country = "Philippines";

  DateTime endDate = DateTime.now();
  DateTime startDate = DateTime.now();

  Future<void> checkout() async {
    try {
      List<String> banks = [];
      for(int i = 0; i < bankNames.length; i++) {
        if(isBankChecked[i]) {
          banks.add(bankNames[i]);
        }
      }
      statementChannel.invokeMethod('checkout', {"apiKey" : apiKeyController.text,
        "orgName" : orgNameController.text, "successURL" : successURLController.text,
        "failURL" : failURLController.text, "country" : country, "banks" : banks,
        "rememberMe" : useRememberMe, "actionBarText" : actionBarEnabled ?
        actionBarController.text : null, "externalID" : externalIDController.text,
        "autoConsent" : autoConsentEnabled, "startDate" :
        statementRetrievalEnabled ? startDate.millisecondsSinceEpoch : null,
        "endDate" :
        statementRetrievalEnabled ? endDate.millisecondsSinceEpoch : null,
        "logging" : loggingEnabled, "balanceRetrieval" : balanceRetrievalEnabled});
    } on PlatformException catch (e) {

    }
  }

  Future<void> getSDKVersion() async {
    String response = "";
    try {
      final String result = await statementChannel.invokeMethod('getVersion');
      response = result;
    } on PlatformException catch (e) {
      response = "Failed to Invoke: '${e.message}'.";
    }

    setState(() {
      _version = response;
    });
  }

  Future<void> getBanks() async {
    List<Object?> banks = [];
    try {
      banks = await statementChannel.invokeMethod(
          'getEnabledBanks', {"country": country,
        "apiKey" : apiKeyController.text, "logging" : loggingEnabled,
        "balanceRetrieval" : balanceRetrievalEnabled});
    } on PlatformException catch (e) {

    }
    setState(() {
      bankNames.clear();
      bankCodes.clear();
      isBankChecked.clear();
      if(banks.isNotEmpty) {
        List<Object?> bankNames = banks[0] as List<Object?>;
        for (final bankName in bankNames) {
          this.bankNames.add(bankName as String);
        }
        List<Object?> bankCodes = banks[1] as List<Object?>;
        for (final bankCode in bankCodes) {
          this.bankCodes.add(bankCode as int);
        }
        List<Object?> bankLogos = banks[2] as List<Object?>;
        for (final bankLogo in bankLogos) {
          this.bankLogos.add(bankLogo as String);
          isBankChecked.add(true);
        }
      }
    });
  }

  void updateCountry(String country) {
    setState(() {
      this.country = country;
      getBanks();
    });
  }

  void autoFillDetails() {
    apiKeyController.text = "";
    externalIDController.text = DateTime.now().toString();
    orgNameController.text = "Org Name";
    successURLController.text = "https://success.com";
    failURLController.text = "https://fail.com";
    getBanks();
  }

  bool isCheckoutEnabled() {
    return apiKeyController.text.isNotEmpty &&
        externalIDController.text.isNotEmpty &&
        orgNameController.text.isNotEmpty &&
        successURLController.text.isNotEmpty &&
        failURLController.text.isNotEmpty;
  }

  void toggleRememberMe(bool value) {
    setState(() {
      useRememberMe = value;
    });
  }

  void toggleActionBar(bool value) {
    setState(() {
      actionBarEnabled = value;
    });
  }

  void toggleAutoConsent(bool value) {
    setState(() {
      autoConsentEnabled = value;
    });
  }

  void toggleStatementRetrieval(bool value) {
    setState(() {
      statementRetrievalEnabled = value;
    });
  }

  void toggleLogging(bool value) {
    setState(() {
      loggingEnabled = value;
    });
  }

  void toggleBalanceRetrieval(bool value) {
    setState(() {
      balanceRetrievalEnabled = value;
      getBanks();
    });
  }

  Future<void> showPicker(BuildContext context, DateTime date) async {
    DateTime date = DateTime.now();
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(date.year, date.month, date.day - 1),
        lastDate: DateTime.now());
    if (picked != null && picked != date) {
      setState(() {
        date = picked;
      });
    }
  }

  Future<void> methodHandler(MethodCall call) async {
    final bool loggingEnabled = call.arguments;

    switch (call.method) {
      case "updateLogging":
        showLogging = false;
        this.loggingEnabled = loggingEnabled;
        break;
      default:
        print('no method handler for method ${call.method}');
    }
  }

  @override
  void initState() {
    super.initState();
    statementChannel.setMethodCallHandler(methodHandler);
    getSDKVersion();
    apiKeyController.text = "";
    getBanks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(_version),
        ),
        body: Center(
            child: LayoutBuilder(builder: (BuildContext context,
                BoxConstraints viewportConstraints) {
              return SingleChildScrollView(child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: OutlinedButton(
                          onPressed: autoFillDetails,
                          child: const Text("Auto Fill Details"),
                        ),
                      ),
                    ),
                    if(showLogging)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            const Text("Enable Logging"),
                            Switch(onChanged: toggleLogging,
                                value: loggingEnabled,
                                activeColor: Colors.purple)
                          ]
                      ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Use Remember Me"),
                          Switch(onChanged: toggleRememberMe,
                            value: useRememberMe,
                            activeColor: Colors.purple)
                        ]
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Enable Action Bar Text"),
                          Switch(onChanged: toggleActionBar,
                              value: actionBarEnabled,
                              activeColor: Colors.purple)
                        ]
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Enable Auto Consent"),
                          Switch(onChanged: toggleAutoConsent,
                              value: autoConsentEnabled,
                              activeColor: Colors.purple)
                        ]
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Enable Statement Retrieval"),
                          Switch(onChanged: toggleStatementRetrieval,
                              value: statementRetrievalEnabled,
                              activeColor: Colors.purple)
                        ]
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Enable Balance Retrieval"),
                          Switch(onChanged: toggleBalanceRetrieval,
                              value: balanceRetrievalEnabled,
                              activeColor: Colors.purple)
                        ]
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'API Key',
                        ),
                        controller: apiKeyController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Organizational Name',
                        ),
                        controller: orgNameController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Success URL',
                        ),
                        controller: successURLController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Fail URL',
                        ),
                        controller: failURLController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'External ID',
                        ),
                        controller: externalIDController,
                      ),
                    ),
                    const Text("Select Country", style: TextStyle(color: Colors.purple)),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: DropdownButton(value: country,
                            icon: const Icon(Icons.flag),
                            items: countries.map((String items) {
                              return DropdownMenuItem(
                                value: items,
                                child: Text(items),
                              );
                            }).toList(),
                            onChanged: (String? country) {
                              updateCountry(country!);
                            },
                          ),
                      )
                    ),
                    const Text("Select Banks", style: TextStyle(color: Colors.purple)),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: SizedBox(
                            width: double.infinity,
                            height: (60 * isBankChecked.length).toDouble(),
                            child:  ListView(
                              children: bankNames.map((String bank) {
                                int index = bankNames.indexOf(bank);
                                return CheckboxListTile(
                                  title: Text(bank),
                                  value: isBankChecked[index],
                                  onChanged: (value) => {
                                    setState(() {
                                    isBankChecked[index] = value!;
                                    })
                                  },
                                );
                              }).toList(),
                            )
                        )
                    ),
                    if(actionBarEnabled)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Action Bar Text',
                          ),
                          controller: actionBarController,
                        ),
                      ),
                    if(statementRetrievalEnabled)
                      Column(mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Text("Start Date: $startDate"),
                            OutlinedButton(
                              child: const Text("Update Start Date"),
                              onPressed: () => showPicker(context, startDate),
                            ),
                            Text("End Date: $endDate"),
                            OutlinedButton(
                              child: const Text("Update End Date"),
                              onPressed: () => showPicker(context, endDate),
                            )
                          ]
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            disabledBackgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isCheckoutEnabled() ? checkout : null,
                          child: const Text("Checkout"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              );
            })
        )
    );
  }
}
