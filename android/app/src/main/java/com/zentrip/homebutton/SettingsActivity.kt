package com.zentrip.homebutton

import android.content.Context
import android.content.Intent
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.MenuItem
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import androidx.core.view.isVisible
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

class SettingsActivity : AppCompatActivity(), TextWatcher {

    private var colorRun: Int = R.color.green
    private var colorStop: Int = R.color.red
    private var colorPair: Int = R.color.blue

    private var isRunning = false
    private var pi: PiClient = PiClient()
    private var settings: DoorSettings = DoorSettings()

    private lateinit var inputGlobalHost: EditText
    private lateinit var inputGlobalPort: EditText
    private lateinit var inputLocalHost: EditText
    private lateinit var inputLocalPort: EditText
    private lateinit var inputUser: EditText
    private lateinit var inputPassword: EditText
    private lateinit var buttonRun: Button
    private lateinit var buttonPair: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        inputGlobalHost = findViewById(R.id.inputGlobalHost)
        inputGlobalPort = findViewById(R.id.inputGlobalPort)
        inputLocalHost = findViewById(R.id.inputLocalHost)
        inputLocalPort = findViewById(R.id.inputLocalPort)
        inputUser = findViewById(R.id.inputPiUsername)
        inputPassword = findViewById(R.id.inputPiPassword)
        buttonRun = findViewById(R.id.buttonRun)
        buttonPair = findViewById(R.id.buttonPair)
        buttonPair.text = getString(R.string.pair_door)

        settings = intent.getSerializableExtra(SETTINGS_MESSAGE) as DoorSettings
        isRunning = intent.getBooleanExtra(CONNECTED_MESSAGE, false)

        inputGlobalHost.text.append(settings.globalHost)
        inputLocalHost.text.append(settings.localHost)
        inputGlobalPort.text.append(settings.globalPort.toString())
        inputLocalPort.text.append(settings.localPort.toString())
        inputUser.text.append(settings.piUser)
        inputPassword.text.append(settings.piPassword)

        inputGlobalHost.addTextChangedListener(this)
        inputGlobalPort.addTextChangedListener(this)
        inputLocalHost.addTextChangedListener(this)
        inputLocalPort.addTextChangedListener(this)
        inputUser.addTextChangedListener(this)
        inputPassword.addTextChangedListener(this)

        pi.host = settings.localHost
        pi.username = settings.piUser
        pi.password = settings.piPassword

        inputUser.isVisible = settings.user == "admin"
        inputPassword.isVisible = settings.user == "admin"
        buttonRun.isVisible = settings.user == "admin"
        buttonPair.isVisible = settings.user == "admin"

        updateButtons()
    }

    override fun onBackPressed() {
        setResult(RESULT_OK, Intent().apply { putExtra(SETTINGS_MESSAGE, settings)  })
        finish()
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        onBackPressed()
        return true
    }


    override fun beforeTextChanged(p0: CharSequence?, p1: Int, p2: Int, p3: Int) { }
    override fun afterTextChanged(p0: Editable?) {}
    override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
        onSettingsChanged()
    }

    private fun onSettingsChanged() {
        settings.globalHost = inputGlobalHost.text.toString()
        settings.localHost = inputLocalHost.text.toString()
        if (inputGlobalPort.text.isNotEmpty())
            settings.globalPort = inputGlobalPort.text.toString().toInt()
        if (inputLocalPort.text.isNotEmpty())
            settings.localPort = inputLocalPort.text.toString().toInt()
        settings.piUser = inputUser.text.toString()
        settings.piPassword = inputPassword.text.toString()

        pi.host = settings.localHost
        pi.username = settings.piUser
        pi.password = settings.piPassword

        GlobalScope.launch(Dispatchers.IO) {
            settings.save(getPreferences(Context.MODE_PRIVATE))
        }
    }

    fun handleButtonRun(view: View) {
        hideUserInput(view)

        buttonRun.isEnabled = false

        if (!isRunning) {
            isRunning = true
            updateButtons()

            if (!pi.dev)
                CoroutineScope(Dispatchers.IO).launch { pi.copyScripts() }

            Handler(Looper.getMainLooper()).postDelayed({
                CoroutineScope(Dispatchers.IO).launch {
                    pi.start()
                    enableRunButtonLater()
                }
            }, 1000)
        }
        else {
            isRunning = false
            updateButtons()
            CoroutineScope(Dispatchers.IO).launch { pi.stop() }
            enableRunButtonLater()
        }
    }

    fun handleButtonPair(view: View) {
        hideUserInput(view)
        buttonPair.text = getString(R.string.pairing_door)
        buttonPair.isEnabled = false
        CoroutineScope(Dispatchers.IO).launch { pi.pair() }
        Handler(Looper.getMainLooper()).postDelayed({
            buttonPair.text = getString(R.string.pair_door)
            buttonPair.isEnabled = true
        }, 30000)
    }

    private fun hideUserInput(view: View) {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(view.windowToken, 0)
    }

    private fun enableRunButtonLater() {
        Handler(Looper.getMainLooper()).postDelayed({
            buttonRun.isEnabled = true
        }, 300)
    }

    private fun updateButtons() {
        buttonPair.setBackgroundColor(resources.getColor(colorPair))
        buttonRun.text = getString(if (isRunning) R.string.stop_server else R.string.run_server)
        buttonRun.setBackgroundColor(resources.getColor(if (isRunning) colorStop else colorRun))
    }
}