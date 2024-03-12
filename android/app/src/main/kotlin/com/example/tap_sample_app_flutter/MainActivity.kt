package com.example.tap_sample_app_flutter

import `as`.brank.sdk.core.CoreError
import `as`.brank.sdk.core.CoreListener
import `as`.brank.sdk.tap.direct.DirectTapSDK
import android.app.AlertDialog
import android.content.Intent
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import tap.model.*
import tap.model.Currency
import tap.model.direct.*
import tap.request.direct.DirectTapRequest
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val directTapChannel = "com.brankas.tap/direct"

    private var banks = mutableListOf<Bank>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor, directTapChannel).setMethodCallHandler { call, result ->
            when(call.method) {
                "checkout" -> {
                    DirectTapSDK.initialize(this, call.argument<String>("apiKey").orEmpty(), isDebug = false,
                        isLoggingEnabled = call.argument<Boolean>("logging")!!)

                    val bankCode: Int = call.argument<Int>("sourceBank")!!
                    var bank: BankCode? = null

                    if(banks.isNotEmpty()) {
                        bank = banks.find { it.bankCode.value == bankCode }?.bankCode
                    }

                    val country: String = call.argument<String>("country").orEmpty()
                    val countryCode = if(country == "Indonesia") Country.ID else Country.PH

                    val currency = if(countryCode == Country.PH) Currency.PHP else Currency.IDR
                    val language = getLanguage(call.argument<String>("language").orEmpty())

                    // Amount should be in centavos; thus, needs to be multiplied to 100
                    val amount = (call.argument<String>("amount")!!.toDouble() * 100).toInt().toString()
                    val logoURL: String? = call.argument<String?>("logoURL")
                    val actionBarText: String? = call.argument<String?>("actionBarText")

                    val request = DirectTapRequest.Builder()
                        .sourceAccount(Account(bank, countryCode))
                        .destinationAccountId(call.argument<String>("destinationAccountId").orEmpty())
                        .amount(Amount(currency, amount))
                        .memo(call.argument<String>("memo").orEmpty())
                        .customer(Customer(call.argument<String>("firstName").orEmpty(),
                            call.argument<String>("lastName").orEmpty(),
                            call.argument<String>("email").orEmpty(),
                            call.argument<String>("mobileNumber").orEmpty())
                        )
                        .referenceId(call.argument<String>("referenceId").orEmpty())
                        .client(Client(call.argument<String>("orgName").orEmpty(), logoURL,
                            call.argument<String>("successURL").orEmpty(),
                            call.argument<String>("failURL").orEmpty(), language = language))
                        .dismissalDialog(
                            DismissalDialog("Do you want to close the application?",
                                "Yes", "No")
                        ).apply {
                            call.argument<Int?>("expiryDate")?.let {
                                expiryDate = Calendar.getInstance().apply {
                                    timeInMillis = it.toLong()
                                }
                            }
                        }

                    DirectTapSDK.checkout(this, request.build(), object:
                        CoreListener<String?> {
                        override fun onResult(data: String?, error: CoreError?) {
                            error?.let {
                                Toast.makeText(this@MainActivity, "${it.errorCode.getCode()} " +
                                        "- ${it.errorCode.getErrorMessage()}", Toast.LENGTH_LONG).show()
                            }
                        }

                    }, 3000, call.argument<Boolean>("rememberMe")!!, actionBarText)
                }
                "getVersion" -> {
                    result.success(DirectTapSDK.getSDKVersion())
                }
                "getBanks" -> {
                    DirectTapSDK.initialize(this@MainActivity, call.argument("apiKey")!!,
                        isDebug = false, isLoggingEnabled = call.argument<Boolean>("logging")!!)
                    DirectTapSDK.getSourceBanks(getCountry(call.argument("country")!!),
                        getBankCode(call.argument("bank")!!), object:
                            CoreListener<List<Bank>> {
                            override fun onResult(data: List<Bank>?, error: CoreError?) {
                                data?.let { bankList ->
                                    banks.clear()
                                    banks.addAll(bankList.filter { it.isEnabled })
                                    val bankNames = banks.map { bank -> bank.title }
                                    val bankCodes = banks.map { bank -> bank.bankCode.value }
                                    val bankIcons = banks.map { bank ->
                                        bank.logoUrl
                                    }
                                    result.success(listOf(bankNames, bankCodes, bankIcons))
                                } ?: run {
                                    error?.errorMessage?.let {
                                        Toast.makeText(this@MainActivity, it, Toast.LENGTH_SHORT).show()
                                    }
                                    result.error("Failed to retrieve source banks",
                                        "Failed to retrieve source banks", "Failed to retrieve source banks")
                                }
                            }
                        })
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if(requestCode == 3000) {
            if(resultCode == RESULT_OK) {
                val transaction = data?.getParcelableExtra<Reference<Transaction>>(
                    DirectTapSDK.TRANSACTION)!!.get!!
                showTransaction(transaction)
            } else {
                val error = data?.getStringExtra(DirectTapSDK.ERROR)
                val errorCode = data?.getStringExtra(DirectTapSDK.ERROR_CODE)
                Toast.makeText(this, "$error ($errorCode)", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun getCountry(country: String): Country {
        return when(country) {
            "Indonesia" -> Country.ID
            else -> Country.PH
        }
    }

    private fun getLanguage(language: String): Language {
        return when(language) {
            "Indonesian" -> tap.model.direct.Language.INDONESIAN
            else -> Language.ENGLISH
        }
    }

    private fun getBankCode(bank: String): BankCode {
        return when(bank) {
            "BDO" -> BankCode.BDO_PERSONAL
            "BPI" -> BankCode.BPI_PERSONAL
            "EastWest" -> BankCode.EASTWEST_PERSONAL
            "LandBank" -> BankCode.LANDBANK_PERSONAL
            "MetroBank" -> BankCode.METROBANK_PERSONAL
            "PNB" -> BankCode.PNB_PERSONAL
            "RCBC" -> BankCode.RCBC_PERSONAL
            "UnionBank" -> BankCode.UNIONBANK_PERSONAL
            "BCA" -> BankCode.BCA_PERSONAL
            "BNI" -> BankCode.BNI_PERSONAL
            "BRI" -> BankCode.BRI_PERSONAL
            "Mandiri" -> BankCode.MANDIRI_PERSONAL
            else -> BankCode.UNKNOWN_BANK
        }
    }

    private fun showTransaction(transaction: Transaction) {
        val dialogBuilder = AlertDialog.Builder(this)
        val stringBuilder = StringBuilder()

        stringBuilder.append("TRANSACTION (")
        stringBuilder.append(transaction.id)
        stringBuilder.append("):")
        stringBuilder.appendLine()
        stringBuilder.append("Reference ID: ")
        stringBuilder.append(transaction.referenceId)
        stringBuilder.appendLine()
        stringBuilder.append("Status: ")
        stringBuilder.append(transaction.status.name)
        stringBuilder.appendLine()
        stringBuilder.append("Status Code: ")
        stringBuilder.append(transaction.statusMessage.orEmpty()+" ("+transaction.statusCode+")")
        stringBuilder.appendLine()
        stringBuilder.append("Bank: ")
        stringBuilder.append(transaction.bankCode.name+" "+transaction.country.name)
        stringBuilder.appendLine()
        if(transaction.amount.numInCents.isNotEmpty()) {
            stringBuilder.append("Amount: ")
            stringBuilder.append(transaction.amount.currency.name + " " + ((
                    transaction.amount.numInCents.toInt() / 100).toFloat()))
            stringBuilder.appendLine()
        }
        if(transaction.bankFee.numInCents.isNotEmpty()) {
            stringBuilder.append("Bank Fee: ")
            stringBuilder.append(transaction.bankFee.currency.name + " " + ((
                    transaction.bankFee.numInCents.toInt() / 100).toFloat()))
            stringBuilder.appendLine()
        }
        stringBuilder.append("Date: ")
        stringBuilder.append(transaction.finishedDate.getDateString())
        stringBuilder.appendLine()

        dialogBuilder.setMessage(stringBuilder.toString())
            .setCancelable(false)
            .setPositiveButton("OK") { dialogInterface, _ ->
                dialogInterface.dismiss()
            }

        val alert = dialogBuilder.create()
        alert.show()
    }

    fun Calendar.getDateString() : String {
        val format = SimpleDateFormat("MMMM d yyyy hh:mm:ss", Locale.getDefault())
        return format.format(timeInMillis)
    }
}