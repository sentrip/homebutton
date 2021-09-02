package com.zentrip.homebutton

import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch


class MainActivity : AppCompatActivity(), TextWatcher, DoorClient.Watcher {

    private var colorOpen: Int = Color.GREEN
    private var colorClose: Int = Color.RED
    private var colorPair: Int = Color.BLUE

    private var pi: PiClient = PiClient()
    private var client: DoorClient = DoorClient()
    private var settings: DoorSettings = DoorSettings()
    private var submittedUser: String = ""

    private lateinit var inputUser: EditText
    private lateinit var inputPin: EditText
    private lateinit var buttonOpen: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        super.setContentView(R.layout.activity_main)
        inputUser = findViewById(R.id.inputUsername)
        inputPin = findViewById(R.id.inputPassword)
        buttonOpen = findViewById(R.id.buttonOpen)
        client.delegate = this
        loadSettings()
        inputUser.text.append(settings.user)
        inputPin.text.append(settings.pin)
        inputUser.addTextChangedListener(this)
        inputPin.addTextChangedListener(this)
        onStateChanged(false)
        GlobalScope.launch(Dispatchers.IO) {
            pi.host = "192.168.0.102"
            pi.username = "jayjay"
            pi.password = "K@yaisL@brad0r"
            pi.targetDir = "/home/jayjay/projects/homebutton"
            pi.dev = true
            pi.start()
            client.connect()
        }
    }

    override fun onPause() {
        super.onPause()
        onDisconnect()
    }

    override fun onDestroy() {
        super.onDestroy()
        onDisconnect()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        onDisconnect()
    }

    override fun beforeTextChanged(p0: CharSequence?, p1: Int, p2: Int, p3: Int) { }
    override fun afterTextChanged(p0: Editable?) {}
    override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
        onSettingsChanged()
    }

    fun handleButtonOpen(view: View) {
        hideUserInput(view)
        GlobalScope.launch(Dispatchers.IO) {
            if (settings.isPaired) {
                if (!settings.state)
                    client.open(settings.user, settings.pin)
                else
                    client.close(settings.user, settings.pin)
            }
            else {
                submittedUser = settings.user
                client.pair(settings.user, settings.pin)
            }
        }
    }

    override fun onStateChanged(state: Boolean) {
        val wasPaired = settings.isPaired
        if (!wasPaired) {
            settings.isPaired = state
            if (settings.isPaired && submittedUser.isNotEmpty())
                settings.pairHistory.add(submittedUser)
            onSettingsChanged()
        }
        else
            settings.state = state

        onButtonUpdate()
    }

    private fun onButtonUpdate() {
        if (settings.isPaired) {
            buttonOpen.text = getString(if (settings.state) R.string.close_door else R.string.open_door)
            buttonOpen.setBackgroundColor(if (settings.state) colorClose else colorOpen)
        }
        else {
            buttonOpen.text = getString(R.string.pair_door)
            buttonOpen.setBackgroundColor(colorPair)
        }
    }

    private fun onSettingsChanged() {
        settings.user = inputUser.text.toString()
        settings.pin = inputPin.text.toString()
        settings.isPaired = settings.pairHistory.contains(settings.user)
        onButtonUpdate()
        client.settings = settings
        pi.host = settings.localHost
        pi.host = "192.168.0.244"
        pi.username = "pi"
        pi.password = "L@brad0r"
        GlobalScope.launch(Dispatchers.IO) {
            saveSettings()
        }
    }

    private fun onDisconnect() {
        GlobalScope.launch(Dispatchers.IO) {
            saveSettings()
            client.disconnect()
        }
    }

    private fun hideUserInput(view: View) {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(view.windowToken, 0)
        inputPin.clearFocus()
        inputUser.clearFocus()
    }

    private fun loadSettings() {
        settings = DoorSettings.load(getPreferences(Context.MODE_PRIVATE))
        client.settings = settings
        pi.host = settings.localHost
        pi.host = "192.168.0.244"
        pi.username = "pi"
        pi.password = "L@brad0r"
    }

    private fun saveSettings() {
        settings.save(getPreferences(Context.MODE_PRIVATE))
    }
}
