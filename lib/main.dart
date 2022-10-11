import 'dart:async';
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
        primarySwatch: Colors.blue,
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
  bool expiryDateEnabled = false;
  bool logoURLEnabled = false;
  DateTime expiryDate = DateTime.now();

  static const MethodChannel directChannel = MethodChannel('com.brankas.tap/direct');

  var apiKeyController = TextEditingController();
  var firstNameController = TextEditingController();
  var lastNameController = TextEditingController();
  var emailAddressController = TextEditingController();
  var mobileNumberController = TextEditingController();
  var destinationAccountIdController = TextEditingController();
  var amountController = TextEditingController();
  var memoController = TextEditingController();
  var referenceIdController = TextEditingController();
  var orgNameController = TextEditingController();
  var successURLController = TextEditingController();
  var failURLController = TextEditingController();
  var actionBarController = TextEditingController();
  var logoURLController = TextEditingController();
  List<String> countries = ["Philippines", "Indonesia"];
  List<String> destinationBanksPH = ["None", "BDO", "BPI", "EastWest", "LandBank",
    "MetroBank", "PNB", "RCBC", "UnionBank"];
  List<String> destinationBanksID = ["None", "BCA", "BNI", "BRI", "Mandiri"];
  List<String> destinationBanks = [];
  List<String> sourceBankNames = [];
  List<int> sourceBankCodes = [];
  List<String> sourceBankLogos = [];
  String country = "Philippines";
  String bank = "None";
  String destinationBank = "None";
  int bankCode = 0;
  String bankLogo = "";

  Future<void> checkout() async {
    try {
      directChannel.invokeMethod('checkout', {"apiKey" : apiKeyController.text,
      "firstName" : firstNameController.text, "lastName" : lastNameController.text,
      "emailAddress" : emailAddressController.text, "mobileNumber" : mobileNumberController.text,
      "destinationAccountId" : destinationAccountIdController.text, "amount" : amountController.text,
      "memo" : memoController.text, "referenceId" : referenceIdController.text,
        "orgName" : orgNameController.text, "successURL" : successURLController.text,
      "failURL" : failURLController.text, "country" : country, "sourceBank" : bankCode,
        "rememberMe" : useRememberMe, "actionBarText" : actionBarEnabled ?
        actionBarController.text : null, "logoURL" :
        logoURLEnabled ? logoURLController.text : null,
        "expiryDate" : expiryDateEnabled ? expiryDate.millisecondsSinceEpoch : null});
    } on PlatformException catch (e) {

    }
  }

  Future<void> getSDKVersion() async {
    String response = "";
    try {
      final String result = await directChannel.invokeMethod('getVersion');
      response = result;
    } on PlatformException catch (e) {
      response = "Failed to Invoke: '${e.message}'.";
    }

    setState(() {
      _version = response;
    });
  }

  Future<void> updateSourceBanks(String bank) async {
    if(bank != "None") {
      List<Object?> banks = [];
      try {
        banks = await directChannel.invokeMethod(
            'getBanks', {"country": country, "bank": bank, "apiKey" : apiKeyController.text});
      } on PlatformException catch (e) {

      }
      setState(() {
        sourceBankNames.clear();
        sourceBankCodes.clear();
        if(banks.isNotEmpty) {
          List<Object?> bankNames = banks[0] as List<Object?>;
          sourceBankNames.add("None");
          for (final bankName in bankNames) {
            sourceBankNames.add(bankName as String);
          }
          List<Object?> bankCodes = banks[1] as List<Object?>;
          sourceBankCodes.add(-1);
          for (final bankCode in bankCodes) {
            sourceBankCodes.add(bankCode as int);
          }
          List<Object?> bankLogos = banks[2] as List<Object?>;
          sourceBankLogos.add("");
          for (final bankLogo in bankLogos) {
            sourceBankLogos.add(bankLogo as String);
          }
          this.bank = sourceBankNames[0];
          bankCode = sourceBankCodes[0];
          bankLogo = sourceBankLogos[0];
        }
      });
    }
    setState(() {
      destinationBank = bank;
    });
  }

  void updateCountry(String country) {
    setState(() {
      this.country = country;
      destinationBank = "None";

      if(country == "Philippines") {
        destinationBanks = destinationBanksPH;
      }
      else {
        destinationBanks = destinationBanksID;
      }
    });
  }

  void autoFillDetails() {
    apiKeyController.text = "";
    destinationAccountIdController.text = "";
    firstNameController.text = "First";
    lastNameController.text = "Last";
    emailAddressController.text = "hello@gmail.com";
    mobileNumberController.text = "09123456789";
    amountController.text = "100";
    memoController.text = "Memo";
    referenceIdController.text = DateTime.now().toString();
    orgNameController.text = "Org Name";
    successURLController.text = "https://success.com";
    failURLController.text = "https://fail.com";
  }

  bool isCheckoutEnabled() {
    bool enabled = apiKeyController.text.isNotEmpty &&
        destinationAccountIdController.text.isNotEmpty &&
        firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        emailAddressController.text.isNotEmpty &&
        mobileNumberController.text.isNotEmpty &&
        amountController.text.isNotEmpty &&
        memoController.text.isNotEmpty &&
        referenceIdController.text.isNotEmpty &&
        orgNameController.text.isNotEmpty &&
        successURLController.text.isNotEmpty &&
        failURLController.text.isNotEmpty;
    return enabled;
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

  void toggleLogoURL(bool value) {
    setState(() {
      logoURLEnabled = value;
    });
  }

  void toggleExpiryDate(bool value) {
    setState(() {
      expiryDateEnabled = value;
    });
  }

  Future<void> showPicker(BuildContext context) async {
    DateTime date = DateTime.now();
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(date.year + 1, date.month, date.day));
    if (picked != null && picked != expiryDate) {
      setState(() {
        expiryDate = picked;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getSDKVersion();
    apiKeyController.text = "";
    destinationAccountIdController.text = "";
    destinationBanks = destinationBanksPH;
    destinationBank = destinationBanks[0];
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
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Use Remember Me"),
                          Switch(onChanged: toggleRememberMe,
                            value: useRememberMe,
                            activeColor: Colors.blue)
                        ]
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Enable Action Bar Text"),
                          Switch(onChanged: toggleActionBar,
                              value: actionBarEnabled,
                              activeColor: Colors.blue)
                        ]
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Enable Expiry Date"),
                          Switch(onChanged: toggleExpiryDate,
                              value: expiryDateEnabled,
                              activeColor: Colors.blue)
                        ]
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text("Enable Logo URL"),
                          Switch(onChanged: toggleLogoURL,
                              value: logoURLEnabled,
                              activeColor: Colors.blue)
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
                          hintText: 'First Name',
                        ),
                        controller: firstNameController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Last Name',
                        ),
                        controller: lastNameController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Email Address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        controller: emailAddressController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Mobile Number',
                        ),
                        keyboardType: TextInputType.phone,
                        controller: mobileNumberController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Destination Account ID',
                        ),
                        controller: destinationAccountIdController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Amount',
                        ),
                        keyboardType: TextInputType.number,
                        controller: amountController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Memo',
                        ),
                        controller: memoController,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Reference ID',
                        ),
                        controller: referenceIdController,
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
                    const Text("Select Country", style: TextStyle(color: Colors.blue)),
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
                    const Text("Select Destination Bank", style: TextStyle(color: Colors.blue)),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: DropdownButton(value: destinationBank,
                                icon: const Icon(Icons.account_balance_rounded),
                                // Array list of items
                                items: destinationBanks.map((String items) {
                                  return DropdownMenuItem(
                                    value: items,
                                    child: Text(items),
                                  );
                                }).toList(),
                                // After selecting the desired option,it will
                                // change button value to selected value
                                onChanged: (String? bank) {
                                  updateSourceBanks(bank!);
                                },
                              )
                        )
                    ),
                    if(destinationBank != "None") ...
                      [const Text("Select Source Bank", style: TextStyle(color: Colors.blue)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: DropdownButton(value: bank,
                              icon: bankLogo == "" ? const Icon(Icons.account_balance) : Image.network(bankLogo),
                              // Array list of items
                              items: sourceBankNames.map((String name) {
                                return DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                );
                              }).toList(),
                              // After selecting the desired option,it will
                              // change button value to selected value
                              onChanged: (String? bank) {
                                setState(() {
                                  this.bank = bank!;
                                  int index = sourceBankNames.indexOf(bank);
                                  bankCode = sourceBankCodes[index];
                                  bankLogo = sourceBankLogos[index];
                                });
                              },
                          )
                        )
                      )],
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
                    if(logoURLEnabled)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Logo URL',
                          ),
                          controller: logoURLController,
                        ),
                      ),
                    if(expiryDateEnabled)
                      Column(mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Text("Expiry Date: $expiryDate"),
                            OutlinedButton(
                              child: const Text("Update Expiry Date"),
                              onPressed: () => showPicker(context),
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
                            backgroundColor: Colors.blue,
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
