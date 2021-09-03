package com.zentrip.homebutton

import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import java.util.Properties
import com.neovisionaries.ws.client.WebSocket
import com.neovisionaries.ws.client.WebSocketAdapter
import com.neovisionaries.ws.client.WebSocketException
import com.neovisionaries.ws.client.WebSocketFactory
import com.jcraft.jsch.JSch
import com.jcraft.jsch.Session
import com.jcraft.jsch.ChannelExec
import java.io.Serializable


class DoorSettings: Serializable {
    var globalHost: String = ""
    var globalPort: Int = DEFAULT_GLOBAL_PORT
    var localHost: String = DEFAULT_LOCAL_HOST
    var localPort: Int = DEFAULT_LOCAL_PORT
    var piUser: String = ""
    var piPassword: String = ""
    var user: String = ""
    var pin: String = ""
    var isPaired: Boolean = false
    var state: Boolean = false
    var pairHistory: MutableSet<String> = HashSet<String>()

    fun save(pref: SharedPreferences) {
        with (pref.edit()) {
            putString("globalHost", globalHost)
            putInt("globalPort", globalPort)
            putString("localHost", localHost)
            putInt("localPort", localPort)
            putString("piUser", piUser)
            putString("piPassword", piPassword)
            putString("user", user)
            putString("pin", pin)
            putBoolean("isPaired", isPaired)
            putStringSet("pairHistory", pairHistory)
            apply()
        }
    }

    companion object {
        var DEFAULT_LOCAL_HOST: String = "192.168.0.89"
        var DEFAULT_LOCAL_PORT: Int = 6000
        var DEFAULT_GLOBAL_PORT: Int = 4000

        fun load(pref: SharedPreferences): DoorSettings {
            val s = DoorSettings()
            s.globalHost = pref.getString("globalHost", "").toString()
            s.globalPort = pref.getInt("globalPort", DEFAULT_GLOBAL_PORT)
            s.localHost = pref.getString("localHost", DEFAULT_LOCAL_HOST).toString()
            s.localPort = pref.getInt("localPort", DEFAULT_LOCAL_PORT)
            s.piUser = pref.getString("piUser", "").toString()
            s.piPassword = pref.getString("piPassword", "").toString()
            s.user = pref.getString("user", "").toString()
            s.pin = pref.getString("pin", "").toString()
            s.isPaired = pref.getBoolean("isPaired", false)
            s.pairHistory = pref.getStringSet("pairHistory", HashSet<String>()) ?: HashSet<String>()
            return s
        }
    }
}


class DoorClient : WebSocketAdapter() {
    interface Watcher {
        fun onStateChanged(state: Boolean)
    }

    var settings: DoorSettings = DoorSettings()
    var delegate: Watcher? = null

    fun isConnected(): Boolean {
        return ws.isOpen
    }

    fun open(usr: String, pwd: String) {
        setState(usr, pwd, OPEN)
    }

    fun close(usr: String, pwd: String) {
        setState(usr, pwd, CLOSE)
    }

    fun pair(usr: String, pwd: String) {
        setState(usr, pwd, PAIR)
    }

    fun connect() {
        disconnect()
        if (doConnect("ws://${settings.localHost}:${settings.localPort}/"))
            return
        if (!settings.globalHost.isEmpty())
            doConnect("ws://${settings.globalHost}:${settings.globalPort}/")
    }

    fun disconnect() {
        if (ws.isOpen)
            ws.disconnect()
    }

    private fun setState(usr: String, pwd: String, state: String) {
        if (!ws.isOpen)
            connect()
        ws.sendBinary(Base64.encode("$usr,$pwd,$state".encodeToByteArray(), Base64.DEFAULT))
    }

    private fun doConnect(uri: String): Boolean {
        ws = WebSocketFactory().createSocket(uri)
        ws.addListener(this)
        try {
            ws.connect()
            return true;
        }
        catch (e: Exception) {
            return false;
        }
    }

    override fun onBinaryMessage(websocket: WebSocket?, binary: ByteArray?) {
        super.onBinaryMessage(websocket, binary)
        if (binary != null && binary.isNotEmpty()) {
            delegate?.onStateChanged(Char(binary[0].toInt()) == '1')
        }
    }

    override fun onError(websocket: WebSocket?, cause: WebSocketException?) {
        super.onError(websocket, cause)
    }

    companion object {
        private var CLOSE: String = "0"
        private var OPEN: String = "1"
        private var PAIR: String = "2"
    }

    private var ws: WebSocket = WebSocketFactory().createSocket("ws://localhost:6000")
}


class PiClient {

    var username: String = "pi"
    var host: String = DoorSettings.DEFAULT_LOCAL_HOST;
    var password: String = ""
    val targetDir: String
        get() = "/home/$username/homebutton"

    var dev: Boolean = false

    fun start() {
        executeSSHCommand(if(!dev) "cd $targetDir; sh door.sh" else "cd $targetDir; venv/bin/python door.py --dev --host ${DoorSettings.DEFAULT_LOCAL_HOST}", username, password, host)
    }

    fun stop() {
        executeSSHCommand("echo '' > $targetDir/kill", username, password, host)
    }

    fun pair() {
        executeSSHCommand("echo '' > $targetDir/pair", username, password, host)
    }

    fun copyScripts() {
        executeSSHCommand("mkdir $targetDir; echo '$host' > $targetDir/.host_name", username, password, host)
        copyFileSSH("/res/raw/door.py", "$targetDir/door.py", username, password, host)
        copyFileSSH("/res/raw/run_door.sh", "$targetDir/door.sh", username, password, host)
    }

    private fun executeSSHCommand(cmd: String, username: String, password: String, host: String, port: Int = 22): Boolean {
        try {
            val jsch = JSch()
            val session: Session = jsch.getSession(username, host, port)
            session.setPassword(password)

            val prop = Properties()
            prop["StrictHostKeyChecking"] = "no"
            session.setConfig(prop)
            session.connect()

            val channelssh = session.openChannel("exec") as ChannelExec
            channelssh.setCommand(cmd)
            channelssh.connect()
            channelssh.disconnect()
            return true
        }
        catch (e: Exception) {
            Log.e("SSH", e.message.toString())
            return false
        }
    }

    private fun copyFileSSH(file: String, target: String, username: String, password: String, host: String, port: Int = 22): Boolean {
        val data = object{}.javaClass.getResource(file)?.readText()

        if (data == null) {
            Log.e("SSH", "Failed to find $file")
            return false
        }
        else if (!executeSSHCommand("echo '$data' > $target", username, password, host, port))  {
            Log.e("SSH", "Failed to copy $file to $target")
            return false
        }
        return true
    }

}
