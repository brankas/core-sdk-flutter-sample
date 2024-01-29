package com.example.tap_sample_app_flutter

import `as`.brank.sdk.core.CoreError
import `as`.brank.sdk.core.CoreListener
import `as`.brank.sdk.tap.statement.StatementTapSDK
import android.app.Activity.RESULT_OK
import android.content.Intent
import android.os.Looper
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.widget.AppCompatButton
import androidx.appcompat.widget.AppCompatTextView
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import tap.model.Country
import tap.model.DismissalDialog
import tap.model.Reference
import tap.model.balance.Account
import tap.model.statement.Bank
import tap.model.statement.Statement
import tap.model.statement.StatementResponse
import tap.request.statement.StatementRetrievalRequest
import tap.request.statement.StatementTapRequest
import java.util.*

class MainActivity: FlutterFragmentActivity() {
    private val statementTapChannel = "com.brankas.tap/statement"

    private var banks = mutableListOf<Bank>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor, statementTapChannel).setMethodCallHandler { call, result ->
            when(call.method) {
                "checkout" -> {
                    StatementTapSDK.initialize(this, call.argument<String>("apiKey").orEmpty(),
                        isDebug = false, isLoggingEnabled = call.argument<Boolean>("logging")!!)

                    val country: String = call.argument<String>("country").orEmpty()
                    val countryCode = getCountry(country)
                    val actionBarText: String? = call.argument<String?>("actionBarText")

                    val bankNames = call.argument<List<String>>("banks")!!
                    val bankCodes = banks.filter { bank ->
                        bankNames.any { it == bank.title }
                    }.map {
                        it.bankCode
                    }

                    val request = StatementTapRequest.Builder()
                        .country(countryCode)
                        .externalId(call.argument<String>("externalID").orEmpty())
                        .successURL(call.argument<String>("successURL").orEmpty())
                        .failURL(call.argument<String>("failURL").orEmpty())
                        .organizationName(call.argument<String>("orgName").orEmpty())
                        .bankCodes(bankCodes)
                        .includeBalance(call.argument<Boolean>("balanceRetrieval")!!)
                        .hasPdfUpload(call.argument<Boolean>("pdfUpload")!!)
                        .dismissalDialog(
                            DismissalDialog("Do you want to close the application?",
                                "Yes", "No")

                        ).apply {
                            val statementRetrievalBuilder = StatementRetrievalRequest.Builder()
                            var hasRetrieval = false
                            call.argument<Int?>("startDate")?.let {
                                statementRetrievalBuilder.startDate(Calendar.getInstance().apply {
                                    timeInMillis = it.toLong()
                                    hasRetrieval = true
                                })
                            } ?: run {
                                hasRetrieval = false
                            }
                            call.argument<Int?>("endDate")?.let {
                                statementRetrievalBuilder.endDate(Calendar.getInstance().apply {
                                    timeInMillis = it.toLong()
                                    hasRetrieval = true
                                })
                            } ?: run {
                                hasRetrieval = false
                            }
                            if(hasRetrieval)
                                statementRetrievalRequest = statementRetrievalBuilder.build()
                        }.build()

                    StatementTapSDK.checkout(this, request, object:
                        CoreListener<String?> {
                        override fun onResult(data: String?, error: CoreError?) {
                            error?.let {
                                Toast.makeText(this@MainActivity, it.errorMessage, Toast.LENGTH_LONG).show()
                            }
                        }
                    }, useRememberMe = call.argument<Boolean>("rememberMe")!!,
                        isAutoConsent = call.argument<Boolean>("autoConsent")!!, requestCode = 2000,
                        actionBarText = actionBarText)
                }
                "getVersion" -> {
                    result.success(StatementTapSDK.getSDKVersion())
                }
                "getEnabledBanks" -> {
                    StatementTapSDK.initialize(this@MainActivity, call.argument("apiKey")!!, isDebug = false,
                        isLoggingEnabled = call.argument<Boolean>("logging")!!)
                    StatementTapSDK.getEnabledBanks(getCountry(call.argument("country")!!),
                        call.argument<Boolean>("balanceRetrieval")!!, object:
                        CoreListener<List<Bank>> {
                        override fun onResult(data: List<Bank>?, error: CoreError?) {
                            data?.let { bankList ->
                                banks.clear()
                                banks.addAll(bankList)
                                val bankNames = bankList.map { bank -> bank.title }
                                val bankCodes = bankList.map { bank -> bank.bankCode.value }
                                val bankIcons = bankList.map { bank ->
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
        if(requestCode == 2000) {
            if(resultCode == RESULT_OK) {
                val statementResponse = data?.getParcelableExtra<Reference<StatementResponse>>(
                    StatementTapSDK.STATEMENTS)
                var statementId = ""
                val builder = StringBuilder()

                statementResponse?.get?.let { response ->
                    response.statementList?.let {
                        statementId = response.statementId
                        it.forEach { statement ->
                            statement.transactions.forEach { _ ->
                                builder.append("ACCOUNT: ${statement.account.holderName} ${statement.account.number} - ${statement.transactions.size}")
                                statement.transactions.forEach { transaction ->
                                    builder.append("TRANSACTION: ${transaction.id} - ${statement.account.holderName}")
                                }
                            }
                        }
                    } ?: run {
                        statementId = response.statementId
                    }
                } ?: run {
                    statementId = data?.getStringExtra(StatementTapSDK.STATEMENT_ID)!!
                }

                val dialogBuilder: AlertDialog.Builder = AlertDialog.Builder(this)
                val contentView = layoutInflater.inflate(R.layout.dialog_statement, null)
                val text = contentView.findViewById<AppCompatTextView>(R.id.statementList)
                val closeButton = contentView.findViewById<AppCompatButton>(R.id.closeButton)
                val downloadButton = contentView.findViewById<AppCompatButton>(R.id.downloadButton)
                val statementIdText = contentView.findViewById<AppCompatTextView>(R.id.statementId)

                statementIdText.text = "Statement ID: $statementId"

                if(builder.isEmpty())
                    statementIdText.text = statementIdText.text.toString() + "\n\n\nStatement List is Empty"

                text.text = builder.toString()

                dialogBuilder.setView(contentView)
                val dialog = dialogBuilder.create()
                dialog.show()

                val accounts: List<Account>? = statementResponse?.get?.accountList
                closeButton.setOnClickListener {
                    dialog.dismiss()
                    accounts?.let {
                        showAccounts(it)
                    }
                }

                downloadButton.setOnClickListener {
                    dialog.dismiss()
                    accounts?.let {
                        showAccounts(it)
                    }
                    StatementTapSDK.downloadStatement(this@MainActivity, statementId,
                        object: CoreListener<Pair<String?, ByteArray>> {
                            override fun onResult(data: Pair<String?, ByteArray>?, error: CoreError?) {
                                error?.let {
                                    if (Looper.myLooper() == null)
                                        Looper.prepare()
                                    Toast.makeText(this@MainActivity, it.errorMessage,
                                        Toast.LENGTH_LONG).show()
                                }
                            }
                        }, true)
                }
            }
            else {
                val error = data?.getStringExtra(StatementTapSDK.ERROR)
                val errorCode = data?.getStringExtra(StatementTapSDK.ERROR_CODE)
                Toast.makeText(this, "$error ($errorCode)", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun getCountry(country: String): Country {
        return when(country) {
            "Indonesia" -> Country.ID
            "Thailand" -> Country.TH
            else -> Country.PH
        }
    }

    private fun showAccounts(accounts: List<Account>) {
        val dialogBuilder = AlertDialog.Builder(this, R.style.AlertDialogTheme)
        val stringBuilder = StringBuilder()

        accounts.forEach {
            stringBuilder.append("Account: ${it.holderName} - ${it.number}: " +
                    "${it.balance.currency}${it.balance.numInCents.toLong() / 100}")
            stringBuilder.appendLine()
        }

        dialogBuilder.setMessage(stringBuilder.toString())
            .setCancelable(false)
            .setPositiveButton("OK") { dialogInterface, _ ->
                dialogInterface.dismiss()
            }

        val alert = dialogBuilder.create()
        alert.show()
    }
}
