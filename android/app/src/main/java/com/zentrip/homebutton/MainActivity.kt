package com.zentrip.homebutton

import android.content.Context
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.util.Base64
import com.neovisionaries.ws.client.WebSocket
import com.neovisionaries.ws.client.WebSocketFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.EditText


fun create_door_message(usr: String, pwd: String, state: String): ByteArray
{
    return Base64.encode("$usr,$pwd,$state".encodeToByteArray(), Base64.DEFAULT)
}

class MainActivity : AppCompatActivity() {

    lateinit var user: EditText
    lateinit var password: EditText

    fun handleButtonOpen(view: View) {
        val imm =
            getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(view.windowToken, 0)

        GlobalScope.launch(Dispatchers.IO) {
            val ws: WebSocket = WebSocketFactory().createSocket("ws://192.168.0.102:6000/")
            ws.connect()
            ws.sendBinary(create_door_message(user.text.toString(), password.text.toString(), "1"))
            ws.disconnect()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        super.setContentView(R.layout.activity_main)
        user = findViewById(R.id.inputUsername)
        password = findViewById(R.id.inputPassword)

//        GlobalScope.launch(Dispatchers.IO) {
//            val ws: WebSocket = WebSocketFactory().createSocket("ws://192.168.0.102:6000/")
//            ws.connect()
//            ws.sendBinary(create_door_message("admin", "admin", "1"))
//            ws.disconnect()
//        }

    }
}