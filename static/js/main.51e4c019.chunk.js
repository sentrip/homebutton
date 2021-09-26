(this.webpackJsonphomebutton=this.webpackJsonphomebutton||[]).push([[0],{25:function(t,e,n){},26:function(t,e,n){},41:function(t,e,n){"use strict";n.r(e);var o=n(2),c=n.n(o),a=n(11),s=n.n(a),i=(n(25),n(1)),l=n(7),r=n(20),u=n(19),h=n(5),p=n(6),d=(n(26),n(12)),b=n.n(d),g=n(13),j=n.n(g),f=n(18),_=n.n(f),O=n(0),m=function(){function t(){var e=arguments.length>0&&void 0!==arguments[0]?arguments[0]:function(){},n=arguments.length>1&&void 0!==arguments[1]?arguments[1]:function(){},o=arguments.length>2&&void 0!==arguments[2]?arguments[2]:function(t){};Object(h.a)(this,t),this._socket=null,this._host="",this._port=8080,this._connected=!1,this._onOpen=e,this._onClose=n,this._onMessage=o,this._actionId=null,this._keepConnected()}return Object(p.a)(t,[{key:"connected",get:function(){return this._connected}},{key:"host",get:function(){return this._host},set:function(t){this._validHost(t)&&this._host!==t&&(this._host=t,this._createSocket())}},{key:"port",get:function(){return this._port},set:function(t){this._port!==t&&(this._port=t,this._createSocket())}},{key:"send",value:function(t){this._socket.send(t)}},{key:"_createSocket",value:function(){var t=this;null!==this._socket&&this._socket.readyState===WebSocket.OPEN&&(this._socket.onopen=function(t){},this._socket.onclose=function(t){},this._socket.onerror=function(t){},this._socket.onmessage=function(t){},this._socket.close(),this._socket=null),this._validHost(this._host)&&(null!==this._actionId&&(clearTimeout(this._actionId),this._actionId=null),this._actionId=setTimeout((function(){t._socket=new WebSocket("ws://".concat(t._host,":").concat(t._port)),t._socket.onopen=function(e){return t._onConnect()},t._socket.onclose=function(e){return t._onDisconnect()},t._socket.onerror=function(e){return t._onDisconnect()},t._socket.onmessage=function(e){return t._onMessage(e.data)},t._actionId=null}),500))}},{key:"_onConnect",value:function(){this._connected||this._onOpen(),this._connected=!0}},{key:"_onDisconnect",value:function(){var t=this._connected;this._connected=!1,t&&this._onClose()}},{key:"_validHost",value:function(t){return null!==t&&void 0!==t&&0!==t.length}},{key:"_keepConnected",value:function(){var t=this;null===this._socket||this.connected||this._createSocket(),setTimeout((function(){t._keepConnected()}),1e3)}}]),t}(),v=function(){function t(){var e=this;Object(h.a)(this,t),this.local=new m((function(){return e._onConnect()}),(function(){return e._onDisconnect()}),(function(t){return e._onMessage(t)})),this.global=new m((function(){return e._onConnect()}),(function(){return e._onDisconnect()}),(function(t){return e._onMessage(t)})),this._setState=function(t){}}return Object(p.a)(t,[{key:"setState",value:function(){var t=arguments.length>0&&void 0!==arguments[0]?arguments[0]:function(t){};this._setState=t}},{key:"setup",value:function(t){this.local.host=t.localHost,this.local.port=t.localPort,this.global.host=t.globalHost,this.global.port=t.globalPort}},{key:"send",value:function(t,e,n){(this.local.connected||this.global.connected)&&(this.local.connected?this.local:this.global).send(btoa("".concat(t,",").concat(e,",").concat(n)))}},{key:"_onMessage",value:function(t){var e=this,n=new FileReader;n.addEventListener("loadend",(function(t){var n=t.target.result;"1"===n?e._setState({paired:!0,open:!0}):"0"===n?e._setState({paired:!0,open:!1}):e._setState({paired:!1,open:!1})})),n.readAsText(t)}},{key:"_onConnect",value:function(){this.local.connected||this.global.connected||this._setState({connected:!0})}},{key:"_onDisconnect",value:function(){this.local.connected||this.global.connected||this._setState({connected:!1})}}]),t}();v.Close="0",v.Open="1",v.Pair="2";var k=function(t){Object(r.a)(n,t);var e=Object(u.a)(n);function n(){return Object(h.a)(this,n),e.apply(this,arguments)}return Object(p.a)(n,[{key:"render",value:function(){return Object(O.jsx)("div",{className:this.props.className,style:{padding:10,display:"inline-block",borderRadius:"50%"}})}}]),n}(o.Component);b.a.setAppElement("#root");var y=new v,S=function(){var t=Object(o.useState)(!1),e=Object(l.a)(t,2),n=e[0],c=e[1],a=Object(o.useState)({open:!1,paired:"true"===(localStorage.getItem("paired")||"false"),connected:!1,username:localStorage.getItem("username")||"",pin:localStorage.getItem("pin")||""}),s=Object(l.a)(a,2),r=s[0],u=s[1],h=Object(o.useState)({globalHost:localStorage.getItem("globalHost")||"",globalPort:parseInt(localStorage.getItem("globalPort")||"8000"),localHost:localStorage.getItem("localHost")||"192.168.0.104",localPort:parseInt(localStorage.getItem("localPort")||"8080"),piUsername:localStorage.getItem("piUsername")||"",piPassword:localStorage.getItem("piPassword")||"",piDirectory:localStorage.getItem("piDirectory")||""}),p=Object(l.a)(h,2),d=p[0],f=p[1];y.setState((function(t){u(Object(i.a)(Object(i.a)({},r),t))})),localStorage.clear();for(var m=0,S=["paired","username","pin"];m<S.length;m++){var C=S[m];localStorage.setItem(C,r[C])}for(var x=0,D=Object.keys(d);x<D.length;x++){var I=D[x];localStorage.setItem(I,d[I])}var P="admin"===r.username?"":"HideAdmin";return y.setup(d),Object(O.jsx)(j.a,{lockOrientation:"portrait",children:Object(O.jsx)(g.Orientation,{orientation:"portrait",children:Object(O.jsxs)("div",{className:"App",id:"root",children:[Object(O.jsx)(_.a,{}),Object(O.jsxs)("header",{className:"App-header",children:[Object(O.jsxs)("span",{children:[Object(O.jsx)(k,{className:"StatusIcon Door-"+(r.connected?"open":"close")}),Object(O.jsx)("h2",{style:{display:"inline-block"},children:"homebutton"}),Object(O.jsx)("button",{className:"Settings-button",onClick:function(){c(!0)}})]}),Object(O.jsx)("input",{className:"Door-input",id:"user",placeholder:"username",value:r.username,onChange:function(t){u(Object(i.a)(Object(i.a)({},r),{},{paired:!1,username:t.target.value}))}}),Object(O.jsx)("input",{className:"Door-input",id:"pin",placeholder:"pin",type:"number",value:r.pin,onChange:function(t){u(Object(i.a)(Object(i.a)({},r),{},{paired:!1,pin:t.target.value}))}}),Object(O.jsx)("button",{id:"submit",className:"Door-button Door-"+(r.paired?r.open?"close":"open":"pair"),style:{minHeight:"70vh"},onClick:function(t){var e=r.paired?r.open?v.Close:v.Open:v.Pair;y.send(r.username,r.pin,e)},children:r.paired?r.open?"Close":"Open":"Pair"})]}),Object(O.jsxs)(b.a,{isOpen:n,onAfterOpen:function(){},onRequestClose:function(){c(!1)},style:{content:{backgroundColor:"#282c34"}},contentLabel:"Settings",children:[Object(O.jsxs)("span",{className:"Door-input",children:[Object(O.jsx)("input",{style:{width:"75%",fontSize:"0.9em"},id:"globalHost",placeholder:"global host",value:d.globalHost,onChange:function(t){f(Object(i.a)(Object(i.a)({},d),{},{globalHost:t.target.value}))}}),Object(O.jsx)("input",{style:{width:"25%",fontSize:"0.9em"},id:"globalPort",placeholder:"port",type:"number",value:d.globalPort,onChange:function(t){f(Object(i.a)(Object(i.a)({},d),{},{globalPort:parseInt(t.target.value)||0}))}})]}),Object(O.jsxs)("span",{className:"Door-input",children:[Object(O.jsx)("input",{style:{width:"75%",fontSize:"0.9em"},id:"localHost",placeholder:"local host",value:d.localHost,onChange:function(t){f(Object(i.a)(Object(i.a)({},d),{},{localHost:t.target.value}))}}),Object(O.jsx)("input",{style:{width:"25%",fontSize:"0.9em"},id:"localPort",placeholder:"port",type:"number",value:d.localPort,onChange:function(t){f(Object(i.a)(Object(i.a)({},d),{},{localPort:parseInt(t.target.value)||0}))}})]}),Object(O.jsx)("input",{className:"Door-input "+P,id:"piUsername",placeholder:"pi username",value:d.piUsername,onChange:function(t){f(Object(i.a)(Object(i.a)({},d),{},{piUsername:t.target.value}))}}),Object(O.jsx)("input",{className:"Door-input "+P,id:"piPassword",placeholder:"pi password",type:"password",value:d.piPassword,onChange:function(t){f(Object(i.a)(Object(i.a)({},d),{},{piPassword:t.target.value}))}}),Object(O.jsx)("input",{className:"Door-input "+P,id:"piDirectory",placeholder:"pi directory",value:d.piDirectory,onChange:function(t){f(Object(i.a)(Object(i.a)({},d),{},{piDirectory:t.target.value}))}}),Object(O.jsx)("button",{id:"run",className:"Door-button Door-"+(r.connected?"close":"open")+" "+P,style:{height:"30%"},onClick:function(t){},children:r.connected?"Stop":"Run"}),Object(O.jsx)("button",{id:"pair",className:"Door-button Door-pair "+P,style:{height:"30%"},onClick:function(t){},children:"Pair"})]})]})})})},C=function(t){t&&t instanceof Function&&n.e(3).then(n.bind(null,42)).then((function(e){var n=e.getCLS,o=e.getFID,c=e.getFCP,a=e.getLCP,s=e.getTTFB;n(t),o(t),c(t),a(t),s(t)}))};s.a.render(Object(O.jsx)(c.a.StrictMode,{children:Object(O.jsx)(S,{})}),document.getElementById("root")),C()}},[[41,1,2]]]);
//# sourceMappingURL=main.51e4c019.chunk.js.map