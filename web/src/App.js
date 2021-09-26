import './App.css';
import {useState, Component} from "react";
import Modal from 'react-modal';
import DeviceOrientation, {Orientation} from 'react-screen-orientation'
import ScrollLock from "react-scrolllock";

class DoorSocket {
    constructor(onOpen = () => {}, onClose = () => {}, onMessage = data => {}) {
        this._socket = null
        this._host = ""
        this._port = 6000
        this._connected = false
        this._onOpen = onOpen
        this._onClose = onClose
        this._onMessage = onMessage
        this._actionId = null
        this._keepConnected()
    }

    get connected() {
        return this._connected
    }

    get host() {
        return this._host
    }

    set host(newHost) {
        if (this._validHost(newHost) && this._host !== newHost) {
            this._host = newHost
            this._createSocket()
        }
    }

    get port() {
        return this._port
    }

    set port(newPort) {
        if (this._port !== newPort) {
            this._port = newPort
            this._createSocket()
        }
    }

    send(data) {
        this._socket.send(data)
    }

    _createSocket() {
        if (this._socket !== null && this._socket.readyState === WebSocket.OPEN) {
            this._socket.onopen = e => {}
            this._socket.onclose = e => {}
            this._socket.onerror = e => {}
            this._socket.onmessage = e => {}
            this._socket.close()
            this._socket = null
        }
        if (!this._validHost(this._host)) {
            return
        }
        if (this._actionId !== null) {
            clearTimeout(this._actionId)
            this._actionId = null
        }
        this._actionId = setTimeout(() => {
            this._socket = new WebSocket(`ws://${this._host}:${this._port}`)
            this._socket.onopen = e => this._onConnect()
            this._socket.onclose = e => this._onDisconnect()
            this._socket.onerror = e => this._onDisconnect()
            this._socket.onmessage = e => this._onMessage(e.data)
            this._actionId = null
        }, 500)
    }

    _onConnect() {
        if (!this._connected) {
            this._onOpen()
        }
        this._connected = true
    }

    _onDisconnect() {
        const wasConnected = this._connected
        this._connected = false
        if (wasConnected) {
            this._onClose()
        }
    }

    _validHost(h) {
        return h !== null && h !== undefined && h.length !== 0
    }

    _keepConnected() {
        if (this._socket !== null && !this.connected) {
            this._createSocket()
        }
        setTimeout(() => {
            this._keepConnected()
        }, 1000)
    }
}

class DoorClient {
    static Close = '0'
    static Open = '1'
    static Pair = '2'

    constructor() {
        this.local = new DoorSocket(() => this._onConnect(), () => this._onDisconnect(), data => this._onMessage(data))
        this.global = new DoorSocket(() => this._onConnect(), () => this._onDisconnect(), data => this._onMessage(data))
        this._setState = s => {}
    }

    setState(func = s => {}) {
        this._setState = func
    }

    setup(settings) {
        this.local.host = settings.localHost
        this.local.port = settings.localPort
        this.global.host = settings.globalHost
        this.global.port = settings.globalPort
    }

    send(username, password, msg) {
        if (!this.local.connected && !this.global.connected) return
        let socket = this.local.connected ? this.local : this.global
        socket.send(btoa(`${username},${password},${msg}`))
    }

    _onMessage(data) {
        const reader = new FileReader()
        reader.addEventListener('loadend', (e) => {
            const text = e.target.result
            if (text === '1') {
                this._setState({paired: true, open: true})
            } else if (text === '0') {
                this._setState({paired: true, open: false})
            } else {
                this._setState({paired: false, open: false})
            }
        })
        reader.readAsText(data)
    }

    _onConnect() {
        if (!this.local.connected && !this.global.connected) {
            this._setState({connected: true})
        }
    }

    _onDisconnect() {
        if (!this.local.connected && !this.global.connected) {
            this._setState({connected: false})
        }
    }

}

class Circle extends Component {
    render() {
        let circleStyle = {
            padding:10,
            display:"inline-block",
            borderRadius: "50%",
        };
        return (
            <div className={this.props.className} style={circleStyle}>
            </div>
        );
    }
}

function App() {
    const [modalIsOpen, setIsOpen] = useState(false)

    const [state, setState] = useState({
        open: false,
        paired: (localStorage.getItem("paired") || "false") === "true",
        connected: false,
        username: localStorage.getItem("username") || "",
        pin: localStorage.getItem("pin") || ""
    });

    const [settings, setSettings] = useState({
        globalHost: localStorage.getItem("globalHost") || "",
        globalPort: parseInt(localStorage.getItem("globalPort") || "4000"),
        localHost: localStorage.getItem("localHost") || "192.168.0.89",
        localPort: parseInt(localStorage.getItem("localPort") || "6000"),
        piUsername: localStorage.getItem("piUsername") || "",
        piPassword: localStorage.getItem("piPassword") || "",
        piDirectory: localStorage.getItem("piDirectory") || ""
    });

    globalClient.setState(s => {
        setState({...state, ...s})
    })
    localStorage.clear()
    for (let key of ["paired", "username", "pin"]) {
        localStorage.setItem(key, state[key])
    }
    for (let key of Object.keys(settings)) {
        localStorage.setItem(key, settings[key])
    }

    const handleSubmit = e => {
        const msg = !state.paired ? DoorClient.Pair : (state.open ? DoorClient.Close : DoorClient.Open)
        globalClient.send(state.username, state.pin, msg)
    }

    const handleUsernameChange = e => {
        setState({...state, paired: false, username: e.target.value})
    }

    const handlePinChange = e => {
        setState({...state, paired: false, pin: e.target.value})
    }

    const handleGlobalHostChange = e => {
        setSettings({...settings, globalHost: e.target.value})
    }

    const handleGlobalPortChange = e => {
        setSettings({...settings, globalPort: parseInt(e.target.value) || 0})
    }

    const handleLocalHostChange = e => {
        setSettings({...settings, localHost: e.target.value})
    }

    const handleLocalPortChange = e => {
        setSettings({...settings, localPort: parseInt(e.target.value) || 0})
    }

    // TODO: Server management
    const handlePiUsernameChange = e => {
        setSettings({...settings, piUsername: e.target.value})
    }

    const handlePiPasswordChange = e => {
        setSettings({...settings, piPassword: e.target.value})
    }

    const handlePiDirectoryChange = e => {
        setSettings({...settings, piDirectory: e.target.value})
    }

    const handleRunStop = e => {

    }

    const handlePair = e => {

    }

    function openModal() {
        setIsOpen(true);
    }

    function afterOpenModal() {

    }

    function closeModal() {
        setIsOpen(false);
    }

    let adminClass = state.username === "admin" ? "" : "HideAdmin"

    globalClient.setup(settings)

    return (
        <DeviceOrientation lockOrientation={'portrait'}>
        <Orientation orientation='portrait'>
        <div className="App" id="root">
            <ScrollLock/>
            <header className="App-header">
                <span>
                    <Circle className={"StatusIcon Door-" + (state.connected ? "open" : "close")} />
                    <h2 style={{display: "inline-block"}}>homebutton</h2>
                    <button className="Settings-button" onClick={openModal}/>
                </span>
                <input className="Door-input" id="user" placeholder="username" value={state.username} onChange={handleUsernameChange}/>
                <input className="Door-input" id="pin" placeholder="pin" type="number" value={state.pin} onChange={handlePinChange}/>
                <button id="submit" className={"Door-button Door-" + (!state.paired ? "pair" : (state.open ? "close" : "open"))}
                    style={{minHeight: "70vh"}}
                    onClick={handleSubmit}>
                    {!state.paired ? "Pair" : (state.open ? "Close" : "Open")}</button>
            </header>
            <Modal
                isOpen={modalIsOpen}
                onAfterOpen={afterOpenModal}
                onRequestClose={closeModal}
                style={{content: {
                    backgroundColor: "#282c34"
                }}}
                contentLabel="Settings"
              >
                <span className="Door-input">
                    <input style={{width: "75%", fontSize: "0.9em"}} id="globalHost" placeholder="global host" value={settings.globalHost} onChange={handleGlobalHostChange}/>
                    <input style={{width: "25%", fontSize: "0.9em"}} id="globalPort" placeholder="port" type="number" value={settings.globalPort} onChange={handleGlobalPortChange}/>
                </span>
                <span className="Door-input">
                    <input style={{width: "75%", fontSize: "0.9em"}} id="localHost" placeholder="local host"  value={settings.localHost} onChange={handleLocalHostChange}/>
                    <input style={{width: "25%", fontSize: "0.9em"}} id="localPort" placeholder="port" type="number" value={settings.localPort} onChange={handleLocalPortChange}/>
                </span>

                <input className={"Door-input " + adminClass} id="piUsername" placeholder="pi username" value={settings.piUsername} onChange={handlePiUsernameChange}/>
                <input className={"Door-input " + adminClass} id="piPassword" placeholder="pi password" type="password" value={settings.piPassword} onChange={handlePiPasswordChange}/>
                <input className={"Door-input " + adminClass} id="piDirectory" placeholder="pi directory" value={settings.piDirectory} onChange={handlePiDirectoryChange}/>

                <button id="run" className={"Door-button Door-" + (state.connected ? "close" : "open") + " " + adminClass}  style={{height: "30%"}}
                    onClick={handleRunStop}>
                    {state.connected ? "Stop" : "Run"}</button>

                <button id="pair" className={"Door-button Door-pair " + adminClass} style={{height: "30%"}}
                    onClick={handlePair}>
                    Pair</button>
            </Modal>
        </div>
        </Orientation>
        </DeviceOrientation>
    );
}

Modal.setAppElement('#root')
let globalClient = new DoorClient()

export default App;
